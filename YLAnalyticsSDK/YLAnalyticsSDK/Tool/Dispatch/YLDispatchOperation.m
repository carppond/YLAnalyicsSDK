//
//  YLDispatchOperation.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/11/3.
//

#import "YLDispatchOperation.h"
#import "YLDispatchAsync.h"


#ifndef YLDispatchAsync_m
#define YL_INLINE static inline
#endif

#define YL_FUNCTION_OVERLOAD __attribute__((overloadable))


YL_INLINE YL_FUNCTION_OVERLOAD void __YLLockExecute(dispatch_block_t block, dispatch_time_t threshold);

YL_INLINE YL_FUNCTION_OVERLOAD void __YLLockExecute(dispatch_block_t block) {
    __YLLockExecute(block, dispatch_time(DISPATCH_TIME_NOW, DISPATCH_TIME_FOREVER));
}

YL_INLINE YL_FUNCTION_OVERLOAD void __YLLockExecute(dispatch_block_t block, dispatch_time_t threshold) {
    if (block == nil) { return ; }
    static dispatch_semaphore_t YL_queue_semaphore;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        YL_queue_semaphore = dispatch_semaphore_create(0);
    });
    dispatch_semaphore_wait(YL_queue_semaphore, threshold);
    block();
    dispatch_semaphore_signal(YL_queue_semaphore);
}


@interface YLDispatchOperation ()

@property (nonatomic, assign) BOOL isCanceled;
@property (nonatomic, assign) BOOL isExcuting;
@property (nonatomic, assign) dispatch_queue_t queue;
@property (nonatomic, assign) dispatch_queue_t (*asyn)(dispatch_block_t);
@property (nonatomic, copy) YLCancelableBlock cancelableBlock;

@end


@implementation YLDispatchOperation


+ (instancetype)dispatchOperationWithBlock: (dispatch_block_t)block {
    return [self dispatchOperationWithCancelableBlock: ^(YLDispatchOperation *operation) {
        if (!operation.isCanceled) {
            block();
        }
    } inQos: NSQualityOfServiceDefault];
}

+ (instancetype)dispatchOperationWithBlock: (dispatch_block_t)block inQoS: (NSQualityOfService)qos {
    return [self dispatchOperationWithCancelableBlock: ^(YLDispatchOperation *operation) {
        if (!operation.isCanceled) {
            block();
        }
    } inQos: qos];
}

+ (instancetype)dispatchOperationWithCancelableBlock:(YLCancelableBlock)block {
    return [self dispatchOperationWithCancelableBlock: block inQos: NSQualityOfServiceDefault];
}

+ (instancetype)dispatchOperationWithCancelableBlock:(YLCancelableBlock)block inQos: (NSQualityOfService)qos {
    return [[self alloc] initWithBlock: block inQos: qos];
}

- (instancetype)initWithBlock: (YLCancelableBlock)block inQos: (NSQualityOfService)qos {
    if (block == nil) { return nil; }
    if (self = [super init]) {
        switch (qos) {
            case NSQualityOfServiceUserInteractive:
                self.asyn = YLDispatchQueueAsyncBlockInUserInteractive;
                break;
            case NSQualityOfServiceUserInitiated:
                self.asyn = YLDispatchQueueAsyncBlockInUserInitiated;
                break;
            case NSQualityOfServiceDefault:
                self.asyn = YLDispatchQueueAsyncBlockInDefault;
                break;
            case NSQualityOfServiceUtility:
                self.asyn = YLDispatchQueueAsyncBlockInUtility;
                break;
            case NSQualityOfServiceBackground:
                self.asyn = YLDispatchQueueAsyncBlockInBackground;
                break;
            default:
                self.asyn = YLDispatchQueueAsyncBlockInDefault;
                break;
        }
        self.cancelableBlock = block;
    }
    return self;
}

- (void)dealloc {
    [self cancel];
}

- (void)start {
    __YLLockExecute(^{
        self.queue = self.asyn(^{
            self.cancelableBlock(self);
            self.cancelableBlock = nil;
        });
        self.isExcuting = YES;
    });
}

- (void)cancel {
    __YLLockExecute(^{
        self.isCanceled = YES;
        if (!self.isExcuting) {
            self.asyn = NULL;
            self.cancelableBlock = nil;
        }
    });
}


@end
