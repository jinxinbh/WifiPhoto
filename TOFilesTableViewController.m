
//
//  TOFilesViewControllerTableViewController.m
//  TOSMBClientExample
//
//  Created by Tim Oliver on 8/5/15.
//  Copyright (c) 2015 TimOliver. All rights reserved.
//

#import "TOFilesTableViewController.h"
#import "TOSMBClient.h"

@interface TOFilesTableViewController ()

@property (nonatomic, copy) NSString *directoryTitle;
@property (nonatomic, strong) TOSMBSession *session;

@end

@implementation TOFilesTableViewController

- (instancetype)initWithSession:(TOSMBSession *)session title:(NSString *)title
{
    if (self = [super initWithStyle:UITableViewStylePlain]) {
        _directoryTitle = title;
        _session = session;
        _picsArray = [[NSMutableArray alloc]init];
    }
    
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Loading...";
    
    picView = [[PicViewController alloc]init];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSLog(@"%lu",self.files.count);
    return self.files.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    
    TOSMBSessionFile *file = self.files[indexPath.row];
    cell.textLabel.text = file.name;
    cell.detailTextLabel.text = file.directory ? @"Directory" : [NSString stringWithFormat:@"File | Size: %ld", (long)file.fileSize];
    cell.accessoryType = file.directory ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    TOSMBSessionFile *file = self.files[indexPath.row];
    if (file.directory == YES) {
//        [self.rootController downloadFileFromSession:self.session atFilePath:file.filePath];
//        [self findAllPics:file.filePath];
        [self presentViewController:picView animated:YES completion:nil];
        
        return;
    }
    

//
//    TOFilesTableViewController *controller = [[TOFilesTableViewController alloc] initWithSession:self.session title:file.name];
//    controller.rootController = self.rootController;
//    controller.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
//    [self.navigationController pushViewController:controller animated:YES];
//    
//    [self.session requestContentsOfDirectoryAtFilePath:file.filePath success:^(NSArray *files) {
//        controller.files = files;
//    } error:^(NSError *error) {
//        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"SMB Client Error" message:error.localizedDescription delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
//        [alert show];
//    }];
}

//-(void)findAllPics:(NSString *)path
//{
//    static int count=0;
//    count++;
//    NSLog(@"%d",count);
//    
//    [self.session requestContentsOfDirectoryAtFilePath:path success:^(NSArray *files) {
//        for (TOSMBSessionFile * file in files) {
//            if (file.directory==YES) {
//                [self findAllPics:file.filePath];
//            }
//            else
//            {
//                if ([[file.filePath pathExtension] isEqualToString:@"jpg"] ||
//                    [[file.filePath pathExtension] isEqualToString:@"png"] ||
//                    [[file.filePath pathExtension] isEqualToString:@"bmp"] ||
//                    [[file.filePath pathExtension] isEqualToString:@"tiff"] ||
//                    [[file.filePath pathExtension] isEqualToString:@"gif"]) {
//                    [_picsArray addObject:file];
//                    NSLog(@"%lu[%@]",_picsArray.count,file.filePath);
//                    if(_picsArray.count<9){
//                        [self download:((TOSMBSessionFile *)_picsArray.lastObject).filePath index:_picsArray.count-1];
//                    }
//                }
//            }
//        }
//    } error:^(NSError *error) {
//        NSLog(@"获取文件目录失败");
//    }];
//}


- (void)setFiles:(NSArray *)files
{
    _files = files;
    self.navigationItem.title = self.directoryTitle;
    [self.tableView reloadData];
}
         
@end
