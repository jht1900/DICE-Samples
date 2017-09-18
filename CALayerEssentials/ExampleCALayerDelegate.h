//
// File:       ExampleCALayerDelegate.h
//
// Abstract:   A sample delegate for a CALayer that draws random content into the layer.
//
// Version:    1.0 2008

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface ExampleCALayerDelegate : NSObject
{
}

-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx;

@end
