//
//  KHSensorsAnalyicsCommonTool.h
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/22.
//

#import <Foundation/Foundation.h>
#import "KHAnalyicsConstants.h"

NS_ASSUME_NONNULL_BEGIN

@interface KHSensorsAnalyicsCommonTool : NSObject

///按字节截取指定长度字符，包括汉字和表情
+ (NSString *)subByteString:(NSString *)string byteLength:(NSInteger )length;

/// 获取当前网络状态
+ (NSString *)currentNetworkStatus;

/// 获取当前网络类型
+ (KHSensorsAnalyticsNetworkType)currentNetworkType;

/// 主线程执行
+ (void)performBlockOnMainThread:(DISPATCH_NOESCAPE dispatch_block_t)block;

/// 获取当前的 UserAgent
+ (NSString *)currentUserAgent;

/// 保存 UserAgent
+ (void)saveUserAgent:(NSString *)userAgent;


void analyics_dispatch_safe_sync(dispatch_queue_t queue,DISPATCH_NOESCAPE dispatch_block_t block);

@end

NS_ASSUME_NONNULL_END
