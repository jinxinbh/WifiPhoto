//
//  TOSMBExifDownloadTask.m
//  test
//
//  Created by 金鑫 on 15/12/20.
//  Copyright © 2015年 -JSX-. All rights reserved.
//

#import "TOSMBExifDownloadTask.h"
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>

#import "TOSMBClient.h"
#import "smb_session.h"
#import "smb_share.h"
#import "smb_file.h"
#import "smb_defs.h"
//#include "EXIF.H"
//#include <iostream>

@interface TOSMBSession ()


@property (readonly) NSOperationQueue *downloadsQueue;

- (NSError *)attemptConnectionWithSessionPointer:(smb_session *)session;
- (NSString *)shareNameFromPath:(NSString *)path;
- (NSString *)filePathExcludingSharePathFromPath:(NSString *)path;
- (void)resumeDownloadTask:(TOSMBSessionDownloadTask *)task;





@end

@interface TOSMBExifDownloadTask ()

@property (assign, readwrite) TOSMBSessionDownloadTaskState state;

@property (nonatomic, strong, readwrite) NSString *sourceFilePath;
@property (nonatomic, strong, readwrite) NSString *destinationFilePath;
@property (nonatomic, strong) NSString *tempFilePath;

@property (nonatomic, weak, readwrite) TOSMBSession *session;
@property (nonatomic, strong) TOSMBSessionFile *file;
@property (assign) smb_session *downloadSession;
@property (nonatomic, strong) NSBlockOperation *downloadOperation;

@property (assign,readwrite) int64_t countOfBytesReceived;
@property (assign,readwrite) int64_t countOfBytesExpectedToReceive;

@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;

/** Feedback handlers */
@property (nonatomic, weak) id<TOSMBExifDownloadTaskDelegate> delegate;

@property (nonatomic, copy) void (^progressHandler)(uint64_t totalBytesWritten, uint64_t totalBytesExpected);
@property (nonatomic, copy) void (^successHandler)(NSString *filePath);
@property (nonatomic, copy) void (^failHandler)(NSError *error);

/* Download methods */
- (void)setupDownloadOperation;
- (void)performDownloadWithOperation:(__weak NSBlockOperation *)weakOperation;
- (TOSMBSessionFile *)requestFileForItemAtPath:(NSString *)filePath inTree:(smb_tid)treeID;

/* File Path Methods */
- (NSString *)hashForFilePath;
- (NSString *)filePathForTemporaryDestination;
- (NSString *)finalFilePathForDownloadedFile;
- (NSString *)documentsDirectory;

/* Feedback events sent to either the delegate or callback blocks */
- (void)didSucceedWithFilePath:(NSString *)filePath;
- (void)didFailWithError:(NSError *)error;
- (void)didUpdateWriteBytes:(uint64_t)bytesWritten totalBytesWritten:(uint64_t)totalBytesWritten totalBytesExpected:(uint64_t)totalBytesExpected;
- (void)didResumeAtOffset:(uint64_t)bytesWritten totalBytesExpected:(uint64_t)totalBytesExpected;

@end


@implementation TOSMBExifDownloadTask


- (instancetype)init
{
    //This class cannot be instantiated on its own.
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initWithSession:(TOSMBSession *)session filePath:(NSString *)filePath destinationPath:(NSString *)destinationPath delegate:(id<TOSMBExifDownloadTaskDelegate>)delegate
{
    if (self = [super init]) {
        _session = session;
        _sourceFilePath = filePath;
        _destinationFilePath = destinationPath.length ? destinationPath : [self documentsDirectory];
        _delegate = delegate;
        
        _tempFilePath = [self filePathForTemporaryDestination];
    }
    
    return self;
}

- (instancetype)initWithSession:(TOSMBSession *)session filePath:(NSString *)filePath destinationPath:(NSString *)destinationPath progressHandler:(id)progressHandler successHandler:(id)successHandler failHandler:(id)failHandler
{
    if (self = [super init]) {
        _session = session;
        _sourceFilePath = filePath;
        _destinationFilePath = destinationPath.length ? destinationPath : [self documentsDirectory];
        
        _progressHandler = progressHandler;
        _successHandler = successHandler;
        _failHandler = failHandler;
        
        _tempFilePath = [self filePathForTemporaryDestination];
    }
    
    return self;
}

- (void)dealloc
{
    smb_session_destroy(self.downloadSession);
}
#pragma mark - Temporary Destination Methods -
- (NSString *)filePathForTemporaryDestination
{
    NSString *fileName = [[self hashForFilePath] stringByAppendingPathExtension:@"smb.data"];
    return [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
}

- (NSString *)hashForFilePath
{
    NSString *filePath = self.sourceFilePath.lowercaseString;
    
    NSData *data = [filePath dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
    {
        [output appendFormat:@"%02x", digest[i]];
    }
    
    return [NSString stringWithString:output];
}

- (NSString *)finalFilePathForDownloadedFile
{
    NSString *path = self.destinationFilePath;
    
    //Check to ensure the destination isn't referring to a file name
    NSString *fileName = [path lastPathComponent];
    BOOL isFile = ([fileName rangeOfString:@"."].location != NSNotFound && [fileName characterAtIndex:0] != '.');
    
    NSString *folderPath = nil;
    if (isFile) {
        folderPath = [path stringByDeletingLastPathComponent];
    }
    else {
        fileName = [self.sourceFilePath lastPathComponent];
        folderPath = path;
    }
    
    path = [folderPath stringByAppendingPathComponent:fileName];
    
    //If a file with that name already exists in the destination directory, append a number on the end of the file name
    NSString *newFilePath = path;
    NSString *newFileName = fileName;
    NSInteger index = 1;
    while ([[NSFileManager defaultManager] fileExistsAtPath:newFilePath]) {
        newFileName = [NSString stringWithFormat:@"%@-%ld.%@", [fileName stringByDeletingPathExtension], (long)index++, [fileName pathExtension]];
        newFilePath = [folderPath stringByAppendingPathComponent:newFileName];
    }
    
    return newFilePath;
}

- (NSString *)documentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    return basePath;
}

#pragma mark - Public Control Methods -
- (void)resume
{
    if (self.state == TOSMBSessionDownloadTaskStateRunning)
        return;
    
    [self setupDownloadOperation];
    [self.session.downloadsQueue addOperation:self.downloadOperation];
    self.state = TOSMBSessionDownloadTaskStateRunning;
}

- (void)suspend
{
    if (self.state != TOSMBSessionDownloadTaskStateRunning)
        return;
    
    [self.downloadOperation cancel];
    self.state = TOSMBSessionDownloadTaskStateSuspended;
    self.downloadOperation = nil;
}

- (void)cancel
{
    if (self.state != TOSMBSessionDownloadTaskStateRunning)
        return;
    
    id deleteBlock = ^{
        [[NSFileManager defaultManager] removeItemAtPath:self.tempFilePath error:nil];
    };
    
    NSBlockOperation *deleteOperation = [[NSBlockOperation alloc] init];
    [deleteOperation addExecutionBlock:deleteBlock];
    [deleteOperation addDependency:self.downloadOperation];
    [self.session.downloadsQueue addOperation:deleteOperation];
    
    [self.downloadOperation cancel];
    self.state = TOSMBSessionDownloadTaskStateCancelled;
    
    self.downloadOperation = nil;
}

#pragma mark - Feedback Methods -
- (BOOL)canBeResumed
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.tempFilePath] == NO)
        return NO;
    
    NSDate *modificationTime = [[[NSFileManager defaultManager] attributesOfItemAtPath:self.tempFilePath error:nil] fileModificationDate];
    if ([modificationTime isEqual:self.file.modificationTime] == NO) {
        return NO;
    }
    
    return YES;
}

