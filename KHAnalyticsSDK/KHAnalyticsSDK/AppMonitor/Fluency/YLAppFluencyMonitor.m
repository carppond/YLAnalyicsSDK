//
//  YLAppFluencyMonitor.m
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/11/6.
//

#import "YLAppFluencyMonitor.h"
#import "YLBacktraceLogger.h"
#import "YLLogger.h"
#import "KHSystemParam.h"
#import "YLJsonConverTool.h"
#import "UIApplication+YLTool.h"
#include <mach/mach.h>

@interface YLAppFluencyMonitor ()
{
    int timeoutCount;
    CFRunLoopObserverRef runLoopObserver;
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

- (void)beginMonitor {
    //监测 CPU 消耗
    self.cpuMonitorTimer = [NSTimer scheduledTimerWithTimeInterval:3
                                                             target:self
                                                           selector:@selector(updateCPUInfo)
                                                           userInfo:nil
                                                            repeats:YES];
    //监测卡顿
    if (runLoopObserver) {
        return;
    }
    dispatchSemaphore = dispatch_semaphore_create(0);
    //创建一个观察者
    CFRunLoopObserverContext context = {0,(__bridge void*)self,NULL,NULL};
    runLoopObserver = CFRunLoopObserverCreate(kCFAllocatorDefault,
                                              kCFRunLoopAllActivities,
                                              YES,
                                              0,
                                              &runLoopObserverCallBack,
                                              &context);
    //将观察者添加到主线程runloop的common模式下的观察中
    CFRunLoopAddObserver(CFRunLoopGetMain(), runLoopObserver, kCFRunLoopCommonModes);
    
    //创建子线程监控
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        //子线程开启一个持续的loop用来进行监控
        while (YES) {
            long semaphoreWait = dispatch_semaphore_wait(self->dispatchSemaphore, dispatch_time(DISPATCH_TIME_NOW, 10*NSEC_PER_MSEC));
            if (semaphoreWait != 0) {
                if (!self->runLoopObserver) {
                    self->timeoutCount = 0;
                    self->dispatchSemaphore = 0;
                    self->runLoopActivity = 0;
                    return;
                }
                //两个runloop的状态，BeforeSources和AfterWaiting这两个状态区间时间能够检测到是否卡顿
                if (self->runLoopActivity == kCFRunLoopBeforeSources ||
                    self->runLoopActivity == kCFRunLoopAfterWaiting) {
                    //出现三次出结果
//                    if (++timeoutCount < 3) {
//                        continue;
//                    }
                    NSLog(@"monitor trigger");
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                        [self recordStackInfoAboutFluency];
                    });
                } //end activity
            }// end semaphore wait
            self->timeoutCount = 0;
        } // end while
    });
    
}

- (void)recordStackInfoAboutFluency {
    
    NSDictionary * appInfoDict = [KHSystemParam getAppInfo];
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

- (void)endMonitor {
    [self.cpuMonitorTimer invalidate];
    if (!runLoopObserver) {
        return;
    }
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), runLoopObserver, kCFRunLoopCommonModes);
    CFRelease(runLoopObserver);
    runLoopObserver = NULL;
}

#pragma mark - Private
- (void)updateCPUInfo {
    [YLAppCPUMonitor updateCPU];
}

static void runLoopObserverCallBack(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info){
    YLAppFluencyMonitor *lagMonitor = (__bridge YLAppFluencyMonitor*)info;
    lagMonitor->runLoopActivity = activity;
    
    dispatch_semaphore_t semaphore = lagMonitor->dispatchSemaphore;
    dispatch_semaphore_signal(semaphore);
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
    
    NSDictionary * appInfoDict = [KHSystemParam getAppInfo];
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
