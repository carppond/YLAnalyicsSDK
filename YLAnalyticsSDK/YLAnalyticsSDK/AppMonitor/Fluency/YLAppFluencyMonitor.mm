//
//  YLAppFluencyMonitor.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/11/6.
//

#import "YLAppFluencyMonitor.h"
#import "YLBacktraceLogger.h"
#import "YLLogger.h"
#import "YLSystemParam.h"
#import "YLJsonConverTool.h"
#import "UIApplication+YLTool.h"
#include <mach/mach.h>
#import <sys/time.h>
//#import <vector>
#include <pthread.h>
#import "YLAnalyicsTyeDefine.h"


#define __timercmp(tvp, uvp, cmp) \
    (((tvp)->tv_sec == (uvp)->tv_sec) ? ((tvp)->tv_usec cmp(uvp)->tv_usec) : ((tvp)->tv_sec cmp(uvp)->tv_sec))

#define BM_MicroFormat_MillSecond 1000
#define BM_MicroFormat_Second 1000000
#define BM_MicroFormat_FrameMillSecond 16000
#define APP_SHOULD_SUSPEND 180 * BM_MicroFormat_Second
#define STACK_PER_MAX_COUNT 100 // the max address count of one stack


mach_port_t g_matrix_block_monitor_dumping_thread_id = 0;

const static useconds_t g_defaultRunLoopTimeOut = 2 * BM_MicroFormat_Second;
const static useconds_t g_defaultCheckPeriodTime = 1 * BM_MicroFormat_Second;
//const static useconds_t g_defaultPerStackInterval = 50 * BM_MicroFormat_MillSecond;

//static useconds_t g_PerStackInterval = g_defaultPerStackInterval;

static useconds_t g_RunLoopTimeOut = g_defaultRunLoopTimeOut;
static useconds_t g_CheckPeriodTime = g_defaultCheckPeriodTime;

static BOOL g_MainThreadHandle = NO;

static size_t g_StackMaxCount = 100;
//static NSUInteger g_CurrentThreadCount = 0;

static struct timeval g_tvRun;
/// 当前 run 是否发生卡顿的标记
static BOOL g_bRun;
static struct timeval g_enterBackground;
static struct timeval g_tvSuspend;
static CFRunLoopActivity g_runLoopActivity;
static BOOL g_bLaunchOver = NO;

static BOOL g_bBackgroundLaunch = NO;
static BOOL g_bMonitor = NO;


typedef enum : NSUInteger {
    ylRunloopInitMode,
    ylRunloopDefaultMode,
} YLRunloopMode;

static YLRunloopMode g_runLoopMode;

@interface YLAppFluencyMonitor () {
    
    NSThread *m_monitorThread;
    BOOL m_bStop;
    
    UIApplicationState m_currentState;
    NSUInteger m_nIntervalTime;
    
//    std::vector<NSUInteger> m_vecLastMainThreadCallStack;
    
    uint64_t m_blockDiffTime;
    uint32_t m_firstSleepTime;
    
    BOOL m_bInSuspend;
    
    CFRunLoopObserverRef m_runLoopBeginObserver;
    CFRunLoopObserverRef m_runLoopEndObserver;
    CFRunLoopObserverRef m_initializationBeginRunloopObserver;
    CFRunLoopObserverRef m_initializationEndRunloopObserver;
    
    int timeoutCount;
    @public
    dispatch_semaphore_t dispatchSemaphore;
    CFRunLoopActivity runLoopActivity;
}

@property (nonatomic, strong) NSTimer *cpuMonitorTimer;

@end

@implementation YLAppFluencyMonitor

