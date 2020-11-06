//
//  NSObject+KHSwizzler.m
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/16.
//

#import "NSObject+KHSwizzler.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation NSObject (KHSwizzler)

+ (BOOL)analyics_swizzleMethod:(SEL)originalSEL withMethod:(SEL)swizzleSEL {
    
    // 获取原始方法
    
    Method originalMethod = class_getInstanceMethod(self, originalSEL);
    if (!originalMethod) {
        return NO;
    }
    
    // 获取要交换的方法
    Method swizzleMethod = class_getInstanceMethod(self, swizzleSEL);
    if (!swizzleMethod) {
        return NO;
    }
    
    // 获取originalSEL方法的实现
    IMP originalIMP = method_getImplementation(originalMethod);
    const char * originalMethodType = method_getTypeEncoding(originalMethod);
    if (class_addMethod(self, originalSEL, originalIMP, originalMethodType)) {
        originalMethod = class_getInstanceMethod(self, originalSEL);
    }
    
    // 获取alternateIMP方法的实现
    IMP swizzleIMP = method_getImplementation(swizzleMethod);
    const char * alternateMethodType = method_getTypeEncoding(swizzleMethod);
    if (class_addMethod(self, swizzleSEL, swizzleIMP, alternateMethodType)) {
        swizzleMethod = class_getInstanceMethod(self, swizzleSEL);
    }
    method_exchangeImplementations(originalMethod, swizzleMethod);
    return YES;
}

#ifdef DEBUG
+ (NSArray<NSString *> *)getIvars {
    
    unsigned int outCount;
    Ivar *ivars =  class_copyIvarList([self class], &outCount);
    NSMutableArray *ivarsM = [NSMutableArray array];
    for (unsigned int i = 0; i < outCount; ++i) {
        Ivar ivar = ivars[i];
        const char * chars = ivar_getName(ivar);
        NSString *name = [NSString stringWithUTF8String:chars];
        [ivarsM addObject:name];
    }
    return ivarsM.copy;
}
#endif

@end


#pragma mark - UIImage

@implementation UIImage (KHSwizzler)

- (void)setImageName:(NSString *)imageName {
    objc_setAssociatedObject(self, @selector(imageName), imageName, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)imageName {
    return objc_getAssociatedObject(self, _cmd);
}

+ (void)load {
    [UIImage analyics_swizzleMethod:@selector(imageNamed:) withMethod:@selector(analyics_imageNamed:)];
}

+ (UIImage *)analyics_imageNamed:(NSString *)imageName {
    UIImage *image = [UIImage analyics_imageNamed:imageName];
    image.imageName = imageName;
    return image;
}

@end
