//
//  UIApplication+Analyics.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/19.
//  Target-Acton

#import "UIApplication+Analyics.h"
#import "YLSensorsAnalyicsSDK.h"
#import "NSObject+YLSwizzler.h"
#import "UIView+Analyics.h"

@implementation UIApplication (Analyics)

+ (void)load {
        
    [UIApplication analyics_swizzleMethod:@selector(sendAction:to:from:forEvent:) withMethod:@selector(analyics_sendAction:to:from:forEvent:)];
}

- (BOOL)analyics_sendAction:(SEL)action
                         to:(nullable id)target
                       from:(nullable id)sender
                   forEvent:(nullable UIEvent *)event {
    if ([sender isKindOfClass:UISwitch.class] ||
        [sender isKindOfClass:UISegmentedControl.class] ||
        [sender isKindOfClass:UIStepper.class] ||
        event.allTouches.anyObject.phase == UITouchPhaseEnded) {
        
        UIView *view = (UIView *)sender;
        NSMutableDictionary *properties = [NSMutableDictionary dictionary];
        [properties setObject:NSStringFromSelector(action) forKey:@"sel_name"];
        [properties setObject:NSStringFromClass([target class]) forKey:@"target_name"];
        
        [[YLSensorsAnalyicsSDK sharedInstance] trackAppClickWithView:view properties:properties.copy];
    }
    
    return [self analyics_sendAction:action to:target from:sender forEvent:event];
}

@end
