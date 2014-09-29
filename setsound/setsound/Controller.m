//
// Created by Mikkel Gravgaard on 27/09/14.
// Copyright (c) 2014 Betafunk. All rights reserved.
//

// To simulate mouse events, check this out:
// https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/Reference/reference.html#//apple_ref/c/func/CGEventCreateMouseEvent
#include <Carbon/Carbon.h>
#import "Controller.h"
#import "Device.h"
#import "ReactiveCocoa.h"
#import "Helper.h"

static NSString *const kAudioDeviceName = @"USB Audio CODEC";

static NSString *const kPreferredDevice = @"PreferredDevice";

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

    RACSignal *selected = [[[[[self rac_signalForSelector:@selector(comboBoxWillDismiss:)] map:^id(RACTuple *args) {
        NSComboBox *c = [[args first] object];
        NSInteger idx = c.indexOfSelectedItem;
        return @(idx);
    }] ignore:@(-1)] map:^id(NSNumber*idx) {
        NSUInteger index = idx.unsignedIntegerValue;
        return index == 0 ? nil : self.devices[index-1];
    }] startWith:[self preferredDevice]];

    [selected subscribeNext:^(Device *d) {
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:d];
        [[NSUserDefaults standardUserDefaults] setValue:data forKey:kPreferredDevice];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self updatePreferredLabel];
    }];

    [[RACObserve(self, preferredLabel) ignore:nil] subscribeNext:^(id x) {
        [self updatePreferredLabel];
    }];

    RACSignal *devices = [[RACObserve(self, devices) ignore:nil] distinctUntilChanged];

    [devices subscribeNext:^(id x) {
        [self.comboBox reloadData];
    }];

    RACSignal *audioDeviceConnected = [[RACSignal combineLatest:@[selected,devices] reduce:^id(Device *d, NSArray *devs) {
        BOOL b = [devs containsObject:d];
        return @(b);
    }] logNext];


    RACSignal *connectedAndRunning = [[RACSignal combineLatest:@[isLiveRunning, audioDeviceConnected]
                                                        reduce:^id(NSNumber *running, NSNumber *connected) {

                                                            return @(running.boolValue && connected.boolValue);
                                                        }] distinctUntilChanged];

    self.devices = [Helper getCurrentDevices];

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

- (Device*)preferredDevice
{
    NSData *data = [[NSUserDefaults standardUserDefaults] valueForKey:kPreferredDevice];
    Device *d = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    return d;
}

- (void)updatePreferredLabel {
    Device *d = [self preferredDevice];
    [self.preferredLabel setStringValue:d.name ?: @"(none)"];
}


#pragma mark - Combobox


- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
    return self.devices.count + 1;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
    return index == 0 ? @"(none)" : [self.devices[(NSUInteger) index-1] description];
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



