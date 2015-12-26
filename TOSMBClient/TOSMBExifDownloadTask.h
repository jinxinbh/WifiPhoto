//
//  TOSMBExifDownloadTask.h
//  test
//
//  Created by 金鑫 on 15/12/20.
//  Copyright © 2015年 -JSX-. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TOSMBConstants.h"


/* Describes format descriptor */
static const int BytesPerFormat[] = {0,1,1,2,4,8,1,1,2,4,8,4,8};
#define NUM_FORMATS 12

#define FMT_BYTE       1
#define FMT_STRING     2
#define FMT_USHORT     3
#define FMT_ULONG      4
#define FMT_URATIONAL  5
#define FMT_SBYTE      6
#define FMT_UNDEFINED  7
#define FMT_SSHORT     8
#define FMT_SLONG      9
#define FMT_SRATIONAL 10
#define FMT_SINGLE    11
#define FMT_DOUBLE    12

/* Describes tag values */

#define TAG_EXIF_VERSION      0x9000
#define TAG_EXIF_OFFSET       0x8769
#define TAG_INTEROP_OFFSET    0xa005

#define TAG_MAKE              0x010F
#define TAG_MODEL             0x0110

#define TAG_ORIENTATION       0x0112
#define TAG_XRESOLUTION       0x011A
#define TAG_YRESOLUTION       0x011B
#define TAG_RESOLUTIONUNIT    0x0128

#define TAG_EXPOSURETIME      0x829A
#define TAG_FNUMBER           0x829D

#define TAG_SHUTTERSPEED      0x9201
#define TAG_APERTURE          0x9202
#define TAG_BRIGHTNESS        0x9203
#define TAG_MAXAPERTURE       0x9205
#define TAG_FOCALLENGTH       0x920A

#define TAG_DATETIME_ORIGINAL 0x9003
#define TAG_USERCOMMENT       0x9286

#define TAG_SUBJECT_DISTANCE  0x9206
#define TAG_FLASH             0x9209

#define TAG_FOCALPLANEXRES    0xa20E
#define TAG_FOCALPLANEYRES    0xa20F
#define TAG_FOCALPLANEUNITS   0xa210
#define TAG_EXIF_IMAGEWIDTH   0xA002
#define TAG_EXIF_IMAGELENGTH  0xA003

/* the following is added 05-jan-2001 vcs */
#define TAG_EXPOSURE_BIAS     0x9204
#define TAG_WHITEBALANCE      0x9208
#define TAG_METERING_MODE     0x9207
#define TAG_EXPOSURE_PROGRAM  0x8822
#define TAG_ISO_EQUIVALENT    0x8827
#define TAG_COMPRESSION_LEVEL 0x9102

#define TAG_THUMBNAIL_OFFSET  0x0201
#define TAG_THUMBNAIL_LENGTH  0x0202



#define M_SOF0  0xC0            // Start Of Frame N
#define M_SOF1  0xC1            // N indicates which compression process
#define M_SOF2  0xC2            // Only SOF0-SOF2 are now in common use
#define M_SOF3  0xC3
#define M_SOF5  0xC5            // NB: codes C4 and CC are NOT SOF markers
#define M_SOF6  0xC6
#define M_SOF7  0xC7
#define M_SOF9  0xC9
#define M_SOF10 0xCA
#define M_SOF11 0xCB
#define M_SOF13 0xCD
#define M_SOF14 0xCE
#define M_SOF15 0xCF
#define M_SOI   0xD8            // Start Of Image (beginning of datastream)
#define M_EOI   0xD9            // End Of Image (end of datastream)
#define M_SOS   0xDA            // Start Of Scan (begins compressed data)
#define M_JFIF  0xE0            // Jfif marker
#define M_EXIF  0xE1            // Exif marker
#define M_COM   0xFE            // COMment


@class TOSMBSession;
@class TOSMBExifDownloadTask;

#define MAX_COMMENT 1000
#define MAX_SECTIONS 20

