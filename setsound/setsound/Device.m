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

@end