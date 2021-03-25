//
//  YLLogger.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/11/3.
//

#import "YLLogger.h"
#import "YLDispatchAsync.h"
#import "YLAnalyicsLog.h"
#import "YLJsonConverTool.h"

#if __has_include(<sqlite3.h>)
#import <sqlite3.h>
#else
#import "sqlite3.h"
#endif

static NSString * const kLoggerDatabaseFileName = @"crash_analyics_logger.sqlite";

NSString * __yl_convert_time(NSDate * date) {
    static NSDateFormatter * yl_date_formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        yl_date_formatter = [NSDateFormatter new];
        yl_date_formatter.dateFormat = @"yyyy-HH-dd HH:mm:ss";
    });
    return [yl_date_formatter stringFromDate: date];
}


@implementation YLLogger

@end


@interface YLAnalyicsLogger ()

@property (nonatomic, copy) NSString *eventName;
@property (nonatomic, copy) NSString *eventTime;
@property (nonatomic, copy) NSDictionary *eventProperties;
@property (nonatomic, assign) BOOL hasCrash;

@end

@implementation YLAnalyicsLogger

+ (instancetype)analyicsLoggerWithName:(NSString *)eventName
                             eventTime:(NSDate *)eventTime
                              hasCrash:(BOOL)hasCrash
                       eventProperties:(NSDictionary *)eventProperties {
    YLAnalyicsLogger * crashLogger = [YLAnalyicsLogger new];
    crashLogger.eventName = eventName ?: @"";
    crashLogger.eventTime = __yl_convert_time(eventTime);
    crashLogger.hasCrash = hasCrash;
    crashLogger.eventProperties = eventProperties ?: @{};
    return crashLogger;
}

- (NSString *)loggerDescription {
    NSString *hasCrash = _hasCrash ? @"YES" : @"NO";
    return [NSString stringWithFormat: @"[Event]: %@\nEventTime: %@\nHasCrash: %@\nEventProperties: %@\n", _eventName, _eventTime, hasCrash, _eventProperties];
}

@end


@interface YLCrashLogger ()

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *reason;
@property (nonatomic, copy) NSString *stackInfo;
@property (nonatomic, copy) NSString *otherStackInfo;
@property (nonatomic, copy) NSString *crashTime;
@property (nonatomic, copy) NSString *topViewController;
@property (nonatomic, copy) NSString *applicationVersion;

@end

@implementation YLCrashLogger

+ (instancetype)crashLoggerWithName:(NSString *)name
                             reason:(NSString *)reason
                          stackInfo:(NSString *)stackInfo
                     otherStackInfo:(NSString *)otherStackInfo
                          crashTime:(NSDate *)crashTime
                  topViewController:(NSString *)topViewController
                 applicationVersion:(NSString *)applicationVersion {
    YLCrashLogger * crashLogger = [YLCrashLogger new];
    crashLogger.name = name ?: @"";
    crashLogger.reason = reason ?: @"";
    crashLogger.stackInfo = stackInfo ?: @"";
    crashLogger.otherStackInfo = otherStackInfo ?: @"";
    crashLogger.topViewController = topViewController ?: @"";
    crashLogger.applicationVersion = applicationVersion ?: @"";
    crashLogger.crashTime = __yl_convert_time(crashTime);
    return crashLogger;
}

- (NSString *)loggerDescription {
    return [NSString stringWithFormat: @"Error: %@\nReson: %@\n%@\nTop viewcontroller: %@\nCrash time: %@\n\nCall Stack: \n%@\nOtherStackInfo=%@", _name, _reason, _applicationVersion, _topViewController, _crashTime, _stackInfo,_otherStackInfo];
}

@end


/*!
 *  @brief  闪退日志服务管理
 */
@interface YLLoggerServer ()

@property (nonatomic, unsafe_unretained) sqlite3 * database;
@property (nonatomic, unsafe_unretained) CFMutableDictionaryRef stmtCache;
@property (nonatomic, assign) NSInteger crashCount;
@property (nonatomic, assign) NSInteger eventCount;
@end

@implementation YLLoggerServer

