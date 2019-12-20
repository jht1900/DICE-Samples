/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
The view controller class for the Game of Life sample. Manages an MTKView for displaying graphics rendered by Metal
    and mediates touch and mouse interactions.
*/

@import Foundation;

#if TARGET_OS_IPHONE
@import UIKit;
@interface AAPLViewController : UIViewController
#else
@import Cocoa;
@interface AAPLViewController : NSViewController
#endif
@end
