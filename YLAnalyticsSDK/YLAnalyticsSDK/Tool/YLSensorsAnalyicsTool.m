//
//  YLSensorsAnalyicsTool.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/22.
//

#import "YLSensorsAnalyicsTool.h"
#import "YLSensorsAnalyicsSDK.h"
#import "YLSensorsAnalyicsCommonTool.h"
#import "YLAnalyicsTrackProperty.h"
#import "UIView+Analyics.h"


id isNil(id obj) {
    if (!obj) return [NSNull null];
    else            return obj;
}



@implementation YLSensorsAnalyicsTool

+ (UIViewController *)findNextViewControllerByResponder:(UIResponder *)responder {
    UIResponder *next = [responder nextResponder];
    do {
        if ([next isKindOfClass:UIViewController.class]) {
            UIViewController *vc = (UIViewController *)next;
            if ([vc isKindOfClass:UINavigationController.class]) {
                next = [(UINavigationController *)vc topViewController];
                break;
            } else if ([vc isKindOfClass:UITabBarController.class]) {
                next = [(UITabBarController *)vc selectedViewController];
                break;
            }
            UIViewController *parentVC = vc.parentViewController;
            if (parentVC) {
                if ([parentVC isKindOfClass:UINavigationController.class] ||
                    [parentVC isKindOfClass:UITabBarController.class] ||
                    [parentVC isKindOfClass:UIPageViewController.class] ||
                    [parentVC isKindOfClass:UISplitViewController.class]) {
                    break;
                }
            } else {
                break;
            }
        }
    } while ((next = next.nextResponder));
    return [next isKindOfClass:UIViewController.class] ? (UIViewController *)next : nil;
}

+ (UIViewController *)findSuperViewControllerByView:(UIView *)view {
    UIViewController *viewController = [YLSensorsAnalyicsTool findNextViewControllerByResponder:view];
    if ([viewController isKindOfClass:UINavigationController.class]) {
        viewController = [YLSensorsAnalyicsTool currentViewController];
    }
    return viewController;
}

+ (UIViewController *)currentViewController {
    __block UIViewController *currentViewController = nil;
    void (^ block)(void) = ^{
        UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
        currentViewController = [YLSensorsAnalyicsTool findCurrentViewControllerFromRootViewController:rootViewController isRoot:YES];
    };

    [YLSensorsAnalyicsCommonTool performBlockOnMainThread:block];
    return currentViewController;
}

+ (UIViewController *)findCurrentViewControllerFromRootViewController:(UIViewController *)viewController isRoot:(BOOL)isRoot {
    __block UIViewController *currentViewController = viewController;
    if (viewController.presentedViewController && ![viewController.presentedViewController isKindOfClass:UIAlertController.class]) {
        viewController = [self findCurrentViewControllerFromRootViewController:viewController.presentedViewController isRoot:NO];
    }

    if ([viewController isKindOfClass:[UITabBarController class]]) {
        return [self findCurrentViewControllerFromRootViewController:[(UITabBarController *)viewController selectedViewController] isRoot:NO];
    }
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        // 根视图为 UINavigationController
        UIViewController *topViewController = [(UINavigationController *)viewController topViewController];
        return [self findCurrentViewControllerFromRootViewController:topViewController isRoot:NO];
    }

    if (viewController.childViewControllers.count > 0) {
        if (viewController.childViewControllers.count == 1 && isRoot) {
            return [self findCurrentViewControllerFromRootViewController:viewController.childViewControllers.firstObject isRoot:NO];
        } else {
            //从最上层遍历（逆序），查找正在显示的 UITabBarController 或 UINavigationController 类型的
            // 是否包含 UINavigationController 或 UITabBarController 类全屏显示的 controller
            __block BOOL isContainController = NO;
            [viewController.childViewControllers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(__kindof UIViewController *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
                // 判断 obj.view 是否加载，如果尚未加载，调用 obj.view 会触发 viewDidLoad，可能影响客户业务
                if (obj.isViewLoaded) {
                    CGPoint point = [obj.view convertPoint:CGPointMake(0, 0) toView:nil];
                   // 正在全屏显示
                    BOOL isFullScreenShow = !obj.view.hidden && obj.view.alpha > 0 && CGPointEqualToPoint(point, CGPointMake(0, 0));
                   // 判断类型
                    BOOL isStopFindController = [obj isKindOfClass:UINavigationController.class] || [obj isKindOfClass:UITabBarController.class];
                    if (isFullScreenShow && isStopFindController) {
                        currentViewController = [self findCurrentViewControllerFromRootViewController:obj isRoot:NO];
                        *stop = YES;
                        isContainController = YES;
                    }
                }
            }];
            if (!isContainController) {
                return viewController;
            }
        }
    } else if ([viewController respondsToSelector:NSSelectorFromString(@"contentViewController")]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        UIViewController *tempViewController = [viewController performSelector:NSSelectorFromString(@"contentViewController")];
#pragma clang diagnostic pop
        if (tempViewController) {
            currentViewController = [self findCurrentViewControllerFromRootViewController:tempViewController isRoot:NO];
        }
    }
    return currentViewController;
}

