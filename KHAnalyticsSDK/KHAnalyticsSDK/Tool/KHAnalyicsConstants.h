//
//  KHAnalyicsConstants.h
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/22.
//

#import <Foundation/Foundation.h>

/*!
 *  网络类型
 *
 *  KHSensorsAnalyticsNetworkTypeNONE - NULL
 *  KHSensorsAnalyticsNetworkType2G - 2G
 *  KHSensorsAnalyticsNetworkType3G - 3G
 *  KHSensorsAnalyticsNetworkType4G - 4G
 *  KHSensorsAnalyticsNetworkTypeWIFI - WIFI
 *  KHSensorsAnalyticsNetworkTypeALL - ALL
 */
typedef NS_OPTIONS(NSInteger, KHSensorsAnalyticsNetworkType) {
    KHSensorsAnalyticsNetworkTypeNONE      = 0,
    KHSensorsAnalyticsNetworkType2G       = 1 << 0,
    KHSensorsAnalyticsNetworkType3G       = 1 << 1,
    KHSensorsAnalyticsNetworkType4G       = 1 << 2,
    KHSensorsAnalyticsNetworkTypeWIFI     = 1 << 3,
    KHSensorsAnalyticsNetworkTypeALL      = 0xFF,
};
