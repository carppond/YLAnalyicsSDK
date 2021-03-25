//
//  YLSensorsAnalyicsSDK.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/16.
//

#import "YLSensorsAnalyicsSDK.h"
#import "UIView+Analyics.h"
#import "YLSensorsAnalyticsKeychainTool.h"
#import "YLSensorsAnalyticsNetwork.h"
#import "YLSystemParam.h"
#import "YLAnalyicsLog.h"
#import "YLSensorsAnalyicsTool.h"
#import "YLLogger.h"

#ifndef SENSORS_ANALYTICS_UIWEBVIEW
#import <WebKit/WebKit.h>
#endif

static NSString * const YLSensorsAnalyticsAnonymousId = @"cn.analyics.anonymous_id";
static NSString * const YLSensorsAnalyticsKeychainService = @"cn.sensorsdata.SensorsAnalytics.id";
static NSString * const YLSensorsAnalyticsLoginId = @"cn.sensorsdata.login_id";
static NSString * const YLSensorsAnalyticsEventBeginKey = @"event_begin";
static NSString * const YLSensorsAnalyticsEventDurationKey = @"event_duration";
static NSString * const YLSensorsAnalyticsEventIsPauseKey = @"is_pause";
static NSUInteger const YLSensorsAnalyticsDefalutFlushEventCount = 50;
static NSString * const YLSensorsAnalyticsJavaScriptTrackEventScheme = @"sensorsanalytics:// trackEvent";


@interface YLSensorsAnalyicsSDK ()
/// 预制属性，用户的基本信息
@property (nonatomic, strong) NSDictionary<NSString *, id> *autoMaticPoperties;
/// 标记应用程序是否收到 UIApplicationWillResignActiveNotification 本地通知 */
@property (nonatomic, assign) BOOL applicationWillResignActive;
/// 是否为被动启动
@property (nonatomic, assign, getter=isLaunchedPassively) BOOL launchedPassively;
/// 用户信息
@property (nonatomic, strong) NSMutableDictionary *userInfo;
/// 登录ID
@property (nonatomic, copy) NSDictionary *loginInfo;
/// 事件开始发生的时间戳
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *trackTimer;
/// 保存进入后台时未暂停的事件名称
@property (nonatomic, strong) NSMutableArray<NSString *> *enterBackgroundTrackTimerEvents;
/// 发送网络请求的对象
@property (nonatomic, strong) YLSensorsAnalyticsNetwork *network;

@property (nonatomic, strong) dispatch_queue_t serialQueue;
/// 定时上传事件的计时器
@property (nonatomic, strong) NSTimer *flushTimer;
/// 数据同步策略
@property (nonatomic, assign) YLSensorsAnalyicsTacticsType tacticsType;

#ifndef SENSORS_ANALYTICS_UIWEBVIEW
/// 由于WKWebView获取UserAgent是异步过程，为了在获取过程中创建的WKWebView对象不被销毁，
/// 需要保存创建的临时对象
@property (nonatomic, strong) WKWebView *webView;
/// 可视化全埋点
@property (nonatomic, strong) NSMutableSet<NSString *> *visualizedAutoTrackViewControllers;
#endif

@end
@implementation YLSensorsAnalyicsSDK {
    NSString *_anonymousId;
}
#pragma mark - Cycle life

static YLSensorsAnalyicsSDK *_sharedInstance = nil;
+ (void)startWithServerURL:(NSString *)urlString
          withFlushTactics:(YLSensorsAnalyicsTacticsType)type {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[YLSensorsAnalyicsSDK alloc] initWithServerURL:urlString withFlushTactics:type];
    });
}


+ (instancetype)sharedInstance {
    return _sharedInstance;
}

