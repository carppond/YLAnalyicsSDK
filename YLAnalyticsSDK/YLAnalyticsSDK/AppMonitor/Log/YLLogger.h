//
//  YLLogger.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/11/3.
//

#import <Foundation/Foundation.h>

NSString * __yl_convert_time(NSDate * date);

/*!
 *  @brief  日志管理
 */
@interface YLLogger : NSObject

@end


/*!
 *  @brief  埋点统计日志管理
 */
@interface YLAnalyicsLogger : NSObject

@property (nonatomic, readonly) NSString *eventName;
/// 如果发生 crash，这里的时间与 crash 记录的时间一致
@property (nonatomic, readonly) NSString *eventTime;
@property (nonatomic, readonly) NSDictionary *eventProperties;
@property (nonatomic, readonly) BOOL hasCrash;

+ (instancetype)analyicsLoggerWithName:(NSString *)eventName
                             eventTime:(NSDate *)eventTime
                              hasCrash:(BOOL)hasCrash
                       eventProperties:(NSDictionary *)eventProperties;

- (NSString *)loggerDescription;

@end


/*!
 *  @brief  崩溃日志
 */
@interface YLCrashLogger : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *reason;
@property (nonatomic, readonly) NSString *stackInfo;
@property (nonatomic, readonly) NSString *otherStackInfo;
@property (nonatomic, readonly) NSString *crashTime;
@property (nonatomic, readonly) NSString *topViewController;
@property (nonatomic, readonly) NSString *applicationVersion;

+ (instancetype)crashLoggerWithName:(NSString *)name
                             reason:(NSString *)reason
                          stackInfo:(NSString *)stackInfo
                     otherStackInfo:(NSString *)otherStackInfo
                          crashTime:(NSDate *)crashTime
                  topViewController:(NSString *)topViewController
                 applicationVersion:(NSString *)applicationVersion;

- (NSString *)loggerDescription;

@end


/*!
 *  @brief  日志服务管理
 */
@interface YLLoggerServer : NSObject

@property (nonatomic, readonly) NSInteger crashCount;
@property (nonatomic, readonly) NSInteger eventCount;

+ (instancetype)sharedServer;

@end


/*!
 *  @brief  闪退日志服务管理
 */
@interface YLLoggerServer (YLCrash)

- (void)insertCrashLogger:(YLCrashLogger *)logger;

- (void)fetchLastCrashLogger:(void(^)(YLCrashLogger *logger))fetchHandle;

- (void)fetchCrashLoggers:(void(^)(NSArray<YLCrashLogger *>*))fetchHandle;

- (BOOL)deleteCrashLoggerForCount:(NSUInteger)count;

@end


/*!
*  @brief  统计日志服务管理
*/
@interface YLLoggerServer (YLAnalyics)

- (void)insertAnalyicsLogger:(YLAnalyicsLogger *)logger;

- (void)fetchLastAnalyicsLogger:(void(^)(YLAnalyicsLogger *logger))fetchHandle;

- (void)fetchAnalyicsLoggers:(void(^)(NSArray<YLAnalyicsLogger *>*))fetchHandle;;

- (BOOL)deleteAnalyicsLoggerForCount:(NSUInteger)count;

@end
