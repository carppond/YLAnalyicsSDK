//
//  YLJsonConverTool.m
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/11/4.
//

#import "YLJsonConverTool.h"
#import "YLAnalyicsLog.h"

@implementation YLJsonConverTool

+ (NSString*)convertToJSONData:(id)infoDict {
    if (infoDict == nil) { return @""; }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:infoDict options:NSJSONWritingPrettyPrinted error:&error];
    
    if (!jsonData) {
        KeHouDebug(@"Got an error: %@", error);
        return @"";
    }
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    jsonString = [jsonString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];  //去除掉首尾的空白字符和换行字符
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    jsonString = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    return jsonString;
}

+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString {
    if (jsonString == nil) { return nil; }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err) { return nil; }
    return dic;
}
+ (NSArray *)arrayWithJsonString:(NSString *)jsonString
{
    if (jsonString == nil) { return nil; }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSArray *array = [NSJSONSerialization JSONObjectWithData:jsonData
                                                     options:NSJSONReadingMutableContainers
                                                       error:&err];
    if(err) { KeHouDebug(@"json解析失败：%@",err); return nil; }
    return array;
}

+ (id)getDataWithResponseObject:(id)data isJson:(BOOL)isJson {
    
    if (isJson) {

        if ([data isKindOfClass:[NSString class]]) {
            id result = [YLJsonConverTool dictionaryWithJsonString:data];
            return result;
        }
        else if ([data isKindOfClass:[NSDictionary class]] ||
                 [data isKindOfClass:[NSArray class]]) {
            return data;
        }
        else if ([data isKindOfClass:[NSURL class]]) {
            return [(NSURL *)data absoluteString];
        }
        else {
            NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            id result = [YLJsonConverTool dictionaryWithJsonString:json];
            return result;
        }
    }
    else {
        if ([data isKindOfClass:[NSString class]]) {
            return data;
        }
        else if ([data isKindOfClass:[NSDictionary class]] ||
             [data isKindOfClass:[NSArray class]]) {
                NSString *json = [YLJsonConverTool convertToJSONData:data];
                return json;
        }
        else {
            NSString *result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            return result;
        }
    }
}
@end
