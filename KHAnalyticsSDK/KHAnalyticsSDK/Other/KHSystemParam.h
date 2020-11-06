//
//  KHSystemParam.h
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/22.
//

#import <Foundation/Foundation.h>

@interface KHSystemParam : NSObject
/*!
 *  获取 App 设备等基础信息
 */
+ (NSDictionary<NSString *, id> *)getAppInfo;

+ (NSDictionary<NSString *, id> *)getCollectAutomaticProperties;

/// 运营商
+ (NSString *)getCarrier;
 /// 品牌
+ (NSString *)getBrand;
/// 获取设备类型
+ (NSString *)getModel;
/// 获取系统类型
+ (NSString *)getOS;
/// 获取系统版本
+ (NSString *)getOSVersion;
/// 获取设备名称
+ (NSString *)getDeviceName;
/// 是否是模拟器
+ (BOOL)isSimulator;
/// 是否含有 NFC
+ (BOOL)hasnfc;
/// 电池电量
+ (NSString *)getBatteryLevel;
/// 电池是否在充电中
+ (NSString *)getBatteryState;
/// 获取网络状态
+ (NSString *)getNetworkStatus;

// App 应用名称
+ (NSString *)getAppName;
// App 应用版本
+ (NSString *)getAppVersion;
// App 应用build 版本
+ (NSString *)getAppBuildVersion;
/// URIScheme
+ (NSString *)getURIScheme;


@end

