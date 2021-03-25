//
//  UIView+Analyics.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/19.
//

#import "UIView+Analyics.h"
#import "YLSensorsAnalyicsSDK.h"
#import "YLSensorsAnalyicsTool.h"
#import <objc/runtime.h>
#import "NSObject+YLSwizzler.h"

@implementation UIView (Analyics)

- (NSString *)analyicsElementType {
    return NSStringFromClass([self class]);
}

- (NSString *)analyicsElementContent {
    if (self.isHidden || self.alpha == 0) {
        return nil;
    }
    NSMutableArray *contents = [NSMutableArray array];
    for (UIView *view in self.subviews) {
        // 获取子控件的内容
        // 如果子类有内容，例如UILabel的text，获取到的就是text属性
        // 如果子类没有内容，就递归调用该方法，获取其子控件的内容
        NSString *content = view.analyicsElementContent;
        if (content.length > 0) {
            [contents addObject:content];
        }
    }
    // 当未获取到子控件内容时，返回nil。如果获取到多个子控件内容时，使用"-"拼接
    return contents.count == 0 ? nil : [contents componentsJoinedByString:@"-"];
}

- (UIViewController *)analyicsViewController {
    UIResponder *responder = self;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass: [UIViewController class]]){
            return (UIViewController *)responder;
        }
    }
    // 如果没有找到，返回nil
    return nil;
}

- (BOOL)shouldTrackAppViewScreen {
    static NSSet *blackList = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 获取黑名单路径
        NSString *path = [[NSBundle bundleForClass:[YLSensorsAnalyicsSDK class]] pathForResource:@"YLAnalycisBlackList" ofType:@"plist"];
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
 
- (NSString *)viewPath {
    NSString * path = @"";

    for (UIView* next = self; next; next = next.superview) {
        if (![next shouldTrackAppViewScreen]) {
            continue;
        }
        if ([next.nextResponder isKindOfClass:UIViewController.class]) {
            path = [NSString stringWithFormat:@"%@_%ld_%@",next.class,(long)[self viewInIndexToSuperView:next],path];
        } else {
            path = [NSString stringWithFormat:@"%@_%ld_%@",next.class,(long)[self viewInIndexToSuperView:next],path];
        }
    }
    return path;
}

+(NSString *)viewPath:(UIView *)currentView{
    __block NSString *viewPath = @"";
    
    for (UIView *view = currentView;view;view = view.superview) {
        NSLog(@"%@",view);
        if (![view shouldTrackAppViewScreen]) {
            continue;
        }
        if ([view isKindOfClass:[UICollectionViewCell class]]) {
            // 是一个
            UICollectionViewCell *cell = (UICollectionViewCell *)view;
            UICollectionView *cv = (UICollectionView *)cell.superview;
            NSIndexPath *indexPath = [cv indexPathForCell:cell];
            NSString *className = NSStringFromClass([cell class]);
            viewPath = [NSString stringWithFormat:@"%@[%ld:%ld]-%@",className,indexPath.section,indexPath.row,viewPath];
            continue;
        }
        
        if ([view isKindOfClass:[UITableViewCell class]]) {
            // 是一个
            UITableViewCell *cell = (UITableViewCell *)view;
            UITableView *tb = (UITableView *)cell.superview;
            NSIndexPath *indexPath = [tb indexPathForCell:cell];
            NSString *className = NSStringFromClass([cell class]);
            viewPath = [NSString stringWithFormat:@"%@[%ld:%ld]-%@",className,indexPath.section,indexPath.row,viewPath];
            continue;
        }
        
        
        if ([view isKindOfClass:[UIView class]]) {
            [view.superview.subviews enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj == view) {
                    NSString *className = NSStringFromClass([view class]);
                    viewPath = [NSString stringWithFormat:@"%@[%ld]-%@",className,idx,viewPath];
                    *stop = YES;
                }
            }];
        }
        
        UIResponder *responder = [view nextResponder];
        if ([responder isKindOfClass:[UIViewController class]]) {
            
            NSString *className = NSStringFromClass([responder class]);
            viewPath = [NSString stringWithFormat:@"%@[0]-%@",className,viewPath];
//            return viewPath;
        }
        if ([view isKindOfClass:[UIWindow class]]) {
            
            NSString *className = NSStringFromClass([view class]);
            viewPath = [NSString stringWithFormat:@"%@[0]-%@",className,viewPath];
            return viewPath;
        }
        
        
    }
    return viewPath;
}