+ (instancetype)shareInstance {
    static YLAppFluencyMonitor *instance = nil;
    static dispatch_once_t dispatchOnce;
    dispatch_once(&dispatchOnce, ^{
        instance = [[YLAppFluencyMonitor alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        m_bStop = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willTerminate) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBackgroundLaunch) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleSuspend) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (void)start {
    
    if (!m_bStop) {
        return;
    }
    
    m_firstSleepTime = 5;
    m_nIntervalTime = 1;
    g_MainThreadHandle = YES;
    
    m_bInSuspend = YES;
    [self setRunloopTimeOut:g_defaultRunLoopTimeOut
         andCheckPeriodTime:g_defaultCheckPeriodTime];
    g_StackMaxCount = STACK_PER_MAX_COUNT;
    
    [self addRunLoopObserver];
    [self addMonitorThread];
    [self addCPUMonitorThread];
}

- (void)stop {
    
    if (m_bStop) {
        return;
    }
    m_bStop = YES;

    [self.cpuMonitorTimer invalidate];
    
    [self removeRunLoopObserver];
    
    while ([m_monitorThread isExecuting]) {
        usleep(100 * BM_MicroFormat_MillSecond);
    }
}


#pragma mark - Application State (Notification Observer)

- (void)willTerminate {
    
    [self stop];
}

- (void)didBecomeActive {
    
    NSLog(@"did become active");
    
    g_enterBackground = {0, 0};

    m_bInSuspend = NO;
    m_currentState = [UIApplication sharedApplication].applicationState;

    g_bMonitor = YES;
    g_bLaunchOver = YES;
    
    if (g_bBackgroundLaunch) {
//        [self clearDumpInBackgroundLaunch];
        g_bBackgroundLaunch = NO;
    }
    
//    [self clearLaunchLagRecord];
}

- (void)didEnterBackground {
    
    NSLog(@"did enter background");
    gettimeofday(&g_enterBackground, NULL);
    m_currentState = [UIApplication sharedApplication].applicationState;
}

- (void)willResignActive {
    
    NSLog(@"will resign active");
    m_currentState = [UIApplication sharedApplication].applicationState;
    g_bLaunchOver = YES;
}
    

- (void)handleBackgroundLaunch {
    
    if (m_bInSuspend) {
        g_bMonitor = NO;
        g_bBackgroundLaunch = YES;
    }
}

- (void)handleSuspend {
    
    g_bMonitor = NO;
    gettimeofday(&g_tvSuspend, NULL);
    m_bInSuspend = YES;
}

#pragma mark - Config

- (void)setRunloopTimeOut:(useconds_t)runloopTimeOut andCheckPeriodTime:(useconds_t)checkPeriodTime {
    
    if (runloopTimeOut < checkPeriodTime || checkPeriodTime < BM_MicroFormat_FrameMillSecond || runloopTimeOut < BM_MicroFormat_FrameMillSecond) {
        NSLog(@"runloopTimeOut[%u] < checkPeriodTime[%u]", runloopTimeOut, checkPeriodTime);
        return;
    }
    useconds_t tmpTimeOut = g_RunLoopTimeOut;
    useconds_t tmpPeriodTime = g_CheckPeriodTime;
    g_RunLoopTimeOut = runloopTimeOut;
    g_CheckPeriodTime = checkPeriodTime;
    NSLog(@"set timeout: before[%u] after[%u], period: before[%u] after[%u]", tmpTimeOut, g_RunLoopTimeOut, tmpPeriodTime, g_CheckPeriodTime);
}

#pragma mark - Monitor Thread

- (void)addMonitorThread {
    
    m_bStop = NO;
    m_monitorThread = [[NSThread alloc] initWithTarget:self selector:@selector(threadProc) object:nil];
    [m_monitorThread start];
}

- (void)threadProc {
    g_matrix_block_monitor_dumping_thread_id = pthread_mach_thread_np(pthread_self());
    
    if (m_firstSleepTime) {
        sleep(m_firstSleepTime);
        m_firstSleepTime = 0;
    }
    dispatchSemaphore = dispatch_semaphore_create(0);
    
    //创建子线程监控
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        //子线程开启一个持续的loop用来进行监控
        while (YES) {
            long semaphoreWait = dispatch_semaphore_wait(self->dispatchSemaphore, dispatch_time(DISPATCH_TIME_NOW, 10*NSEC_PER_MSEC));
            if (semaphoreWait != 0) {
        
                if (g_bMonitor) {
                    YLFuencyType fuencyType = [self check];
                    if (self->m_bStop) {
                        break;
                    }
                    
                    /// 兼容
                    if (fuencyType == YLFuencyType_Normal) {
//                        m_nIntervalTime = 1;
//                        m_vecLastMainThreadCallStack.clear();
                    } else {
                        if (fuencyType == YLFuencyType_MainThreadBlock ||
                            fuencyType == YLFuencyType_BackgroundMainThreadBlock) {
                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                                [self recordStackInfoAboutFluency];
                            });
                        }
                    }
                }
            }
            self->timeoutCount = 0;
           
        }
    });
}

