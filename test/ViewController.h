//
//  ViewController.h
//  test
//
//  Created by 蒋尚秀 on 15/12/10.
//  Copyright © 2015年 -JSX-. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PicViewController.h"

@interface ViewController : UIViewController
{
    //所有照片文件数组
    NSMutableArray * _picsArray;
    NSMutableArray * _downloadPicsArray;
    NSArray * _sortedPicsArray;
    PicViewController * _picView;
    
    //exifInfoArray
    NSMutableArray * _exifInfoArray;
}

@end