- (NSInteger)viewInIndexToSuperView:(UIView *)view
{
    NSInteger index = 0;
    NSArray * viewAry = [view.superview subviews];
    
    //取同类元素的index
    NSInteger j = 0;
    
    for (int i = 0; i<viewAry.count; i++)
    {
        UIView * chileView = viewAry[i];
        if ([chileView.class isEqual:view.class])
        {
            if ([chileView isEqual:view]){
                index = j;
            }
            j++;
        }
    }
    return index;
    
}

- (NSString *)analyicsElementPosition {
    UIView *superview = self.superview;
    if (superview && superview.analyicsElementPosition) {
        return superview.analyicsElementPosition;
    }
    return nil;
}

- (NSString *)analyicsItemPath {
    /* 忽略路径
     UITableViewWrapperView 为 iOS11 以下 UITableView 与 cell 之间的 view
     */
    if ([NSStringFromClass(self.class) isEqualToString:@"UITableViewWrapperView"]) {
        return nil;
    }
    NSInteger index = [YLSensorsAnalyicsTool itemIndexForResponder:self];
    NSString *className = NSStringFromClass(self.class);
    return index < 0 ? className : [NSString stringWithFormat:@"%@[%ld]", className, (long)index];
}

- (NSString *)analyicsSimilarPath {
    // 是否支持限定元素位置功能
    BOOL isCell = [self isKindOfClass:UITableViewCell.class] || [self isKindOfClass:UICollectionViewCell.class];
    
    BOOL isItem = [NSStringFromClass(self.class) isEqualToString:@"UITabBarButton"] || [NSStringFromClass(self.class) isEqualToString:@"UISegment"];

    BOOL enableSupportSimilarPath = isCell || isItem;
    if (self.analyicsElementPosition && enableSupportSimilarPath) {
        NSString *similarPath = [NSString stringWithFormat:@"%@[-]",NSStringFromClass(self.class)];
        return similarPath;
    } else {
        return self.analyicsItemPath;
    }
}

- (NSString *)analyicsHeatMapPath {
    /* 忽略路径
     UITableViewWrapperView 为 iOS11 以下 UITableView 与 cell 之间的 view
     */
    if ([NSStringFromClass(self.class) isEqualToString:@"UITableViewWrapperView"]) {
        return nil;
    }
    
    NSString *identifier = [YLSensorsAnalyicsTool viewIdentifierForView:self];
    if (identifier) {
        return identifier;
    }
    return [YLSensorsAnalyicsTool itemHeatMapPathForResponder:self];
}

@end


#pragma mark - UIButton

@implementation UIButton (Analyics)

- (NSString *)analyicsElementContent {
    
    return self.currentTitle ?: [super analyicsElementContent];
}

@end


#pragma mark - UISwitch

@implementation UISwitch  (Analyics)

- (NSString *)analyicsElementContent {
    return self.on ? @"checked" : @"unchecked";
}

@end


#pragma mark - UISlider

@implementation UISlider (Analyics)

- (NSString *)analyicsElementContent {
    return [NSString stringWithFormat:@"%.2f", self.value];
}
@end

#pragma mark - UIStepper

@implementation UIStepper (Analyics)

- (NSString *)analyicsElementContent {
    return [NSString stringWithFormat:@"%g", self.value];
}

@end


#pragma mark - UILabel

@implementation UILabel (Analyics)

- (NSString *)analyicsElementContent {
    return self.text ?: [super analyicsElementContent];
}

@end


@implementation UIImageView (Analyics)

- (NSString *)analyicsElementContent {
    NSString *imageName = self.image.imageName;
    if (imageName.length > 0) {
        return [NSString stringWithFormat:@"%@", imageName];
    }
    
    return super.analyicsElementContent;
}

- (NSString *)analyicsElementPosition {
    if ([NSStringFromClass(self.class) isEqualToString:@"UISegment"]) {
        NSInteger index = [YLSensorsAnalyicsTool itemIndexForResponder:self];
        return index >= 0 ? [NSString stringWithFormat:@"%ld",(long)index] : [super analyicsElementPosition];
    }
    return [super analyicsElementPosition];
}

@end

@implementation UITextView (Analyics)

- (NSString *)analyicsElementContent {
    return self.text ?: super.analyicsElementContent;
}

- (NSString *)analyicsItemPath {
    /* 忽略路径
     UITableViewWrapperView 为 iOS11 以下 UITableView 与 cell 之间的 view
     */
    if ([NSStringFromClass(self.class) isEqualToString:@"UITableViewWrapperView"]) {
        return nil;
    }
    NSInteger index = [YLSensorsAnalyicsTool itemIndexForResponder:self];
    NSString *className = NSStringFromClass(self.class);
    return index < 0 ? className : [NSString stringWithFormat:@"%@[%ld]", className, (long)index];
}

