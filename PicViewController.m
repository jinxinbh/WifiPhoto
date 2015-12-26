//
//  PicViewController.m
//  test
//
//  Created by 蒋尚秀 on 15/12/13.
//  Copyright © 2015年 -JSX-. All rights reserved.
//

#import "PicViewController.h"

#define LEFTM 20
#define TOPM 20
#define HMARGIN 120
#define VMARGIN 120
#define WH 100

@interface PicViewController ()

@end

@implementation PicViewController

-(id)init
{
    if (self = [super init]) {
        
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _imageViewArray = [[NSMutableArray alloc]init];

    for (int i=0; i<3; i++) {
        for (int j=0; j<3; j++) {
            UIImageView * imageView = [[UIImageView alloc]initWithFrame:CGRectMake(LEFTM+j*VMARGIN, TOPM+i*HMARGIN, WH, WH)];
            [imageView setBackgroundColor:[UIColor purpleColor]];
            [_imageViewArray addObject:imageView];
        }
    }
    
    
    for (UIImageView * imageView in _imageViewArray) {
        [self.view addSubview:imageView];
    }
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
