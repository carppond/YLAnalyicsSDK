//
//  main.m
//  YLAnalyticsSDKDemo
//
//  Created by lcf on 2021/3/25.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"
#import <YLAnalyticsSDK/YLAnalyticsSDK.h>

int main(int argc, char * argv[]) {
    NSString * appDelegateClassName;
    @autoreleasepool {
        [[YLAppFluencyMonitor shareInstance] start];
        // Setup code that might create autoreleased objects goes here.
        appDelegateClassName = NSStringFromClass([AppDelegate class]);
    }
    return UIApplicationMain(argc, argv, nil, appDelegateClassName);
}
