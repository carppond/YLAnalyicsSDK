//
//  SensorsDataReleaseObject.m
//  KHAnalyticsSDKDemo
//
//  Created by lcf on 2020/10/21.
//

#import "SensorsDataReleaseObject.h"

@implementation SensorsDataReleaseObject


- (void)signalCrash {
    NSMutableArray<NSString *> *array = [[NSMutableArray alloc] init];
    [array addObject:@"First"];
    [array release];
    // 在这里会崩溃，因为array已经被释放，访问了不存在的地址
    NSLog(@"Crash: %@", array.firstObject);
}

@end
