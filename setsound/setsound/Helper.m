//
//  Helper.m
//  setsound
//
//  Created by Mikkel Gravgaard on 29/09/14.
//  Copyright (c) 2014 Betafunk. All rights reserved.
//

#import "NSArray+Functional.h"
#import "Device.h"
#import "Controller.h"
#import "Helper.h"
@import AVFoundation;

#pragma mark - Core Audio

static NSString *const kAbletonLiveBundleId = @"com.ableton.live";

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

@implementation Helper

+ (void)setupDeviceChangeListening:(Controller *)c
{
    AudioObjectPropertyAddress propertyAddress = {
        .mSelector = kAudioHardwarePropertyDevices,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMaster
    };

    void *controller = (__bridge void*)c;

    CheckError(AudioObjectAddPropertyListener(kAudioObjectSystemObject, &propertyAddress, devicesChanged, controller),
            "AudioObjectAddPropertyListener failed");

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

+ (NSArray*)getCurrentDevices
{
    return getDevices();
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

#pragma mark - Interface automation

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

+ (NSRunningApplication *)abletonLive{
    return [[[[NSWorkspace sharedWorkspace] runningApplications] filterUsingBlock:^BOOL(NSRunningApplication *app) {
        return [app.bundleIdentifier isEqualToString:kAbletonLiveBundleId];
    }] firstObject];
}

+ (BOOL)isLiveRunning
{
    return [self abletonLive] != nil;

}



@end
