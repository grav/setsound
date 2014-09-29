//
//  Helper.h
//  setsound
//
//  Created by Mikkel Gravgaard on 29/09/14.
//  Copyright (c) 2014 Betafunk. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Helper : NSObject

+ (void)setupDeviceChangeListening:(Controller *)c;

+ (NSArray *)aggregate:(NSArray *)array;

+ (NSArray *)getCurrentDevices;

+ (void)tellSystemEvents:(NSString *)string;

+ (void)click:(CGPoint)p;

+ (NSRunningApplication *)abletonLive;

+ (BOOL)isLiveRunning;

@end
