//
//  KHSensorsAnalyicsSDK.h
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/16.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, KHSensorsAnalyicsTacticsType) {
    /// 本地缓存数据条数发送策略
    KHSensorsAnalyicsTacticsType_BuildSize          = 1 << 1,
    /// 时间间隔发送策略
    KHSensorsAnalyicsTacticsType_TimeInterval       = 1 << 2,
    /// 进入后台发送策略
    KHSensorsAnalyicsTacticsType_EnterBackground    = 1 << 3
};

@interface KHSensorsAnalyicsSDK : NSObject

/// 设备ID （匿名ID）
@property (nonatomic, copy) NSString *anonymousId;
/// 开启可视化全埋点
@property (nonatomic, assign) BOOL enableVisualizedAutoTrack;

/*!
 *  获取 SDK 实例
 */
+ (instancetype)sharedInstance;

/// 当本地缓存的事件达到最大条数时，上传数据（默认为100条）
@property (nonatomic) NSUInteger flushBulkSize;

/// 两次数据发送的时间间隔，单位为秒
@property (nonatomic) NSUInteger flushInterval;

- (instancetype)init NS_UNAVAILABLE;

/*!
 *  初始化SDK
 *
 *  @param urlString 接收数据的服务端URL
 */
+ (void)startWithServerURL:(NSString *)urlString
          withFlushTactics:(KHSensorsAnalyicsTacticsType)type;

/*!
 *  用户登录，设置登录ID
 *
 *  @param loginInfo 用户登录信息
 */
- (void)login:(NSDictionary<NSString *,id> *)loginInfo;

/*!
 *  向服务器同步本地所有数据
 */
- (void)flush;

@end

#pragma mark - Track 跟踪事件

@interface KHSensorsAnalyicsSDK (Track)

/*! 调用 Track 接口，触发事件
 *
 *  @discussion properties是一个NSDictionary（字典）。
 *  其中，key是属性的名称，必须是NSString类型；value则是属性的内容
 *
 *  @param eventName 事件名称
 *  @param properties 事件属性
 */
- (void)track:(NSString *)eventName
   properties:(nullable NSDictionary<NSString *, id> *)properties;

/*! 触发 AppClick 事件
 *
 *  @param view 触发事件的控件
 *  @param properties 事件属性
 */
- (void)trackAppClickWithView:(UIView *)view properties:(nullable NSDictionary <NSString *, id> *)properties;


/*! 支持UITableView触发 AppClick 事件
 *
 *  @param tableView 触发事件的UITableView视图
 *  @param indexPath 在 UITableView 中点击的位置
 *  @param properties 事件属性
 */
- (void)trackAppClickWithTableView:(UITableView *)tableView
           didSelectRowAtIndexPath:(NSIndexPath *)indexPath
                        properties:(nullable NSDictionary<NSString *, id> *)properties;


/*! 支持UICollectionView触发 AppClick 事件
 *
 *  @param collectionView 触发事件的 UICollectionView 视图
 *  @param indexPath 在 UICollectionView 中点击的位置
 *  @param properties 事件属性
 */
- (void)trackAppClickWithCollectionView:(UICollectionView *)collectionView
               didSelectItemAtIndexPath:(NSIndexPath *)indexPath
                             properties:(nullable NSDictionary<NSString *, id> *)properties;

/*! 支持WKWebView触发 AppWKLoad事件
 *
 *  @param webView 触发事件的 webView 视图
 *  @param loadingTime 在 webView 中加载的时间
 *  @param properties 事件属性
 */
- (void)trackAppWithWKWebView:(WKWebView *)webView
                  loadingTime:(NSString *)loadingTime
                   properties:(nullable NSDictionary<NSString *, id> *)properties;
@end


#pragma mark - Timer

@interface KHSensorsAnalyicsSDK (Timer)

/*!
 *  开始统计事件时长
 *  调用这个接口时，并不会真正触发一次事件，只是开始计时
 *
 *  @param event 事件名
 */
- (void)trackTimerStart:(NSString *)event;

/*!
 *  结束事件时长统计，计算时长事件发生时长是从调用-trackTimerStart:方法开始，
 *  一直到调用-trackTimerEnd:properties:方法结束。
 *  如果多次调用-trackTimerStart:方法，则从最后一次调用开始计算。
 *  如果没有调用-trackTimerStart:方法，就直接调用trackTimerEnd:properties:方法，则触发一次
 *  普通事件，不带时长属性。
 *
 *  @param event 事件名，与开始时事件名一一对应
 *  @param properties 事件属性
 */
 - (void)trackTimerEnd:(NSString *)event properties:(nullable NSDictionary *)properties;

/*!
 *  暂停统计事件时长
 *  如果该事件未开始，即没有调用-trackTimerStart: 方法，则不做任何操作。
 *
 *  @param event 事件
 */
- (void)trackTimerPause:(NSString *)event;

/*!
 *  恢复统计事件时长
 *  如果该事件并未暂停，即没有调用-trackTimerPause:方法，则没有影响。
 *
 *  @param event 事件
 */
- (void)trackTimerResume:(NSString *)event;

@end


#pragma mark - WebView

@interface KHSensorsAnalyicsSDK (WebView)

/*!
 *  在WebView控件中添加自定义的UserAgent，用于实现打通方案
 *
 *  @param userAgent 自定义的UserAgent
 */
- (void)addWebViewUserAgent:(nullable NSString *)userAgent;

/*!
 *  判断是否需要拦截并处理JavaScript SDK发送过来的事件数据
 *
 *  @param webView 用于页面展示的WebView控件
 *  @param request WebView 控件中的请求
 */
- (BOOL)shouldTrackWithWebView:(id)webView request:(NSURLRequest *)request;

@end


#pragma mark - VisualizedAutoTrack

@interface KHSensorsAnalyicsSDK (VisualizedAutoTrack)

/*!
 *  判断是否为符合要求的 openURL
 *  !!!!!!! 暂不使用，还没有定规则
 *
 *  @param url 打开的 URL
 *
 *  @return  YES/NO
 */
- (BOOL)canHandleURL:(NSURL *)url;

/*!
 *  是否开启 可视化全埋点 分析，默认开启
 *
 *  @return YES/NO
 */
- (BOOL)isVisualizedAutoTrackEnabled;

/*!
 *  指定哪些页面开启 可视化全埋点 分析
 *  如果指定了页面，只有这些页面的 AppClick 事件会采集控件的 viwPath。
 *
 *  @param controllers 指定的页面的类名数组
 */
- (void)addVisualizedAutoTrackViewControllers:(NSArray<NSString *> *)controllers;

/*!
 *  当前页面是否开启 可视化全埋点 分析。
 *
 *  @param viewController 当前页面 viewController
 *
 *  @return YES/NO
 */
- (BOOL)isVisualizedAutoTrackViewController:(UIViewController *)viewController;


@end
NS_ASSUME_NONNULL_END
