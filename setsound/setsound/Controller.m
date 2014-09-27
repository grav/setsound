//
// Created by Mikkel Gravgaard on 27/09/14.
// Copyright (c) 2014 Betafunk. All rights reserved.
//

#import "Controller.h"
#import "Device.h"

@import AVFoundation;


NSArray *getDevices();

@interface Controller ()
@property(nonatomic, strong) NSArray * devices;
@end

@implementation Controller {

}

- (void)setDevices:(NSArray *)devices {
    _devices = devices;
    NSLog(@"device list updated");
    [self.comboBox reloadData];
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

    return self;
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

- (NSString *)comboBox:(NSComboBox *)aComboBox completedString:(NSString *)string {
    return nil;
}

- (NSUInteger)comboBox:(NSComboBox *)aComboBox indexOfItemWithStringValue:(NSString *)string {
    return 0;
}

@end



