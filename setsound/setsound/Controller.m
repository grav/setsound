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

@import AVFoundation;


static NSString *const kAudioDeviceName = @"USB Audio CODEC";

static NSString *const kAbletonLiveBundleId = @"com.ableton.live";

NSArray *getDevices();


/* Returns key code for given character via the above function, or UINT16_MAX
 * on error. */
CGKeyCode keyCodeForChar(unichar c)
;

@interface Controller ()
@property(nonatomic, strong) NSArray * devices;
@end

@implementation Controller {

}

- (void)setDevices:(NSArray *)devices {
    _devices = [Controller aggregate:devices];
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

    RACSignal *selected = [[self rac_signalForSelector:@selector(comboBoxWillDismiss:)] map:^id(RACTuple *args) {
        NSComboBox *c = [[args first] object];
        NSInteger idx = c.indexOfSelectedItem;
        return idx == -1 ? nil : self.devices[(NSUInteger) idx];
    }];
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


    [[self rac_signalForSelector:@selector(userNotificationCenter:didActivateNotification:)] subscribeNext:^(id n) {
        [[Controller abletonLive] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
        sleep(1);
        NSRect r = [[NSScreen mainScreen] visibleFrame];
        CGFloat x = r.size.width / 2.0 + 100;
        CGFloat y_in = 175.0f;
        CGFloat y_out = 200.0f;

        // cmd+, to open prefs
        [Controller tellSystemEvents:@"keystroke \",\" using command down"];
        sleep(1);

        [@[@(y_in), @(y_out)] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {


            // Click the dropdown
            CGFloat y = [obj floatValue];
            [Controller click:CGPointMake(x, y)];
            sleep(1);

            // Type the name of the device
            // weird - 'b' seems to close popup
            NSString *string = [[kAudioDeviceName lowercaseString] stringByReplacingOccurrencesOfString:@"b" withString:@""];
            NSString *applescript = [NSString stringWithFormat:@"keystroke \"%@\"", string];
            [Controller tellSystemEvents:applescript];

            sleep(1);

            // Type 'enter'
            [Controller tellSystemEvents:@"keystroke return"];
            sleep(1);

        }];

        // esc
        [Controller tellSystemEvents:@"key code 53"];
    }];

    return self;
}

+ (NSArray *)aggregate:(NSArray *)array {
    NSMutableArray *aggregated = [array mutableCopy];
    [array enumerateObjectsUsingBlock:^(Device* obj1, NSUInteger idx1, BOOL *stop1) {
        [array enumerateObjectsUsingBlock:^(Device * obj2, NSUInteger idx2, BOOL *stop2) {
            if(obj1 != obj2 && [obj1.name isEqualToString:obj2.name]){
                Device *d = [Device new];
                d.name = obj1.name;
                d.inputs = obj1.inputs + obj2.inputs;
                d.outputs = obj1.outputs + obj2.outputs;
                [aggregated addObject:d];
                [aggregated removeObject:obj1];
                [aggregated removeObject:obj2];
                *stop1 = YES;
                *stop2 = YES;
            }
        }];
    }];
    return [NSSet setWithArray:aggregated].allObjects;
}

+ (void)tellSystemEvents:(NSString *)string {
    NSString *src = @"\
            tell application \"System Events\"\n\
                    %@\n\
            end tell\n\
    ";

    src = [NSString stringWithFormat:src,string];

    NSDictionary* errorDict;
    NSAppleScript* scriptObject = [[NSAppleScript alloc] initWithSource:src];
    NSAppleEventDescriptor* returnDescriptor = [scriptObject executeAndReturnError:&errorDict];
    NSLog(@"%@",returnDescriptor);
}

+ (void)click:(CGPoint) p
{
    CGEventRef mouseDown = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseDown, p, 0);
    CGEventRef mouseUp = CGEventCreateMouseEvent(NULL, kCGEventLeftMouseUp, p, 0);
    CGEventPost(kCGHIDEventTap, mouseDown);
    CGEventPost(kCGHIDEventTap, mouseUp);
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