- (NSString *)analyicsSimilarPath {
    // 是否支持限定元素位置功能
    BOOL isCell = [self isKindOfClass:UITableViewCell.class] || [self isKindOfClass:UICollectionViewCell.class];
    
    BOOL isItem = [NSStringFromClass(self.class) isEqualToString:@"UITabBarButton"] || [NSStringFromClass(self.class) isEqualToString:@"UISegment"];

    BOOL enableSupportSimilarPath = isCell || isItem;
    if (self.analyicsElementPosition && enableSupportSimilarPath) {
        NSString *similarPath = [NSString stringWithFormat:@"%@[-]",NSStringFromClass(self.class)];
        return similarPath;
    } else {
        return self.analyicsItemPath;
    }
}

- (NSString *)analyicsHeatMapPath {
    /* 忽略路径
     UITableViewWrapperView 为 iOS11 以下 UITableView 与 cell 之间的 view
     */
    if ([NSStringFromClass(self.class) isEqualToString:@"UITableViewWrapperView"]) {
        return nil;
    }
    
    NSString *identifier = [YLSensorsAnalyicsTool viewIdentifierForView:self];
    if (identifier) {
        return identifier;
    }
    return [YLSensorsAnalyicsTool itemHeatMapPathForResponder:self];
}

@end

@implementation UISearchBar (Analyics)

- (NSString *)analyicsElementContent {
    return self.text;
}

@end

@implementation UITableViewHeaderFooterView (Analyics)

- (NSString *)analyicsItemPath {
    UITableView *tableView = (UITableView *)self.superview;
    while (![tableView isKindOfClass:UITableView.class]) {
        tableView = (UITableView *)tableView.superview;
        if (!tableView) {
            return super.analyicsItemPath;
        }
    }
    for (NSInteger i = 0; i < tableView.numberOfSections; i++) {
        if (self == [tableView headerViewForSection:i]) {
            return [NSString stringWithFormat:@"[SectionHeader][%ld]", (long)i];
        }
        if (self == [tableView footerViewForSection:i]) {
            return [NSString stringWithFormat:@"[SectionFooter][%ld]", (long)i];
        }
    }
    return super.analyicsItemPath;
}

- (NSString *)analyicsHeatMapPath {
    UIView *currentTableView = self.superview;
    while (![currentTableView isKindOfClass:UITableView.class]) {
        currentTableView = currentTableView.superview;
        if (!currentTableView) {
            return super.analyicsHeatMapPath;
        }
    }

    UITableView *tableView = (UITableView *)currentTableView;
    for (NSInteger i = 0; i < tableView.numberOfSections; i++) {
        if (self == [tableView headerViewForSection:i]) {
            return [NSString stringWithFormat:@"[SectionHeader][%ld]", (long)i];
        }
        if (self == [tableView footerViewForSection:i]) {
            return [NSString stringWithFormat:@"[SectionFooter][%ld]", (long)i];
        }
    }
    return super.analyicsHeatMapPath;
}

@end

#pragma mark - UIControl

@implementation UIControl (Analyics)

- (NSString *)analyicsElementType {
    // UIBarButtonItem
    if (([NSStringFromClass(self.class) isEqualToString:@"UINavigationButton"] || [NSStringFromClass(self.class) isEqualToString:@"_UIButtonBarButton"])) {
        return @"UIBarButtonItem";
    }

    // UITabBarItem
    if ([NSStringFromClass(self.class) isEqualToString:@"UITabBarButton"]) {
        return @"UITabBarItem";
    }
    return NSStringFromClass(self.class);
}


- (NSString *)analyicsElementPosition {
    // UITabBarItem
    if ([NSStringFromClass(self.class) isEqualToString:@"UITabBarButton"]) {
        NSInteger index = [YLSensorsAnalyicsTool itemIndexForResponder:self];
        return [NSString stringWithFormat:@"%ld", (long)index];
    }

    return super.analyicsElementPosition;
}

@end


@implementation UISegmentedControl (Analyics)

- (NSString *)analyicsElementContent {
    return  self.selectedSegmentIndex == UISegmentedControlNoSegment ? [super analyicsElementContent] : [self titleForSegmentAtIndex:self.selectedSegmentIndex];
}

- (NSString *)analyicsElementPosition {
    return self.selectedSegmentIndex == UISegmentedControlNoSegment ? [super analyicsElementPosition] : [NSString stringWithFormat: @"%ld", (long)self.selectedSegmentIndex];
}

- (NSString *)analyicsItemPath {
    // 支持单个 UISegment 创建事件。UISegment 是 UIImageView 的私有子类，表示UISegmentedControl 单个选项的显示区域
    NSString *subPath = [NSString stringWithFormat:@"%@[%ld]", @"UISegment", (long)self.selectedSegmentIndex];
    return [NSString stringWithFormat:@"%@/%@", super.analyicsItemPath, subPath];
}

