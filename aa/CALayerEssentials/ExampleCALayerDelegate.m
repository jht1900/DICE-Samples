//
// File:       ExampleCALayerDelegate.m
//
// Abstract:   A sample delegate for a CALayer that draws random content into the layer.
//
// Version:    1.0 2008

#import "ExampleCALayerDelegate.h"

@implementation ExampleCALayerDelegate

static CGFloat randomFloat()
{
    CGFloat f = (rand() % RAND_MAX) / (float)(RAND_MAX);
    return f;
}

static CGPoint randomPointInBounds(CGRect bounds)
{
	CGFloat x = randomFloat() * bounds.size.width + bounds.origin.x;
	CGFloat y = randomFloat() * bounds.size.height + bounds.origin.y;
	return CGPointMake(x, y);
}

-(void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
	// We aren't interested in the actual content of this layer, we just want to draw something.
	// Towards that end, we'll fill the content with a random color,
	// then fill a randomly generated polygon.
	
	CGRect bounds = CGContextGetClipBoundingBox(context);
	CGContextSetRGBFillColor(context, randomFloat(), randomFloat(), randomFloat(), 1.0);
	CGContextFillRect(context, bounds);
	
	int sides = (random() % 18) + 1;
	CGPoint p = randomPointInBounds(bounds);
	CGContextMoveToPoint(context, p.x, p.y);
	for(int i = 0; i < sides; ++i)
	{
		p = randomPointInBounds(bounds);
		CGContextAddLineToPoint(context, p.x, p.y);
	}
	CGContextClosePath(context);
	CGContextSetRGBFillColor(context, randomFloat(), randomFloat(), randomFloat(), 1.0);
	CGContextEOFillPath(context);
}

@end
