//
//  YLSensorsAnalyticsKeychainTool.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YLSensorsAnalyticsKeychainTool : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithService:(NSString *)service key:(NSString *)key;
- (instancetype)initWithService:(NSString *)service accessGroup:(nullable NSString *) accessGroup key:(NSString *)key NS_DESIGNATED_INITIALIZER;

- (nullable NSString *)value;
- (void)update:(NSString *)value;
- (void)remove;

@end

NS_ASSUME_NONNULL_END
