//
//  UIGestureRecognizer+Analyics.m
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/19.
//

#import "UIGestureRecognizer+Analyics.h"
#import "NSObject+KHSwizzler.h"
#import "KHSensorsAnalyicsSDK.h"

@implementation UIGestureRecognizer (Analyics)

- (NSDictionary *)getActionTargetDictWithGestureRecognizer:(UIGestureRecognizer *)sender {
    NSArray<UIGestureRecognizer *> *gestureRecognizers = [sender valueForKey:@"targets"];
    NSString *fristDescription = [gestureRecognizers.firstObject description];
    NSArray *descriptions = [fristDescription componentsSeparatedByString:@","];
    NSString *actionString = [descriptions firstObject];
    NSString *targetString = [descriptions lastObject];
    actionString = [actionString stringByReplacingOccurrencesOfString:@"(action=" withString:@""];
    targetString = [targetString stringByReplacingOccurrencesOfString:@"target=" withString:@""];
    targetString = [targetString stringByReplacingOccurrencesOfString:@")" withString:@""];
    
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    [properties setObject:actionString forKey:@"sel_name"];
    [properties setObject:targetString forKey:@"target_name"];
    return properties.copy;
}
@end


#pragma mark - UITapGestureRecognizer

@implementation UITapGestureRecognizer (Analyics)

+ (void)load {
    // Swizzle initWithTarget:action: 方法
    [UITapGestureRecognizer analyics_swizzleMethod:@selector(initWithTarget:action:) withMethod:@selector(analyics_initWithTarget:action:)];
    
    // Swizzle addTarget:action: 方法
    [UITapGestureRecognizer analyics_swizzleMethod:@selector(addTarget:action:) withMethod:@selector(analyics_addTarget:action:)];
}

- (instancetype)analyics_initWithTarget:(nullable id)target action:(nullable SEL)action {
    [self analyics_initWithTarget:target action:action];

    [self addTarget:target action:action];
    return self;
}

- (void)analyics_addTarget:(id)target action:(SEL)action {
    
    [self analyics_addTarget:target action:action];
    
    // 新增Target-Action ，用于触发 AppClick 事件
    [self analyics_addTarget:self action:@selector(analyics_trackTapGestureAction:)];
}

- (void)analyics_trackTapGestureAction:(UITapGestureRecognizer *)sender {
    // 获取手势识别器的控件
    UIView *view = sender.view;
    // TODO: 暂定只采集UILabel和UIImageView
    BOOL isTrackClass = [view isKindOfClass:UILabel.class] || [view isKindOfClass: UIImageView.class];
    if (!isTrackClass) {
        return;
    }
    NSDictionary *properties = [self getActionTargetDictWithGestureRecognizer:sender];
    // 触发 AppClick 事件
    [[KHSensorsAnalyicsSDK sharedInstance] trackAppClickWithView:view properties:properties];
}

@end


#pragma mark - UILongPressGestureRecognizer

@implementation UILongPressGestureRecognizer (Analyics)

+ (void)load {
    // Swizzle initWithTarget:action:方法
    [UILongPressGestureRecognizer analyics_swizzleMethod:@selector(initWithTarget:action:) withMethod:@selector(analyics_initWithTarget:action:)];
    // Swizzle addTarget:action:方法
    [UILongPressGestureRecognizer analyics_swizzleMethod:@selector(addTarget:action:) withMethod:@selector(analyics_addTarget:action:)];
}

- (instancetype)analyics_initWithTarget:(id)target action:(SEL)action {
    
    [self analyics_initWithTarget:target action:action];
    
    [self addTarget:target action:action];
    return self;
}

- (void)analyics_addTarget:(id)target action:(SEL)action {
    
    [self analyics_addTarget:target action:action];
    
    // 新增Target-Action，用于埋点
    [self analyics_addTarget:self action:@selector(analyics_trackLongPressGestureAction:)];
}

