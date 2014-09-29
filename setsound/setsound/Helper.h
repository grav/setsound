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

+ (NSRunningApplication *)abletonLive;

+ (BOOL)isLiveRunning;

+ (NSArray *)aggregate:(NSArray *)array;

+ (void)tellSystemEvents:(NSString *)string;

+ (void)click:(CGPoint)p;
@end
