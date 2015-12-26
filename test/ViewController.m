

//
//  ViewController.m
//  test
//
//  Created by 蒋尚秀 on 15/12/10.
//  Copyright © 2015年 -JSX-. All rights reserved.
//

#import "ViewController.h"
#import "TOSMBClient.h"
#import "TOFilesTableViewController.h"

@interface ViewController ()

@end

@implementation ViewController

-(id)init{
    if (self = [super init]) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _picView = [[PicViewController alloc] init];
    _picsArray = [[NSMutableArray alloc]init];
    _sortedPicsArray = [[NSArray alloc]init];
    _downloadPicsArray = [[NSMutableArray alloc]init];

    
    UIButton * button = [[UIButton alloc]initWithFrame:CGRectMake(100, 100, 100, 50)];
    
    button.backgroundColor = [UIColor redColor];
    
    [button addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    
    
}

-(void)buttonTapped
{

    // Windows
        TOSMBSession *session = [[TOSMBSession alloc] initWithHostName:@"" ipAddress:@"192.168.1.107"];
    [session setLoginCredentialsWithUserName:@"xiu" password:@"1"];
    
   //WD MyPassport
//    TOSMBSession *session = [[TOSMBSession alloc] initWithHostName:@"" ipAddress:@"192.168.1.109"];
//    [session setLoginCredentialsWithUserName:@"Admin" password:@"432868"];
    
    //Mac -jinxin
//    TOSMBSession *session = [[TOSMBSession alloc] initWithHostName:@"" ipAddress:@"192.168.1.100"];
//    [session setLoginCredentialsWithUserName:@"" password:@""];
    
    //Mac -xiu
//    TOSMBSession *session = [[TOSMBSession alloc] initWithHostName:@"" ipAddress:@"192.168.1.102"];
//    [session setLoginCredentialsWithUserName:@"蒋尚秀" password:@"1"];
    
    
    NSString * path = @"/";
    //NSString * path = @"//BaiduYunDownload/";
    //NSString * path = @"//单反/";
    //NSString * path = @"//pic/";
//    path = [path stringByAppendingString:@"//百度云同步盘/"];
    
    [self findAllPics:path session:session];
    
    [self presentViewController:_picView animated:YES completion:nil];

}

-(void)findAllPics:(NSString *)path session:(TOSMBSession *)session
{
    static int count=0;
    count++;
    NSLog(@"count=%d",count);

    NSComparator comparator = ^(TOSMBSessionFile * file1, TOSMBSessionFile * file2){
        if (file1.creationTime > file2.creationTime) {
            return NSOrderedDescending;
        }
        else if(file1.creationTime < file2.creationTime)
        {
            return NSOrderedAscending;
        }
        
        return NSOrderedSame;
    };
    
   
    [session requestContentsOfDirectoryAtFilePath:path success:^(NSArray *files) {
        int i=0;
        for (TOSMBSessionFile * file in files) {
            if (file.directory==YES) {
                [self findAllPics:file.filePath session:session];
                i++;
            }
            else
            {
                if ([[[file.filePath pathExtension] lowercaseString] isEqualToString:@"jpg"] ||
                    [[[file.filePath pathExtension] lowercaseString] isEqualToString:@"png"] ||
                    [[[file.filePath pathExtension] lowercaseString] isEqualToString:@"bmp"] ||
                    [[[file.filePath pathExtension] lowercaseString] isEqualToString:@"tiff"] ||
                    [[[file.filePath pathExtension] lowercaseString] isEqualToString:@"gif"]) {
                    
                    [_picsArray addObject:file];
                }
                i++;
            }
            if (i == files.count) {
                count--;
                if (count==0) {
                    NSLog(@"结束");
                    _sortedPicsArray = [_picsArray sortedArrayUsingComparator:comparator];
                    for (int i=0; i<9; i++) {
                        [_downloadPicsArray addObject:_picsArray[i]];
                        //[self download:_downloadPicsArray[i] session:session];
                       [self downloadExif:_downloadPicsArray[i] session:session];
                    }
                }
            }
        }
    } error:^(NSError *error) {
        NSLog(@"获取文件目录失败");
    }];
    
}

-(void)getExifInfo:(TOSMBSessionFile *)file
{
//    ImageInfoModel * imageInfo = [[ImageInfoModel alloc]init];
//    //图片
//    //    UIImage * image = [UIImage imageWithContentsOfFile:file.filePath];
//    NSString * pathStr = @"smb";
//    //    pathStr = [pathStr stringByAppendingString:file.filePath];
//    NSURL * imageUrl = [NSURL URLWithString:pathStr];
//    CGImageSourceRef imageRef = CGImageSourceCreateWithURL((__bridge CFURLRef)imageUrl, NULL);//((CFURLRef)imageUrl, NULL);
//    NSDictionary * imagePropertyDic = (NSDictionary *)CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(imageRef, 0, NULL));
//    
//    NSDictionary * exifDic = [imagePropertyDic valueForKey:(NSString*)kCGImagePropertyExifDictionary];
    
    
    
    //元数据
    //    NSDictionary *dict = [info objectForKey:UIImagePickerControllerMediaMetadata];
    //    NSMutableDictionary *metadata=[NSMutableDictionary dictionaryWithDictionary:dict];
    //    //EXIF数据
    //    NSMutableDictionary *EXIFDictionary =[[metadata objectForKey:(NSString *)kCGImagePropertyExifDictionary]mutableCopy];
    //    //GPS数据
    //    NSMutableDictionary *GPSDictionary = [[metadata objectForKey:(NSString *)kCGImagePropertyGPSDictionary]mutableCopy];
}

-(int)indexInArray:(NSString *)filePath
{
    for (int i=0; i<_downloadPicsArray.count; i++) {
        NSArray * namesArray1 = [((TOSMBSessionFile *)_downloadPicsArray[i]).filePath componentsSeparatedByString:@"/"];
        NSArray * namesArray2 = [filePath componentsSeparatedByString:@"/"];
        if ([namesArray1.lastObject isEqualToString:namesArray2.lastObject]) {
            return i;
        }
    }
    return 0;
}

-(void)downloadExif:(TOSMBSessionFile *)file session:(TOSMBSession *)session
{
    TOSMBExifDownloadTask * downloadTask = [session downloadExifForFileAtPath:file.filePath destinationPath:nil progressHandler:^(uint64_t totalBytesWritten, uint64_t totalBytesExpected) { NSLog(@"%f", (CGFloat)totalBytesWritten / (CGFloat) totalBytesExpected);}
                                                            completionHandler:^(NSString *filePath)
                                            {
                                                //                                                  NSLog(@"%d下载成功:%@",downloadFilesCount,filePath);
                                                [_picView.imageViewArray[[self indexInArray:filePath]] setImage:[UIImage imageWithContentsOfFile:filePath]];
                                            }
                                                                  failHandler:^(NSError *error) { NSLog(@"Error: %@", error.localizedDescription); }];
    [downloadTask resume];
}


-(void)download:(TOSMBSessionFile *)file session:(TOSMBSession *)session
{
    TOSMBSessionDownloadTask *downloadTask = [session downloadTaskForFileAtPath:file.filePath destinationPath:nil progressHandler:^(uint64_t totalBytesWritten, uint64_t totalBytesExpected) { NSLog(@"%f", (CGFloat)totalBytesWritten / (CGFloat) totalBytesExpected);}
                                                                   completionHandler:^(NSString *filePath)
                                              {
//                                                  NSLog(@"%d下载成功:%@",downloadFilesCount,filePath);
                                                  [_picView.imageViewArray[[self indexInArray:filePath]] setImage:[UIImage imageWithContentsOfFile:filePath]];
                                              }
                                                                         failHandler:^(NSError *error) { NSLog(@"Error: %@", error.localizedDescription); }];
    [downloadTask resume];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
