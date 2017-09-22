/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 main
 */

#ifdef TARGET_IOS
#import <UIKit/UIKit.h>
#else // OS X
#import <Cocoa/Cocoa.h>
#endif

#import "AAPLAppDelegate.h"

int main(int argc, char * argv[]) {
	
#ifdef TARGET_IOS
	@autoreleasepool {
		return UIApplicationMain(argc, argv, nil, NSStringFromClass([AAPLAppDelegate class]));
	}
#else
	return NSApplicationMain(argc, (const char**)argv);
#endif
}
