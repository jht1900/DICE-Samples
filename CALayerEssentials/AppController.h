//
// File:       AppController.h
//
// Abstract:   The window controller that manages user events and sets up the window
//
// Version:    1.0 2008

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@class ExampleCALayerDelegate;
@class ExampleCATiledLayerDelegate;

@interface AppController : NSObject
{
	IBOutlet NSView * hostCALayer;
	IBOutlet NSView * hostCAOpenGLLayer;
	IBOutlet NSView * hostCATextLayer;
	IBOutlet NSView * hostQCCompositionLayer;
	IBOutlet NSView * hostQTMovieLayer;
	IBOutlet NSView * hostCAScrollLayer;
	IBOutlet NSView * hostCATiledLayer;
	
	IBOutlet NSButton * toggleQTCapture;
	IBOutlet NSButton * toggleQTMovie;
	
	// Layers
	CALayer *exampleCALayer;
	CAOpenGLLayer *exampleCAOpenGLLayer;
	CATextLayer *exampleCATextLayer;
	QCCompositionLayer *exampleQCCompositionLayer;
	//QTMovieLayer *exampleQTMovieLayer;
	CAScrollLayer *exampleCAScrollLayer;
	CALayer *scrollLayerContent;
	CATiledLayer *exampleCATiledLayer;
	
	// Delegates
	ExampleCALayerDelegate *delegateCALayer;
	ExampleCATiledLayerDelegate *delegateCATiledLayer;
}

-(IBAction)redrawLayerContent:(id)sender;

-(IBAction)toggleGLAsync:(id)sender;
-(IBAction)toggleGLDisplayOnResize:(id)sender;
-(IBAction)redrawGLContent:(id)sender;

-(IBAction)changeText:(id)sender;

-(IBAction)toggleMovieLayer:(id)sender;

-(IBAction)redrawScrollContent:(id)sender;
-(IBAction)scrollUpperLeft:(id)sender;
-(IBAction)scrollUp:(id)sender;
-(IBAction)scrollUpperRight:(id)sender;
-(IBAction)scrollRight:(id)sender;
-(IBAction)scrollLowerRight:(id)sender;
-(IBAction)scrollDown:(id)sender;
-(IBAction)scrollLowerLeft:(id)sender;
-(IBAction)scrollLeft:(id)sender;

-(IBAction)redrawZoomableContent:(id)sender;
-(IBAction)tiledZoom:(id)sender;

@end