#pragma mark - Singleton
+ (instancetype)sharedServer {
    static YLLoggerServer *sharedServer;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedServer = [[super allocWithZone: NSDefaultMallocZone()] init];
    });
    return sharedServer;
}

+ (instancetype)allocWithZone: (struct _NSZone *)zone {
    return [self sharedServer];
}

- (instancetype)init {
    if (self = [super init]) {
        if ([self dbOpen]) {
            [self dbInitialize];
            CFDictionaryKeyCallBacks keyCallbacks = kCFCopyStringDictionaryKeyCallBacks;
            CFDictionaryValueCallBacks valueCallbacks = { 0 };
            self.stmtCache = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &keyCallbacks, &valueCallbacks);
            [self queryLocalDatabaseCarshCount];
        }
    }
    return self;
}

- (id)copy {
    return [[self class] sharedServer];
}

- (void)dealloc {
    if (!_database) {
        sqlite3_close(_database);
        CFRelease(_stmtCache);
        _stmtCache = NULL;
        _database = NULL;
    }
}

#pragma mark - Private

- (NSString *)crashLoggerFilePath {
    return [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent: kLoggerDatabaseFileName];
}

- (void)syncExecute: (dispatch_block_t)block {
    assert(block != nil);
    if ([NSThread isMainThread]) {
        YLDispatchQueueAsyncBlockInUtility(block);
    } else {
        block();
    }
}

#pragma mark - Private Crash

- (void)_insertCrashLogger: (YLCrashLogger *)crashLogger {
    NSString * sql = @"insert or replace into crash_logger (name, reason, stack_info, otherStackInfo, crash_time, top_view_controller, application_version) values (?1, ?2, ?3, ?4, ?5, ?6, ?7);";
    sqlite3_stmt * stmt = [self dbPrepareStmt: sql];
    if (!stmt) { return; }
    
    sqlite3_bind_text(stmt, 1, crashLogger.name.UTF8String, -1, NULL);
    sqlite3_bind_text(stmt, 2, crashLogger.reason.UTF8String, -1, NULL);
    sqlite3_bind_text(stmt, 3, crashLogger.stackInfo.UTF8String, -1, NULL);
    sqlite3_bind_text(stmt, 4, crashLogger.otherStackInfo.UTF8String, -1, NULL);
    sqlite3_bind_text(stmt, 5, crashLogger.crashTime.UTF8String, -1, NULL);
    sqlite3_bind_text(stmt, 6, crashLogger.topViewController.UTF8String, -1, NULL);
    sqlite3_bind_text(stmt, 7, crashLogger.applicationVersion.UTF8String, -1, NULL);
    sqlite3_step(stmt);
}

- (void)cleanExtraCrashLoggers {
    NSString * sql = @"delete from crash_logger order by crash_time desc limit (select count(crash_time) from crash_logger) offset 20";
    sqlite3_stmt * stmt = [self dbPrepareStmt: sql];
    if (!stmt) { return; }
    sqlite3_step(stmt);
}

- (void)_fetchLastCrashLogger: (void(^)(YLCrashLogger *))fetchHandle {
    assert(fetchHandle != nil);
    sqlite3_stmt * stmt = [self fetchCrashLoggerWithCount: 1];
    if (!stmt) { return; }
    
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        dispatch_async(dispatch_get_main_queue(), ^{
            fetchHandle([self dbGetCrashLoggerFromStmt: stmt]);
        });
    }
}

- (void)_fetchCrashLoggers: (void(^)(NSArray<YLCrashLogger *> *))fetchHandle {
    assert(fetchHandle != nil);
    sqlite3_stmt * stmt = [self fetchCrashLoggerWithCount: self.crashCount];
    if (!stmt) { return; }
    
    NSMutableArray * loggers = [NSMutableArray array];
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        [loggers addObject: [self dbGetCrashLoggerFromStmt: stmt]];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        fetchHandle(loggers);
    });
    // 主动清空
//    if (loggers.count == 20) {
//        [self cleanExtraCrashLoggers];
//    }
}