- (void)didSucceedWithFilePath:(NSString *)filePath
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(downloadTask:didFinishDownloadingToPath:)])
            [self.delegate downloadTask:self didFinishDownloadingToPath:filePath];
        
        if (self.successHandler)
            self.successHandler(filePath);
    });
}

- (void)didFailWithError:(NSError *)error
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(downloadTask:didCompleteWithError:)])
            [self.delegate downloadTask:self didCompleteWithError:error];
        
        if (self.failHandler)
            self.failHandler(error);
    });
}

- (void)didUpdateWriteBytes:(uint64_t)bytesWritten totalBytesWritten:(uint64_t)totalBytesWritten totalBytesExpected:(uint64_t)totalBytesExpected
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(downloadTask:didWriteBytes:totalBytesReceived:totalBytesExpectedToReceive:)])
            [self.delegate downloadTask:self didWriteBytes:bytesWritten totalBytesReceived:self.countOfBytesReceived totalBytesExpectedToReceive:self.countOfBytesExpectedToReceive];
        
        if (self.progressHandler)
            self.progressHandler(self.countOfBytesReceived, self.countOfBytesExpectedToReceive);
    }];
}

- (void)didResumeAtOffset:(uint64_t)bytesWritten totalBytesExpected:(uint64_t)totalBytesExpected
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(downloadTask:didResumeAtOffset:totalBytesExpectedToReceive:)])
            [self.delegate downloadTask:self didResumeAtOffset:bytesWritten totalBytesExpectedToReceive:totalBytesExpected];
    }];
}

#pragma mark - Downloading -
- (TOSMBSessionFile *)requestFileForItemAtPath:(NSString *)filePath inTree:(smb_tid)treeID
{
    const char *fileCString = [filePath cStringUsingEncoding:NSUTF8StringEncoding];
    smb_stat fileStat = smb_fstat(self.downloadSession, treeID, fileCString);
    if (!fileStat)
        return nil;
    
    TOSMBSessionFile *file = [[TOSMBSessionFile alloc] initWithStat:fileStat session:nil parentDirectoryFilePath:filePath];
    
    smb_stat_destroy(fileStat);
    
    return file;
}

- (void)setupDownloadOperation
{
    if (self.downloadOperation)
        return;
    
    NSBlockOperation *operation = [[NSBlockOperation alloc] init];
    
    __weak typeof (self) weakSelf = self;
    __weak NSBlockOperation *weakOperation = operation;
    
    id executionBlock = ^{
        [weakSelf performDownloadWithOperation:weakOperation];
    };
    [operation addExecutionBlock:executionBlock];
    operation.completionBlock = ^{
        weakSelf.downloadOperation = nil;
    };
    
    self.downloadOperation = operation;
}

