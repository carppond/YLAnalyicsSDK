//
//  NSObject+YLSwizzler.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/16.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN



@interface NSObject (YLSwizzler)

/*! 交换方法名为 originalSEL 和 方法名为 swizzleSEL 两个方法的实现
 *
 *  @param originalSEL 原始方法名
 *  @param swizzleSEL 要交换的方法名
 */
+ (BOOL)analyics_swizzleMethod:(SEL)originalSEL withMethod:(SEL)swizzleSEL;

#ifdef DEBUG
+ (NSArray<NSString *> *)getIvars;
#endif
@end


#pragma mark - UIImage

@interface UIImage (YLSwizzler)

@property (nonatomic, copy) NSString *imageName;

@end
NS_ASSUME_NONNULL_END
