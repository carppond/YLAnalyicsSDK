//
//  UIView+YLTool.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/11/4.
//

#import "UIView+YLTool.h"

@implementation UIView (YLTool)

- (NSString *)viewPath {
    __block NSString *viewPath = @"";
    
    for (UIView *view = self;view;view = view.superview) {
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


@end