- (void)performDownloadWithOperation:(__weak NSBlockOperation *)weakOperation
{
    if (weakOperation.isCancelled)
        return;
    
    smb_tid treeID;
    smb_fd fileID;
    
    //---------------------------------------------------------------------------------------
    //Set up a cleanup block that'll release any handles before cancellation
    void (^cleanup)(void) = ^{
        
        //Release the background task handler, making the app eligible to be suspended now
        if (self.backgroundTaskIdentifier)
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
        
        if (treeID)
            smb_tree_disconnect(self.downloadSession, treeID);
        
        if (fileID)
            smb_fclose(self.downloadSession, fileID);
        
        if (self.downloadSession) {
            smb_session_destroy(self.downloadSession);
            self.downloadSession = nil;
        }
    };
    
    //---------------------------------------------------------------------------------------
    //Connect to SMB device
    
    self.downloadSession = smb_session_new();
    
    //First, check to make sure the file is there, and to acquire its attributes
    NSError *error = [self.session attemptConnectionWithSessionPointer:self.downloadSession];
    if (error) {
        [self didFailWithError:error];
        cleanup();
        return;
    }
    
    if (weakOperation.isCancelled) {
        cleanup();
        return;
    }
    
    //---------------------------------------------------------------------------------------
    //Connect to share
    
    //Next attach to the share we'll be using
    NSString *shareName = [self.session shareNameFromPath:self.sourceFilePath];
    const char *shareCString = [shareName cStringUsingEncoding:NSUTF8StringEncoding];
    treeID = smb_tree_connect(self.downloadSession, shareCString);
    if (!treeID) {
        [self didFailWithError:errorForErrorCode(TOSMBSessionErrorCodeShareConnectionFailed)];
        cleanup();
        return;
    }
    
    if (weakOperation.isCancelled) {
        cleanup();
        return;
    }
    
    //---------------------------------------------------------------------------------------
    //Find the target file
    
    NSString *pathExcludingShare = [self.session filePathExcludingSharePathFromPath:self.sourceFilePath];
    
    //Get the file info we'll be working off
    self.file = [self requestFileForItemAtPath:pathExcludingShare inTree:treeID];
    if (self.file == nil) {
        [self didFailWithError:errorForErrorCode(TOSMBSessionErrorCodeFileNotFound)];
        cleanup();
        return;
    }
    
    if (weakOperation.isCancelled) {
        cleanup();
        return;
    }
    
    if (self.file.directory) {
        [self didFailWithError:errorForErrorCode(TOSMBSessionErrorCodeDirectoryDownloaded)];
        cleanup();
        return;
    }
    
    self.countOfBytesExpectedToReceive = self.file.fileSize;
    
    //---------------------------------------------------------------------------------------
    //Open the file handle
    
    fileID = smb_fopen(self.downloadSession, treeID, [pathExcludingShare cStringUsingEncoding:NSUTF8StringEncoding], SMB_MOD_RO);
    if (!fileID) {
        [self didFailWithError:errorForErrorCode(TOSMBSessionErrorCodeFileNotFound)];
        cleanup();
        return;
    }
    
    if (weakOperation.isCancelled) {
        cleanup();
        return;
    }
    
    
    //---------------------------------------------------------------------------------------
    //Start downloading
    
    
//    EXIFINFO exifinfo;
//    
//    memset(&exifinfo, 0, sizeof(EXIFINFO));
    

    
//    Cexif* cexif;
//    cexif= cexif->init(&exifinfo);
    
    
    //exif.DecodeExif(hFile);
    

    
   
    

    
    
    
    
    
    
    
    
    
    //Create the directories to the download destination
    [[NSFileManager defaultManager] createDirectoryAtPath:[self.tempFilePath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    
    //Create a new blank file to write to
    if (self.canBeResumed == NO)
        [[NSFileManager defaultManager] createFileAtPath:self.tempFilePath contents:nil attributes:nil];
    
    //Open a handle to the file and skip ahead if we're resuming
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.tempFilePath];
    
    
    unsigned long seekOffset = [fileHandle seekToEndOfFile];
    self.countOfBytesReceived = seekOffset;
    
    //Create a background handle so the download will continue even if the app is suspended
    self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{ [self suspend]; }];
    
    if (seekOffset > 0) {
        smb_fseek(self.downloadSession, fileID, seekOffset, SMB_SEEK_SET);
        [self didResumeAtOffset:seekOffset totalBytesExpected:self.countOfBytesExpectedToReceive];
    }
    

    //Exif Download added by jinxinbh
    
  
    
    if (![self DecodeExif:fileID])
    {
        NSLog(@"Read Exif Failed");
    }
    
//    uint64_t bytesRead =0;
//    char* jpegHeadBytes =(char *)malloc(6);
//    bytesRead = smb_fread(self.downloadSession,fileID,jpegHeadBytes,6);
//  
//    
//    
//    if((Byte)jpegHeadBytes[0]== 0xff && (Byte)jpegHeadBytes[1] == 0xD8)//isJPEG
//    {
//        if((Byte)jpegHeadBytes[2]==0xff && (Byte)jpegHeadBytes[3] == 0xE1)//isExif
//        {
//            
////            unsigned long seekOffset = 9;
////            smb_fseek(self.downloadSession, fileID, seekOffset, SMB_SEEK_SET);
//            
//            int lh = (Byte)jpegHeadBytes[4];
//            int ll = (Byte)jpegHeadBytes[5];
//
//    
//            NSInteger itemlen = (lh << 8) | ll;
//            
//
//            char* buffer = (char *)malloc(itemlen);
//        
//            buffer[0] = (char)lh;
//            buffer[1] = (char)ll;
//            
//           // char * charBuf = data+2*sizeof(char);
//            
//            bytesRead = smb_fread(self.downloadSession,fileID,buffer+2,itemlen-2);
//            
//            [self process_EXIF:buffer length:(unsigned int)itemlen];
//            
//            
//            
//            
//            
//            
//    
//        }
//    }
    
   
    

    
    
    
    
    
    
    
    
    
    
    
    // original code of TO
    //Perform the file download
//    uint64_t bytesRead = 0;
//    NSInteger bufferSize = 65535;
//    char *buffer = (char *)malloc(bufferSize);
//    
//    do {
//        bytesRead = smb_fread(self.downloadSession, fileID, buffer, bufferSize);
//        [fileHandle writeData:[NSData dataWithBytes:buffer length:bufferSize]];
//        
//        if (weakOperation.isCancelled)
//            break;
//        
//        self.countOfBytesReceived += bytesRead;
//        
//        [self didUpdateWriteBytes:bytesRead totalBytesWritten:self.countOfBytesReceived totalBytesExpected:self.countOfBytesExpectedToReceive];
//    } while (bytesRead > 0);
    
    //Set the modification date to match the one on the SMB device so we can compare the two at a later date
    
    
    [[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate:self.file.modificationTime} ofItemAtPath:self.tempFilePath error:nil];
    
   // free(buffer);
    [fileHandle closeFile];
    
    if (weakOperation.isCancelled) {
        cleanup();
        return;
    }
    
    //---------------------------------------------------------------------------------------
    //Move the finished file to its destination
    
    //Workout the destination of the file and move it
    NSString *finalDestinationPath = [self finalFilePathForDownloadedFile];
    [[NSFileManager defaultManager] moveItemAtPath:self.tempFilePath toPath:finalDestinationPath error:nil];
    
    self.state =TOSMBSessionDownloadTaskStateCompleted;
    
    //Alert the delegate that we finished, so they may perform any additional cleanup operations
    [self didSucceedWithFilePath:finalDestinationPath];
    
    //Perform a final cleanup of all handles and references
    cleanup();
}