- (instancetype)initWithServerURL:(NSString *)urlString
                 withFlushTactics:(YLSensorsAnalyicsTacticsType)type {
    self = [super init];
    if (self) {
        self.autoMaticPoperties = [YLSystemParam getCollectAutomaticProperties];
        /// 设置是否为被动启动
        self.launchedPassively = [UIApplication sharedApplication].backgroundTimeRemaining != UIApplicationBackgroundFetchIntervalNever;
        self.trackTimer = [NSMutableDictionary dictionary];
        self.enterBackgroundTrackTimerEvents = [NSMutableArray array];
        self.loginInfo = [[NSUserDefaults standardUserDefaults] objectForKey:YLSensorsAnalyticsLoginId];
        // TODO: 缺少一个URL
        self.network = [[YLSensorsAnalyticsNetwork alloc] initWithServerURL:[NSURL URLWithString:urlString]];
        NSString *queueLabel = [NSString stringWithFormat:@"cn.sensorsdata.%@.%p", self.class, self];
        self.serialQueue = dispatch_queue_create([queueLabel UTF8String], DISPATCH_QUEUE_SERIAL);
        self.tacticsType = type;
        if (type == YLSensorsAnalyicsTacticsType_BuildSize) {
            self.flushBulkSize = 100000;
        } else if (type == YLSensorsAnalyicsTacticsType_TimeInterval) {
            self.flushInterval = 15;
        } else {
            [self startFlushTimer];
        }
        // 调用异常处理单例对象，进行初始化
//        [YLSensorsAnalyticsExceptionHandler sharedInstance];
        self.enableVisualizedAutoTrack = YES;
        self.visualizedAutoTrackViewControllers = [[NSMutableSet alloc] init];
        // 添加应用程序状态监听
        [self setupListeners];
        
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupListeners {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    // 注册监听UIApplicationDidEnterBackgroundNotification本地通知
    // 即当应用程序进入后台后，调用通知方法”
    [center addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    // 注册监听UIApplicationDidBecomeActiveNotification本地通知
    // 即当应用程序进入前台并处于活动状态之后，调用通知方法
    [center addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    // 注册监听UIApplicationWillResignActiveNotification本地通知
    [center addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    
    // 注册监听UIApplicationDidFinishLaunchingNotification本地通知
    [center addObserver:self selector:@selector(applicationDidFinishLaunching:) name:UIApplicationDidFinishLaunchingNotification object:nil];
}

#pragma mark - Notication

/*! 程序进入后台 */
- (void)applicationDidEnterBackground:(NSNotification *)notification {
    // 还原标记位
    self.applicationWillResignActive = NO;
    
    // 触发 AppEnd 事件
    //    [self track:@"AppEnd" properties:nil];
    [self trackTimerEnd:@"AppEnd" properties:nil];
    
    // 暂停所有事件时长统计
    [self.trackTimer enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSDictionary * _Nonnull obj, BOOL * _Nonnull stop) {
        if (![obj[YLSensorsAnalyticsEventIsPauseKey] boolValue]) {
            [self.enterBackgroundTrackTimerEvents addObject:key];
            [self trackTimerPause:key];
        }
    }];
    // 进入后台策略
    if (self.tacticsType == YLSensorsAnalyicsTacticsType_EnterBackground) {
        UIApplication *application = [UIApplication sharedApplication];
        // 初始化标识符
        __block UIBackgroundTaskIdentifier backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        // 结束后台任务
        void (^endBackgroundTask)(void) = ^() {
            [application endBackgroundTask:backgroundTaskIdentifier];
            backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        };
        // 标记长时间运行的后台任务
        backgroundTaskIdentifier = [application beginBackgroundTaskWithExpirationHandler:^{
            endBackgroundTask();
        }];
        
        dispatch_async(self.serialQueue, ^{
            // 发送数据
            [self flushByEventCount:YLSensorsAnalyticsDefalutFlushEventCount background:YES];
            // 结束后台任务
            endBackgroundTask();
        });
    }
    if (self.tacticsType == YLSensorsAnalyicsTacticsType_TimeInterval) {
        // 停止计时器
        [self stopFlushTimer];
    }
}

static BOOL appFirstStartupStatus = YES;

/*! 程序处于活跃状态 */
- (void)applicationDidBecomeActive:(NSNotification *)notification {
    // 还原标记
    if (self.applicationWillResignActive) {
        self.applicationWillResignActive = NO;
        return;
    }
    if (appFirstStartupStatus) {
        [self track:@"AppStartUp" properties:nil];
        appFirstStartupStatus = NO;
    }
    // 将被动启动标记设为 NO，正常记录事件
    self.launchedPassively = NO;
    
    // 触发 AppStart 事件
    [self track:@"AppStart" properties:nil];
    
    // 恢复所有事件时长统计
    for (NSString *event in self.enterBackgroundTrackTimerEvents) {
        [self trackTimerResume:event];
    }
    [self.enterBackgroundTrackTimerEvents removeAllObjects];
    
    // 开始 AppEnd 事件计时
    [self trackTimerStart:@"AppEnd"];
    /// 时间间隔策略
    if (self.tacticsType == YLSensorsAnalyicsTacticsType_TimeInterval) {
        // 开启计时器
        [self startFlushTimer];
    }
}

- (void)applicationWillResignActive:(NSNotification *)notification {
    // 标记已接收到UIApplicationWillResignActiveNotification本地通知
    self.applicationWillResignActive = YES;
}

/*! 被动启动 */
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    KeHouDebug(@"Application did finish launching.");
    
    // 当程序在后台运行时，触发被动启动时间
    if (self.isLaunchedPassively) {
        // 触发被动启动事件
        [self track:@"AppStartPassively" properties:nil];
    }
}

#pragma mark - Login

- (void)login:(NSDictionary<NSString *,id> *)loginInfo {
    self.loginInfo = loginInfo;
    // 在本地保存登录ID
    [[NSUserDefaults standardUserDefaults] setObject:loginInfo forKey:YLSensorsAnalyticsLoginId];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Properties

+ (double)currentTime {
    return [[NSDate date] timeIntervalSince1970] * 1000;
}

+ (double)systemUpTime {
    return NSProcessInfo.processInfo.systemUptime * 1000;
}

- (void)collectUserInfo {
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    NSString *uuid = [[NSUUID UUID] UUIDString];
    [properties setObject:uuid forKey:@"UUID"];
}

- (void)setAnonymousId:(NSString *)anonymousId {
    _anonymousId = anonymousId;
    [self saveAnonymousId:anonymousId];
}

- (void)saveAnonymousId:(NSString *)anonymousId {
    // 保存设备ID
    [[NSUserDefaults standardUserDefaults] setObject:anonymousId forKey:YLSensorsAnalyticsAnonymousId];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    YLSensorsAnalyticsKeychainTool *item = [[YLSensorsAnalyticsKeychainTool alloc] initWithService:YLSensorsAnalyticsKeychainService key:YLSensorsAnalyticsAnonymousId];
    if (anonymousId) {
        [item update:anonymousId];
    } else {
        [item remove];
    }
}

- (NSString *)anonymousId {
    if (_anonymousId) {
        return _anonymousId;
    }
    YLSensorsAnalyticsKeychainTool *item = [[YLSensorsAnalyticsKeychainTool alloc] initWithService:YLSensorsAnalyticsKeychainService key:YLSensorsAnalyticsAnonymousId];
    _anonymousId = [item value];
    if (_anonymousId) {
        // 保存设备ID
        [[NSUserDefaults standardUserDefaults] setObject:_anonymousId forKey:YLSensorsAnalyticsAnonymousId];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return _anonymousId;
    }
    // 从NSUserDefaults中读取设备ID
    _anonymousId = [[NSUserDefaults standardUserDefaults] objectForKey:YLSensorsAnalyticsAnonymousId];
    if (_anonymousId) {
        return _anonymousId;
    }
    
    // 获取IDFA
    Class cls = NSClassFromString(@"ASIdentifierManager");
    if (cls) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        // 获取ASIdentifierManager的单利对象
        id manager = [cls performSelector:@selector(sharedManager)];
        SEL selector = NSSelectorFromString(@"isAdvertisingTrackingEnabled");
        BOOL (*isAdvertisingTrackingEnabled)(id, SEL) = (BOOL (*)(id, SEL))[manager methodForSelector:selector];
        if (isAdvertisingTrackingEnabled(manager, selector)) {
            // 使用IDFA作为设备ID
            _anonymousId = [(NSUUID *)[manager performSelector:@selector(advertisingIdentifier)] UUIDString];
        }
#pragma clang diagnostic pop
    }
    if (!_anonymousId) {
        // 使用IDFV作为设备ID
        _anonymousId = UIDevice.currentDevice.identifierForVendor.UUIDString;
    }
    if (!_anonymousId) {
        // 使用UUID作为设备ID
        _anonymousId = NSUUID.UUID.UUIDString;
    }
    
    // 保存设备ID（匿名ID）
    [self saveAnonymousId:_anonymousId];
    
    return _anonymousId;
}


- (void)printEvent:(NSDictionary *)event {
#if DEBUG
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:event options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        return KeHouDebug(@"JSON Serialized Error: %@",error);
    }
    NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    KeHouDebug(@"[Event]: %@", jsonString);
#endif
}

#pragma mark - 同步数据

- (void)flush {
    dispatch_async(self.serialQueue, ^{
        // 默认一次向服务端发送50条数据
        [self flushByEventCount:YLSensorsAnalyticsDefalutFlushEventCount background:NO];
    });
}

// TODO: 修改
- (void)flushByEventCount:(NSUInteger)count {
    // 获取本地数据
    NSArray<NSString *> *events = [self getLocalLoggers];
    // 当本地存储的数据为0或者上传失败时，直接返回，退出递归调用
    if (events.count == 0 || ![self.network flushEvents:events]) {
        return;
    }
    // 当删除数据失败时，直接返回，退出递归调用，防止死循环
    if (![[YLLoggerServer sharedServer] deleteCrashLoggerForCount:count] &&
        ![[YLLoggerServer sharedServer] deleteAnalyicsLoggerForCount:count]) {
        return;
    }
    // 继续上传本地的其他数据
    [self flushByEventCount:count];
}

- (void)flushByEventCount:(NSUInteger)count background:(BOOL)background {
    if (background) {
        __block BOOL isContinue = YES;
        dispatch_sync(dispatch_get_main_queue(), ^{
            // 当运行时间大于请求超时时间时，为保证数据库删除时应用不被强杀，不再继续上传
            isContinue = UIApplication.sharedApplication.backgroundTimeRemaining >= 30;
        });
        if (!isContinue) {
            return;
        }
    }
    //
    // 获取本地数据
    NSArray<NSString *> *events = [self getLocalLoggers];
    // 当本地存储的数据为0或者上传失败时，直接返回，退出递归调用
    if (events.count == 0 || ![self.network flushEvents:events]) {
        return;
    }
    // 当删除数据失败时，直接返回，退出递归调用，防止死循环
    if (![[YLLoggerServer sharedServer] deleteCrashLoggerForCount:count] &&
        ![[YLLoggerServer sharedServer] deleteAnalyicsLoggerForCount:count]) {
        return;
    }
    // 继续上传本地的其他数据
    [self flushByEventCount:count background:background];
}

- (NSArray<NSString *> *)getLocalLoggers {
    
    NSMutableArray *arrM = [NSMutableArray array];
    
    dispatch_semaphore_t flushSemaphore = dispatch_semaphore_create(0);
    [[YLLoggerServer sharedServer] fetchCrashLoggers:^(NSArray<YLCrashLogger *> *loggers) {
        for (YLCrashLogger *logger in loggers) {
            [arrM addObject:logger.loggerDescription];
        }
        dispatch_semaphore_signal(flushSemaphore);
    }];
    dispatch_semaphore_wait(flushSemaphore, dispatch_time(DISPATCH_TIME_NOW, DISPATCH_TIME_FOREVER));
    [[YLLoggerServer sharedServer] fetchAnalyicsLoggers:^(NSArray<YLAnalyicsLogger *> *loggers) {
        for (YLAnalyicsLogger *logger in loggers) {
            [arrM addObject:logger.loggerDescription];
        }
        dispatch_semaphore_signal(flushSemaphore);
    }];
    dispatch_semaphore_wait(flushSemaphore, dispatch_time(DISPATCH_TIME_NOW, DISPATCH_TIME_FOREVER));
    return arrM.copy;
}

#pragma mark - FlushTimer
/// 开启上传数据的计时器
- (void)startFlushTimer {
    if (self.flushTimer) {
        return;
    }
    NSTimeInterval interval = self.flushInterval < 5 ? 5 : self.flushInterval;
    self.flushTimer = [NSTimer timerWithTimeInterval:interval target:self selector:@selector(flush) userInfo:nil repeats:YES];
    [NSRunLoop.currentRunLoop addTimer:self.flushTimer forMode:NSRunLoopCommonModes];
}

// 停止上传数据的计时器
- (void)stopFlushTimer {
    [self.flushTimer invalidate];
    self.flushTimer = nil;
}

- (void)setFlushInterval:(NSUInteger)flushInterval {
    if (_flushInterval != flushInterval) {
        _flushInterval = flushInterval;
        // 上传本地缓存的所有事件数据
        [self flush];
        [self stopFlushTimer];
        [self startFlushTimer];
    }
}
@end


#pragma mark - Track 跟踪事件

@implementation YLSensorsAnalyicsSDK (Track)

- (void)track:(NSString *)eventName properties:(NSDictionary<NSString *,id> *)properties {
    NSMutableDictionary *eventDict = [NSMutableDictionary dictionary];
    // 设置事件的 distinct_id 字段用于唯一标识符
    [eventDict setObject:self.loginInfo ?: @{@"distinct_id":self.anonymousId} forKey:@"user_info"];
    // 事件名称
    [eventDict setObject:eventName forKey:@"event"];
    // 设置事件发生的时间间隔，单位毫秒
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [eventDict setObject:[formatter stringFromDate:[NSDate date]] forKey:@"time"];
    NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
    // 添加用户信息]
    if (self.userInfo) {
        [eventDict setObject:self.userInfo forKey:@"user"];
    }
    // 添加自定义属性
    [eventProperties addEntriesFromDictionary:properties];
    /// 闪退、崩溃、第一次启动，添加上上设备信息
    if ([eventName containsString:@"AppCrashed"] ||
        [eventName containsString:@"AppStartUp"]) {
        [eventDict setObject:self.autoMaticPoperties forKey:@"device_info"];
    }
    // 判断是否为被动弄启动状态
    if (self.isLaunchedPassively) {
        // 添加应用程序状态属性
        [eventProperties setObject:@"app_State" forKey:@"background"];
    }
    
    // 设置事件属性
    [eventDict setObject:eventProperties forKey:@"properties"];
    
    YLAnalyicsLogger *logger = [YLAnalyicsLogger analyicsLoggerWithName:eventName eventTime:[NSDate date] hasCrash:NO eventProperties:eventProperties];
    
    dispatch_async(self.serialQueue, ^{
        [self printEvent:eventDict];
        [[YLLoggerServer sharedServer] insertAnalyicsLogger:logger];
    });
    if (self.tacticsType != YLSensorsAnalyicsTacticsType_BuildSize) {
        return;
    }
    if ([YLLoggerServer sharedServer].eventCount >= self.flushBulkSize) {
        [self flush];
    }
}

- (void)trackAppClickWithView:(UIView *)view properties:(nullable NSDictionary <NSString *, id> *)properties {
    NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
    // 获取控件类型
    eventProperties[@"element_type"] = view.analyicsElementType;
    // 获取控件显示文本
    eventProperties[@"element_content"] = view.analyicsElementContent;
    // 获取控件所在的UIViewController
    UIViewController *vc = view.analyicsViewController;
    // 设置页面相关属性
    eventProperties[@"screen_name"] = NSStringFromClass(vc.class);
    
    [eventProperties setObject:[UIView viewPath:view] forKey:@"viewPath"];
    
    // 添加自定义属性
    [eventProperties addEntriesFromDictionary:properties];
    // 触发AppClick事件
    [[YLSensorsAnalyicsSDK sharedInstance] track:@"AppClick" properties: eventProperties];
}

- (void)trackAppWKLoadWithView:(UIView *)view properties:(nullable NSDictionary <NSString *, id> *)properties {
    NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
    // 获取控件类型
    eventProperties[@"element_type"] = view.analyicsElementType;
    // 获取控件显示文本
    eventProperties[@"element_content"] = view.analyicsElementContent;
    // 获取控件所在的UIViewController
    UIViewController *vc = view.analyicsViewController;
    // 设置页面相关属性
    eventProperties[@"screen_name"] = NSStringFromClass(vc.class);
    
    [eventProperties setObject:[UIView viewPath:view] forKey:@"viewPath"];
    
    // 添加自定义属性
    [eventProperties addEntriesFromDictionary:properties];
    // 触发AppClick事件
    [[YLSensorsAnalyicsSDK sharedInstance] track:@"AppWKLoad" properties: eventProperties];
}


- (void)trackAppClickWithTableView:(UITableView *)tableView
           didSelectRowAtIndexPath:(NSIndexPath *)indexPath
                        properties:(nullable NSDictionary<NSString *, id> *)properties {
    NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
    
    // 获取用户点击的UITableViewCell控件对象
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    [eventProperties setObject:NSStringFromClass(cell.class) forKey:@"element_name"];
    [eventProperties setObject:cell.analyicsElementContent forKey:@"element_content"];
    [eventProperties setObject:[NSString stringWithFormat: @"%ld:%ld", (long)indexPath.section, (long)indexPath.row] forKey:@"element_position"];
    [eventProperties setObject:[UIView viewPath:cell] forKey:@"viewPath"];
    // 添加自定义属性
    [eventProperties addEntriesFromDictionary:properties];
    // 触发 AppClick 事件sharedServer
    [[YLSensorsAnalyicsSDK sharedInstance] trackAppClickWithView:tableView properties:eventProperties];
}

- (void)trackAppClickWithCollectionView:(UICollectionView *)collectionView
               didSelectItemAtIndexPath:(NSIndexPath *)indexPath
                             properties:(nullable NSDictionary<NSString *, id> *)properties {
    NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
    
    // 获取用户点击的UICollectionViewCell控件对象
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    [eventProperties setObject:NSStringFromClass(cell.class) forKey:@"element_name"];
    [eventProperties setObject:cell.analyicsElementContent forKey:@"element_content"];
    [eventProperties setObject:[NSString stringWithFormat: @"%ld:%ld", (long)indexPath.section, (long)indexPath.row] forKey:@"element_position"];
    [eventProperties setObject:[UIView viewPath:cell] forKey:@"viewPath"];
    
    // 添加自定义属性
    [eventProperties addEntriesFromDictionary:properties];
    // 触发 AppClick 事件
    [[YLSensorsAnalyicsSDK sharedInstance] trackAppClickWithView:collectionView properties:eventProperties];
}

- (void)trackAppWithWKWebView:(WKWebView *)webView
                  loadingTime:(NSString *)loadingTime
                   properties:(nullable NSDictionary<NSString *, id> *)properties {
    NSMutableDictionary *eventProperties = [NSMutableDictionary dictionary];
   
    [eventProperties setObject:isNil(webView.URL.absoluteString) forKey:@"web_url"];
    [eventProperties setObject:isNil(webView.title) forKey:@"web_title"];
    [eventProperties setObject:isNil(loadingTime) forKey:@"web_loading_time"];
    // 添加自定义属性
    [eventProperties addEntriesFromDictionary:properties];
    // 触发 AppClick 事件
    [[YLSensorsAnalyicsSDK sharedInstance] trackAppWKLoadWithView:webView properties:eventProperties];
}


@end


#pragma mark - Timer

@implementation YLSensorsAnalyicsSDK (Timer)

- (void)trackTimerStart:(NSString *)event {
    // 记录事件开始时间
    self.trackTimer[event] = @{YLSensorsAnalyticsEventBeginKey: @([YLSensorsAnalyicsSDK systemUpTime])};
}

- (void)trackTimerEnd:(NSString *)event properties:(NSDictionary *)properties {
    
    NSDictionary *eventTimer = self.trackTimer[event];
    if (!eventTimer) {
        return [self track:event properties:properties];
    }
    
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithDictionary:properties];
    [self.trackTimer removeObjectForKey:event];
    if ([eventTimer[YLSensorsAnalyticsEventIsPauseKey] boolValue]) {
        // 获取事件时长
        double eventDuration = [eventTimer[YLSensorsAnalyticsEventDurationKey] doubleValue] / 100;
        p[@"event_duration"] = [NSString stringWithFormat:@"%.3f", eventDuration];
    } else {
        double beginTime = [(NSNumber *)eventTimer[YLSensorsAnalyticsEventBeginKey] doubleValue];
        double currentTime = [YLSensorsAnalyicsSDK systemUpTime];
        // 计算事件市场
        double eventDuration = currentTime - beginTime + [eventTimer[YLSensorsAnalyticsEventDurationKey] doubleValue];
        p[@"event_duration"] = [NSString stringWithFormat:@"%.3f", eventDuration / 1000];
    }
    // 触发事件
    [self track:event properties:p];
}

- (void)trackTimerPause:(NSString *)event {
    NSMutableDictionary *eventTimer = [self.trackTimer[event] mutableCopy];
    // 如果没有开始，直接返回
    if (!eventTimer) {
        return;
    }
    // 如果该事件时长统计已经暂停，直接返回，不做任何处理
    if ([eventTimer[YLSensorsAnalyticsEventIsPauseKey] boolValue]) {
        return;
    }
    // 获取当前系统启动时间
    double systemUpTime = [YLSensorsAnalyicsSDK systemUpTime];
    // 获取开始时间
    double beginTime = [eventTimer[YLSensorsAnalyticsEventBeginKey] doubleValue];
    // 计算暂停前统计的时长
    double duration = [eventTimer[YLSensorsAnalyticsEventDurationKey] doubleValue] + systemUpTime - beginTime;
    eventTimer[YLSensorsAnalyticsEventDurationKey] = @(duration);
    // 事件处于暂停状态
    eventTimer[YLSensorsAnalyticsEventIsPauseKey] = @(YES);
    self.trackTimer[event] = eventTimer;
}

- (void)trackTimerResume:(NSString *)event {
    NSMutableDictionary *eventTimer = [self.trackTimer[event] mutableCopy];
    // 如果没有开始，直接返回
    if (!eventTimer) {
        return;
    }
    // 如果该事件时长统计没有暂停，直接返回，不做任何处理
    if (![eventTimer[YLSensorsAnalyticsEventIsPauseKey] boolValue]) {
        return;
    }
    // 获取当前系统启动时间
    double systemUpTime = [YLSensorsAnalyicsSDK systemUpTime];
    // 重置事件开始时间
    eventTimer[YLSensorsAnalyticsEventBeginKey] = @(systemUpTime);
    // 将事件暂停标记设置为NO
    eventTimer[YLSensorsAnalyticsEventIsPauseKey] = @(NO);
    self.trackTimer[event] = eventTimer;
}

@end


#pragma mark - WebView

@implementation YLSensorsAnalyicsSDK (WebView)

- (void)loadUserAgent:(void(^)(NSString *))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
#ifdef SENSORS_ANALYTICS_UIWEBVIEW
        UIWebView *webView = [[UIWebView alloc] initWithFrame:CGRectZero];
        // 取出UIWebView的UserAgent
        NSString *userAgent = [webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
        completion(userAgent);
#else
        // 创建一个空的WKWebView，由于WKWebView执行JavaScript代码是异步过程，
        // 所以需要强引用WKWebView对象
        self.webView = [[WKWebView alloc] initWithFrame:CGRectZero];
        
        __weak typeof(self) weakSelf = self;
        // 执行JavaScript代码，获取WKWebView中的UserAgent
        [self.webView evaluateJavaScript:@"navigator.userAgent" completionHandler:^ (id result, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            // 调用回调，返回获取到的UserAgent
            completion(result);
            strongSelf.webView = nil;
        }];
#endif
    });
}

