//
//  YLCrashMonitor.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/11/4.
//

#import "YLCrashMonitor.h"
#import "YLSystemParam.h"
#import "YLJsonConverTool.h"
#import "YLLogger.h"
#import "YLBacktraceLogger.h"
#import "UIApplication+YLTool.h"
#import "YLAnalyicsLog.h"
#import "YLAnalyicsTyeDefine.h"


void (*other_exception_caught_handler)(NSException * exception) = NULL;


@implementation YLCrashMonitor


static void yl_exception_caught(NSException * exception) {
    
    NSDictionary * appInfoDict = [YLSystemParam getAppInfo];
    NSString * appInfo = [YLJsonConverTool convertToJSONData:appInfoDict];

    NSArray *otherStacks = [exception callStackSymbols] ?: [NSThread callStackSymbols];
    NSString *stacksString = [otherStacks componentsJoinedByString:@"\n"];
    NSDate *date = [NSDate date];
    __block NSString *topViewController = nil;
    dispatch_main_async_safe(^{
        topViewController = NSStringFromClass([[[UIApplication sharedApplication] findTopViewController] class]);
    });
    
    YLCrashLogger *crashLogger = [YLCrashLogger crashLoggerWithName: exception.name
                                                                reason: exception.reason
                                                             stackInfo: [YLBacktraceLogger yl_backtraceOfCurrentThread]
                                                     otherStackInfo: stacksString crashTime: date
                                                     topViewController:topViewController
                                                    applicationVersion: appInfo];
    YLAnalyicsLogger *analyicsLogger = [YLAnalyicsLogger analyicsLoggerWithName:@"AppCrashed" eventTime:date hasCrash:YES eventProperties:appInfoDict];
    
    [[YLLoggerServer sharedServer] insertCrashLogger: crashLogger];
    [[YLLoggerServer sharedServer] insertAnalyicsLogger: analyicsLogger];
    
    if (other_exception_caught_handler != NULL) {
        (*other_exception_caught_handler)(exception);
    }
}

CF_INLINE NSString * __signal_name(int signal) {
    switch (signal) {
            /// 非法指令
        case SIGILL:
            return @"SIGILL";
            /// 计算错误
        case SIGFPE:
            return @"SIGFPE";
            /// 总线错误
        case SIGBUS:
            return @"SIGBUS";
            /// 无进程接手数据
        case SIGPIPE:
            return @"SIGPIPE";
            /// 无效地址
        case SIGSEGV:
            return @"SIGSEGV";
            /// abort信号
        case SIGABRT:
            return @"SIGABRT";
        default:
            return @"Unknown";
    }
}

CF_INLINE NSString * __signal_reason(int signal) {
    switch (signal) {
            /// 非法指令
        case SIGILL:
            return @"Invalid Command";
            /// 计算错误
        case SIGFPE:
            return @"Math Type Error";
            /// 总线错误
        case SIGBUS:
            return @"Bus Error";
            /// 无进程接手数据
        case SIGPIPE:
            return @"No Data Receiver";
            /// 无效地址
        case SIGSEGV:
            return @"Invalid Address";
            /// abort信号
        case SIGABRT:
            return @"Abort Signal";
        default:
            return @"Unknown";
    }
}

static void yl_signal_handler(int signal) {
    
    NSDictionary *userInfo = @{@"SignalExceptionHandlerUserInfo": @(signal)};
    yl_exception_caught([NSException exceptionWithName: __signal_name(signal) reason: __signal_reason(signal) userInfo: userInfo]);
    
    [YLCrashMonitor yl_killApp];
}


#pragma mark - Public
+ (void)startMonitoring {
    other_exception_caught_handler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(yl_exception_caught);
    
    signal(SIGILL, yl_signal_handler);
    signal(SIGABRT, yl_signal_handler);
    signal(SIGBUS, yl_signal_handler);
    signal(SIGFPE, yl_signal_handler);
    signal(SIGSEGV, yl_signal_handler);
    signal(SIGTRAP, yl_signal_handler);
    signal(SIGPIPE, yl_signal_handler);
    signal(SIGHUP, yl_signal_handler);
    signal(SIGINT, yl_signal_handler);
    signal(SIGQUIT, yl_signal_handler);
}


#pragma mark - Private
+ (void)yl_killApp {
    NSSetUncaughtExceptionHandler(NULL);
    
    signal(SIGILL, SIG_DFL);
    signal(SIGABRT, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGTRAP, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    signal(SIGHUP, SIG_DFL);
    signal(SIGINT, SIG_DFL);
    signal(SIGQUIT, SIG_DFL);
    kill(getpid(), SIGKILL);
}


@end
/*
 SIGILL：程序非法指令信号，通常是因为可执行文件本身出现错误，或者试图执行数据段。堆栈溢出时也有可能产生该信号。
 SIGABRT：程序中止命令中止信号，调用abort函数时产生该信号。
 
 SIGBUS：程序内存字节地址未对齐中止信号，比如访问一个4字节长的整数，但其地址不是4的倍数
 
 SIGFPE：程序浮点异常信号，通常在浮点运算错误、溢出及除数为0等算术错误时都会产生该信号。
 
 SIGKILL：程序结束接收中止信号，用来立即结束程序运行，不能被处理、阻塞和忽略。
 
 SIGSEGV：程序无效内存中止信号，即试图访问未分配的内存，或向没有写权限的内存地址写数据。

 SIGPIPE：程序管道破裂信号，通常是在进程间通信时产生该信号。

 SIGSTOP：程序进程中止信号，与SIGKILL一样不能被处理、阻塞和忽略。
 
 SIGTRAP：断点指令或者其他trap指令产生
 
 SIGHUP：程序终端中止信号
 
 SIGINT：程序键盘中断信号
 
 SIGQUIT：进程在因收到SIGQUIT退出时会产生coredump文件, 在这个意义上类似于一个程序错误信号。
 */
