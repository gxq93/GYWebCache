//
//  GYWebCacheURLProtocol.m
//  GYWebCacheDemo
//
//  Created by GuYi on 16/11/9.
//  Copyright © 2016年 aicai. All rights reserved.
//

#import "GYWebCacheURLProtocol.h"
#import <CommonCrypto/CommonDigest.h>

@interface GYWebCacheData : NSObject<NSCoding>
@property (nonatomic, strong) NSDate *timeDate;                //缓存时间
@property (nonatomic, strong) NSData *data;                    //缓存数据
@property (nonatomic, strong) NSURLResponse *response;         //缓存请求
@end

@implementation GYWebCacheData

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.timeDate = [aDecoder decodeObjectForKey:@"timeDate"];
        self.data = [aDecoder decodeObjectForKey:@"data"];
        self.response = [aDecoder decodeObjectForKey:@"response"];
    }
    
    return self;
    
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_timeDate forKey:@"timeDate"];
    [aCoder encodeObject:_data forKey:@"data"];
    [aCoder encodeObject:_response forKey:@"response"];
}
@end

@implementation NSString(MD5)

- (NSString *)md5String {
    const char *cStr = [self UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, (CC_LONG) strlen(cStr), result); // This is the md5 call
    
    
    NSString *string32 = [NSString stringWithFormat:
                          @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                          result[0], result[1], result[2], result[3],
                          result[4], result[5], result[6], result[7],
                          result[8], result[9], result[10], result[11],
                          result[12], result[13], result[14], result[15]];
    return string32;
}

@end


@interface GYWebCacheURLProtocol ()<NSURLSessionDelegate>
@property (nonatomic, strong) NSURLSessionDataTask *downloadTask;  //下载任务
@property (nonatomic, strong) NSURLResponse *response;  //请求
@property (nonatomic, strong) NSMutableData *cacheData; //缓存数据
@end

@implementation GYWebCacheURLProtocol

static NSString * const GYURLProtocolHandledKey = @"GYURLProtocolHandledKey";//防止循环创建自定义的protocol，给已经处理的request加个标示
static NSUInteger const CacheTime = 300;//缓存的时间,默认设置为300秒

#pragma mark- privateMethod

//缓存路径
- (NSString *)filePathWithUrlString:(NSString *)urlString
{
    NSString *cachesPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    //如果直接以url作为文件路径有的url最后带有’／‘无法归档，因为干脆md5签名
    NSString *fileName = [urlString md5String];
    return [cachesPath stringByAppendingPathComponent:fileName];
}

//判读是否有缓存
- (BOOL)isUseCahceWithCache:(GYWebCacheData *)cache
{
    if (cache == nil) {
        return NO;
    }
    
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:cache.timeDate];
    return timeInterval < CacheTime;
}

- (void)setupTask
{
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    NSMutableURLRequest *request = [self setupRequest];
    request.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
    [request setValue:@"YES" forHTTPHeaderField:GYURLProtocolHandledKey];
    _downloadTask = [session dataTaskWithRequest:request];
    [_downloadTask resume];
    
}

- (NSMutableURLRequest*)setupRequest
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.request.URL
                                                                cachePolicy:self.request.cachePolicy
                                                            timeoutInterval:self.request.timeoutInterval];
    [request setAllHTTPHeaderFields:self.request.allHTTPHeaderFields];
    if ([self.request HTTPBodyStream]) {
        [request setHTTPBodyStream:self.request.HTTPBodyStream];
    } else {
        [request setHTTPBody:self.request.HTTPBody];
    }
    [request setHTTPMethod:self.request.HTTPMethod];
    return request;
    
}


#pragma mark- override NSURLProtocol method

/**
 @abstract 拦截处理对应的request，如果不打算处理，返回NO，URL Loading System会使用系统默认的行为去处理；如果打算处理，返回YES，需要处理该请求的所有东西，包括获取请求数据并返回给URL Loading System。每个NSURLProtocol对象都有一个NSURLProtocolClient实例，可以通过该client将获取到的数据返回给URL Loading System。
 @param request A request to inspect.
 @result YES if the protocol can handle the given request, NO if not.
 
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if (![NSURLProtocol propertyForKey:GYURLProtocolHandledKey inRequest:request]) {
        return YES;
    }
    return NO;
}

/**
 @abstract 返回加载的request
 @param request A request to make canonical.
 @result The canonical form of the given request.
 */
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}


/**
 @abstract 主要判断两个request是否相同，如果相同的话可以使用缓存数据，通常只需要调用父类的实现。
 @result YES if the two requests are cache-equivalent, NO otherwise.
 */
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}


/**
 重载NSURLProtocol开始加载方法
 */
- (void)startLoading
{
    NSString *url = self.request.URL.absoluteString;
    NSLog(@"requst url = %@",url);
    GYWebCacheData *cache = (GYWebCacheData*)[NSKeyedUnarchiver unarchiveObjectWithFile:[self filePathWithUrlString:url]];
    
    //判断是否有缓存，如果有并且在缓存时间内则读缓存
    if ([self isUseCahceWithCache:cache]) {
        NSLog(@"catch from cache = %@",cache.response.URL.absoluteString);
        [self.client URLProtocol:self didReceiveResponse:cache.response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [self.client URLProtocol:self didLoadData:cache.data];
        [self.client URLProtocolDidFinishLoading:self];
    }
    else {
        NSMutableURLRequest *newRequest = [self setupRequest];
        NSLog(@"catch from sever = %@",newRequest.URL.absoluteString);
        //给新的请求加标示防止循环创建protocol
        [NSURLProtocol setProperty:@YES forKey:GYURLProtocolHandledKey inRequest:newRequest];
        [self setupTask];
    }
}


/**
 重载NSURLProtocol停止加载方法
 */
- (void)stopLoading
{
    [self.downloadTask cancel];
    self.cacheData = nil;
    self.downloadTask = nil;
    self.response = nil;
}

#pragma mark- NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
{
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
    self.cacheData = [NSMutableData data];
    self.response = response;
}

-  (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    //下载过程中
    [self.client URLProtocol:self didLoadData:data];
    [self.cacheData appendData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    //下载完成后触发
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        //将数据的缓存归档存入到本地文件中
        GYWebCacheData *cache = [[GYWebCacheData alloc] init];
        cache.data = [self.cacheData copy];
        cache.timeDate = [NSDate date];
        cache.response = self.response;
        NSLog(@"write in cache = %@ filepath = %@",cache,self.request.URL.absoluteString);
        [NSKeyedArchiver archiveRootObject:cache toFile:[self filePathWithUrlString:self.request.URL.absoluteString]];
        [self.client URLProtocolDidFinishLoading:self];
    }
}

@end
