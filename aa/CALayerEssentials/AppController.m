//
// File:       AppController.m
//
// Abstract:   The window controller that manages user events and sets up the window
//
// Version:    1.0 2008

#import <Quartz/Quartz.h>
#import <QTKit/QTMovieModernizer.h>

#import "AppController.h"
#import "ExampleCALayerDelegate.h"
#import "ExampleCAOpenGLLayer.h"
#import "ExampleCATiledLayerDelegate.h"

@interface AppController()
-(void)setupCALayer;
-(void)setupCAOpenGLLayer;
-(void)setupCATextLayer;
-(void)setupQCCompositionLayer;
-(void)setupQTMovieLayer;
-(void)setupCAScrollLayer;
-(void)setupCATiledLayer;
@end

@implementation AppController

// Constants used by the Scroll layer to setup its contents and to scroll.
#define kScrollContentRect CGRectMake(  0.0,   0.0, 300.0, 300.0)

-(void)awakeFromNib
{
	// Setup the delegates that are used by setupCALayer, setupCAScrollLayer and setupCATiledLayer
	delegateCALayer = [[ExampleCALayerDelegate alloc] init];
	delegateCATiledLayer = [[ExampleCATiledLayerDelegate alloc] init];
	
	[self setupCALayer];
	[self setupCAOpenGLLayer];
	[self setupCATextLayer];
	[self setupCAScrollLayer];
	[self setupCATiledLayer];
	[self setupQCCompositionLayer];
	[self setupQTMovieLayer];
}

-(void)dealloc
{
	[delegateCALayer release];
	[delegateCATiledLayer release];
	[super dealloc];
}

-(void)setupCALayer
{
	exampleCALayer = [CALayer layer];
	
	// Set the layer delegate so that we have some content drawn
	exampleCALayer.delegate = delegateCALayer;
	
	// Layers start life validated (unlike views).
	// We request that the layer have its contents drawn so that it can display something.
	[exampleCALayer setNeedsDisplay];
	
	// Set the view to host the layer!
	hostCALayer.layer = exampleCALayer;
}

-(void)setupCAOpenGLLayer
{
	exampleCAOpenGLLayer = [ExampleCAOpenGLLayer layer];
	
	// Layers start life validated (unlike views).
	// We request that the layer have its contents drawn so that it can display something.
	[exampleCAOpenGLLayer setNeedsDisplay];
	
	hostCAOpenGLLayer.layer = exampleCAOpenGLLayer;
}

-(void)setupCATextLayer
{
	exampleCATextLayer = [CATextLayer layer];
	
	// Setting the layer's text will invalidate the layer, so we don't need
	// to call -setNeedsDisplay directly.
	exampleCATextLayer.string = @"Hello World";
	
	// The default foreground color is white, so we get a bit more contrast
	// we'll set the color to something darker.
	CGColorRef fgColor = CGColorCreateGenericRGB(0.1, 0.2, 0.3, 1.0);
	exampleCATextLayer.foregroundColor = fgColor;
	CGColorRelease(fgColor);
	
	hostCATextLayer.layer = exampleCATextLayer;
}

-(void)setupQCCompositionLayer
{
	// Grab a composition
	NSString * compositionPath = [[NSBundle mainBundle] pathForResource:@"Clouds" ofType:@"qtz"];
	
	// Create a QCComposition Layer with the path to that composition
	// A QCCompositionLayer is a CAOpenGLLayer with the asynchronous property set to YES
	// therefore it does not need to be invalidated to display (it will automatically be invalidated).
	exampleQCCompositionLayer = [QCCompositionLayer compositionLayerWithFile:compositionPath];
	
	hostQCCompositionLayer.layer = exampleQCCompositionLayer;
}

-(void)setupQTMovieLayer
{
	// Grab a Quicktime Movie from our bundle
	QTMovie * movie = [QTMovie movieNamed:@"Sample.mov" error:nil];
	
	// Set it on the movie layer
	//exampleQTMovieLayer = [QTMovieLayer layerWithMovie:movie];
	
	//hostQTMovieLayer.layer = exampleQTMovieLayer;
}

-(void)setupCAScrollLayer
{
	// A scroll layer by itself is rather uninteresting
	// so we'll create a regular layer to provide content.
	scrollLayerContent = [CALayer layer];
	exampleCAScrollLayer = [CAScrollLayer layer];
	
	// Since its handy, we'll use the same content as our basic CALayer example
	// This also shows that you can use the same delegate for multiple layers :)
	scrollLayerContent.delegate = delegateCALayer;
	
	// Layers start life validated (unlike views).
	// We request that the layer have its contents drawn so that it can display something.
	[scrollLayerContent setNeedsDisplay];
	
	// We set a frame for this layer. Sublayers coordinates are always in terms of the
	// parent layer's bounds.
	scrollLayerContent.frame = kScrollContentRect;
	
	// Now we add the configured layer to the scroll layer.
	[exampleCAScrollLayer addSublayer:scrollLayerContent];
	
	hostCAScrollLayer.layer = exampleCAScrollLayer;
}