- (YLFuencyType)check {
    
    // runloop 超时
    BOOL tmp_g_bRun = g_bRun;
    struct timeval tmp_g_tvRun = g_tvRun;
    
    struct timeval tvCur;
    gettimeofday(&tvCur, NULL);
    unsigned long long diff = [self diffTime:&tmp_g_tvRun endTime:&tvCur];
    
    struct timeval tmp_g_tvSuspend = g_tvSuspend;
    if (__timercmp(&tmp_g_tvSuspend, &tmp_g_tvRun, >)) {
        printf("过滤掉运行后暂停\n");
        return YLFuencyType_Normal;
    }
    
    m_blockDiffTime = 0;
    
    if (tmp_g_bRun && tmp_g_tvRun.tv_sec && tmp_g_tvRun.tv_usec && __timercmp(&tmp_g_tvRun, &tvCur, <) && diff > g_RunLoopTimeOut) {
        
        m_blockDiffTime = diff;
        printf("check run loop time out %u %ld bRun %d runloopActivity %lu block diff time %llu\n",
                   g_RunLoopTimeOut, (long) m_currentState, g_bRun, g_runLoopActivity, diff);
        
        if (g_bBackgroundLaunch) {
            printf("background launch, filter\n");
            return YLFuencyType_Normal;
        }
        
        if (m_currentState == UIApplicationStateBackground) {
            if (g_enterBackground.tv_sec != 0 || g_enterBackground.tv_usec != 0) {
                unsigned long long enterBackgroundTime = [self diffTime:&g_enterBackground endTime:&tvCur];
                if (__timercmp(&g_enterBackground, &tvCur, <) && (enterBackgroundTime > APP_SHOULD_SUSPEND)) {
                    printf("may mistake block %lld\n", enterBackgroundTime);
                    return YLFuencyType_Normal;
                }
            }

            return YLFuencyType_BackgroundMainThreadBlock;
        }
        return YLFuencyType_MainThreadBlock;
    }
    
    return YLFuencyType_Normal;
}

- (unsigned long long)diffTime:(struct timeval *)tvStart endTime:(struct timeval *)tvEnd {
    return 1000000 * (tvEnd->tv_sec - tvStart->tv_sec) + tvEnd->tv_usec - tvStart->tv_usec;
}

#pragma mark - Runloop Observer & Call back

- (void)addRunLoopObserver
{
    NSRunLoop *curRunLoop = [NSRunLoop currentRunLoop];

    // 第一个监控，监控是否处于 <<运行状态>>
    // the first observer
    CFRunLoopObserverContext context = {0, (__bridge void *) self, NULL, NULL, NULL};
    CFRunLoopObserverRef beginObserver = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, LONG_MIN, &myRunLoopBeginCallback, &context);
    CFRetain(beginObserver);
    m_runLoopBeginObserver = beginObserver;

    //  第二个监控，监控是否处于 <<睡眠状态>>
    CFRunLoopObserverRef endObserver = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, LONG_MAX, &myRunLoopEndCallback, &context);
    CFRetain(endObserver);
    m_runLoopEndObserver = endObserver;

    CFRunLoopRef runloop = [curRunLoop getCFRunLoop];
    CFRunLoopAddObserver(runloop, beginObserver, kCFRunLoopCommonModes);
    CFRunLoopAddObserver(runloop, endObserver, kCFRunLoopCommonModes);

    CFRunLoopObserverContext initializationContext = {0, (__bridge void *) self, NULL, NULL, NULL};
    // 第三个监控，监控启动App进入第一个 runloop 是否处于 <<运行状态>>
    m_initializationBeginRunloopObserver = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, LONG_MIN, &myInitializetionRunLoopBeginCallback, &initializationContext);
    CFRetain(m_initializationBeginRunloopObserver);
    // 第四个监控，监控启动App进入第一个 runloop 是否处于 <<睡眠状态>>
    m_initializationEndRunloopObserver = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopAllActivities, YES, LONG_MAX, &myInitializetionRunLoopEndCallback, &initializationContext);
    CFRetain(m_initializationEndRunloopObserver);

    CFRunLoopAddObserver(runloop, m_initializationBeginRunloopObserver, (CFRunLoopMode) @"UIInitializationRunLoopMode");
    CFRunLoopAddObserver(runloop, m_initializationEndRunloopObserver, (CFRunLoopMode) @"UIInitializationRunLoopMode");
}

