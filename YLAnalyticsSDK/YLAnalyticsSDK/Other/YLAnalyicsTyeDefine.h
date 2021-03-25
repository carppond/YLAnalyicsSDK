//
//  YLAnalyicsTyeDefine.h
//  YLAnalyticsSDK
//
//  Created by lcf on 2021/3/25.
//

#ifndef YLAnalyicsTyeDefine_h
#define YLAnalyicsTyeDefine_h
#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, YLFuencyType) {
    YLFuencyType_Normal   = 1 << 1,
    YLFuencyType_MainThreadBlock   = 1 << 2,// 程序处于前台阻塞
    YLFuencyType_BackgroundMainThreadBlock   = 1 << 3,// 程序处于后台台阻塞
    YLFuencyType_BlockThreadTooMuch   = 1 << 4,// 线程太多(主线程+子线程)，超过64个线程
};


#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block)\
if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {\
    block();\
} else {\
    dispatch_async(dispatch_get_main_queue(), block);\
}
#endif

#endif /* YLAnalyicsTyeDefine_h */
