//
//  ImageInfoModel.h
//  test
//
//  Created by 蒋尚秀 on 15/12/14.
//  Copyright © 2015年 -JSX-. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TOSMBSessionFile.h"

@interface ImageInfoModel : NSObject

@property (nonatomic,retain) TOSMBSessionFile * file;

@property (nonatomic,assign) NSDate * _shotDate;
@property (nonatomic,copy) NSString * location;



@end
