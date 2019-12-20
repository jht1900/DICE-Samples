//
// File:       ExampleCATiledLayerDelegate.h
//
// Abstract:   A sample delegate for a CATiledLayer that draws zoomable content into the tiled layer.
//
// Version:    1.0 2008

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

#define kTiledLayerExampleWidth 1024.0
#define kTiledLayerExampleHeight 1024.0

@interface ExampleCATiledLayerDelegate : NSObject
{
	CGMutablePathRef path;
	CGColorRef bgColor, fgColor;
}

-(void)refreshContent;
-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx;

@end
