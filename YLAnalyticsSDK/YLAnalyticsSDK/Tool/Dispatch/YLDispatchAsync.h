//
//  YLDispatchQueuePool.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/11/3.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, YLQualityOfService) {
    YLQualityOfServiceUserInteractive = NSQualityOfServiceUserInteractive,
    YLQualityOfServiceUserInitiated = NSQualityOfServiceUserInitiated,
    YLQualityOfServiceUtility = NSQualityOfServiceUtility,
    YLQualityOfServiceBackground = NSQualityOfServiceBackground,
    YLQualityOfServiceDefault = NSQualityOfServiceDefault,
};


dispatch_queue_t YLDispatchQueueAsyncBlockInQOS(YLQualityOfService qos, dispatch_block_t block);
dispatch_queue_t YLDispatchQueueAsyncBlockInUserInteractive(dispatch_block_t block);
dispatch_queue_t YLDispatchQueueAsyncBlockInUserInitiated(dispatch_block_t block);
dispatch_queue_t YLDispatchQueueAsyncBlockInBackground(dispatch_block_t block);
dispatch_queue_t YLDispatchQueueAsyncBlockInDefault(dispatch_block_t block);
dispatch_queue_t YLDispatchQueueAsyncBlockInUtility(dispatch_block_t block);
