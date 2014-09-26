//
//  CoconutKit_demoAppDelegate.m
//  CoconutKit-demo
//
//  Created by Samuel Défago on 2/10/11.
//  Copyright 2011 Samuel Défago. All rights reserved.
//

#import "CoconutKit_demoAppDelegate.h"

#import "CoconutKit_demoApplication.h"

// Disable quasi-simultaneous taps
HLSEnableUIControlExclusiveTouch();

// Enable Core Data easy validation
HLSEnableNSManagedObjectValidation();

@interface CoconutKit_demoAppDelegate ()

@property (nonatomic, strong) CoconutKit_demoApplication *application;

@end

@implementation CoconutKit_demoAppDelegate

#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // We do not assign to the optional property, to ensure that CoconutKit does not rely on this property
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];
    [self.window makeKeyAndVisible];
    
    // Use optional preloading provided by CoconutKit
    [application preload];
    
    // Instead of using the UIAppFonts key in the plist to load the Beon font, do it in code
    [UIFont loadFontWithFileName:@"Beon-Regular.otf" inBundle:nil];
    
    self.application = [[CoconutKit_demoApplication alloc] init];
    self.window.rootViewController = [self.application rootViewController];
    
    return YES;
}

@end