+ (BOOL)isAlertForResponder:(UIResponder *)responder {
    do {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        BOOL isUIAlertView = [responder isKindOfClass:UIAlertView.class];
        BOOL isUIActionSheet = [responder isKindOfClass:UIActionSheet.class];
#pragma clang diagnostic pop

        BOOL isUIAlertController = [responder isKindOfClass:UIAlertController.class];
        
        if (isUIAlertController || isUIAlertView || isUIActionSheet) {
            return YES;
        }
    } while ((responder = [responder nextResponder]));
    return NO;
}

/// 是否为弹框点击
+ (BOOL)isAlertClickForView:(UIView *)view {
 #ifndef SENSORS_ANALYTICS_DISABLE_PRIVATE_APIS
        if ([NSStringFromClass(view.class) isEqualToString:@"_UIInterfaceActionCustomViewRepresentationView"] || [NSStringFromClass(view.class) isEqualToString:@"_UIAlertControllerCollectionViewCell"]) { // 标记弹框
            return YES;
        }
#endif
     return NO;
}


@end


#pragma mark - ViewPath

@implementation YLSensorsAnalyicsTool (ViewPath)

/// 采集时，是否忽略这个 viewController 对象
+ (BOOL)isIgnoredVisualizedAutoTrackForViewController:(UIViewController *)viewController {
    if (!viewController) {
        return NO;
    }
    YLSensorsAnalyicsSDK *sa = [YLSensorsAnalyicsSDK sharedInstance];
    BOOL isEnableVisualizedAutoTrack = [sa isVisualizedAutoTrackEnabled] && [sa isVisualizedAutoTrackViewController:viewController];
    return !isEnableVisualizedAutoTrack;
}

/// 采集时，是否忽略这个 viewController 对象
+ (BOOL)isIgnoredViewPathForViewController:(UIViewController *)viewController {
    YLSensorsAnalyicsSDK *sa = [YLSensorsAnalyicsSDK sharedInstance];

    BOOL isEnableVisualizedAutoTrack = [sa isVisualizedAutoTrackEnabled] && [sa isVisualizedAutoTrackViewController:viewController];
    return !isEnableVisualizedAutoTrack;
}

+ (NSArray<NSString *> *)viewPathsForViewController:(UIViewController<YLAnalyicsTrackViewPathProperty> *)viewController {
    NSMutableArray *viewPaths = [NSMutableArray array];
    do {
        [viewPaths addObject:viewController.analyicsHeatMapPath];
        viewController = (UIViewController<YLAnalyicsTrackViewPathProperty> *)viewController.parentViewController;
    } while (viewController);

    UIViewController<YLAnalyicsTrackViewPathProperty> *vc = (UIViewController<YLAnalyicsTrackViewPathProperty> *)viewController.presentingViewController;
    if ([vc conformsToProtocol:@protocol(YLAnalyicsTrackViewPathProperty)]) {
        [viewPaths addObjectsFromArray:[self viewPathsForViewController:vc]];
    }
    return viewPaths;
}

// 找到 view 的路径数组
+ (NSArray<NSString *> *)viewPathsForView:(UIView<YLAnalyicsTrackViewPathProperty> *)view {
    NSMutableArray *viewPathArray = [NSMutableArray array];
    do { // 遍历 view 层级 路径
        if (view.analyicsHeatMapPath) {
            [viewPathArray addObject:view.analyicsHeatMapPath];
        }
    } while ((view = (id)view.nextResponder) && [view isKindOfClass:UIView.class] && ![view isKindOfClass:UIWindow.class]);

    if ([view isKindOfClass:UIViewController.class] && [view conformsToProtocol:@protocol(YLAnalyicsTrackViewPathProperty)]) {
        // 遍历 controller 层 路径
        [viewPathArray addObjectsFromArray:[self viewPathsForViewController:(UIViewController<YLAnalyicsTrackViewPathProperty> *)view]];
    }
    return viewPathArray;
}

/// 获取 view 的路径字符串
+ (NSString *)viewPathForView:(UIView *)view atViewController:(UIViewController *)viewController {
    if ([self isIgnoredViewPathForViewController:viewController] &&
        viewController) {
        return nil;
    }
    NSArray *viewPaths = [[[self viewPathsForView:view] reverseObjectEnumerator] allObjects];
    NSString *viewPath = [viewPaths componentsJoinedByString:@"/"];

    return viewPath;
}