//--------------------------------------------------------------------------
// Get 16 bits motorola order (always) for jpeg header stuff.
//--------------------------------------------------------------------------
-(int) Get16m:(Byte *) Short
{
    int value;
    int first = (Byte)Short[0];
    int second = (Byte)Short[1];
    value = first << 8 | second;
    return value;
   // return (((unsigned char *)Short)[0] << 8) | ((unsigned char *)Short)[1];
}


/*--------------------------------------------------------------------------
 Convert a 16 bit unsigned value from file's native unsigned char order
 --------------------------------------------------------------------------*/
-(int) Get16u:(Byte *) Short
{
    int value;
    
    int first = (Byte)Short[0];
    int second = (Byte)Short[1];
    
    if (motorolaOrder)
    {
        value = first << 8 | second ;
        return value;
       // return (((unsigned char *)Short)[0] << 8) | ((unsigned char *)Short)[1];
    }
    else
    {
        value = second << 8 | first;
        return value;
        //return (((unsigned char *)Short)[1] << 8) | ((unsigned char *)Short)[0];
    }
}
////////////////////////////////////////////////////////////////////////////////
/*--------------------------------------------------------------------------
 Convert a 32 bit signed value from file's native unsigned char order
 --------------------------------------------------------------------------*/
-(long) Get32s:(Byte *) Long
{
    
    long value;
    
    long first = (Byte)Long[0];
    long second = (Byte)Long[1];
    long third = (Byte)Long[2];
    long fourth = (Byte)Long[3];
    
    
    if (motorolaOrder)
    {
        value = first << 24 | second << 16 | third << 8 | fourth << 0;
        return value;
        
        
//        return  ((( char *)Long)[0] << 24) | (((unsigned char *)Long)[1] << 16)
//        | (((unsigned char *)Long)[2] << 8 ) | (((unsigned char *)Long)[3] << 0 );
    }
    else
    {
        value = fourth << 24 | third << 16 | second << 8 | first << 0;
        return value;
//        return  ((( char *)Long)[3] << 24) | (((unsigned char *)Long)[2] << 16)
//        | (((unsigned char *)Long)[1] << 8 ) | (((unsigned char *)Long)[0] << 0 );
    }
}
////////////////////////////////////////////////////////////////////////////////
/*--------------------------------------------------------------------------
 Convert a 32 bit unsigned value from file's native unsigned char order
 --------------------------------------------------------------------------*/
-(unsigned long) Get32u:(Byte *) Long
{
    unsigned long value;
    value = [self Get32s:Long];
    return value & 0xffffffff;
    
  //  return (unsigned long)Get32s(Long) & 0xffffffff;
    
//    long get32s;
//    
//    if (motorolaOrder)
//    {
//        get32s = ((( char *)Long)[0] << 24) | (((unsigned char *)Long)[1] << 16)
//        | (((unsigned char *)Long)[2] << 8 ) | (((unsigned char *)Long)[3] << 0 );
//        
//         return (unsigned long)get32s & 0xffffffff;
//    }
//    
//    else
//    {
//        get32s =  ((( char *)Long)[3] << 24) | (((unsigned char *)Long)[2] << 16)
//        | (((unsigned char *)Long)[1] << 8 ) | (((unsigned char *)Long)[0] << 0 );
//        
//        return (unsigned long)get32s & 0xffffffff;
//    }
    
}