- (void)addWebViewUserAgent:(nullable NSString *)userAgent {
    [self loadUserAgent:^(NSString *oldUserAgent) {
        // 给UserAgent添加自己需要的内容
        NSString *newUserAgent = [oldUserAgent stringByAppendingString:userAgent ?: @" /analyics-sdk-ios"];
        // 将UserAgent字典内容注册到NSUserDefaults中
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"UserAgent": newUserAgent}];
    }];
}

// TODO: 完善
- (BOOL)shouldTrackWithWebView:(id)webView request:(NSURLRequest *)request {
    // 获取请求的完整路径
    NSString *urlString = request.URL.absoluteString;
    // 查找在完整路径中是否包含sensorsanalytics://trackEvent，
    // 如果不包含，则是普通请求，不做处理，返回NO
    if ([urlString rangeOfString:YLSensorsAnalyticsJavaScriptTrackEventScheme].location == NSNotFound) {
        return NO;
    }

    NSMutableDictionary *queryItems = [NSMutableDictionary dictionary];
    // 请求中的所有Query，并解析获取数据
    NSArray<NSString *> *allQuery = [request.URL.query componentsSeparatedByString: @"&"];
    for (NSString *query in allQuery) {
        NSArray<NSString *> *items = [query componentsSeparatedByString:@"="];
        if (items.count >= 2) {
            queryItems[items.firstObject] = [items.lastObject stringByRemovingPercentEncoding];
        }
    }

    // TODO: 采集请求中的数据
    [self trackFromH5WithEvent:queryItems[@"event"]];

    return YES;
}

