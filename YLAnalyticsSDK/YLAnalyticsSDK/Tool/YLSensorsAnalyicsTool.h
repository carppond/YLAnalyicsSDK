//
//  YLSensorsAnalyicsTool.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/22.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

id isNil(id obj);

@interface YLSensorsAnalyicsTool : NSObject

/// 返回当前的 ViewController
@property(class, nonatomic, readonly) UIViewController *currentViewController;

/*!
 *  获取响应链中的下一个 UIViewController
 *
 *  @param responder 响应链中的对象
 *
 *  @return 下一个 ViewController
 */
+ (nullable UIViewController *)findNextViewControllerByResponder:(UIResponder *)responder;

/*!
 *  找到 view 所在的直接 ViewController
 *
 *  @param view 需要寻找的 View
 *
 *  @return SuperViewController
 */
+ (UIViewController *)findSuperViewControllerByView:(UIView *)view;

/// 是否为弹框
+ (BOOL)isAlertForResponder:(UIResponder *)responder;

/// 是否为弹框点击
+ (BOOL)isAlertClickForView:(UIView *)view;

@end


#pragma mark - ViewPath

@interface YLSensorsAnalyicsTool (ViewPath)

/*!
 *  采集时，是否忽略这个 viewController 对象
 *
 *  @param viewController 需要判断的对象
 *
 *  @return 是否忽略
 */
+ (BOOL)isIgnoredViewPathForViewController:(UIViewController *)viewController;

/*!
 *  创建 view 的唯一标识符
 *
 *  @param view 需要创建的对象
 *
 *  @return 唯一标识符
 */
+ (nullable NSString *)viewIdentifierForView:(UIView *)view;

/*!
 *  通过响应链找到 对象的点击图路径
 *
 *  @param responder 响应链中的对象，可以是 UIView 或者 UIViewController
 *
 *  @return 路径
 */
+ (NSString *)itemHeatMapPathForResponder:(UIResponder *)responder;

/*!
 *  通过响应链找到 对象的序号
 *
 *  @param responder 响应链中的对象，可以是 UIView 或者 UIViewController
 *
 *  @return 序号
 */
+ (NSInteger )itemIndexForResponder:(UIResponder *)responder;
 
/*!
 *  找到 view 的路径数组
 *
 *  @param view 需要获取路径的 view
 *
 *  @return 路径数组
 */
+ (NSArray<NSString *> *)viewPathsForView:(UIView *)view;

/*!
 *  获取 view 的路径字符串
 *
 *  @param view 需要获取路径的 view
 *  @param viewController view 所在的 viewController
 *
 *  @return 路径字符串
 */
+ (nullable NSString *)viewPathForView:(UIView *)view atViewController:(nullable UIViewController *)viewController;

/*!
 *  获取 view 的模糊路径
 *
 *  @param view 需要获取路径的 view
 *  @param viewController view 所在的 viewController
 *  @param shouldSimilarPath 是否需要取相似路径
 *
 *  @return 路径字符串
 */
+ (NSString *)viewSimilarPathForView:(UIView *)view atViewController:(nullable UIViewController *)viewController shouldSimilarPath:(BOOL)shouldSimilarPath;


@end


#pragma mark - Validator

@interface YLSensorsAnalyicsTool (Validator)

+ (BOOL)isValidString:(NSString *)string;

+ (BOOL)isValidDictionary:(NSDictionary *)dictionary;

+ (BOOL)isValidArray:(NSArray *)array;

@end
NS_ASSUME_NONNULL_END
