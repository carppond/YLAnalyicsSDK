//
//  UIGestureRecognizer+Analyics.h
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/19.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIGestureRecognizer (Analyics)

/*!
 *  获取 action、target信息字典
 *
 *  @param sender 手势
 *
 *  @return 方法信息字典
 */
- (NSDictionary *)getActionTargetDictWithGestureRecognizer:(UIGestureRecognizer *)sender;
@end


#pragma mark - UITapGestureRecognizer

@interface UITapGestureRecognizer (Analyics)

@end


#pragma mark - UILongPressGestureRecognizer

@interface UILongPressGestureRecognizer (Analyics)

@end


#pragma mark - UIPanGestureRecognizer

@interface UIPanGestureRecognizer (Analyics)

@end


#pragma mark - UISwipeGestureRecognizer

@interface UISwipeGestureRecognizer (Analyics)

@end


NS_ASSUME_NONNULL_END