- (void)removeRunLoopObserver
{
    NSRunLoop *curRunLoop = [NSRunLoop currentRunLoop];

    CFRunLoopRef runloop = [curRunLoop getCFRunLoop];
    CFRunLoopRemoveObserver(runloop, m_runLoopBeginObserver, kCFRunLoopCommonModes);
    CFRunLoopRemoveObserver(runloop, m_runLoopBeginObserver, (CFRunLoopMode) @"UIInitializationRunLoopMode");

    CFRunLoopRemoveObserver(runloop, m_runLoopEndObserver, kCFRunLoopCommonModes);
    CFRunLoopRemoveObserver(runloop, m_runLoopEndObserver, (CFRunLoopMode) @"UIInitializationRunLoopMode");
}


void myRunLoopBeginCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    g_runLoopActivity = activity;
    g_runLoopMode = ylRunloopDefaultMode;
    switch (activity) {
        case kCFRunLoopEntry:
            g_bRun = YES;
            break;

        case kCFRunLoopBeforeTimers:
            if (g_bRun == NO) {
                gettimeofday(&g_tvRun, NULL);
            }
            g_bRun = YES;
            break;

        case kCFRunLoopBeforeSources:
            if (g_bRun == NO) {
                gettimeofday(&g_tvRun, NULL);
            }
            g_bRun = YES;
            break;

        case kCFRunLoopAfterWaiting:
            if (g_bRun == NO) {
                gettimeofday(&g_tvRun, NULL);
            }
            g_bRun = YES;
            break;

        case kCFRunLoopAllActivities:
            break;

        default:
            break;
    }
}

void myRunLoopEndCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    g_runLoopActivity = activity;
    g_runLoopMode = ylRunloopDefaultMode;
    switch (activity) {
        case kCFRunLoopBeforeWaiting:
            gettimeofday(&g_tvRun, NULL);
            g_bRun = NO;
            break;

        case kCFRunLoopExit:
            g_bRun = NO;
            break;

        case kCFRunLoopAllActivities:
            break;

        default:
            break;
    }
}


void myInitializetionRunLoopBeginCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    g_runLoopActivity = activity;
    g_runLoopMode = ylRunloopInitMode;
    switch (activity) {
        case kCFRunLoopEntry:
            g_bRun = YES;
            static BOOL g_bLaunchOver = NO;
            break;

        case kCFRunLoopBeforeTimers:
            gettimeofday(&g_tvRun, NULL);
            g_bRun = YES;
            g_bLaunchOver = NO;
            break;

        case kCFRunLoopBeforeSources:
            gettimeofday(&g_tvRun, NULL);
            g_bRun = YES;
            g_bLaunchOver = NO;
            break;

        case kCFRunLoopAfterWaiting:
            gettimeofday(&g_tvRun, NULL);
            g_bRun = YES;
            g_bLaunchOver = NO;
            break;

        case kCFRunLoopAllActivities:
            break;
        default:
            break;
    }
}

void myInitializetionRunLoopEndCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info)
{
    g_runLoopActivity = activity;
    g_runLoopMode = ylRunloopInitMode;
    switch (activity) {
        case kCFRunLoopBeforeWaiting:
            gettimeofday(&g_tvRun, NULL);
            g_bRun = NO;
            g_bLaunchOver = YES;
            break;

        case kCFRunLoopExit:
            g_bRun = NO;
            g_bLaunchOver = YES;
            break;

        case kCFRunLoopAllActivities:
            break;

        default:
            break;
    }
}

