//
//  YYWebImageManager.m
//  YYWebImage <https://github.com/ibireme/YYWebImage>
//
//  Created by ibireme on 15/2/19.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYWebImageManager.h"
#import "YYImageCache.h"
#import "YYWebImageOperation.h"
#import "YYImageCoder.h"
#import <objc/runtime.h>
#import "_YYWebImageWeakProxy.h"

#define Lock() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define Unlock() dispatch_semaphore_signal(self->_lock)

#define kNetworkIndicatorDelay (1/30.0)

/// Returns nil in App Extension.
static UIApplication *_YYSharedApplication() {
    static BOOL isAppExtension = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class cls = NSClassFromString(@"UIApplication");
        if(!cls || ![cls respondsToSelector:@selector(sharedApplication)]) isAppExtension = YES;
        if ([[[NSBundle mainBundle] bundlePath] hasSuffix:@".appex"]) isAppExtension = YES;
    });
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    return isAppExtension ? nil : [UIApplication performSelector:@selector(sharedApplication)];
#pragma clang diagnostic pop
}

@interface _YYWebImageApplicationNetworkIndicatorInfo : NSObject
@property (nonatomic, assign) NSInteger count;
@property (nonatomic, strong) NSTimer *timer;
@end
@implementation _YYWebImageApplicationNetworkIndicatorInfo
@end

@interface YYWebImageManager () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) dispatch_semaphore_t lock;
@property (nonatomic, strong) NSHashTable<YYWebImageOperation *> *operations;

@end

@implementation YYWebImageManager

+ (instancetype)sharedManager {
    static YYWebImageManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        YYImageCache *cache = [YYImageCache sharedCache];
        NSOperationQueue *queue = [NSOperationQueue new];
        queue.name = @"com.YYWebImageManager.ibireme";
        queue.maxConcurrentOperationCount = 5;
        if ([queue respondsToSelector:@selector(setQualityOfService:)]) {
            queue.qualityOfService = NSQualityOfServiceBackground;
        }
        manager = [[self alloc] initWithCache:cache queue:queue];
    });
    return manager;
}

- (void)dealloc {
    [_session invalidateAndCancel];
    _session = nil;
    [_queue cancelAllOperations];
}

- (instancetype)initWithCache:(YYImageCache *)cache queue:(NSOperationQueue *)queue {
    self = [super init];
    if (self) {
        _cache = cache;
        _queue = queue;
        _timeout = 15.f;
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        id delegate = [_YYWebImageWeakProxy proxyWithTarget:self];
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:delegate delegateQueue:nil];
        _lock = dispatch_semaphore_create(1);
        _operations = [NSHashTable weakObjectsHashTable];
        
        if (YYImageWebPAvailable()) {
            _headers = @{@"Accept" : @"image/webp,image/*;q=0.8"};
        } else {
            _headers = @{@"Accept" : @"image/*;q=0.8"};
        }
    }
    return self;
}

- (YYWebImageOperation *)requestImageWithURL:(NSURL *)url
                                     options:(YYWebImageOptions)options
                                    progress:(YYWebImageProgressBlock)progress
                                   transform:(YYWebImageTransformBlock)transform
                                  completion:(YYWebImageCompletionBlock)completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = _timeout;
    request.HTTPShouldHandleCookies = (options & YYWebImageOptionHandleCookies) != 0;
    request.allHTTPHeaderFields = [self headersForURL:url];
    request.HTTPShouldUsePipelining = YES;
    request.cachePolicy = (options & YYWebImageOptionUseNSURLCache) ?
    NSURLRequestUseProtocolCachePolicy : NSURLRequestReloadIgnoringLocalCacheData;
    
    YYWebImageOperation *operation = [[YYWebImageOperation alloc] initWithSession:_session
                                                                          request:request
                                                                          options:options
                                                                            cache:_cache
                                                                         cacheKey:[self cacheKeyForURL:url]
                                                                         progress:progress
                                                                        transform:transform ? transform : _sharedTransformBlock
                                                                       completion:completion];
    if (!operation) { return nil; }
    
    dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER);
    [_operations addObject:operation];
    dispatch_semaphore_signal(self->_lock);
    
    if (_username && _password) {
        operation.credential = [NSURLCredential credentialWithUser:_username password:_password persistence:NSURLCredentialPersistenceForSession];
    }
    
    NSOperationQueue *queue = _queue;
    if (queue) {
        [queue addOperation:operation];
    } else {
        [operation start];
    }
    return operation;
}

