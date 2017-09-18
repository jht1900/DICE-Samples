/*
     File: APLCustomVideoCompositor.h
 Abstract:  Custom video compositor class implementing the AVVideoCompositing protocol. 
Version: 1.1 2013 
 */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface APLCustomVideoCompositor : NSObject <AVVideoCompositing>

@end

@interface APLCrossDissolveCompositor : APLCustomVideoCompositor

@end

@interface APLDiagonalWipeCompositor : APLCustomVideoCompositor

@end
