//
//  TOFilesViewControllerTableViewController.h
//  TOSMBClientExample
//
//  Created by Tim Oliver on 8/5/15.
//  Copyright (c) 2015 TimOliver. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PicViewController.h"

@class TOSMBSession;

@interface TOFilesTableViewController : UITableViewController
{
    PicViewController * picView;
    NSMutableArray * _picsArray;

}

@property (nonatomic, strong) NSArray *files;

- (instancetype)initWithSession:(TOSMBSession *)session title:(NSString *)title;

@end
