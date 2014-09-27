//
// Created by Mikkel Gravgaard on 27/09/14.
// Copyright (c) 2014 Betafunk. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Device : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic) NSUInteger inputs, outputs;
@end