- (void)analyics_trackLongPressGestureAction:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateEnded) {
        return;
    }
    UIView *view = sender.view;
    // TODO: 暂定只采集UILabel和UIImageView
    BOOL isTrackClass = [view isKindOfClass:UILabel.class] || [view isKindOfClass: UIImageView.class];
    if (!isTrackClass) {
        return;
    }
    NSDictionary *properties = [self getActionTargetDictWithGestureRecognizer:sender];
    // 触发 AppClick 事件
    [[KHSensorsAnalyicsSDK sharedInstance] trackAppClickWithView:view properties:properties];
}

@end


#pragma mark - UIPanGestureRecognizer

@implementation UIPanGestureRecognizer (Analyics)

+ (void)load {
    // Swizzle initWithTarget:action: 方法
    [UIPanGestureRecognizer analyics_swizzleMethod:@selector(initWithTarget:action:) withMethod:@selector(analyics_initWithTarget:action:)];
    
    // Swizzle addTarget:action: 方法
    [UIPanGestureRecognizer analyics_swizzleMethod:@selector(addTarget:action:) withMethod:@selector(analyics_addTarget:action:)];
}

- (instancetype)analyics_initWithTarget:(nullable id)target action:(nullable SEL)action {
    [self analyics_initWithTarget:target action:action];

    [self addTarget:target action:action];
    return self;
}

- (void)analyics_addTarget:(id)target action:(SEL)action {
    
    [self analyics_addTarget:target action:action];
    
    // 新增Target-Action ，用于触发 AppClick 事件
    [self analyics_addTarget:self action:@selector(analyics_trackTapGestureAction:)];
}

- (void)analyics_trackTapGestureAction:(UITapGestureRecognizer *)sender {
    // 获取手势识别器的控件
    UIView *view = sender.view;
    // TODO: 暂定只采集UILabel和UIImageView
    BOOL isTrackClass = [view isKindOfClass:UILabel.class] || [view isKindOfClass: UIImageView.class];
    if (!isTrackClass) {
        return;
    }
    NSDictionary *properties = [self getActionTargetDictWithGestureRecognizer:sender];
    // 触发 AppClick 事件
    [[KHSensorsAnalyicsSDK sharedInstance] trackAppClickWithView:view properties:properties];
}

@end


#pragma mark - UISwipeGestureRecognizer

@implementation UISwipeGestureRecognizer (Analyics)

+ (void)load {
    // Swizzle initWithTarget:action: 方法
    [UISwipeGestureRecognizer analyics_swizzleMethod:@selector(initWithTarget:action:) withMethod:@selector(analyics_initWithTarget:action:)];
    
    // Swizzle addTarget:action: 方法
    [UISwipeGestureRecognizer analyics_swizzleMethod:@selector(addTarget:action:) withMethod:@selector(analyics_addTarget:action:)];
}

- (instancetype)analyics_initWithTarget:(nullable id)target action:(nullable SEL)action {
    [self analyics_initWithTarget:target action:action];

    [self addTarget:target action:action];
    return self;
}

- (void)analyics_addTarget:(id)target action:(SEL)action {
    
    [self analyics_addTarget:target action:action];
    
    // 新增Target-Action ，用于触发 AppClick 事件
    [self analyics_addTarget:self action:@selector(analyics_trackTapGestureAction:)];
}

- (void)analyics_trackTapGestureAction:(UITapGestureRecognizer *)sender {
    // 获取手势识别器的控件
    UIView *view = sender.view;
    // TODO: 暂定只采集UILabel和UIImageView
    BOOL isTrackClass = [view isKindOfClass:UILabel.class] || [view isKindOfClass: UIImageView.class];
    if (!isTrackClass) {
        return;
    }
    NSDictionary *properties = [self getActionTargetDictWithGestureRecognizer:sender];
    // 触发 AppClick 事件
    [[KHSensorsAnalyicsSDK sharedInstance] trackAppClickWithView:view properties:properties];
}


@end
