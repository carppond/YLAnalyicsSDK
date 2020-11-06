//
//  KHSensorsAnalyticsNetwork.m
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/20.
//

#import "KHSensorsAnalyticsNetwork.h"
#import "KHAnalyicsLog.h"

/// 网络请求结束处理回调类型
typedef void(^KHSAURLSessionTaskCompletionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);


@interface KHSensorsAnalyticsNetwork ()<NSURLSessionDelegate>

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation KHSensorsAnalyticsNetwork

- (instancetype)initWithServerURL:(NSURL *)serverURL {
    self = [super init];
    if (self) {
        _serverURL = serverURL;
        // 创建默认的session配置对象
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPMaximumConnectionsPerHost = 5;
        configuration.timeoutIntervalForRequest = 30;
        configuration.allowsCellularAccess = YES;
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        // 设置同步运行的最大操作数为1，即各操作FIFO
        queue.maxConcurrentOperationCount = 1;
        // 通过配置对象创建一个session对象
        self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:queue];
    }
    return self;
}

- (NSString *)buildJSONStringWithEvents:(NSArray<NSString *> *)events {
    return [NSString stringWithFormat:@"[\n%@\n]", [events componentsJoinedByString:@",\n"]];
}

- (NSURLRequest *)buildRequestWithJSONString:(NSString *)json {
    // 通过服务器URL地址创建请求
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.serverURL];
    // 设置请求的body
    request.HTTPBody = [json dataUsingEncoding:NSUTF8StringEncoding];
    // 请求方法
    request.HTTPMethod = @"POST";
    return request;
}

- (BOOL)flushEvents:(NSArray<NSString *> *)events {

    NSString *jsonString = [self buildJSONStringWithEvents:events];
    
    NSURLRequest *request = [self buildRequestWithJSONString:jsonString];
    // 数据上传结果
    __block BOOL flushSuccess = NO;
    // 使用GCD中的信号量，实现线程锁
    dispatch_semaphore_t flushSemaphore = dispatch_semaphore_create(0);
    KHSAURLSessionTaskCompletionHandler handler = ^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            KeHouDebug(@"Flush events error: %@", error);
            dispatch_semaphore_signal(flushSemaphore);
            return;
        }
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        if (statusCode >= 200 && statusCode < 300) {
            // 打印上传成功的数据
            KeHouDebug(@"Flush events success: %@", jsonString);
            // 数据上传成功
            flushSuccess = YES;
        } else {
            NSString *desc = [NSString stringWithFormat:@"Flush events error, statusCode: %d, events: %@", (int)statusCode, jsonString];
            KeHouDebug(@"Flush events error:%@", desc);
        }
        dispatch_semaphore_signal(flushSemaphore);
    };
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:handler];
    [task resume];
    
    dispatch_semaphore_wait(flushSemaphore, DISPATCH_TIME_FOREVER);
    
    return flushSuccess;
}
            
                  
                  
@end
