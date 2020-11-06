//
//  KHAnalyicsTrackProperty.h
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/23.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol KHAnalyicsTrackProperty <NSObject>

@end

#pragma mark -
@protocol KHAnalyicsTrackViewPathProperty <NSObject>
@optional

/// AppClick 某个元素的相对路径，拼接 element_path，用于可视化全埋点
@property (nonatomic, copy, readonly) NSString *analyicsItemPath;

/// AppClick 某个元素的相对路径，拼接 element_selector，用于点击图
@property (nonatomic, copy, readonly) NSString *analyicsHeatMapPath;


/// 元素相似路径，可能包含 [-]
@property (nonatomic, copy, readonly) NSString *analyicsSimilarPath;
@end


NS_ASSUME_NONNULL_END
