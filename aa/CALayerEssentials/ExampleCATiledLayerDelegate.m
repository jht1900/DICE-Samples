//
// File:       ExampleCATiledLayerDelegate.m
//
// Abstract:   A sample delegate for a CATiledLayer that draws zoomable content into the tiled layer.
//
// Version:    1.0 2008

#import "ExampleCATiledLayerDelegate.h"

@implementation ExampleCATiledLayerDelegate

static CGFloat randomFloat()
{
    return random() / (double)LONG_MAX;
}

-(instancetype)init
{
    self = [super init];
    if(self != nil)
    {
        // Create our initial content.
        [self refreshContent];
    }
    return self;
}

-(void)dealloc
{
    CGPathRelease(path);
    CGColorRelease(bgColor);
    CGColorRelease(fgColor);
    [super dealloc];
}

-(void)refreshContent
{
    CGPathRelease(path);
    CGColorRelease(bgColor);
    CGColorRelease(fgColor);

    // We aren't interested in the actual content of the layer, but we want the same object
    // everytime we draw, so we create a CGPathRef to store a randomly generated path and a CGColorRef
    // to store the color to draw it in.
    bgColor = CGColorCreateGenericRGB(randomFloat(), randomFloat(), randomFloat(), 1.0);
    fgColor = CGColorCreateGenericRGB(randomFloat(), randomFloat(), randomFloat(), 1.0);
    path = CGPathCreateMutable();
    int sides = (random() % 18) + 1;
    CGPathMoveToPoint(path, NULL, randomFloat() * kTiledLayerExampleWidth, randomFloat() * kTiledLayerExampleHeight);
    for(int i = 0; i < sides; ++i)
    {
        CGPathAddLineToPoint(path, NULL, randomFloat() * kTiledLayerExampleWidth, randomFloat() * kTiledLayerExampleHeight);
    }
    CGPathCloseSubpath(path);
}

-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    // First, fill the clipping bounds with the background color.
    CGRect bounds = CGContextGetClipBoundingBox(context);
    CGContextSetFillColorWithColor(context, bgColor);
    CGContextFillRect(context, bounds);

    // Then add and fill the pre-generated path with the foreground color.
    CGContextSetFillColorWithColor(context, fgColor);
    CGContextAddPath(context, path);
    CGContextEOFillPath(context);
}

@end
