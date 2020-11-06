//
//  UIView+Analyics.h
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/19.
//

#import <UIKit/UIKit.h>
#import "KHAnalyicsTrackProperty.h"

NS_ASSUME_NONNULL_BEGIN

@interface UIView (Analyics)<KHAnalyicsTrackViewPathProperty>

@property (nonatomic, copy, readonly) NSString *analyicsElementType;
@property (nonatomic, copy, readonly) NSString *analyicsElementContent;
@property (nonatomic, readonly) UIViewController *analyicsViewController;
@property (nonatomic, copy, readonly) NSString *viewPath;

+(NSString *)viewPath:(UIView *)currentView;
@end


#pragma mark - UISlider

@interface UISlider (Analyics)<KHAnalyicsTrackViewPathProperty>

@end

#pragma mark - UILabel

@interface UILabel (Analyics) <KHAnalyicsTrackViewPathProperty>
@end

@interface UIImageView (Analyics) <KHAnalyicsTrackViewPathProperty>
@end

@interface UITextView (Analyics) <KHAnalyicsTrackViewPathProperty>
@end

@interface UISearchBar (Analyics) <KHAnalyicsTrackViewPathProperty>
@end

@interface UITableViewHeaderFooterView (Analyics) <KHAnalyicsTrackViewPathProperty>
@end

#pragma mark - UIControl

@interface UIControl (Analyics) <KHAnalyicsTrackViewPathProperty>
@end

@interface UIButton (Analyics) <KHAnalyicsTrackViewPathProperty>
@end

@interface UISwitch (Analyics) <KHAnalyicsTrackViewPathProperty>
@end

@interface UIStepper (Analyics) <KHAnalyicsTrackViewPathProperty>
@end

@interface UISegmentedControl (Analyics) <KHAnalyicsTrackViewPathProperty>
@end


@interface UIPageControl (Analyics) <KHAnalyicsTrackViewPathProperty>
@end

#pragma mark - Cell
@interface UITableViewCell (Analyics) <KHAnalyicsTrackViewPathProperty>

// 遍历查找 cell 所在的 indexPath
@property (nonatomic, strong, readonly) NSIndexPath *analyicsIndexPath;

@end

@interface UICollectionViewCell (Analyics) <KHAnalyicsTrackViewPathProperty>
@end


NS_ASSUME_NONNULL_END
