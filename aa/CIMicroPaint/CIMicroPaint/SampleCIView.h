
/*
     File: SampleCIView.h
 Abstract: Simple OpenGL based CoreImage view.
  Version: 1.1 2012 
 */

#import <Cocoa/Cocoa.h>
#import <QuartzCore/CoreImage.h>

@interface SampleCIView : NSOpenGLView

@property (nonatomic, strong) CIImage *image;
- (void)setImage:(CIImage *)image dirtyRect:(CGRect)r;

- (void)setContextOptions:(NSDictionary *)dict;

// Called when the view bounds have changed
- (void)viewBoundsDidChange:(NSRect)bounds;

@end


@protocol SampleCIViewDraw

// If defined in the view subclass, called when rendering
- (void)drawRect:(NSRect)bounds inCIContext:(CIContext *)ctx;

@end
