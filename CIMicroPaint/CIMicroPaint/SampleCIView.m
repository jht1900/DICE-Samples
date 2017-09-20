
/*
 File: SampleCIView.m
 Abstract: Simple OpenGL based CoreImage view.
 Version: 1.1 2012
 */

#import "SampleCIView.h"

#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>

@interface SampleCIView ()

@property (nonatomic, strong) CIContext *context;
@property (nonatomic, strong) NSDictionary *contextOptions;

@property (NS_NONATOMIC_IOSONLY, readonly) BOOL displaysWhenScreenProfileChanges;
- (void)viewWillMoveToWindow:(NSWindow*)newWindow;
- (void)displayProfileChanged:(NSNotification*)notification;

@end

@implementation SampleCIView
{
  NSRect				_lastBounds;
  CGLContextObj		_cglContext;
  NSOpenGLPixelFormat *pixelFormat;
  CGDirectDisplayID	_directDisplayID;
}

+ (NSOpenGLPixelFormat *)defaultPixelFormat
{
  static NSOpenGLPixelFormat *pf;
  if (pf == nil) {
    // Making sure the context's pixel format doesn't have a recovery renderer is important
    // - otherwise CoreImage may not be able to create deeper context's that share textures with this one.
    static const NSOpenGLPixelFormatAttribute attr[] = {
      NSOpenGLPFAAccelerated,
      NSOpenGLPFANoRecovery,
      NSOpenGLPFAColorSize, 32,
      NSOpenGLPFAAllowOfflineRenderers,  /* Allow use of offline renderers */
      0
    };
    pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:(void *)&attr];
  }
  return pf;
}

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setContextOptions:(NSDictionary *)dict
{
  _contextOptions = dict;
  self.context = nil;
}

- (void)setImage:(CIImage *)image
{
  [self setImage:image dirtyRect:CGRectInfinite];
}

- (void)setImage:(CIImage *)image dirtyRect:(CGRect)rect
{
  if (_image != image) {
    _image = image;
    if (CGRectIsInfinite(rect)) {
      [self setNeedsDisplay:YES];
    }
    else {
      [self setNeedsDisplayInRect:NSRectFromCGRect(rect)];
    }
  }
}

- (void)prepareOpenGL
{
  GLint parm = 1;
  /* Enable beam-synced updates. */
  [self.openGLContext setValues:&parm forParameter:NSOpenGLCPSwapInterval];
  /* Make sure that everything we don't need is disabled. Some of these
   * are enabled by default and can slow down rendering. */
  glDisable(GL_ALPHA_TEST);
  glDisable(GL_DEPTH_TEST);
  glDisable(GL_SCISSOR_TEST);
  glDisable(GL_BLEND);
  glDisable(GL_DITHER);
  glDisable(GL_CULL_FACE);
  glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
  glDepthMask(GL_FALSE);
  glStencilMask(0);
  glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
  glHint(GL_TRANSFORM_HINT_APPLE, GL_FASTEST);
}

- (void)viewBoundsDidChange:(NSRect)bounds
{
  /* For subclasses. */
}

- (void)updateMatrices
{
  NSRect bounds = self.bounds;
  if (!NSEqualRects(bounds, _lastBounds)) {
    [self.openGLContext update];
    /* Install an orthographic projection matrix (no perspective)
     * with the origin in the bottom left and one unit equal to one
     * device pixel. */
    glViewport(0, 0, bounds.size.width, bounds.size.height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, bounds.size.width, 0, bounds.size.height, -1, 1);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    _lastBounds = bounds;
    [self viewBoundsDidChange:bounds];
  }
}

- (BOOL)displaysWhenScreenProfileChanges
{
  return YES;
}