- (YLCrashLogger *)dbGetCrashLoggerFromStmt: (sqlite3_stmt *)stmt {
    int idx = 0;
    char * name = (char *)sqlite3_column_text(stmt, idx++);
    char * reason = (char *)sqlite3_column_text(stmt, idx++);
    char * stack_info = (char *)sqlite3_column_text(stmt, idx++);
    char * other_stack_info = (char *)sqlite3_column_text(stmt, idx++);
    char * crash_time = (char *)sqlite3_column_text(stmt, idx++);
    char * top_view_controller = (char *)sqlite3_column_text(stmt, idx++);
    char * application_version = (char *)sqlite3_column_text(stmt, idx++);
    
    YLCrashLogger * logger = [YLCrashLogger new];
    logger.name = [NSString stringWithUTF8String: name];
    logger.reason = [NSString stringWithUTF8String: reason];
    logger.stackInfo = [NSString stringWithUTF8String: stack_info];
    logger.otherStackInfo = [NSString stringWithUTF8String: other_stack_info];
    logger.crashTime = [NSString stringWithUTF8String: crash_time];
    logger.applicationVersion = [NSString stringWithUTF8String: application_version];
    logger.topViewController = [NSString stringWithUTF8String: top_view_controller];
    return logger;
}

- (sqlite3_stmt *)fetchCrashLoggerWithCount: (NSUInteger)count {
    NSString * sql = @"select * from crash_logger order by crash_time desc limit 0,?1;";
    sqlite3_stmt * stmt = [self dbPrepareStmt: sql];
    if (!stmt) { return NULL; }
    sqlite3_bind_int64(stmt, 1, count);
    return stmt;
}


#pragma mark - Private Analyics

- (BOOL)_insertAnalyicsLogger: (YLAnalyicsLogger *)analyicsLogger {
    NSString * sql = @"insert or replace into event_logger (eventName, eventTime, propertiesStr, hasCrash) values (?1, ?2, ?3, ?4);";
    sqlite3_stmt * stmt = [self dbPrepareStmt: sql];
    if (!stmt) { return NO; }
    NSString *propertiesStr = [YLJsonConverTool convertToJSONData:analyicsLogger.eventProperties];
    sqlite3_bind_text(stmt, 1, analyicsLogger.eventName.UTF8String, -1, NULL);
    sqlite3_bind_text(stmt, 2, analyicsLogger.eventTime.UTF8String, -1, NULL);
    sqlite3_bind_text(stmt, 3, propertiesStr.UTF8String, -1, NULL);
    sqlite3_bind_int(stmt, 4, analyicsLogger.hasCrash);
    int result = sqlite3_step(stmt);
    sqlite3_reset(stmt);
    if (result != SQLITE_DONE) {
        KeHouDebug(@"sqlite insert error (%d): %s", result, sqlite3_errmsg(self.database));
        return NO;
    }
    return YES;
}

- (void)cleanExtraAnalyicsLoggers {
    NSString * sql = @"delete from event_logger order by eventTime desc limit (select count(eventTime) from event_logger) offset 20";
    sqlite3_stmt * stmt = [self dbPrepareStmt: sql];
    if (!stmt) { return; }
    sqlite3_step(stmt);
    sqlite3_reset(stmt);
}

- (void)_fetchLastAnalyicsLogger: (void(^)(YLAnalyicsLogger *))fetchHandle {
    assert(fetchHandle != nil);
    sqlite3_stmt * stmt = [self fetchAnalyicsLoggerWithCount: 1];
    if (!stmt) { return; }
    
    int result = sqlite3_step(stmt);
    
    if (result == SQLITE_ROW) {
        dispatch_async(dispatch_get_main_queue(), ^{
            fetchHandle([self dbGetAnalyicsLoggerFromStmt: stmt]);
            sqlite3_reset(stmt);
        });
        return;
    }
    sqlite3_reset(stmt);
    if (result != SQLITE_DONE) {
        KeHouDebug(@"sqlite query error (%d): %s",result, sqlite3_errmsg(_database));
    }
    fetchHandle(nil);
}