-(BOOL)process_EXIF:(Byte *)charBuf length:(unsigned int)length
{
    memset(&m_exifinfo, 0, sizeof(EXIFINFO));
    m_exifinfo.FlashUsed = 0;
    
    
    m_exifinfo.FlashUsed = 0;
    /* If it's from a digicam, and it used flash, it says so. */
    m_exifinfo.Comments[0] = '\0';  /* Initial value - null string */
    
    ExifImageWidth = 0;
    
    
    
    //   int MMorII = (Byte)charBuf[8];
    
    Byte* CharBuf = (Byte*)(charBuf);
    
    if(CharBuf[6] == 0x49)
    {
        motorolaOrder = 0;
    }
    else
    {
        if(CharBuf[6] == 0x4D)
        {
            motorolaOrder = 1;
        }
        else
        {
            NSLog(@"Invalid Exif alignment marker.");
        }
    }
    
    /* Check the next two values for correctness. */
    
    int get16u =[self Get16u:(CharBuf+8)];
    
    if (get16u!= 0x2a){
        NSLog(@"Invalid Exif start (1)");
        return 0;
    }
    
    int FirstOffset = (int)[self Get32u:(Byte*)(CharBuf+10)];
    if (FirstOffset < 8 || FirstOffset > 16){
        // I used to ensure this was set to 8 (website I used indicated its 8)
        // but PENTAX Optio 230 has it set differently, and uses it as offset. (Sept 11 2002)
        NSLog(@"Suspicious offset of first IFD value");
        return 0;
    }
    
    unsigned char * LastExifRefd = CharBuf;
    
    /* First directory starts 16 unsigned chars in.  Offsets start at 8 unsigned chars in. */
    
    if (![self ProcessExifDir:CharBuf+14 OffsetBase:CharBuf+6 ExifLength:length-6 p_exifinfo:&m_exifinfo LastExifRefdP:&LastExifRefd])
        return 0;
    
    /* This is how far the interesting (non thumbnail) part of the exif went. */
    // int ExifSettingsLength = LastExifRefd - CharBuf;
    
    /* Compute the CCD width, in milimeters. */
    if (m_exifinfo.FocalplaneXRes != 0){
        m_exifinfo.CCDWidth = (float)(ExifImageWidth * m_exifinfo.FocalplaneUnits / m_exifinfo.FocalplaneXRes);
    }
    
    return YES;
}


//bool Cexif::ProcessExifDir(unsigned char * DirStart, unsigned char * OffsetBase, unsigned ExifLength, EXIFINFO * const m_exifinfo, unsigned char ** const LastExifRefdP )



