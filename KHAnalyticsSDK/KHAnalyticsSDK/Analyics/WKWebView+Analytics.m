//
//  WKWebView+Analytics.m
//  KHAnalyticsSDK
//
//  Created by lcf on 2020/10/23.
//

#import "WKWebView+Analytics.h"
#import "NSObject+KHSwizzler.h"
#import "KHSensorsAnalyicsSDK.h"
#import "Aspects.h"

static CFAbsoluteTime _start;
static CFAbsoluteTime _end;

@implementation WKWebView (Analytics)

+ (void)load {
    
    [WKWebView analyics_swizzleMethod:@selector(setNavigationDelegate:) withMethod:@selector(analyics_setNavigationDelegate:)];
}

- (void)analyics_setNavigationDelegate:(id<WKNavigationDelegate>)delegate {
    [self analyics_setNavigationDelegate:delegate];
    
    NSObject *obg = (NSObject *)delegate;
    if(![obg isKindOfClass:[NSObject class]]){
        return;
    }
    SEL sel = @selector(webView:didFinishNavigation:);
    [obg aspect_hookSelector:sel withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspectInfo){
        NSArray *arr = aspectInfo.arguments;
        if(arr.count>1){
            [self analyics_webView:arr[0] didFinishNavigation:arr[1]];
        }
    } error:nil];
    
    SEL didStarSel = @selector(webView:didStartProvisionalNavigation:);
    [obg aspect_hookSelector:didStarSel withOptions:AspectPositionAfter usingBlock:^(id<AspectInfo> aspectInfo){
        NSArray *arr = aspectInfo.arguments;
        if(arr.count>1){
            [self analyics_webView:arr[0] didStartProvisionalNavigation:arr[1]];
        }
    } error:nil];
    
}


// 链接开始加载时调用
- (void)analyics_webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    _start = CFAbsoluteTimeGetCurrent();
}

// 加载完成
- (void)analyics_webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    _end = CFAbsoluteTimeGetCurrent();
    [self trackWebView:webView loadingTime:[NSString stringWithFormat:@"%0.2f",_end - _start]];
}

- (void)trackWebView:(WKWebView *)webview loadingTime:(NSString *)loadingTime{
    KHSensorsAnalyicsSDK * analyics = [KHSensorsAnalyicsSDK sharedInstance];
    
    [analyics trackAppWithWKWebView:webview loadingTime:loadingTime properties:nil];

}


@end
