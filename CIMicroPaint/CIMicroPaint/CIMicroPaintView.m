
/*
 File: CIMicroPaintView.m
 Abstract: Subclass of SampleCIView to handle painting.
 Version: 1.1 2012
 */

#import "CIMicroPaintView.h"

@interface CIMicroPaintView ()

@property (nonatomic, strong) CIImageAccumulator *imageAccumulator;
@property (nonatomic, strong) NSColor *color;
@property (nonatomic, strong) CIFilter *brushFilter;
@property (nonatomic, strong) CIFilter *compositeFilter;
@property (assign) CGFloat brushSize;

@end

@implementation CIMicroPaintView
{
}

- (instancetype)initWithFrame:(NSRect)frame
{
  self = [super initWithFrame:frame];
  if (self != nil) {
    _brushSize = 25.0;
    
    _color = [NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    
    _brushFilter = [CIFilter filterWithName: @"CIRadialGradient" keysAndValues:
                    @"inputColor1", [CIColor colorWithRed:0.0 green:0.0
                                                     blue:0.0 alpha:0.0], @"inputRadius0", @0.0, nil];
    
    _compositeFilter = [CIFilter filterWithName: @"CISourceOverCompositing"];
  }
  return self;
}

- (void)viewBoundsDidChange:(NSRect)bounds
{
  if ((self.imageAccumulator != nil) && (CGRectEqualToRect (*(CGRect *)&bounds, (self.imageAccumulator).extent))) {
    return;
  }
  
  /* Create a new accumulator and composite the old one over the it. */
  
  CIImageAccumulator *newAccumulator = [[CIImageAccumulator alloc] initWithExtent:*(CGRect *)&bounds format:kCIFormatRGBA16];
  CIFilter *filter = [CIFilter filterWithName:@"CIConstantColorGenerator" keysAndValues:@"inputColor", [CIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:1.0], nil];
  [newAccumulator setImage:[filter valueForKey:@"outputImage"]];
  
  if (self.imageAccumulator != nil)
  {
    filter = [CIFilter filterWithName:@"CISourceOverCompositing"
                        keysAndValues:@"inputImage", [self.imageAccumulator image],
              @"inputBackgroundImage", [newAccumulator image], nil];
    [newAccumulator setImage:[filter valueForKey:@"outputImage"]];
  }
  
  self.imageAccumulator = newAccumulator;
  
  self.image = [self.imageAccumulator image];
}


- (void)mouseDragged:(NSEvent *)event
{
  CIFilter *brushFilter = self.brushFilter;
  
  NSPoint  loc = [self convertPoint:event.locationInWindow fromView:nil];
  [brushFilter setValue:@(self.brushSize) forKey:@"inputRadius1"];
  
  CIColor *cicolor = [[CIColor alloc] initWithColor:self.color];
  [brushFilter setValue:cicolor forKey:@"inputColor0"];
  
  CIVector *inputCenter = [CIVector vectorWithX:loc.x Y:loc.y];
  [brushFilter setValue:inputCenter forKey:@"inputCenter"];
  
  
  CIFilter *compositeFilter = self.compositeFilter;
  
  [compositeFilter setValue:[brushFilter valueForKey:@"outputImage"] forKey:@"inputImage"];
  [compositeFilter setValue:[self.imageAccumulator image] forKey:@"inputBackgroundImage"];
  
  CGFloat brushSize = self.brushSize;
  CGRect rect = CGRectMake(loc.x-brushSize, loc.y-brushSize, 2.0*brushSize, 2.0*brushSize);
  
  [self.imageAccumulator setImage:[compositeFilter valueForKey:@"outputImage"] dirtyRect:rect];
  [self setImage:[self.imageAccumulator image] dirtyRect:rect];
}


- (void)mouseDown:(NSEvent *)event
{
  [self mouseDragged: event];
}


@end
