//
//  YLSensorsAnalyticsKeychainTool.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/10/20.
//

#import "YLSensorsAnalyticsKeychainTool.h"
#import <Security/Security.h>
#import "YLAnalyicsLog.h"

@interface YLSensorsAnalyticsKeychainTool ()

@property (nonatomic, strong) NSString *service;
@property (nonatomic, strong) NSString *accessGroup;
@property (nonatomic, strong) NSString *key;

@end

@implementation YLSensorsAnalyticsKeychainTool

- (instancetype)initWithService:(NSString *)service key:(NSString *)key {
    return [self initWithService:service accessGroup:nil key:key];
}

- (instancetype)initWithService:(NSString *)service accessGroup:(nullable NSString *) accessGroup key:(NSString *)key {
    self = [super init];
    if (self) {
        _service = service;
        _key = key;
        _accessGroup = accessGroup;
    }
    return self;
}

- (nullable NSString *)value {
    NSMutableDictionary *query = [YLSensorsAnalyticsKeychainTool keychainQueryWithService:self.service accessGroup:self.accessGroup key:self.key];
    query[(NSString *)kSecMatchLimit] = (id)kSecMatchLimitOne;
    query[(NSString *)kSecReturnAttributes] = (id)kCFBooleanTrue;
    query[(NSString *)kSecReturnData] = (id)kCFBooleanTrue;

    CFTypeRef queryResult;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &queryResult);

    if (status == errSecItemNotFound) {
        return nil;
    }
    if (status != noErr) {
        KeHouDebug(@"Get item value error %d", (int)status);
        return nil;
    }

    NSData *data = [(__bridge_transfer NSDictionary *)queryResult objectForKey: (NSString *)kSecValueData];
    if (!data) {
        return nil;
    }
    NSString *value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    KeHouDebug(@"Get item value %@", value);
    return value;
}

- (void)update:(NSString *)value {
    NSData *encodedValue = [value dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *query = [YLSensorsAnalyticsKeychainTool keychainQueryWithService: self.service accessGroup:self.accessGroup key:self.key];
    
    NSString *originalValue = [self value];
    if (originalValue) {
        NSMutableDictionary *attributesToUpdate = [[NSMutableDictionary alloc] init];
        attributesToUpdate[(NSString *)kSecValueData] = encodedValue;
        
        OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributesToUpdate);
        if (status == noErr) {
            KeHouDebug(@"update item ok");
        } else {
            KeHouDebug(@"update item error %d", (int)status);
        }
    } else {
        [query setObject:encodedValue forKey:(id)kSecValueData];
        OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
        if (status == noErr) {
            KeHouDebug(@"add item ok");
        } else {
            KeHouDebug(@"add item error %d", (int)status);
        }
    }
}

- (void)remove {
    NSMutableDictionary *query = [YLSensorsAnalyticsKeychainTool keychainQueryWithService: self.service accessGroup:self.accessGroup key:self.key];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);

    if (status != noErr && status != errSecItemNotFound) {
        KeHouDebug(@"remove item %d", (int)status);
    }
}

#pragma mark - Private

+ (NSMutableDictionary *)keychainQueryWithService:(NSString *)service accessGroup: (nullable NSString *)accessGroup key:(NSString *)key {
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
    query[(NSString *)kSecClass] = (NSString *)kSecClassGenericPassword;
    query[(NSString *)kSecAttrService] = service;
    query[(NSString *)kSecAttrAccount] = key;
    
    query[(NSString *)kSecAttrAccessGroup] = accessGroup;
    return query;
}
@end