- (void)viewWillMoveToWindow:(NSWindow*)newWindow
{
  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  [center removeObserver:self name:NSWindowDidChangeScreenProfileNotification object:nil];
  [center addObserver:self selector:@selector(displayProfileChanged:) name:NSWindowDidChangeScreenProfileNotification object:newWindow];
  [center addObserver:self selector:@selector(displayProfileChanged:) name:NSWindowDidMoveNotification object:newWindow];
  
  // When using OpenGL, we should disable the window's "one-shot" feature
  [newWindow setOneShot:NO];
}

- (void)displayProfileChanged:(NSNotification*)notification
{
  CGDirectDisplayID oldDid = _directDisplayID;
  _directDisplayID = (CGDirectDisplayID)[self.window.screen.deviceDescription[@"NSScreenNumber"] pointerValue];
  if (_directDisplayID == oldDid) {
    return;
  }
  _cglContext = self.openGLContext.CGLContextObj;
  if (pixelFormat == nil) {
    pixelFormat = self.pixelFormat;
    if (pixelFormat == nil) {
      pixelFormat = [[self class] defaultPixelFormat];
    }
  }
  
  CGLLockContext(_cglContext);
  {
    // Create a new CIContext using the new output color space
    // Since the cgl context will be rendered to the display,
    // it is valid to rely on CI to get the colorspace from the context.
    self.context = [CIContext contextWithCGLContext:_cglContext
                                        pixelFormat:pixelFormat.CGLPixelFormatObj
                                         colorSpace:nil
                                            options:_contextOptions];
  }
  CGLUnlockContext(_cglContext);
}


- (void)drawRect:(NSRect)rect
{
  [self.openGLContext makeCurrentContext];
  
  // Allocate a CoreImage rendering context using the view's OpenGL
  // context as its destination if none already exists.
  if (self.context == nil) {
    [self displayProfileChanged:nil];
  }
  
  CGRect integralRect = CGRectIntegral(NSRectToCGRect(rect));
  
  if ([NSGraphicsContext currentContextDrawingToScreen]) {
    NSLog(@"currentContextDrawingToScreen");
    
    [self updateMatrices];
    
    // Clear the specified subrect of the OpenGL surface then render the image into the view.
    // Use the GL scissor test to clip to the subrect.
    // Ask CoreImage to generate an extra pixel in case it has to interpolate (allow for hardware inaccuracies).
    CGRect rr = CGRectIntersection(CGRectInset (integralRect, -1.0f, -1.0f), NSRectToCGRect(_lastBounds));
    
    glScissor(integralRect.origin.x, integralRect.origin.y, integralRect.size.width, integralRect.size.height);
    glEnable(GL_SCISSOR_TEST);
    
    glClear(GL_COLOR_BUFFER_BIT);
    
    if ([self respondsToSelector:@selector(drawRect:inCIContext:)]) {
      // For Subclasses to provide their own drawing method.
      [(id <SampleCIViewDraw>)self drawRect:NSRectFromCGRect(rr) inCIContext:self.context];
    }
    else {
      if (self.image != nil) {
        [self.context drawImage:self.image inRect:rr fromRect:rr];
      }
    }
    
    glDisable(GL_SCISSOR_TEST);
    
    // Flush the OpenGL command stream. If the view is double buffered this should be replaced by
    // [[self openGLContext] flushBuffer].
    glFlush();
  }
  else
  {
    // Printing the view contents. Render using CG, not OpenGL.
    NSLog(@"Printing the view contents");

    if ([self respondsToSelector:@selector (drawRect:inCIContext:)]) {
      [(id <SampleCIViewDraw>)self drawRect:NSRectFromCGRect(integralRect) inCIContext:self.context];
    }
    else {
      if (self.image != nil) {
        CGImageRef cgImage = [self.context createCGImage:self.image
                                                fromRect:integralRect
                                                  format:kCIFormatRGBA16
                                              colorSpace:nil];
        if (cgImage != NULL) {
          CGContextDrawImage([NSGraphicsContext currentContext].graphicsPort, integralRect, cgImage);
          CGImageRelease(cgImage);
        }
      }
    }
  }
}

@end