-(BOOL)ProcessExifDir:(Byte *)DirStart
           OffsetBase:(Byte *)OffsetBase
           ExifLength:(unsigned)ExifLength
           p_exifinfo:(EXIFINFO *)p_exifinfo
           LastExifRefdP:(unsigned char ** const)LastExifRefdP
{
    int de;
    int a;
    int NumDirEntries;
    unsigned ThumbnailOffset = 0;
    unsigned ThumbnailSize = 0;
    
    
    NumDirEntries = [self Get16u:DirStart];
    
    if ((DirStart+2+NumDirEntries*12) > (OffsetBase+ExifLength)){
        NSLog(@"Illegally sized directory");
        return 0;
    }
    
    
    
    for (de=0;de<NumDirEntries;de++){
        int Tag, Format, Components;
        unsigned char * ValuePtr;
        /* This actually can point to a variety of things; it must be
         cast to other types when used.  But we use it as a unsigned char-by-unsigned char
         cursor, so we declare it as a pointer to a generic unsigned char here.
         */
        int BytesCount;
        unsigned char * DirEntry;
        DirEntry = DirStart+2+12*de;
        
        Tag = [self Get16u:DirEntry];
        Format = [self Get16u:(DirEntry+2)];
        Components = (int)[self Get32u:(DirEntry+4)];
        
        if ((Format-1) >= NUM_FORMATS) {
            /* (-1) catches illegal zero case as unsigned underflows to positive large */
            NSLog(@"Illegal format code in EXIF dir");
            return 0;
        }
        
        BytesCount = Components * BytesPerFormat[Format];
        
        if (BytesCount > 4){
            unsigned OffsetVal;
            OffsetVal = (unsigned int)[self Get32u:(DirEntry+8)];
            /* If its bigger than 4 unsigned chars, the dir entry contains an offset.*/
            if (OffsetVal+BytesCount > ExifLength){
                /* Bogus pointer offset and / or unsigned charcount value */
                NSLog(@"Illegal pointer offset value in EXIF.");
                return 0;
            }
            ValuePtr = OffsetBase+OffsetVal;
        }else{
            /* 4 unsigned chars or less and value is in the dir entry itself */
            ValuePtr = DirEntry+8;
        }
        
        if (*LastExifRefdP < ValuePtr+BytesCount){
            /* Keep track of last unsigned char in the exif header that was
             actually referenced.  That way, we know where the
             discardable thumbnail data begins.
             */
            *LastExifRefdP = ValuePtr+BytesCount;
        }
        
        /* Extract useful components of tag */
        switch(Tag){
                
            case TAG_MAKE:
                strncpy(p_exifinfo->CameraMake, (char*)ValuePtr, 31);
                break;
                
            case TAG_MODEL:
                strncpy(p_exifinfo->CameraModel, (char*)ValuePtr, 39);
                break;
                
            case TAG_EXIF_VERSION:
                strncpy(p_exifinfo->Version,(char*)ValuePtr, 4);
                break;
                
            case TAG_DATETIME_ORIGINAL:
                strncpy(p_exifinfo->DateTime, (char*)ValuePtr, 19);
                break;
                
            case TAG_USERCOMMENT:
                // Olympus has this padded with trailing spaces. Remove these first.
                for (a=BytesCount;;){
                    a--;
                    if (((char*)ValuePtr)[a] == ' '){
                        ((char*)ValuePtr)[a] = '\0';
                    }else{
                        break;
                    }
                    if (a == 0) break;
                }
                
                /* Copy the comment */
                if (memcmp(ValuePtr, "ASCII",5) == 0){
                    for (a=5;a<10;a++){
                        char c;
                        c = ((char*)ValuePtr)[a];
                        if (c != '\0' && c != ' '){
                            strncpy(p_exifinfo->Comments, (char*)ValuePtr+a, 199);
                            break;
                        }
                    }
                    
                }else{
                    strncpy(p_exifinfo->Comments, (char*)ValuePtr, 199);
                }
                break;
                
            case TAG_FNUMBER:
                /* Simplest way of expressing aperture, so I trust it the most.
                 (overwrite previously computd value if there is one)
                 */
                p_exifinfo->ApertureFNumber =
                (float)[self ConvertAnyFormat:ValuePtr Format:Format];
               
                break;
                
            case TAG_APERTURE:
            case TAG_MAXAPERTURE:
                /* More relevant info always comes earlier, so only
                 use this field if we don't have appropriate aperture
                 information yet.
                 */
                if (p_exifinfo->ApertureFNumber == 0){
                    p_exifinfo->ApertureFNumber = (float)exp([self ConvertAnyFormat:ValuePtr Format:Format]*log(2)*0.5);
                }
                break;
                
            case TAG_BRIGHTNESS:
                p_exifinfo->Brightness = (float)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_FOCALLENGTH:
                /* Nice digital cameras actually save the focal length
                 as a function of how farthey are zoomed in.
                 */
                
                p_exifinfo->FocalLength = (float)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_SUBJECT_DISTANCE:
                /* Inidcates the distacne the autofocus camera is focused to.
                 Tends to be less accurate as distance increases.
                 */
                p_exifinfo->Distance = (float)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_EXPOSURETIME:
                /* Simplest way of expressing exposure time, so I
                 trust it most.  (overwrite previously computd value
                 if there is one)
                 */
                p_exifinfo->ExposureTime =
                (float)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_SHUTTERSPEED:
                /* More complicated way of expressing exposure time,
                 so only use this value if we don't already have it
                 from somewhere else.
                 */
                if (p_exifinfo->ExposureTime == 0){
                    p_exifinfo->ExposureTime = (float)
                    (1/exp([self ConvertAnyFormat:ValuePtr Format:Format]*log(2)));
                }
                break;
                
            case TAG_FLASH:
                if ((int)[self ConvertAnyFormat:ValuePtr Format:Format] & 7){
                    p_exifinfo->FlashUsed = 1;
                }else{
                    p_exifinfo->FlashUsed = 0;
                }
                break;
                
            case TAG_ORIENTATION:
                p_exifinfo->Orientation = (int)[self ConvertAnyFormat:ValuePtr Format:Format];
                if (p_exifinfo->Orientation < 1 || p_exifinfo->Orientation > 8){
                    NSLog(@"Undefined rotation value");
                    p_exifinfo->Orientation = 0;
                }
                break;
                
            case TAG_EXIF_IMAGELENGTH:
            case TAG_EXIF_IMAGEWIDTH:
                /* Use largest of height and width to deal with images
                 that have been rotated to portrait format.
                 */
                a = (int)[self ConvertAnyFormat:ValuePtr Format:Format];
                if (ExifImageWidth < a) ExifImageWidth = a;
                break;
                
            case TAG_FOCALPLANEXRES:
                p_exifinfo->FocalplaneXRes = (float)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_FOCALPLANEYRES:
                p_exifinfo->FocalplaneYRes = (float)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_RESOLUTIONUNIT:
                switch((int)[self ConvertAnyFormat:ValuePtr Format:Format]){
                    case 1: p_exifinfo->ResolutionUnit = 1.0f; break; /* 1 inch */
                    case 2:	p_exifinfo->ResolutionUnit = 1.0f; break;
                    case 3: p_exifinfo->ResolutionUnit = 0.3937007874f;    break;  /* 1 centimeter*/
                    case 4: p_exifinfo->ResolutionUnit = 0.03937007874f;   break;  /* 1 millimeter*/
                    case 5: p_exifinfo->ResolutionUnit = 0.00003937007874f;  /* 1 micrometer*/
                }
                break;
                
            case TAG_FOCALPLANEUNITS:
                switch((int)[self ConvertAnyFormat:ValuePtr Format:Format]){
                    case 1: p_exifinfo->FocalplaneUnits = 1.0f; break; /* 1 inch */
                    case 2:	p_exifinfo->FocalplaneUnits = 1.0f; break;
                    case 3: p_exifinfo->FocalplaneUnits = 0.3937007874f;    break;  /* 1 centimeter*/
                    case 4: p_exifinfo->FocalplaneUnits = 0.03937007874f;   break;  /* 1 millimeter*/
                    case 5: p_exifinfo->FocalplaneUnits = 0.00003937007874f;  /* 1 micrometer*/
                }
                break;
                
                // Remaining cases contributed by: Volker C. Schoech <schoech(at)gmx(dot)de>
                
            case TAG_EXPOSURE_BIAS:
                p_exifinfo->ExposureBias = (float)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_WHITEBALANCE:
                p_exifinfo->Whitebalance = (int)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_METERING_MODE:
                p_exifinfo->MeteringMode = (int)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_EXPOSURE_PROGRAM:
                p_exifinfo->ExposureProgram = (int)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_ISO_EQUIVALENT:
                p_exifinfo->ISOequivalent = (int)[self ConvertAnyFormat:ValuePtr Format:Format];
                if ( p_exifinfo->ISOequivalent < 50 ) p_exifinfo->ISOequivalent *= 200;
                break;
                
            case TAG_COMPRESSION_LEVEL:
                p_exifinfo->CompressionLevel = (int)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_XRESOLUTION:
                p_exifinfo->Xresolution = (float)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
            case TAG_YRESOLUTION:
                p_exifinfo->Yresolution = (float)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_THUMBNAIL_OFFSET:
                ThumbnailOffset = (unsigned)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
            case TAG_THUMBNAIL_LENGTH:
                ThumbnailSize = (unsigned)[self ConvertAnyFormat:ValuePtr Format:Format];
                break;
                
        }
        
        if (Tag == TAG_EXIF_OFFSET || Tag == TAG_INTEROP_OFFSET){
            unsigned char * SubdirStart;
            SubdirStart = OffsetBase + [self Get32u:(ValuePtr)];
            if (SubdirStart < OffsetBase ||
                SubdirStart > OffsetBase+ExifLength){
                NSLog(@"Illegal subdirectory link");
                return 0;
            }
           
            [self ProcessExifDir:SubdirStart OffsetBase:OffsetBase ExifLength:ExifLength p_exifinfo:p_exifinfo LastExifRefdP:LastExifRefdP];
            
         
            
           // ProcessExifDir(SubdirStart, OffsetBase, ExifLength, p_exifinfo, LastExifRefdP);
            continue;
        }
    }
    
    
    {
        /* In addition to linking to subdirectories via exif tags,
         there's also a potential link to another directory at the end
         of each directory.  This has got to be the result of a
         committee!
         */
        unsigned char * SubdirStart;
        unsigned Offset;
        Offset = [self Get16u:(DirStart+2+12*NumDirEntries)];
        if (Offset){
            SubdirStart = OffsetBase + Offset;
            if (SubdirStart < OffsetBase 
                || SubdirStart > OffsetBase+ExifLength){
                NSLog(@"Illegal subdirectory link");
                return 0;
            }
            
             [self ProcessExifDir:SubdirStart OffsetBase:OffsetBase ExifLength:ExifLength p_exifinfo:p_exifinfo LastExifRefdP:LastExifRefdP];
            
        }
    }
    
    
    if (ThumbnailSize && ThumbnailOffset){
        if (ThumbnailSize + ThumbnailOffset <= ExifLength){
            /* The thumbnail pointer appears to be valid.  Store it. */
            p_exifinfo->ThumbnailPointer = OffsetBase + ThumbnailOffset;
            p_exifinfo->ThumbnailSize = ThumbnailSize;
        }
    }
    
    
    
    return YES;
    
}



