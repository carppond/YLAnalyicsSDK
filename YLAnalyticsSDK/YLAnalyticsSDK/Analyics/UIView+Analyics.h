//
//  UIView+Analyics.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/19.
//

#import <UIKit/UIKit.h>
#import "YLAnalyicsTrackProperty.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIView (Analyics)<YLAnalyicsTrackViewPathProperty>

@property (nonatomic, copy, readonly) NSString *analyicsElementType;
@property (nonatomic, copy, readonly) NSString *analyicsElementContent;
@property (nonatomic, readonly) UIViewController *analyicsViewController;
@property (nonatomic, copy, readonly) NSString *viewPath;

+(NSString *)viewPath:(UIView *)currentView;
@end


#pragma mark - UISlider

@interface UISlider (Analyics)<YLAnalyicsTrackViewPathProperty>

@end

#pragma mark - UILabel

@interface UILabel (Analyics) <YLAnalyicsTrackViewPathProperty>
@end

@interface UIImageView (Analyics) <YLAnalyicsTrackViewPathProperty>
@end

@interface UITextView (Analyics) <YLAnalyicsTrackViewPathProperty>
@end

@interface UISearchBar (Analyics) <YLAnalyicsTrackViewPathProperty>
@end

@interface UITableViewHeaderFooterView (Analyics) <YLAnalyicsTrackViewPathProperty>
@end

#pragma mark - UIControl

@interface UIControl (Analyics) <YLAnalyicsTrackViewPathProperty>
@end

@interface UIButton (Analyics) <YLAnalyicsTrackViewPathProperty>
@end

@interface UISwitch (Analyics) <YLAnalyicsTrackViewPathProperty>
@end

@interface UIStepper (Analyics) <YLAnalyicsTrackViewPathProperty>
@end

@interface UISegmentedControl (Analyics) <YLAnalyicsTrackViewPathProperty>
@end


@interface UIPageControl (Analyics) <YLAnalyicsTrackViewPathProperty>
@end

#pragma mark - Cell
@interface UITableViewCell (Analyics) <YLAnalyicsTrackViewPathProperty>

// 遍历查找 cell 所在的 indexPath
@property (nonatomic, strong, readonly) NSIndexPath *analyicsIndexPath;

@end

@interface UICollectionViewCell (Analyics) <YLAnalyicsTrackViewPathProperty>
@end


NS_ASSUME_NONNULL_END
