//
// Created by Mikkel Gravgaard on 27/09/14.
// Copyright (c) 2014 Betafunk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface Controller : NSObject<NSComboBoxDataSource, NSComboBoxDelegate, NSUserNotificationCenterDelegate>
@property (nonatomic, weak) IBOutlet NSComboBox *comboBox;
@property (nonatomic, weak) IBOutlet NSTextField *preferredLabel;
@property(nonatomic, strong) NSArray * devices;
@property (weak) IBOutlet NSButton *selectButton;

@end