-(void)setupCATiledLayer
{
	// If we set the tiled layer as the layer for the host NSView, then it won't be able to zoom
	// and we won't be able to demonstrate multiple levels of detail, thus we create a dummy CALayer
	// to act as the CATiledLayer's parent and we'll set the sublayer transform of that layer in order to zoom it.
	CALayer *baseLayer = [CALayer layer];
	hostCATiledLayer.layer = baseLayer;

	// Now the real fun begins as we setup the CATiledLayer
	exampleCATiledLayer = [CATiledLayer layer];
	[baseLayer addSublayer:exampleCATiledLayer];

	// Like a CALayer, a CATiledLayer can use a delegate to do the drawing.
	// The ExampleCATiledLayerDelegate is essentially the same as the ExampleCALayerDelegate
	// that have already seen, but instead draws an image 
	exampleCATiledLayer.delegate = delegateCATiledLayer;
	
	// To provide multiple levels of content, you need to set the levelsOfDetail property.
	// For this sample, we have 5 levels of detail (1/4x - 4x).
	// By setting the value to 5, we establish that we have levels of 1/16x - 1x (2^-4 - 2^0)
	// we use the levelsOfDetailBias property we shift this up by 2 raised to the power
	// of the bias, changing the range to 1/4-4x (2^-2 - 2^2).
	exampleCATiledLayer.levelsOfDetail = 5;
	exampleCATiledLayer.levelsOfDetailBias = 2;

	// Layers start life validated (unlike views).
	// We request that the layer have its contents drawn so that it can display something.
	[exampleCATiledLayer setNeedsDisplay];
	
	// Set the size of the layer
	exampleCATiledLayer.bounds = CGRectMake(0.0, 0.0, kTiledLayerExampleWidth, kTiledLayerExampleHeight);
	
	// And position its center over the center of the host view (whose size determines the size of our parent layer)
	// We don't update this, so if you resize the window the layer won't appear in the center of that window anymore.
	exampleCATiledLayer.position = CGPointMake(NSMidX(hostCATiledLayer.frame), NSMidY(hostCATiledLayer.frame));
}

-(IBAction)redrawLayerContent:(id)sender
{
	// Just tell the layer to display itself and it will redraw
	[exampleCALayer setNeedsDisplay];
}

-(IBAction)toggleGLAsync:(id)sender
{
	// By turning on Async, the layer will update on its own.
	exampleCAOpenGLLayer.asynchronous = [sender state] == NSOnState;
}

-(IBAction)toggleGLDisplayOnResize:(id)sender
{
	// By turning on needsDisplayOnBoundsChange, the GLLayer will get redisplayed when it is resized, forcing the content
	// to be resized to the layer's current size automatically. With this off, the content will be resized when -display is called.
	exampleCAOpenGLLayer.needsDisplayOnBoundsChange = [sender state] == NSOnState;
}

-(IBAction)redrawGLContent:(id)sender
{
	// Just tell the layer to display itself and it will redraw
	[hostCAOpenGLLayer.layer setNeedsDisplay];
}

-(IBAction)changeText:(id)sender
{
	exampleCATextLayer.string = [sender stringValue];
}

-(IBAction)toggleMovieLayer:(id)sender
{
	// When we are asked to play, we'll just goto the beginning.
//	[exampleQTMovieLayer.movie gotoBeginning];
//	[exampleQTMovieLayer.movie play];
}

-(IBAction)redrawScrollContent:(id)sender
{
	[scrollLayerContent setNeedsDisplay];
	[exampleCAScrollLayer setNeedsDisplay];
}

// Creates a rect that is a fraction of the original rect
CGRect MakeSubrect(CGRect r, CGFloat x, CGFloat y, CGFloat w, CGFloat h)
{
	return CGRectMake(	
		r.origin.x + r.size.width * x,
		r.origin.y + r.size.height * y,
		r.size.width * w,
		r.size.height * h);
}

-(IBAction)scrollUp:(id)sender
{
	[exampleCAScrollLayer scrollToRect:MakeSubrect(kScrollContentRect, 0.25, 0.5, 1.0, 0.5)];
}

-(IBAction)scrollRight:(id)sender
{
	[exampleCAScrollLayer scrollToRect:MakeSubrect(kScrollContentRect, 0.5, 0.25, 1.0, 0.5)];
}

-(IBAction)scrollDown:(id)sender
{
	[exampleCAScrollLayer scrollToRect:MakeSubrect(kScrollContentRect, 0.25, 0.0, 1.0, 0.5)];
}

-(IBAction)scrollLeft:(id)sender
{
	[exampleCAScrollLayer scrollToRect:MakeSubrect(kScrollContentRect, 0.0, 0.25, 1.0, 0.5)];
}

-(IBAction)scrollUpperLeft:(id)sender
{
	[exampleCAScrollLayer scrollToRect:MakeSubrect(kScrollContentRect, 0.0, 0.5, 0.5, 0.5)];
}

-(IBAction)scrollUpperRight:(id)sender
{
	[exampleCAScrollLayer scrollToRect:MakeSubrect(kScrollContentRect, 0.5, 0.5, 0.5, 0.5)];
}

-(IBAction)scrollLowerLeft:(id)sender
{
	[exampleCAScrollLayer scrollToRect:MakeSubrect(kScrollContentRect, 0.0, 0.0, 0.5, 0.5)];
}

-(IBAction)scrollLowerRight:(id)sender
{
	[exampleCAScrollLayer scrollToRect:MakeSubrect(kScrollContentRect, 0.5, 0.0, 0.5, 0.5)];
}

-(IBAction)redrawZoomableContent:(id)sender
{
	[delegateCATiledLayer refreshContent];
	[exampleCATiledLayer setNeedsDisplay];
}

-(IBAction)tiledZoom:(id)sender
{
	CGFloat zoom = 1.0;
	switch([sender selectedSegment])
	{
		case 0:
			zoom = 0.25;
			break;
			
		case 1:
			zoom = 0.5;
			break;
			
		case 2:
			zoom = 1.0;
			break;
			
		case 3:
			zoom = 2.0;
			break;
			
		case 4:
			zoom = 4.0;
			break;
	}
	hostCATiledLayer.layer.sublayerTransform = CATransform3DMakeScale(zoom, zoom, 1.0);
}

@end
