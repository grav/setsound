//
//  AppDelegate.m
//  setsound
//
//  Created by Mikkel Gravgaard on 27/09/14.
//  Copyright (c) 2014 Betafunk. All rights reserved.
//


#import "AppDelegate.h"
#import "Controller.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property(nonatomic, strong) Controller *controller;
@end

@implementation AppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.controller = [Controller new];
    // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end