- (void)_fetchAnalyicsLoggers: (void(^)(NSArray<YLAnalyicsLogger *> *))fetchHandle {
    assert(fetchHandle != nil);
    sqlite3_stmt * stmt = [self fetchAnalyicsLoggerWithCount: self.eventCount];
    if (!stmt) { return; }
    
    NSMutableArray * loggers = [NSMutableArray array];
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        [loggers addObject: [self dbGetAnalyicsLoggerFromStmt: stmt]];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        fetchHandle(loggers);
    });
    // 主动清空
//    if (loggers.count == 20) {
//        [self cleanExtraAnalyicsLoggers];
//    }
}

- (YLAnalyicsLogger *)dbGetAnalyicsLoggerFromStmt: (sqlite3_stmt *)stmt {
    int idx = 0;
    char * eventName = (char *)sqlite3_column_text(stmt, idx++);
    char * eventTime = (char *)sqlite3_column_text(stmt, idx++);
    char * properties = (char *)sqlite3_column_text(stmt, idx++);
    int hasCrash = sqlite3_column_int(stmt, idx++);
    
    NSString *propertiesStr = [NSString stringWithUTF8String: properties];
    
    YLAnalyicsLogger * logger = [YLAnalyicsLogger new];
    logger.eventName = [NSString stringWithUTF8String: eventName];
    logger.eventTime = [NSString stringWithUTF8String: eventTime];
    logger.eventProperties = [YLJsonConverTool dictionaryWithJsonString:propertiesStr];
    logger.hasCrash = hasCrash;
    return logger;
}

- (sqlite3_stmt *)fetchAnalyicsLoggerWithCount: (NSUInteger)count {
    NSString * sql = @"select * from event_logger order by eventTime desc limit 0,?1;";
    sqlite3_stmt * stmt = [self dbPrepareStmt: sql];
    if (!stmt) { return NULL; }
    sqlite3_bind_int64(stmt, 1, count);
    return stmt;
}

#pragma mark - Sqlite
- (BOOL)dbOpen {
    if (_database) { return YES; }
    int result = sqlite3_open([self crashLoggerFilePath].UTF8String, &_database);
    if (result == SQLITE_OK) {
        return YES;
    } else {
        _database = NULL;
        return NO;
    }
}

- (BOOL)dbInitialize {
    NSString * sql = @"pragma journal_mode = wal; pragma synchronous = normal; create table if not exists crash_logger (id INTEGER PRIMARY KEY AUTOINCREMENT, name text, reason text, stack_info text,otherStackInfo text, crash_time text, top_view_controller text, application_version text);";

    NSString * eventSql = @"pragma journal_mode = wal; pragma synchronous = normal; create table if not exists event_logger (id INTEGER PRIMARY KEY AUTOINCREMENT, eventName text, eventTime text, propertiesStr text,hasCrash INTEGER);";
    
    BOOL crashResult = [self dbExecute: sql];
    BOOL eventResult = [self dbExecute: eventSql];
    
    return eventResult && crashResult;
}

- (BOOL)dbExecute: (NSString *)sql {
    if (sql.length == 0) { return NO; }
    if (![self dbCheck]) { return NO; }
    
    char * error = NULL;
    int result = sqlite3_exec(_database, sql.UTF8String, NULL, NULL, &error);
    if (error) {
        sqlite3_free(error);
    }
    return (result == SQLITE_OK);
}

- (BOOL)dbCheck {
    if (!_database) {
        return ([self dbOpen] && [self dbInitialize]);
    }
    return YES;
}

- (sqlite3_stmt *)dbPrepareStmt: (NSString *)sql {
    if (![self dbCheck] || sql.length == 0 || !_stmtCache) { return NULL; }
    sqlite3_stmt * stmt = (sqlite3_stmt *)CFDictionaryGetValue(_stmtCache, (__bridge const void *)sql);
    if (!stmt) {
        int result = sqlite3_prepare_v2(_database, sql.UTF8String, -1, &stmt, NULL);
        if (result != SQLITE_OK) {
            return NULL;
        }
        CFDictionarySetValue(_stmtCache, (__bridge const void *)sql, stmt);
    } else {
        sqlite3_reset(stmt);
    }
    return stmt;
}