- (NSDictionary *)headersForURL:(NSURL *)url {
    if (!url) return nil;
    return _headersFilter ? _headersFilter(url, _headers) : _headers;
}

- (NSString *)cacheKeyForURL:(NSURL *)url {
    if (!url) return nil;
    return _cacheKeyFilter ? _cacheKeyFilter(url) : url.absoluteString;
}

#pragma mark - Tool Methods
- (YYWebImageOperation *)_operationWithTask:(NSURLSessionTask *)task {
    dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER);
    NSArray *operations = [self.operations.allObjects copy];
    dispatch_semaphore_signal(self->_lock);
    
    for (YYWebImageOperation *operation in operations) {
        if (operation.task.taskIdentifier == task.taskIdentifier) {
            return operation;
        }
    }
    return nil;
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
    YYWebImageOperation *operation = [self _operationWithTask:task];
    if ([operation respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)]) {
        [operation URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
    } else {
        !completionHandler ?: completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    YYWebImageOperation *operation = [self _operationWithTask:task];
    if ([operation respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [operation URLSession:session task:task didCompleteWithError:error];
    }
}

#pragma mark - NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    YYWebImageOperation *operation = [self _operationWithTask:dataTask];
    if ([operation respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [operation URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
    } else {
        !completionHandler ?: completionHandler(NSURLSessionResponseAllow);
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    YYWebImageOperation *operation = [self _operationWithTask:dataTask];
    if ([operation respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [operation URLSession:session dataTask:dataTask didReceiveData:data];
    }
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse * _Nullable cachedResponse))completionHandler {
    YYWebImageOperation *operation = [self _operationWithTask:dataTask];
    if ([operation respondsToSelector:@selector(URLSession:dataTask:willCacheResponse:completionHandler:)]) {
        [operation URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
    } else {
        !completionHandler ?: completionHandler(proposedResponse);
    }
}

#pragma mark - Network Indicator

+ (_YYWebImageApplicationNetworkIndicatorInfo *)_networkIndicatorInfo {
    return objc_getAssociatedObject(self, @selector(_networkIndicatorInfo));
}

+ (void)_setNetworkIndicatorInfo:(_YYWebImageApplicationNetworkIndicatorInfo *)info {
    objc_setAssociatedObject(self, @selector(_networkIndicatorInfo), info, OBJC_ASSOCIATION_RETAIN);
}

+ (void)_delaySetActivity:(NSTimer *)timer {
    UIApplication *app = _YYSharedApplication();
    if (!app) return;
    
    NSNumber *visiable = timer.userInfo;
    if (app.networkActivityIndicatorVisible != visiable.boolValue) {
        [app setNetworkActivityIndicatorVisible:visiable.boolValue];
    }
    [timer invalidate];
}

+ (void)_changeNetworkActivityCount:(NSInteger)delta {
    if (!_YYSharedApplication()) return;
    
    void (^block)(void) = ^{
        _YYWebImageApplicationNetworkIndicatorInfo *info = [self _networkIndicatorInfo];
        if (!info) {
            info = [_YYWebImageApplicationNetworkIndicatorInfo new];
            [self _setNetworkIndicatorInfo:info];
        }
        NSInteger count = info.count;
        count += delta;
        info.count = count;
        [info.timer invalidate];
        info.timer = [NSTimer timerWithTimeInterval:kNetworkIndicatorDelay target:self selector:@selector(_delaySetActivity:) userInfo:@(info.count > 0) repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:info.timer forMode:NSRunLoopCommonModes];
    };
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

+ (void)incrementNetworkActivityCount {
    [self _changeNetworkActivityCount:1];
}

+ (void)decrementNetworkActivityCount {
    [self _changeNetworkActivityCount:-1];
}

+ (NSInteger)currentNetworkActivityCount {
    _YYWebImageApplicationNetworkIndicatorInfo *info = [self _networkIndicatorInfo];
    return info.count;
}

@end
