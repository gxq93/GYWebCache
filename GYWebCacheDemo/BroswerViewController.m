//
//  ViewController.m
//  GYWebCacheDemo
//
//  Created by GuYi on 16/11/9.
//  Copyright © 2016年 aicai. All rights reserved.
//

#import "BroswerViewController.h"
#import "GYWebCacheURLProtocol.h"

@interface BroswerViewController ()
@property(nonatomic, strong) UIWebView *webView;
@end

@implementation BroswerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    UIBarButtonItem *refreshItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshAction:)];
    self.navigationItem.rightBarButtonItem = refreshItem;
    
    self.webView = [[UIWebView alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    [self.webView setMultipleTouchEnabled:YES];
    [self.webView setAutoresizesSubviews:YES];
    [self.webView setScalesPageToFit:YES];
    [self.webView.scrollView setAlwaysBounceVertical:YES];
    [self.view addSubview:self.webView];
    
    //加这句话就可以，将url load system使用的默认URLProtocol替换成自定义的URLProtocol
    [NSURLProtocol registerClass:[GYWebCacheURLProtocol class]];
    
    [self refreshAction:nil];
}


- (IBAction)refreshAction:(UIBarButtonItem *)sender {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.jd.com"]];
    
    [self.webView loadRequest:request];
    
}

@end