- (void)recordStackInfoAboutFluency {
    
    printf("==========监控到卡顿\n");
    
    NSDictionary * appInfoDict = [YLSystemParam getAppInfo];
    NSString * appInfo = [YLJsonConverTool convertToJSONData:appInfoDict];

    NSDate *date = [NSDate date];
    
    YLCrashLogger *crashLogger = [YLCrashLogger crashLoggerWithName: @"Fluency"
                                                                reason: @"卡顿"
                                                             stackInfo: [YLBacktraceLogger yl_backtraceOfAllThread]
                                                     otherStackInfo: @""
                                                          crashTime: date
                                                     topViewController: NSStringFromClass([[[UIApplication sharedApplication] findTopViewController] class])
                                                    applicationVersion: appInfo];
    YLAnalyicsLogger *analyicsLogger = [YLAnalyicsLogger analyicsLoggerWithName:@"AppFluency" eventTime:date hasCrash:YES eventProperties:appInfoDict];
    
    [[YLLoggerServer sharedServer] insertCrashLogger: crashLogger];
    [[YLLoggerServer sharedServer] insertAnalyicsLogger: analyicsLogger];
}

static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info){
    YLAppFluencyMonitor *lagMonitor = (__bridge YLAppFluencyMonitor*)info;
    lagMonitor->runLoopActivity = activity;
    
    dispatch_semaphore_t semaphore = lagMonitor->dispatchSemaphore;
    dispatch_semaphore_signal(semaphore);
}


#pragma mark - CPU

- (void)addCPUMonitorThread {
    //监测 CPU 消耗
    self.cpuMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:3
                                                             target:self
                                                           selector:@selector(updateCPUInfo)
                                                           userInfo:nil
                                                        repeats:YES];
}

- (void)updateCPUInfo {
    
    [YLAppCPUMonitor updateCPU];
}

@end

@implementation YLAppCPUMonitor

//轮询检查多个线程 cpu 情况
+ (void)updateCPU {
    thread_act_array_t threads;
    mach_msg_type_number_t threadCount = 0;
    const task_t thisTask = mach_task_self();
    kern_return_t kr = task_threads(thisTask, &threads, &threadCount);
    if (kr != KERN_SUCCESS) {
        return;
    }
    for (int i = 0; i < threadCount; i++) {
        thread_info_data_t threadInfo;
        thread_basic_info_t threadBaseInfo;
        mach_msg_type_number_t threadInfoCount = THREAD_INFO_MAX;
        if (thread_info((thread_act_t)threads[i], THREAD_BASIC_INFO, (thread_info_t)threadInfo, &threadInfoCount) == KERN_SUCCESS) {
            threadBaseInfo = (thread_basic_info_t)threadInfo;
            if (!(threadBaseInfo->flags & TH_FLAGS_IDLE)) {
                integer_t cpuUsage = threadBaseInfo->cpu_usage / 10;
                if (cpuUsage > 70) {
                    //cup 消耗大于 70 时打印和记录堆栈
                    NSString *reStr = [YLBacktraceLogger yl_backtraceOfPThread:threads[i]];
                    //记录数据库中
                    [self recordStackInfoAboutFluency];
                    NSLog(@"CPU useage overload thread stack：\n%@",reStr);
                }
            }
        }
    }
}

+ (void)recordStackInfoAboutFluency {
    
    NSDictionary * appInfoDict = [YLSystemParam getAppInfo];
    NSString * appInfo = [YLJsonConverTool convertToJSONData:appInfoDict];

    NSDate *date = [NSDate date];
    
    YLCrashLogger *crashLogger = [YLCrashLogger crashLoggerWithName: @"Fluency"
                                                                reason: @"CPU高"
                                                             stackInfo: [YLBacktraceLogger yl_backtraceOfAllThread]
                                                     otherStackInfo: @""
                                                          crashTime: date
                                                     topViewController: NSStringFromClass([[[UIApplication sharedApplication] findTopViewController] class])
                                                    applicationVersion: appInfo];
    YLAnalyicsLogger *analyicsLogger = [YLAnalyicsLogger analyicsLoggerWithName:@"AppFluencyCPU高" eventTime:date hasCrash:YES eventProperties:appInfoDict];
    
    [[YLLoggerServer sharedServer] insertCrashLogger: crashLogger];
    [[YLLoggerServer sharedServer] insertAnalyicsLogger: analyicsLogger];
}

@end
