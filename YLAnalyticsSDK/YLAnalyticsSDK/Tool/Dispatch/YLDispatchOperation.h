//
//  YLDispatchOperation.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/11/3.
//

#import <Foundation/Foundation.h>

@class YLDispatchOperation;
typedef void(^YLCancelableBlock)(YLDispatchOperation * operation);


/*!
 *  @brief  派发任务封装
 */
@interface YLDispatchOperation : NSObject

@property (nonatomic, readonly) BOOL isCanceled;
@property (nonatomic, readonly) dispatch_queue_t queue;

+ (instancetype)dispatchOperationWithBlock: (dispatch_block_t)block;
+ (instancetype)dispatchOperationWithBlock: (dispatch_block_t)block inQoS: (NSQualityOfService)qos;

+ (instancetype)dispatchOperationWithCancelableBlock:(YLCancelableBlock)block;
+ (instancetype)dispatchOperationWithCancelableBlock:(YLCancelableBlock)block inQos: (NSQualityOfService)qos;

- (void)start;
- (void)cancel;

@end
