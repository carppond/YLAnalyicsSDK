//
//  YLBacktraceLogger.h
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/11/4.
//

#import <Foundation/Foundation.h>
#import <mach/mach.h>

/*!
 *  @brief  线程堆栈上下文输出
 */
@interface YLBacktraceLogger : NSObject

+ (NSString *)yl_backtraceOfAllThread;
+ (NSString *)yl_backtraceOfMainThread;
+ (NSString *)yl_backtraceOfCurrentThread;
+ (NSString *)yl_backtraceOfNSThread:(NSThread *)thread;
+ (NSString *)yl_backtraceOfPThread:(thread_t)thread;

+ (void)yl_logMain;
+ (void)yl_logCurrent;
+ (void)yl_logAllThread;

+ (NSString *)backtraceLogFilePath;
+ (void)recordLoggerWithFileName: (NSString *)fileName;

@end

