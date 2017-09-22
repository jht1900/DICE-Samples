/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
Application delegate for the Game of Life sample. Responds to application lifecycle messages.
*/

#import "AAPLAppDelegate.h"

@implementation AAPLAppDelegate

#if TARGET_OS_OSX

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#endif

@end
