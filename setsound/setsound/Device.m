//
// Created by Mikkel Gravgaard on 27/09/14.
// Copyright (c) 2014 Betafunk. All rights reserved.
//

#import "Device.h"


@implementation Device {

}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@ inputs: %ld, outputs: %ld",self.name,self.inputs,self.outputs];
}

- (BOOL)isEqual:(id)object {

    if(![object isKindOfClass:[Device class]]) return NO;
    Device *other = object;
    return [self.name isEqualToString:other.name] && self.inputs == other.inputs && self.outputs == other.outputs;

}

- (NSUInteger)hash {
    return [self.name hash] + 13 * self.inputs + 7 * self.outputs;
}


@end