/// 获取模糊路径
+ (NSString *)viewSimilarPathForView:(UIView *)view atViewController:(UIViewController *)viewController shouldSimilarPath:(BOOL)shouldSimilarPath {
    if ([self isIgnoredVisualizedAutoTrackForViewController:viewController] &&
        viewController) {
        return nil;
    }

    NSMutableArray *viewPathArray = [NSMutableArray array];
    BOOL isContainSimilarPath = NO;

    do {
        if (isContainSimilarPath || !shouldSimilarPath) { // 防止 cell 嵌套，被拼上多个 [-]
            if (view.analyicsItemPath) {
                [viewPathArray addObject:view.analyicsItemPath];
            }
        } else {
            NSString *currentSimilarPath = view.analyicsSimilarPath;
            if (currentSimilarPath) {
                [viewPathArray addObject:currentSimilarPath];
                if ([currentSimilarPath rangeOfString:@"[-]"].location != NSNotFound) {
                    isContainSimilarPath = YES;
                }
            }
        }
    } while ((view = (id)view.nextResponder) && [view isKindOfClass:UIView.class]);

    if ([view isKindOfClass:UIAlertController.class]) {
        UIViewController<YLAnalyicsTrackViewPathProperty> *viewController = (UIViewController<YLAnalyicsTrackViewPathProperty> *)view;
        [viewPathArray addObject:viewController.analyicsItemPath];
    }

    NSString *viewPath = [[[viewPathArray reverseObjectEnumerator] allObjects] componentsJoinedByString:@"/"];

    return viewPath;
}

+ (NSInteger)itemIndexForResponder:(UIResponder *)responder {
    NSString *classString = NSStringFromClass(responder.class);
    NSArray *subResponder = nil;
    if ([responder isKindOfClass:UIView.class]) {
        UIResponder *next = [responder nextResponder];
        if ([next isKindOfClass:UISegmentedControl.class]) {
            // UISegmentedControl 点击之后，subviews 顺序会变化，需要根据坐标排序才能匹配正确
            UISegmentedControl *segmentedControl = (UISegmentedControl *)next;
            NSArray <UIView *> *subViews = segmentedControl.subviews;
            subResponder = [subViews sortedArrayUsingComparator:^NSComparisonResult (UIView *obj1, UIView *obj2) {
                if (obj1.frame.origin.x > obj2.frame.origin.x) {
                    return NSOrderedDescending;
                } else {
                    return NSOrderedAscending;
                }
            }];
        } else if ([next isKindOfClass:UIView.class]) {
            subResponder = [(UIView *)next subviews];
        }
    } else if ([responder isKindOfClass:UIViewController.class]) {
        subResponder = [(UIViewController *)responder parentViewController].childViewControllers;
    }

    NSInteger count = 0;
    NSInteger index = -1;
    for (UIResponder *res in subResponder) {
        if ([classString isEqualToString:NSStringFromClass(res.class)]) {
            count++;
        }
        if (res == responder) {
            index = count - 1;
        }
    }
    // 单个 UIViewController 拼接路径，不需要序号
    if ([responder isKindOfClass:UIViewController.class] && ![responder isKindOfClass:UIAlertController.class] && count == 1) {
        index = -1;
    }
    return index;
}

+ (NSString *)viewIdentifierForView:(UIView *)view {
    
    NSString *uuid = [NSUUID UUID].UUIDString;
    NSString *value = [NSString stringWithFormat:@"%p&&%@",view,uuid];
    return [NSString stringWithFormat:@"%@[(%@)]", NSStringFromClass([view class]), value];
}

+ (NSString *)itemHeatMapPathForResponder:(UIResponder *)responder {
    NSString *classString = NSStringFromClass(responder.class);

    NSArray *subResponder = nil;
    if ([responder isKindOfClass:UIView.class]) {
        UIResponder *next = [responder nextResponder];
        if ([next isKindOfClass:UIView.class]) {
            subResponder = [(UIView *)next subviews];
        }
    } else if ([responder isKindOfClass:UIViewController.class]) {
        subResponder = [(UIViewController *)responder parentViewController].childViewControllers;
    }

    NSInteger count = 0;
    NSInteger index = -1;
    for (UIResponder *res in subResponder) {
        if ([classString isEqualToString:NSStringFromClass(res.class)]) {
            count++;
        }
        if (res == responder) {
            index = count - 1;
        }
    }
    return count <= 1 ? classString : [NSString stringWithFormat:@"%@[%ld]", classString, (long)index];
}

@end


#pragma mark - Validator

@implementation YLSensorsAnalyicsTool (Validator)

+ (BOOL)isValidString:(NSString *)string {
    return ([string isKindOfClass:[NSString class]] && ([string length] > 0));
}

+ (BOOL)isValidArray:(NSArray *)array {
    return ([array isKindOfClass:[NSArray class]] && ([array count] > 0));
}

+ (BOOL)isValidDictionary:(NSDictionary *)dictionary {
    return ([dictionary isKindOfClass:[NSDictionary class]] && ([dictionary count] > 0));
}

@end
