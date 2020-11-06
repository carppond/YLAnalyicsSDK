//
//  KHAnalyicsLog.h
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/22.
//
#import <Foundation/Foundation.h>

#ifndef KHAnalyicsLog_h
#define KHAnalyicsLog_h

static inline void KEHOULog(NSString *format, ...) {
    __block va_list arg_list;
    va_start (arg_list, format);
    NSString *formattedString = [[NSString alloc] initWithFormat:format arguments:arg_list];
    va_end(arg_list);
    NSLog(@"[wanpeng]: %@", formattedString);
}

#ifdef KEHOU_LOG
#define KeHouDebug(...) KEHOULog(__VA_ARGS__)
#else
#define KeHouDebug(...)
#endif



#endif /* KHAnalyicsLog_h */
