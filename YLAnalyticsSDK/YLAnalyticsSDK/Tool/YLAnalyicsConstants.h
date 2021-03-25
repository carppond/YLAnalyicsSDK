//
//  YLAnalyicsConstants.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/22.
//

#import <Foundation/Foundation.h>

/*!
 *  网络类型
 *
 *  YLSensorsAnalyticsNetworkTypeNONE - NULL
 *  YLSensorsAnalyticsNetworkType2G - 2G
 *  YLSensorsAnalyticsNetworkType3G - 3G
 *  YLSensorsAnalyticsNetworkType4G - 4G
 *  YLSensorsAnalyticsNetworkTypeWIFI - WIFI
 *  YLSensorsAnalyticsNetworkTypeALL - ALL
 */
typedef NS_OPTIONS(NSInteger, YLSensorsAnalyticsNetworkType) {
    YLSensorsAnalyticsNetworkTypeNONE      = 0,
    YLSensorsAnalyticsNetworkType2G       = 1 << 0,
    YLSensorsAnalyticsNetworkType3G       = 1 << 1,
    YLSensorsAnalyticsNetworkType4G       = 1 << 2,
    YLSensorsAnalyticsNetworkTypeWIFI     = 1 << 3,
    YLSensorsAnalyticsNetworkTypeALL      = 0xFF,
};