- (void)trackFromH5WithEvent:(NSString *)jsonString {
    NSError *error = nil;
    // 将JSON字符串转换成NSData类型
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    // 解析JSON
    NSMutableDictionary *event = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
    if (error || !event) {
        return;
    }

    NSMutableDictionary *properties = [event[@"properties"] mutableCopy];
    // 预置属性以SDK中采集的属性为主
    [properties addEntriesFromDictionary:self.autoMaticPoperties];
    event[@"properties"] = properties;
    // 用于区分事件来源字段，表示是H5采集到的数据
    event[@"_hybrid_h5"] = @(YES);
    // 设置事件的distinct_id，用于唯一标识一个用户
    event[@"distinct_id"] = self.loginInfo ?: self.anonymousId;
    // 打印最终的入库事件数据
    [self printEvent:event];
    // 本地保存事件数据
    YLAnalyicsLogger *logger = [YLAnalyicsLogger analyicsLoggerWithName:@"H5" eventTime:[NSDate date] hasCrash:NO eventProperties:event];
    [[YLLoggerServer sharedServer] insertAnalyicsLogger:logger];
    
    // 在本地事件数据总量大于最大缓存数时，发送数据
    if ([YLLoggerServer sharedServer].eventCount >= self.flushBulkSize) {
        [self flush];
    }
}


