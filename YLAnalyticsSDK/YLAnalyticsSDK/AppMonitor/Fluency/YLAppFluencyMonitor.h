//
//  YLAppFluencyMonitor.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/11/6.
//

#import <Foundation/Foundation.h>


@interface YLAppFluencyMonitor : NSObject

+ (instancetype)shareInstance;

- (void)start;

- (void)stop;

@end

@interface YLAppCPUMonitor : NSObject

+ (void)updateCPU;

@end