- (BOOL)dbdeleteFoSql:(NSString *)sql {
    char *errmsg;
    // 执行删除语句
    if (sqlite3_exec(self.database, sql.UTF8String, NULL, NULL, &errmsg) != SQLITE_OK) {
        KeHouDebug(@"Failed to delete record msg=%s", errmsg);
        return NO;
    }
    return YES;
}
    
- (void)queryLocalDatabaseEventCount {
    // 查询语句
    NSString *sql = @"SELECT count(*) FROM event_logger;";
    sqlite3_stmt *stmt = NULL;
    // 准备执行SQL语句，获取sqlite3_stmt
    if (sqlite3_prepare_v2(self.database, sql.UTF8String, -1, &stmt, NULL) != SQLITE_OK) {
        // 准备执行SQL语句失败，打印log返回失败（NO）
        return KeHouDebug(@"SQLite stmt prepare error: %s", sqlite3_errmsg(self.database));
    }
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        self.eventCount = sqlite3_column_int(stmt, 0);
    }
}

- (void)queryLocalDatabaseCarshCount {
    // 查询语句
    NSString *sql = @"SELECT count(*) FROM crash_logger;";
    sqlite3_stmt *stmt = NULL;
    // 准备执行SQL语句，获取sqlite3_stmt
    if (sqlite3_prepare_v2(self.database, sql.UTF8String, -1, &stmt, NULL) != SQLITE_OK) {
        // 准备执行SQL语句失败，打印log返回失败（NO）
        return KeHouDebug(@"SQLite stmt prepare error: %s", sqlite3_errmsg(self.database));
    }
    while (sqlite3_step(stmt) == SQLITE_ROW) {
        self.crashCount = sqlite3_column_int(stmt, 0);
    }
}


@end


#pragma mark - Crash

@implementation YLLoggerServer (YLCrash)

- (void)insertCrashLogger:(YLCrashLogger *)logger {
    [self _insertCrashLogger:logger];
}

- (void)fetchLastCrashLogger:(void(^)(YLCrashLogger *logger))fetchHandle {
    [self syncExecute: ^{
        [self _fetchLastCrashLogger: fetchHandle];
    }];
}

- (void)fetchCrashLoggers:(void(^)(NSArray<YLCrashLogger *>*))fetchHandle {
    [self syncExecute: ^{
        [self _fetchCrashLoggers: fetchHandle];
    }];
}


- (BOOL)deleteCrashLoggerForCount:(NSUInteger)count {
    // 当本地事件数量为0时，直接返回
    if (self.crashCount == 0) {
        return YES;
    }
    if (count > self.crashCount) {
        count = self.crashCount;
    }
    // 删除语句
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM crash_logger WHERE id IN (SELECT id FROM crash_logger ORDER BY id ASC LIMIT %lu);", (unsigned long)count];
    BOOL result = [self dbdeleteFoSql:sql];
    if (result) {
        self.crashCount -= count;
    }
    return result;
}

@end


#pragma mark - Analyics

@implementation YLLoggerServer (YLAnalyics)

- (void)insertAnalyicsLogger:(YLAnalyicsLogger *)logger {
    [self _insertAnalyicsLogger:logger];
}

- (void)fetchLastAnalyicsLogger:(void(^)(YLAnalyicsLogger *logger))fetchHandle {
    [self syncExecute: ^{
        [self _fetchLastAnalyicsLogger: fetchHandle];
    }];
}

- (void)fetchAnalyicsLoggers:(void(^)(NSArray<YLAnalyicsLogger *>*))fetchHandle {
    [self syncExecute: ^{
        [self _fetchAnalyicsLoggers: fetchHandle];
    }];
}

- (BOOL)deleteAnalyicsLoggerForCount:(NSUInteger)count {
    
    // 当本地事件数量为0时，直接返回
    if (self.eventCount == 0) {
        return YES;
    }
    if (count > self.eventCount) {
        count = self.eventCount;
    }
    // 删除语句
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM event_logger WHERE id IN (SELECT id FROM event_logger ORDER BY id ASC LIMIT %lu);", (unsigned long)count];
    BOOL result = [self dbdeleteFoSql:sql];
    if (result) {
        self.eventCount -= count;
    }
    return result;
}

@end