@end


#pragma mark - VisualizedAutoTrack

@implementation YLSensorsAnalyicsSDK (VisualizedAutoTrack)

/// 判断是否为符合要求的 openURL
- (BOOL)canHandleURL:(NSURL *)url {
    
    return YES;
}

/// 是否开启 可视化全埋点 分析，默认开启
- (BOOL)isVisualizedAutoTrackEnabled {
    return self.enableVisualizedAutoTrack;
}

/// 指定哪些页面开启 可视化全埋点 分析,如果指定了页面，只有这些页面的  AppClick 事件会采集控件的 viwPath。
- (void)addVisualizedAutoTrackViewControllers:(NSArray<NSString *> *)controllers {
    if (![controllers isKindOfClass:[NSArray class]] || controllers.count == 0) {
        return;
    }
    [self.visualizedAutoTrackViewControllers addObjectsFromArray:controllers];
}

/// 当前页面是否开启 可视化全埋点 分析。
- (BOOL)isVisualizedAutoTrackViewController:(UIViewController *)viewController {
    if (!viewController) {
        return NO;
    }

    if (self.visualizedAutoTrackViewControllers.count == 0 && self.enableVisualizedAutoTrack) {
        return YES;
    }

    NSString *screenName = NSStringFromClass([viewController class]);
    return [self.visualizedAutoTrackViewControllers containsObject:screenName];
}


@end
