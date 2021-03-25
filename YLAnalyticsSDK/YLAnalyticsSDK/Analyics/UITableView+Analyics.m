//
//  UITableView+Analyics.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/19.
//

#import "UITableView+Analyics.h"
#import "NSObject+YLSwizzler.h"
#import <objc/message.h>
#import "YLSensorsAnalyicsSDK.h"
#import "YLAnalyicsLog.h"

@implementation UITableView (Analyics)
+ (void)load {
    [UITableView analyics_swizzleMethod:@selector(setDelegate:) withMethod:@selector(analyics_setDelegate:)];
}

- (void)analyics_setDelegate:(id<UITableViewDelegate>)delegate {
    [self analyics_setDelegate:delegate];
    // 方案一：方法交换
    // 交换delegate对象中的tableView:didSelectRowAtIndexPath:方法
    [self analyics_swizzleDidSelectRowAtIndexPathMethodWithDelegate:delegate];
}

- (void)analyics_swizzleDidSelectRowAtIndexPathMethodWithDelegate:(id)delegate {
    
    Class delegateClass = [delegate class];
    SEL sourceSelector = @selector(tableView:didSelectRowAtIndexPath:);
    if (![delegate respondsToSelector:sourceSelector]) {
        return;
    }
    
    SEL destinationSelector = NSSelectorFromString(@"analyics_tableView:didSelectRowAtIndexPath:");
    // 当delegate对象中已经存在了sensorsdata_tableView:didSelectRowAtIndexPath:方法，
    // 说明已经进行交换，因此可以直接返回
    if ([delegate respondsToSelector:destinationSelector]) {
        return;
    }
    
    Method sourceMethod = class_getInstanceMethod(delegateClass, sourceSelector);
    const char * encoding = method_getTypeEncoding(sourceMethod);
    // 当该类中已经存在相同的方法，则添加方法失败。
    // 但是前面已经判断过是否存在，因此，此处一定会添加成功
    if (!class_addMethod([delegate class], destinationSelector, (IMP)analyics_tableViewDidSelectRow, encoding)) {
        KeHouDebug(@"Add %@ to %@ error", NSStringFromSelector(sourceSelector), [delegate class]);
        return;
    }
    // 方法添加成功之后，进行方法交换
    [delegateClass analyics_swizzleMethod:sourceSelector withMethod:destinationSelector];
}



static void analyics_tableViewDidSelectRow(id object, SEL selector, UITableView *tableView, NSIndexPath *indexPath) {
    SEL destinationSelector = NSSelectorFromString(@"analyics_tableView:didSelectRowAtIndexPath:");
    // 通过消息发送，调用原始的tableView:didSelectRowAtIndexPath:方法实现
    ((void(*)(id, SEL, id, id))objc_msgSend)(object, destinationSelector, tableView, indexPath);
    
    // 触发 AppClick 事件
    [[YLSensorsAnalyicsSDK sharedInstance] trackAppClickWithTableView:tableView didSelectRowAtIndexPath:indexPath properties:nil];
}
@end
