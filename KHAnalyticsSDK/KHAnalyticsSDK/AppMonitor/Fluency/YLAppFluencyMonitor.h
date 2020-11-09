//
//  YLAppFluencyMonitor.h
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/11/6.
//

#import <Foundation/Foundation.h>


@interface YLAppFluencyMonitor : NSObject

+ (instancetype)shareInstance;

- (void)beginMonitor;

- (void)endMonitor;

@end

@interface YLAppCPUMonitor : NSObject

+ (void)updateCPU;

@end
