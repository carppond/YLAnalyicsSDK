//
//  YLSensorsAnalyicsCommonTool.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/22.
//

#import "YLSensorsAnalyicsCommonTool.h"
#import "YLReachability.h"
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "YLAnalyicsLog.h"
#import "YLSensorsAnalyicsTool.h"

@implementation YLSensorsAnalyicsCommonTool

///按字节截取指定长度字符，包括汉字
+ (NSString *)subByteString:(NSString *)string byteLength:(NSInteger )length {
    
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF8);
    NSData* data = [string dataUsingEncoding:enc];
    
    NSData *subData = [data subdataWithRange:NSMakeRange(0, length)];
    NSString*txt=[[NSString alloc] initWithData:subData encoding:enc];
    
     //utf8 汉字占三个字节，表情占四个字节，可能截取失败
    NSInteger index = 1;
    while (index <= 3 && !txt) {
        if (length > index) {
            subData = [data subdataWithRange:NSMakeRange(0, length - index)];
            txt = [[NSString alloc] initWithData:subData encoding:enc];
        }
        index ++;
    }
    
    if (!txt) {
        return string;
    }
    return txt;
}

+ (NSString *)currentNetworkStatus {
#ifdef SA_UT
    SALogDebug(@"In unit test, set NetWorkStates to wifi");
    return @"WIFI";
#endif
    NSString *network = @"NULL";
    @try {
        YLReachability *reachability = [YLReachability reachabilityForInternetConnection];
        YLNetworkStatus status = [reachability currentReachabilityStatus];
        
        if (status == ReachableViaWiFi) {
            network = @"WIFI";
        } else if (status == ReachableViaWWAN) {
            static CTTelephonyNetworkInfo *netinfo = nil;
            NSString *currentRadioAccessTechnology = nil;
            
            if (!netinfo) {
                netinfo = [[CTTelephonyNetworkInfo alloc] init];
            }
#ifdef __IPHONE_12_0
            if (@available(iOS 12.1, *)) {
                currentRadioAccessTechnology = netinfo.serviceCurrentRadioAccessTechnology.allValues.lastObject;
            }
#endif
            //测试发现存在少数 12.0 和 12.0.1 的机型 serviceCurrentRadioAccessTechnology 返回空
            if (!currentRadioAccessTechnology) {
                currentRadioAccessTechnology = netinfo.serviceCurrentRadioAccessTechnology;
            }
            
            if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyGPRS]) {
                network = @"2G";
            } else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyEdge]) {
                network = @"2G";
            } else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyWCDMA]) {
                network = @"3G";
            } else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSDPA]) {
                network = @"3G";
            } else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyHSUPA]) {
                network = @"3G";
            } else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMA1x]) {
                network = @"3G";
            } else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORev0]) {
                network = @"3G";
            } else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevA]) {
                network = @"3G";
            } else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyCDMAEVDORevB]) {
                network = @"3G";
            } else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyeHRPD]) {
                network = @"3G";
            } else if ([currentRadioAccessTechnology isEqualToString:CTRadioAccessTechnologyLTE]) {
                network = @"4G";
            } else {
                network = @"UNKNOWN";
            }
        }
    } @catch (NSException *exception) {
        KEHOULog(@"%@: %@", self, exception);
    }
    return network;
}

+ (void)performBlockOnMainThread:(DISPATCH_NOESCAPE dispatch_block_t)block {
    if (NSThread.isMainThread) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

+ (YLSensorsAnalyticsNetworkType)toNetworkType:(NSString *)networkType {
    if ([@"NULL" isEqualToString:networkType]) {
        return YLSensorsAnalyticsNetworkTypeNONE;
    } else if ([@"WIFI" isEqualToString:networkType]) {
        return YLSensorsAnalyticsNetworkTypeWIFI;
    } else if ([@"2G" isEqualToString:networkType]) {
        return YLSensorsAnalyticsNetworkType2G;
    }   else if ([@"3G" isEqualToString:networkType]) {
        return YLSensorsAnalyticsNetworkType3G;
    }   else if ([@"4G" isEqualToString:networkType]) {
        return YLSensorsAnalyticsNetworkType4G;
    } else if ([@"UNKNOWN" isEqualToString:networkType]) {
        return YLSensorsAnalyticsNetworkType4G;
    }
    return YLSensorsAnalyticsNetworkTypeNONE;
}

+ (YLSensorsAnalyticsNetworkType)currentNetworkType {
    NSString *currentNetworkStatus = [YLSensorsAnalyicsCommonTool currentNetworkStatus];
    return [YLSensorsAnalyicsCommonTool toNetworkType:currentNetworkStatus];
}

+ (NSString *)currentUserAgent {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"UserAgent"];
}

+ (void)saveUserAgent:(NSString *)userAgent {
    if (![YLSensorsAnalyicsTool isValidString:userAgent]) {
        return;
    }
    
    NSDictionary *dictionnary = [[NSDictionary alloc] initWithObjectsAndKeys:userAgent, @"UserAgent", nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionnary];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

void analyics_dispatch_safe_sync(dispatch_queue_t queue,DISPATCH_NOESCAPE dispatch_block_t block) {
    if ((dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL)) == dispatch_queue_get_label(queue)) {
        block();
    } else {
        dispatch_sync(queue, block);
    }
}


@end
