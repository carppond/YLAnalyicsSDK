//
//  YLJsonConverTool.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2020/11/4.
//

#import <Foundation/Foundation.h>


@interface YLJsonConverTool : NSObject
/*!
 *  字典转json
 */
+ (NSString*)convertToJSONData:(id)infoDict;

/*!
 *  json转字典
 */
+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString;

/*!
 *  json转数组
 */
+ (NSArray *)arrayWithJsonString:(NSString *)jsonString;

+ (id)getDataWithResponseObject:(id)data isJson:(BOOL)isJson;


@end

