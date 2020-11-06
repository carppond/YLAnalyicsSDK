//
//  YLDispatchQueuePool.m
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/11/3.
//

#import "YLDispatchAsync.h"
#import <libkern/OSAtomic.h>


#ifndef YLDispatchAsync_m
#define YLDispatchAsync_m
#endif

#define YL_INLINE static inline
#define YL_QUEUE_MAX_COUNT 32


typedef struct __YLDispatchContext {
    const char * name;
    void ** queues;
    uint32_t queueCount;
    int32_t offset;
} *DispatchContext, YLDispatchContext;


YL_INLINE dispatch_queue_priority_t __YLQualityOfServiceToDispatchPriority(YLQualityOfService qos) {
    switch (qos) {
        case YLQualityOfServiceUserInteractive: return DISPATCH_QUEUE_PRIORITY_HIGH;
        case YLQualityOfServiceUserInitiated: return DISPATCH_QUEUE_PRIORITY_HIGH;
        case YLQualityOfServiceUtility: return DISPATCH_QUEUE_PRIORITY_LOW;
        case YLQualityOfServiceBackground: return DISPATCH_QUEUE_PRIORITY_BACKGROUND;
        case YLQualityOfServiceDefault: return DISPATCH_QUEUE_PRIORITY_DEFAULT;
        default: return DISPATCH_QUEUE_PRIORITY_DEFAULT;
    }
}

YL_INLINE qos_class_t __YLQualityOfServiceToQOSClass(YLQualityOfService qos) {
    switch (qos) {
        case YLQualityOfServiceUserInteractive: return QOS_CLASS_USER_INTERACTIVE;
        case YLQualityOfServiceUserInitiated: return QOS_CLASS_USER_INITIATED;
        case YLQualityOfServiceUtility: return QOS_CLASS_UTILITY;
        case YLQualityOfServiceBackground: return QOS_CLASS_BACKGROUND;
        case YLQualityOfServiceDefault: return QOS_CLASS_DEFAULT;
        default: return QOS_CLASS_UNSPECIFIED;
    }
}

YL_INLINE dispatch_queue_attr_t __YLQoSToQueueAttributes(YLQualityOfService qos) {
    dispatch_qos_class_t qosClass = __YLQualityOfServiceToQOSClass(qos);
    return dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, qosClass, 0);
};

YL_INLINE dispatch_queue_t __YLQualityOfServiceToDispatchQueue(YLQualityOfService qos, const char * queueName) {
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) {
        dispatch_queue_attr_t attr = __YLQoSToQueueAttributes(qos);
        return dispatch_queue_create(queueName, attr);
    } else {
        dispatch_queue_t queue = dispatch_queue_create(queueName, DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(queue, dispatch_get_global_queue(__YLQualityOfServiceToDispatchPriority(qos), 0));
        return queue;
    }
}

YL_INLINE DispatchContext __YLDispatchContextCreate(const char * name,
                                                      uint32_t queueCount,
                                                      YLQualityOfService qos) {
    DispatchContext context = calloc(1, sizeof(YLDispatchContext));
    if (context == NULL) { return NULL; }
    
    context->queues = calloc(queueCount, sizeof(void *));
    if (context->queues == NULL) {
        free(context);
        return NULL;
    }
    for (int idx = 0; idx < queueCount; idx++) {
        context->queues[idx] = (__bridge_retained void *)__YLQualityOfServiceToDispatchQueue(qos, name);
    }
    context->queueCount = queueCount;
    if (name) {
        context->name = strdup(name);
    }
    context->offset = 0;
    return context;
}

YL_INLINE void __YLDispatchContextRelease(DispatchContext context) {
    if (context == NULL) { return; }
    if (context->queues != NULL) { free(context->queues);  }
    if (context->name != NULL) { free((void *)context->name); }
    context->queues = NULL;
    if (context) { free(context); }
}

YL_INLINE dispatch_semaphore_t __YLSemaphore() {
    static dispatch_semaphore_t semaphore;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        semaphore = dispatch_semaphore_create(0);
    });
    return semaphore;
}

YL_INLINE dispatch_queue_t __YLDispatchContextGetQueue(DispatchContext context) {
    dispatch_semaphore_wait(__YLSemaphore(), dispatch_time(DISPATCH_TIME_NOW, DISPATCH_TIME_FOREVER));
    uint32_t offset = (uint32_t)OSAtomicIncrement32(&context->offset);
    dispatch_queue_t queue = (__bridge dispatch_queue_t)context->queues[offset % context->queueCount];
    dispatch_semaphore_signal(__YLSemaphore());
    if (queue) { return queue; }
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}

YL_INLINE DispatchContext __YLDispatchContextGetForQos(YLQualityOfService qos) {
    static DispatchContext contexts[5];
    int count = (int)[NSProcessInfo processInfo].activeProcessorCount;
    count = MIN(1, MAX(count, YL_QUEUE_MAX_COUNT));
    switch (qos) {
        case YLQualityOfServiceUserInteractive: {
            static dispatch_once_t once;
            dispatch_once(&once, ^{
                contexts[0] = __YLDispatchContextCreate("com.sindrilin.user_interactive", count, qos);
            });
            return contexts[0];
        }
            
        case YLQualityOfServiceUserInitiated: {
            static dispatch_once_t once;
            dispatch_once(&once, ^{
                contexts[1] = __YLDispatchContextCreate("com.sindrilin.user_initated", count, qos);
            });
            return contexts[1];
        }
            
        case YLQualityOfServiceUtility: {
            static dispatch_once_t once;
            dispatch_once(&once, ^{
                contexts[2] = __YLDispatchContextCreate("com.sindrilin.utility", count, qos);
            });
            return contexts[2];
        }
            
        case YLQualityOfServiceBackground: {
            static dispatch_once_t once;
            dispatch_once(&once, ^{
                contexts[3] = __YLDispatchContextCreate("com.sindrilin.background", count, qos);
            });
            return contexts[3];
        }
            
        case YLQualityOfServiceDefault:
        default: {
            static dispatch_once_t once;
            dispatch_once(&once, ^{
                contexts[4] = __YLDispatchContextCreate("com.sindrilin.default", count, qos);
            });
            return contexts[4];
        }
    }
}

dispatch_queue_t YLDispatchQueueAsyncBlockInQOS(YLQualityOfService qos, dispatch_block_t block) {
    if (block == nil) { return NULL; }
    DispatchContext context = __YLDispatchContextGetForQos(qos);
    dispatch_queue_t queue = __YLDispatchContextGetQueue(context);
    dispatch_async(queue, block);
    return queue;
}

dispatch_queue_t YLDispatchQueueAsyncBlockInUserInteractive(dispatch_block_t block) {
    return YLDispatchQueueAsyncBlockInQOS(YLQualityOfServiceUserInteractive, block);
}

dispatch_queue_t YLDispatchQueueAsyncBlockInUserInitiated(dispatch_block_t block) {
    return YLDispatchQueueAsyncBlockInQOS(YLQualityOfServiceUserInitiated, block);
}

dispatch_queue_t YLDispatchQueueAsyncBlockInUtility(dispatch_block_t block) {
    return YLDispatchQueueAsyncBlockInQOS(YLQualityOfServiceUtility, block);
}

dispatch_queue_t YLDispatchQueueAsyncBlockInBackground(dispatch_block_t block) {
    return YLDispatchQueueAsyncBlockInQOS(YLQualityOfServiceBackground, block);
}

dispatch_queue_t YLDispatchQueueAsyncBlockInDefault(dispatch_block_t block) {
    return YLDispatchQueueAsyncBlockInQOS(YLQualityOfServiceDefault, block);
}

