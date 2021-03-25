//
//  YLSensorsAnalyticsNetwork.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/20.
//  同步数据工具类

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YLSensorsAnalyticsNetwork : NSObject

/// 数据上报的服务器地址
@property (nonatomic, strong) NSURL *serverURL;

/*!
 *  禁止直接使用- init方法进行初始化
 */
- (instancetype)init NS_UNAVAILABLE;

/*!
 *  指定初始化方法
 *
 *  @param serverURL 服务器URL地址
 *
 *  @return 初始化对象
 */
- (instancetype)initWithServerURL:(NSURL *)serverURL NS_DESIGNATED_INITIALIZER;

/*!
 *  同步数据
 *
 *  @param events 事件数组
 *
 *  @return YES:同步成功；NO:同步失败
 */
- (BOOL)flushEvents:(NSArray<NSString *> *)events;


@end




NS_ASSUME_NONNULL_END
