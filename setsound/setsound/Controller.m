//
// Created by Mikkel Gravgaard on 27/09/14.
// Copyright (c) 2014 Betafunk. All rights reserved.
//

// To simulate mouse events, check this out:
// https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/Reference/reference.html#//apple_ref/c/func/CGEventCreateMouseEvent
#include <Carbon/Carbon.h>
#import "Controller.h"
#import "Device.h"
#import "NSArray+Functional.h"
#import "ReactiveCocoa.h"
#import "Helper.h"

static NSString *const kAudioDeviceName = @"USB Audio CODEC";

NSArray *getDevices();

@implementation Controller {

}

- (void)setDevices:(NSArray *)devices {
    _devices = [Helper aggregate:devices];
}


#pragma mark - audio converter -


- (instancetype)init {
    if (!(self = [super init])) return nil;

    [Helper setupDeviceChangeListening:self];

    RACSignal *isLiveRunning = [[[RACSignal interval:2 onScheduler:[RACScheduler currentScheduler]] map:^id(id value) {
        return @([Helper isLiveRunning]);
    }] distinctUntilChanged];

    RACSignal *selected = [[self rac_signalForSelector:@selector(comboBoxWillDismiss:)] map:^id(RACTuple *args) {
        NSComboBox *c = [[args first] object];
        NSInteger idx = c.indexOfSelectedItem;
        return idx == -1 ? nil : self.devices[(NSUInteger) idx];
    }];

    RACSignal *devices = [[RACObserve(self, devices) ignore:nil] distinctUntilChanged];

//    [RACSignal combineLatest:@[selected,devices] reduce:^id(Device *d, NSArray *devs) {
//        return nil;
//    }]

    RACSignal *audioDeviceConnected = [devices map:^id(NSArray *devs) {
        return @([devs filterUsingBlock:^BOOL(Device *d) {
            return [d.name rangeOfString:kAudioDeviceName].location != NSNotFound;
        }].count > 0);
    }];

    RACSignal *connectedAndRunning = [[RACSignal combineLatest:@[isLiveRunning, audioDeviceConnected]
                                                        reduce:^id(NSNumber *running, NSNumber *connected) {
                                                            return @(running.boolValue && connected.boolValue);
                                                        }] distinctUntilChanged];

    self.devices = getDevices();

    [[connectedAndRunning ignore:@NO] subscribeNext:^(id x) {
        NSLog(@"%@", x);
        NSUserNotification *notification = [NSUserNotification new];
        notification.hasActionButton = YES;
        notification.actionButtonTitle = @"Select";
        notification.title = @"Audio device connected";
        notification.informativeText = [NSString stringWithFormat:@"%@ has been connected. Select in Live?",kAudioDeviceName];
        [NSUserNotificationCenter defaultUserNotificationCenter].delegate = self;
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];

    }];


    [[self rac_signalForSelector:@selector(userNotificationCenter:didActivateNotification:)] subscribeNext:^(id n) {
        [[Helper abletonLive] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        sleep(1);
        NSRect r = [[NSScreen mainScreen] visibleFrame];
        CGFloat x = r.size.width / 2.0 + 100;
        CGFloat y_in = 175.0f;
        CGFloat y_out = 200.0f;

        // cmd+, to open prefs
        [Helper tellSystemEvents:@"keystroke \",\" using command down"];
        sleep(1);

        [@[@(y_in), @(y_out)] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {


            // Click the dropdown
            CGFloat y = [obj floatValue];
            [Helper click:CGPointMake(x, y)];
            sleep(1);

            // Type the name of the device
            // weird - 'b' seems to close popup
            NSString *string = [[kAudioDeviceName lowercaseString] stringByReplacingOccurrencesOfString:@"b" withString:@""];
            NSString *applescript = [NSString stringWithFormat:@"keystroke \"%@\"", string];
            [Helper tellSystemEvents:applescript];

            sleep(1);

            // Type 'enter'
            [Helper tellSystemEvents:@"keystroke return"];
            sleep(1);

        }];

        // esc
        [Helper tellSystemEvents:@"key code 53"];
    }];

    return self;
}

#pragma mark - Combobox


- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
    return self.devices.count;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
    return [self.devices[(NSUInteger) index] description];
}

- (void)comboBoxWillDismiss:(NSNotification *)notification {
    // For signaling
}

#pragma mark -


- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    // For signaling
}



@end