-(double) ConvertAnyFormat:(void *)ValuePtr  Format:(int)Format
{
    double Value;
    Value = 0;
    
    switch(Format){
        case FMT_SBYTE:     Value = *(signed char *)ValuePtr;  break;
        case FMT_BYTE:      Value = *(unsigned char *)ValuePtr;        break;
            
        case FMT_USHORT:    Value = [self Get16u:(ValuePtr)];          break;
        case FMT_ULONG:     Value = [self Get32u:(ValuePtr)];          break;
            
        case FMT_URATIONAL:
        case FMT_SRATIONAL:
        {
            int Num,Den;
            Num = (int)[self Get32s:(ValuePtr)];
            Den = (int)[self Get32s:(4+(Byte *)ValuePtr)];
            if (Den == 0){
                Value = 0;
            }else{
                Value = (double)Num/Den;
            }
            break;
        }
            
        case FMT_SSHORT:    Value = (signed short)[self Get16u:(ValuePtr)];  break;
        case FMT_SLONG:     Value = [self Get32s:(ValuePtr)];                break;
            
            /* Not sure if this is correct (never seen float used in Exif format)
             */
        case FMT_SINGLE:    Value = (double)*(float *)ValuePtr;      break;
        case FMT_DOUBLE:    Value = *(double *)ValuePtr;             break;
    }
    return Value;
}











