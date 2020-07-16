//
//  _YYWebImageWeakProxy.h
//  YYWebImageDemo
//
//  Created by liang on 2020/7/15.
//  Copyright © 2020 ibireme. All rights reserved.
//
//  A proxy used to hold a weak object.
//  

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface _YYWebImageWeakProxy : NSProxy

@property (nonatomic, weak, readonly) id target;

+ (instancetype)proxyWithTarget:(id)target;
- (instancetype)initWithTarget:(id)target;

@end

NS_ASSUME_NONNULL_END
