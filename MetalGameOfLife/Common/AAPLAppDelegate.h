/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
Application delegate for the Game of Life sample. Responds to application lifecycle messages.
*/

#include <TargetConditionals.h>

#if TARGET_OS_IOS || TARGET_OS_TV

@import UIKit;

@interface AAPLAppDelegate : UIResponder <UIApplicationDelegate>

@property (nullable, nonatomic, strong) UIWindow *window;

@end

#elif TARGET_OS_MAC

@import Cocoa;

@interface AAPLAppDelegate : NSObject <NSApplicationDelegate>

@end

#endif