-(bool) DecodeExif:(smb_fd) fileID;
{
    int a;
    int HaveCom = 0;
    
    
    uint64_t bytesRead =0;
    
    Byte* fgetc2 =(Byte *)malloc(2);
    bytesRead = smb_fread(self.downloadSession,fileID,fgetc2,2);
    
   // a = fgetc(hFile);
    
    if ((int)fgetc2[0] != 0xff || (int)fgetc2[1] != M_SOI){
        return 0;
    }
    
    for(;;){
        int itemlen;
        int marker = 0;
        int ll,lh;//, got;
        Byte * Data;
        
        if (SectionsRead >= MAX_SECTIONS){
            NSLog(@"Too many sections in jpg file");
            return 0;
        }
        
        Byte* fgetc1 =(Byte *)malloc(1);
        for (a=0;a<7;a++){
            bytesRead = smb_fread(self.downloadSession,fileID,fgetc1,1);
            marker = fgetc1[0];
           // marker = fgetc(hFile);
            if (marker != 0xff) break;
            
            if (a >= 6){
                printf("too many padding unsigned chars\n");
                return 0;
            }
        }
        
        if (marker == 0xff){
            // 0xff is legal padding, but if we get that many, something's wrong.
           NSLog(@"too many padding unsigned chars!");
            return 0;
        }
        
        Sections[SectionsRead].Type = marker;
        
        
         bytesRead = smb_fread(self.downloadSession,fileID,fgetc2,2);
        
        // Read the length of the section.
        lh = fgetc2[0];
        ll = fgetc2[1];
//        lh = fgetc(hFile);
//        ll = fgetc(hFile);
        
        itemlen = (lh << 8) | ll;
        
        if (itemlen < 2){
            NSLog(@"invalid marker");
            return 0;
        }
        
        Sections[SectionsRead].Size = itemlen;
        
        Data = (Byte *)malloc(itemlen);
        if (Data == NULL){
            NSLog(@"Could not allocate memory");
            return 0;
        }
        Sections[SectionsRead].Data = Data;
        
        // Store first two pre-read unsigned chars.
        Data[0] = (unsigned char)lh;
        Data[1] = (unsigned char)ll;
        
        
        bytesRead = smb_fread(self.downloadSession,fileID,Data+2,itemlen-2);
        
        //got = fread(Data+2, 1, itemlen-2,hFile); // Read the whole section.
        
        if (bytesRead != itemlen-2){
            NSLog(@"Premature end of file?");
            return 0;
        }
        SectionsRead += 1;
        
        switch(marker){
                
            case M_SOS:   // stop before hitting compressed data
                // If reading entire image is requested, read the rest of the data.
                /*if (ReadMode & READ_IMAGE){
                 int cp, ep, size;
                 // Determine how much file is left.
                 cp = ftell(infile);
                 fseek(infile, 0, SEEK_END);
                 ep = ftell(infile);
                 fseek(infile, cp, SEEK_SET);
                 
                 size = ep-cp;
                 Data = (uchar *)malloc(size);
                 if (Data == NULL){
                 strcpy(m_szLastError,"could not allocate data for entire image");
                 return 0;
                 }
                 
                 got = fread(Data, 1, size, infile);
                 if (got != size){
                 strcpy(m_szLastError,"could not read the rest of the image");
                 return 0;
                 }
                 
                 Sections[SectionsRead].Data = Data;
                 Sections[SectionsRead].Size = size;
                 Sections[SectionsRead].Type = PSEUDO_IMAGE_MARKER;
                 SectionsRead ++;
                 HaveAll = 1;
                 }*/
                return 1;
                
            case M_EOI:   // in case it's a tables-only JPEG stream
                printf("No image in jpeg!\n");
                return 0;
                
            case M_COM: // Comment section
                if (HaveCom){
                    // Discard this section.
                    free(Sections[--SectionsRead].Data);
                    Sections[SectionsRead].Data=0;
                }else{
                    
                    [self process_COM:Data length:itemlen];
                
                    //process_COM(Data, itemlen);
                    HaveCom = 1;
                }
                break;
                
            case M_JFIF:
                // Regular jpegs always have this tag, exif images have the exif
                // marker instead, althogh ACDsee will write images with both markers.
                // this program will re-create this marker on absence of exif marker.
                // hence no need to keep the copy from the file.
                free(Sections[--SectionsRead].Data);
                Sections[SectionsRead].Data=0;
                break;
                
            case M_EXIF:
                // Seen files from some 'U-lead' software with Vivitar scanner
                // that uses marker 31 for non exif stuff.  Thus make sure
                // it says 'Exif' in the section before treating it as exif.
                if (memcmp(Data+2, "Exif", 4) == 0)
                {
                    m_exifinfo.IsExif = [self process_EXIF:Data+2 length:(unsigned int)itemlen];
                    //m_exifinfo->IsExif = process_EXIF((unsigned char *)Data+2, itemlen);
                }
                else
                {
                    // Discard this section.
                    free(Sections[--SectionsRead].Data);
                    Sections[SectionsRead].Data=0;
                }
                break;
                
            case M_SOF0:
            case M_SOF1:
            case M_SOF2:
            case M_SOF3:
            case M_SOF5:
            case M_SOF6:
            case M_SOF7:
            case M_SOF9:
            case M_SOF10:
            case M_SOF11:
            case M_SOF13:
            case M_SOF14:
            case M_SOF15:
                [self process_SOFn:Data marker:marker];
               // process_SOFn(Data, marker);
                break;
            default:
                // Skip any other sections.
                //if (ShowTags) printf("Jpeg section marker 0x%02x size %d\n",marker, itemlen);
                break;
        }
    }
    return 1;
}




////////////////////////////////////////////////////////////////////////////////
-(void) process_COM:(const Byte *)Data length:(int)length
{
    int ch;
    char Comment[MAX_COMMENT+1];
    int nch;
    int a;
    
    nch = 0;
    
    if (length > MAX_COMMENT) length = MAX_COMMENT; // Truncate if it won't fit in our structure.
    
    for (a=2;a<length;a++){
        ch = Data[a];
        
        if (ch == '\r' && Data[a+1] == '\n') continue; // Remove cr followed by lf.
        
        if ((ch>=0x20) || ch == '\n' || ch == '\t'){
            Comment[nch++] = (char)ch;
        }else{
            Comment[nch++] = '?';
        }
    }
    
    Comment[nch] = '\0'; // Null terminate
    
    //if (ShowTags) printf("COM marker comment: %s\n",Comment);
    
    strcpy(m_exifinfo.Comments,Comment);
}
////////////////////////////////////////////////////////////////////////////////
-(void) process_SOFn:(const Byte *)Data marker:(int)marker
{
    int data_precision, num_components;
    
    data_precision = Data[2];
    m_exifinfo.Height = [self Get16m:((void*)(Data+3))];
    m_exifinfo.Width = [self Get16m:((void*)(Data+5))];
    num_components = Data[7];
    
    if (num_components == 3){
        m_exifinfo.IsColor = 1;
    }else{
        m_exifinfo.IsColor = 0;
    }
    
    m_exifinfo.Process = marker;
    
    //if (ShowTags) printf("JPEG image is %uw * %uh, %d color components, %d bits per sample\n",
    //               ImageInfo.Width, ImageInfo.Height, num_components, data_precision);
}
////////////////////////////////////////////////////////////////////////////////




@end