typedef struct tag_ExifInfo {
    char  Version      [5];
    char  CameraMake   [32];
    char  CameraModel  [40];
    char  DateTime     [20];
    int   Height, Width;
    int   Orientation;
    int   IsColor;
    int   Process;
    int   FlashUsed;
    float FocalLength;
    float ExposureTime;
    float ApertureFNumber;
    float Distance;
    float CCDWidth;
    float ExposureBias;
    int   Whitebalance;
    int   MeteringMode;
    int   ExposureProgram;
    int   ISOequivalent;
    int   CompressionLevel;
    float FocalplaneXRes;
    float FocalplaneYRes;
    float FocalplaneUnits;
    float Xresolution;
    float Yresolution;
    float ResolutionUnit;
    float Brightness;
    char  Comments[MAX_COMMENT];
    
    unsigned char * ThumbnailPointer;  /* Pointer at the thumbnail */
    unsigned ThumbnailSize;     /* Size of thumbnail. */
    
    bool  IsExif;
} EXIFINFO;


typedef struct tag_Section_t{
    unsigned char*    Data;
    int      Type;
    unsigned Size;
} Section_t;


@protocol TOSMBExifDownloadTaskDelegate <NSObject>


@optional

/**
 Delegate event that is called when the file has successfully completed downloading and was moved to its final destionation.
 If there was a file with the same name in the destination, the name of this file will be modified and this will be reflected in the
 `destinationPath` value
 
 @param downloadTask The download task object calling this delegate method.
 @param destinationPath The absolute file path to the file.
 */
- (void)downloadTask:(TOSMBExifDownloadTask *)downloadTask didFinishDownloadingToPath:(NSString *)destinationPath;

/**
 Delegate event that is called periodically as the download progresses, updating the delegate with the amount of data that has been downloaded.
 
 @param downloadTask The download task object calling this delegate method.
 @param bytesWritten The number of bytes written in this particular iteration
 @param totalBytesWrite The total number of bytes written to disk so far
 @param totalBytesTowWrite The expected number of bytes encompassing this entire file
 */
- (void)downloadTask:(TOSMBExifDownloadTask *)downloadTask
       didWriteBytes:(uint64_t)bytesWritten
  totalBytesReceived:(uint64_t)totalBytesReceived
totalBytesExpectedToReceive:(int64_t)totalBytesToReceive;

/**
 Delegate event that is called when a file download that was previously suspended is now resumed.
 
 @param downloadTask The download task object calling this delegate method.
 @param byteOffset The byte offset at which the download resumed.
 @param totalBytesToWrite The number of bytes expected to write for this entire file.
 */
- (void)downloadTask:(TOSMBExifDownloadTask *)downloadTask
   didResumeAtOffset:(uint64_t)byteOffset
totalBytesExpectedToReceive:(uint64_t)totalBytesToReceive;

/**
 Delegate event that is called when the file did not successfully complete.
 
 @param downloadTask The download task object calling this delegate method.
 @param error The error describing why the task failed.
 */
- (void)downloadTask:(TOSMBExifDownloadTask *)downloadTask didCompleteWithError:(NSError *)error;

@end


@interface TOSMBExifDownloadTask : NSObject
{
    EXIFINFO m_exifinfo;
    int motorolaOrder;
    int ExifImageWidth;
    Section_t Sections[MAX_SECTIONS];
    int SectionsRead;
}

/** The parent session that is managing this download task. (Retained by this class) */
@property (readonly, weak) TOSMBSession *session;

/** The file path to the target file on the SMB network device. */
@property (readonly) NSString *sourceFilePath;

/** The target file path that the file will be downloaded to. */
@property (readonly) NSString *destinationFilePath;

/** The number of bytes presently downloaded by this task */
@property (readonly) int64_t countOfBytesReceived;

/** The total number of bytes we expect to download */
@property (readonly) int64_t countOfBytesExpectedToReceive;

/** Returns if download data from a suspended task exists */
@property (readonly) BOOL canBeResumed;

/** The state of the download task. */
@property (readonly) TOSMBSessionDownloadTaskState state;

/**
 Resumes an existing download, or starts a new one otherwise.
 
 Downloads are resumed if there is already data for this file on disk,
 and the modification date of that file matches the one on the network device.
 */
- (void)resume;

/**
 Suspends a download and halts network activity.
 */
- (void)suspend;

/**
 Cancels a download, and deletes all related transient data on disk.
 */
- (void)cancel;



@end
