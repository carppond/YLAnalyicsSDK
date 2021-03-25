//
//  YLSystemParam.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/22.
//

#import "YLSystemParam.h"
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#include <sys/utsname.h>
#import <UIKit/UIKit.h>
#include <sys/sysctl.h>
#import "YLReachability.h"
#import "YLAnalyicsLog.h"

static NSString * const YLAnalyticsVersion = @"1.0.0";

@implementation YLSystemParam

+ (NSDictionary<NSString *, id> *)getAppInfo {
    static dispatch_once_t onceToken;
    static NSDictionary *appInfo = nil;
    dispatch_once(&onceToken, ^{
        appInfo = [YLSystemParam getCollectAutomaticProperties];
    });
    return appInfo;
}

+ (NSDictionary<NSString *, id> *)getCollectAutomaticProperties {
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    // 操作系统类型
    [properties setObject:[YLSystemParam getOS] forKey:@"os"];
    // sdk 平台类型
    [properties setObject:@"iOS" forKey:@"lib"];
    // 设备制造商
    [properties setObject:[YLSystemParam getBrand] forKey:@"manufacturer"];
    // SDK 版本号
    [properties setObject:YLAnalyticsVersion forKey:@"lib_version"];
    // 手机型号
    [properties setObject:[YLSystemParam getModel] forKey:@"model"];
    // 操作系统版本号
    [properties setObject:[YLSystemParam getOSVersion] forKey:@"os_version"];
    // 运营商
    [properties setObject:[YLSystemParam getCarrier] forKey:@"carrier"];
    // 设备名称
    [properties setObject:[YLSystemParam getDeviceName] forKey:@"device_name"];
    // 是否是模拟器
    [properties setObject:[YLSystemParam isSimulator] ? @"是":@"否" forKey:@"isSimulator"];
    // 电池电量
    [properties setObject:[YLSystemParam getBatteryLevel] forKey:@"battery_level"];
    // 是否在充电
    [properties setObject:[YLSystemParam getBatteryState] forKey:@"battery_status"];
    // 网络
    [properties setObject:[YLSystemParam  getNetworkStatus] forKey:@"battery_status"];
    
    // App 应用名称
    [properties setObject:[YLSystemParam getAppName] forKey:@"app_name"];
    // App 应用版本
    [properties setObject:[YLSystemParam getAppVersion] forKey:@"app_version"];
    // App 应用build 版本
    [properties setObject:[YLSystemParam getAppBuildVersion] forKey:@"app_build_Version"];
    // URIScheme
    [properties setObject:[YLSystemParam getURIScheme] forKey:@"app_urlscheme"];
    /// 应用程序版本号
    [properties setObject:[[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"] forKey:@"app_version"];
    return properties.copy;
}


+ (NSString *)getNetworkStatus {
    YLReachability *reach = [YLReachability reachabilityWithHostName:@"www.baidu.com"];
    NSString *status = @"";
    // 判断当前的网络状态
    switch([reach currentReachabilityStatus]){
            case ReachableViaWWAN:
            KeHouDebug(@"正在使用移动数据网络");
            status = @"正在使用移动数据网络";
            break;
            case ReachableViaWiFi:
            KeHouDebug(@"正在使用WiFi");
            status = @"正在使用WiFi";
            break;
        default:
            KeHouDebug(@"无网络");
            status = @"无网络";
            break;
    }
    return status;
}

    
+ (NSString *)getURIScheme {
    NSArray *urlTypes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleURLTypes"];
    if (urlTypes) {
        for (NSDictionary *urlType in urlTypes) {
            NSArray *urlSchemes = [urlType objectForKey:@"CFBundleURLSchemes"];
            if (urlSchemes) {
                for (NSString *urlScheme in urlSchemes) {
                    if (![[urlScheme substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"fb"] &&
                        ![[urlScheme substringWithRange:NSMakeRange(0, 2)] isEqualToString:@"db"] &&
                        ![[urlScheme substringWithRange:NSMakeRange(0, 3)] isEqualToString:@"pin"]) {
                        return urlScheme;
                    }
                }
            }
        }
    }
    return @"";
}


+ (NSString *)getCarrier {
    CTTelephonyNetworkInfo *networkInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [networkInfo subscriberCellularProvider];
    if (carrier == nil) {
        return @"没有运营商";
    }
    return carrier.carrierName;
}

+ (NSString *)getBrand {
    return @"Apple";
}

+ (NSString *)getModel {
    struct utsname systemInfo;
    uname(&systemInfo);
    
    return [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
}

+ (BOOL)isSimulator {
    UIDevice *currentDevice = [UIDevice currentDevice];
    return [currentDevice.model rangeOfString:@"Simulator"].location != NSNotFound;
}

+ (NSString *)getDeviceName {
    if ([YLSystemParam isSimulator]) {
        struct utsname name;
        uname(&name);
        return [NSString stringWithFormat:@"%@ %s", [[UIDevice currentDevice] name], name.nodename];
    } else {
        return [[UIDevice currentDevice] name];
    }
}

+ (NSString *)getOS {
    return @"iOS";
}

+ (NSString *)getOSVersion {
    UIDevice *device = [UIDevice currentDevice];
    return [device systemVersion];
}

+ (BOOL)hasnfc {
    NSString *device_version = [YLSystemParam getModel];
    if ([device_version isEqualToString:@"iPhone7,1"]||[device_version isEqualToString:@"iPhone7,2"]||[device_version isEqualToString:@"iPhone8,1"]||[device_version isEqualToString:@"iPhone8,2"]) {
        return true;
    } else {
        return false;
    }
}

/// 电池电量
+ (NSString *)getBatteryLevel {
    CGFloat BL = [[UIDevice currentDevice] batteryLevel] * 100;
    return [NSString stringWithFormat:@"%.2f",BL];
}


+ (NSString *)getBatteryState {
    UIDevice *device = [UIDevice currentDevice];
    device.batteryMonitoringEnabled = YES;
    UIDeviceBatteryState state = device.batteryState;
    if (state == UIDeviceBatteryStateCharging) {
        return @"充电中..";
    }
    return @"正常电池状态";
}

+ (NSString *)getAppName {
    NSString * appName = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleDisplayName"];
    if (appName) {
        return appName;
    }
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
}

+ (NSString *)getAppVersion {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
}

+ (NSString *)getAppBuildVersion {
    return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
}

- (NSString *)deviceModel {
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    return platform;
}


@end
