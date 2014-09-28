//
// Created by Mikkel Gravgaard on 27/09/14.
// Copyright (c) 2014 Betafunk. All rights reserved.
//

// To simulate mouse events, check this out:
// https://developer.apple.com/library/mac/documentation/Carbon/Reference/QuartzEventServicesRef/Reference/reference.html#//apple_ref/c/func/CGEventCreateMouseEvent

#import "Controller.h"
#import "Device.h"
#import "NSArray+Functional.h"
#import "ReactiveCocoa.h"
@import AVFoundation;


static NSString *const kAudioDeviceName = @"USB Audio CODEC";

static NSString *const kAbletonLiveBundleId = @"com.ableton.live";

NSArray *getDevices();

@interface Controller ()
@property(nonatomic, strong) NSArray * devices;
@end

@implementation Controller {

}

// generic error handler - if err is nonzero, prints error message and exits program.
static void CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) return;

	char str[20];
	// see if it appears to be a 4-char-code
	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
	if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
		str[0] = str[5] = '\'';
		str[6] = '\0';
	} else
		// no, format it as an integer
		sprintf(str, "%d", (int)error);

	fprintf(stderr, "Error: %s (%s)\n", operation, str);

	exit(1);
}

#pragma mark - audio converter -

char *getDeviceName(AudioDeviceID id, char *buf, UInt32 maxlen)
{
    AudioObjectPropertyScope theScope = kAudioDevicePropertyScopeOutput;

    AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyDeviceName,
                                              theScope,
                                              0 }; // channel

    CheckError(AudioObjectGetPropertyData(id, &theAddress, 0, NULL,  &maxlen, buf),"AudioObjectGetPropertyData failed");

	return buf;
}

int numChannels(AudioDeviceID deviceID, bool inputChannels){
    OSStatus err;
   	UInt32 propSize;
   	int result = 0;

       AudioObjectPropertyScope theScope = inputChannels ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput;

       AudioObjectPropertyAddress theAddress = { kAudioDevicePropertyStreamConfiguration,
                                                 theScope,
                                                 0 }; // channel

       err = AudioObjectGetPropertyDataSize(deviceID, &theAddress, 0, NULL, &propSize);
   	if (err) return 0;

   	AudioBufferList *buflist = (AudioBufferList *)malloc(propSize);
       err = AudioObjectGetPropertyData(deviceID, &theAddress, 0, NULL, &propSize, buflist);
   	if (!err) {
   		for (UInt32 i = 0; i < buflist->mNumberBuffers; ++i) {
   			result += buflist->mBuffers[i].mNumberChannels;
   		}
   	}
   	free(buflist);
   	return result;
}

static OSStatus
devicesChanged(AudioObjectID inObjectID,
        UInt32 inNumberAddresses,
        const AudioObjectPropertyAddress inAddresses[],
        void *inClientData)
{
    Controller *c = ((__bridge Controller*)inClientData);
    c.devices = getDevices();
    return 0;
}

+ (NSRunningApplication *)abletonLive{
    return [[[[NSWorkspace sharedWorkspace] runningApplications] filterUsingBlock:^BOOL(NSRunningApplication *app) {
        return [app.bundleIdentifier isEqualToString:kAbletonLiveBundleId];
    }] firstObject];
}

+ (BOOL)isLiveRunning
{
    return [self abletonLive] != nil;

}

- (instancetype)init {
    if (!(self = [super init])) return nil;

    NSLog(@"controller init");

    AudioObjectPropertyAddress propertyAddress = {
        .mSelector = kAudioHardwarePropertyDevices,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMaster
    };

    void *this = (__bridge void*)self;

    CheckError(AudioObjectAddPropertyListener(kAudioObjectSystemObject, &propertyAddress, devicesChanged, this),
            "AudioObjectAddPropertyListener failed");


    RACSignal *isLiveRunning = [[[RACSignal interval:2 onScheduler:[RACScheduler currentScheduler]] map:^id(id value) {
        return @([Controller isLiveRunning]);
    }] distinctUntilChanged];

    RACSignal *devices = [[RACObserve(self, devices) ignore:nil] distinctUntilChanged];
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


    [[self rac_signalForSelector:@selector(userNotificationCenter:didActivateNotification:)] subscribeNext:^(id x) {
        [[Controller abletonLive] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        sleep(1);
        [Controller cmd_comma];
//        // TODO - move and click mouse!
//        CGEventRef pEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, CGPointMake(500, 100), 0);
//        CGEventPost(kCGHIDEventTap, pEvent);
    }];

    return self;
}

+ (void)cmd_comma
{
      CGEventSourceRef src =
        CGEventSourceCreate(kCGEventSourceStateHIDSystemState);

      CGEventRef cmd_dn = CGEventCreateKeyboardEvent(src, kVK_Command, true);
      CGEventRef cmd_up = CGEventCreateKeyboardEvent(src, kVK_Command, false);
      CGEventRef comma_dn = CGEventCreateKeyboardEvent(src, kVK_ANSI_Comma, true);
      CGEventRef comma_up = CGEventCreateKeyboardEvent(src, kVK_ANSI_Comma, false);

      CGEventSetFlags(comma_dn, kCGEventFlagMaskCommand);
      CGEventSetFlags(comma_up, kCGEventFlagMaskCommand);

      CGEventTapLocation loc = kCGHIDEventTap; // kCGSessionEventTap also works
      CGEventPost(loc, cmd_dn);
      CGEventPost(loc, comma_dn);
      CGEventPost(loc, comma_up);
      CGEventPost(loc, cmd_up);

      CFRelease(cmd_dn);
      CFRelease(cmd_up);
      CFRelease(comma_dn);
      CFRelease(comma_up);
      CFRelease(src);
}

NSArray *getDevices() {
    UInt32 propsize;

    AudioObjectPropertyAddress theAddress = { kAudioHardwarePropertyDevices,
                                                 kAudioObjectPropertyScopeGlobal,
                                                 kAudioObjectPropertyElementMaster };

    CheckError(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &theAddress, 0, NULL, &propsize),"AudioObjectGetPropertyDataSize failed");
    int nDevices = propsize / sizeof(AudioDeviceID);
    AudioDeviceID *devids = malloc(sizeof(AudioDeviceID) * nDevices); // propsize
    CheckError(AudioObjectGetPropertyData(kAudioObjectSystemObject, &theAddress, 0, NULL, &propsize, devids),"AudioObjectGetPropertyData failed");


    NSMutableArray *devices = [NSMutableArray array];
    for (int i = 0; i < nDevices; ++i) {
        Device *device = [Device new];
        AudioDeviceID testId = devids[i];
        char name[64];
        getDeviceName(testId, name, 64);
        device.name = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
        device.inputs = (NSUInteger) numChannels(testId, true);
        device.outputs = (NSUInteger) numChannels(testId, false);
        [devices addObject:device];
    }

    free(devids);

    return devices;
}

#pragma mark -- Combobox


- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
    return self.devices.count;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
    return [self.devices[(NSUInteger) index] description];
}

#pragma mark --


- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    // For signaling
}



@end



