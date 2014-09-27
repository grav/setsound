//
// Created by Mikkel Gravgaard on 27/09/14.
// Copyright (c) 2014 Betafunk. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface Controller : NSObject<NSComboBoxDataSource>
@property (nonatomic, weak) IBOutlet NSComboBox *comboBox;
@end