- (NSString *)analyicsSimilarPath {
    NSString *subPath = [NSString stringWithFormat:@"%@[-]", @"UISegment"];
    return [NSString stringWithFormat:@"%@/%@", super.analyicsSimilarPath, subPath];
}

- (NSString *)analyicsHeatMapPath {
    NSString *subPath = [NSString stringWithFormat:@"%@[%ld]", @"UISegment", (long)self.selectedSegmentIndex];
    return [NSString stringWithFormat:@"%@/%@", super.analyicsHeatMapPath, subPath];
}

@end

@implementation UIPageControl (Analyics)

- (NSString *)analyicsElementContent {
    return [NSString stringWithFormat:@"%ld", (long)self.currentPage];
}

@end

#pragma mark - Cell

@implementation UITableViewCell (Analyics)

- (NSIndexPath *)analyicsIndexPath {
    UITableView *tableView = (UITableView *)[self superview];
    do {
        if ([tableView isKindOfClass:UITableView.class]) {
            NSIndexPath *indexPath = [tableView indexPathForCell:self];
            return indexPath;
        }
    } while ((tableView = (UITableView *)[tableView superview]));
    return nil;
}

- (NSString *)analyicsItemPath {
    if (self.analyicsIndexPath) {
        return [self analyicsItemPathWithIndexPath:self.analyicsIndexPath];
    }
    return [super analyicsItemPath];
}

- (NSString *)analyicsSimilarPath {
    if (self.analyicsIndexPath) {
        return [self analyicsSimilarPathWithIndexPath:self.analyicsIndexPath];
    } else {
        return self.analyicsItemPath;
    }
}

- (NSString *)analyicsHeatMapPath {
    if (self.analyicsIndexPath) {
        return [self analyicsItemPathWithIndexPath:self.analyicsIndexPath];
    }
    return [super analyicsHeatMapPath];
}
                
- (NSString *)analyicsElementPositionWithIndexPath:(NSIndexPath *)indexPath {
    return [NSString stringWithFormat: @"%ld:%ld", (long)indexPath.section, (long)indexPath.row];
}

- (NSString *)analyicsItemPathWithIndexPath:(NSIndexPath *)indexPath {
    return [NSString stringWithFormat:@"%@[%ld][%ld]", NSStringFromClass(self.class), (long)indexPath.section, (long)indexPath.row];
}

- (NSString *)analyicsSimilarPathWithIndexPath:(NSIndexPath *)indexPath {
    return [NSString stringWithFormat:@"%@[%ld][-]", NSStringFromClass(self.class), (long)indexPath.section];
}

@end

@implementation UICollectionViewCell (Analyics)

- (NSIndexPath *)sensorsdata_IndexPath {
    UICollectionView *collectionView = (UICollectionView *)[self superview];
    if ([collectionView isKindOfClass:UICollectionView.class]) {
        NSIndexPath *indexPath = [collectionView indexPathForCell:self];
        return indexPath;
    }
    return nil;
}

- (NSString *)analyicsItemPath {
    if (self.sensorsdata_IndexPath) {
        return [self analyicsItemPathWithIndexPath:self.sensorsdata_IndexPath];
    }
    return [super analyicsItemPath];
}

- (NSString *)analyicsSimilarPath {
    if (self.sensorsdata_IndexPath) {
        return [self analyicsSimilarPathWithIndexPath:self.sensorsdata_IndexPath];
    } else {
        return super.analyicsSimilarPath;
    }
}

- (NSString *)analyicsHeatMapPath {
    if (self.sensorsdata_IndexPath) {
        return [self analyicsItemPathWithIndexPath:self.sensorsdata_IndexPath];
    }
    return [super analyicsHeatMapPath];
}

- (NSString *)analyicsElementPositionWithIndexPath:(NSIndexPath *)indexPath {
    return [NSString stringWithFormat: @"%ld:%ld", (long)indexPath.section, (long)indexPath.item];
}

- (NSString *)analyicsItemPathWithIndexPath:(NSIndexPath *)indexPath {
    return [NSString stringWithFormat:@"%@[%ld][%ld]", NSStringFromClass(self.class), (long)indexPath.section, (long)indexPath.item];
}

- (NSString *)analyicsSimilarPathWithIndexPath:(NSIndexPath *)indexPath {
    if ([YLSensorsAnalyicsTool isAlertClickForView:self]) {
        return [self analyicsItemPathWithIndexPath:indexPath];
    }
    return [NSString stringWithFormat:@"%@[%ld][-]", NSStringFromClass(self.class), (long)indexPath.section];
}

@end

