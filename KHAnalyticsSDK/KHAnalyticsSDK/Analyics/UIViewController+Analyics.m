//
//  UIViewController+Analyics.m
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/16.
//  页面浏览事件全埋点

#import "UIViewController+Analyics.h"
#import "KHSensorsAnalyicsSDK.h"
#import "NSObject+KHSwizzler.h"
#import "YLLogger.h"

static NSString * const kSensorsDataBlackListFileName = @"KHAnalycisBlackList";

@implementation UIViewController (Analyics)

+ (void)load {
    [UIViewController analyics_swizzleMethod:@selector(viewDidAppear:) withMethod:@selector(analyics_viewDidAppear:)];
}

- (void)analyics_viewDidAppear:(BOOL)animated {
    [self analyics_viewDidAppear:animated];
    
    if ([self shouldTrackAppViewScreen]) {
        NSMutableDictionary *properties = [NSMutableDictionary dictionary];
        [properties setObject:NSStringFromClass([self class]) forKey:@"screen_name"];
        //navigationItem.titleView的优先级高于navigationItem.title
        NSString *title = [self contentFromView:self.navigationItem.titleView];
        if (title.length == 0) {
            title = self.navigationItem.title;
        }
        if (title) {
            [properties setObject:title forKey:@"title"];
        }
        [[KHSensorsAnalyicsSDK sharedInstance] track:@"AppViewScreen" properties:properties];
    }
}

- (NSString *)contentFromView:(UIView *)rootView {
    if (rootView.isHidden) {
        return nil;
    }
    NSMutableString *elementContent = [NSMutableString string];
    
    if ([rootView isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)rootView; NSString *title = button.titleLabel.text;
        if (title.length > 0) {
            [elementContent appendString:title];
        } else if ([rootView isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)rootView;
            NSString *title = label.text;
            if (title.length > 0) {
                [elementContent appendString:title];
            }
        } else if ([rootView isKindOfClass:[UITextView class]]) {
            UITextView *textView = (UITextView *)rootView;
            NSString *title = textView.text;
            if (title.length > 0) {
                [elementContent appendString:title];
            }
        } else {
            NSMutableArray<NSString *> *elementContentArray = [NSMutableArray array];
            
            for (UIView *subview in rootView.subviews) {
                NSString *temp = [self contentFromView:subview];
                if (temp.length > 0) {
                    [elementContentArray addObject:temp];
                }
            }
            if (elementContentArray.count > 0) {
                [elementContent appendString:[elementContentArray componentsJoinedByString:
                                              @"-"]];
            }
        }
    }
    return [elementContent copy];
}

- (BOOL)shouldTrackAppViewScreen {
    static NSSet *blackList = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 获取黑名单路径
        NSString *path = [[NSBundle bundleForClass:[KHSensorsAnalyicsSDK class]] pathForResource:kSensorsDataBlackListFileName ofType:@"plist"];
        /// 读取文件中黑名单类名的数组
        NSArray *classNames = [NSArray arrayWithContentsOfFile:path];
        NSMutableSet *set = [NSMutableSet setWithCapacity:classNames.count];
        for (NSString *className in classNames) {
            [set addObject:NSClassFromString(className)];
        }
        blackList = [set copy];
    });
    for (Class cls in blackList) {
        if ([self isKindOfClass:cls]) {
            return NO;
        }
    }
    return YES;
}
    
@end
