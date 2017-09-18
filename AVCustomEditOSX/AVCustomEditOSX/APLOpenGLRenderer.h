/*
     File: APLOpenGLRenderer.h
 Abstract:  OpenGL base class renderer setups a CGLContextObj for rendering, it also loads, compiles and links the vertex and fragment shaders. 
Version: 1.1 2013 
 */

#import <Foundation/Foundation.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#import <OpenGL/glu.h>

enum
{
	UNIFORM_RGB,
	UNIFORM_RENDER_TRANSFORM,
   	NUM_UNIFORMS
};
extern GLint uniforms[NUM_UNIFORMS];

enum
{
	ATTRIB_VERTEX,
	ATTRIB_TEXCOORD,
   	NUM_ATTRIBUTES
};

@interface APLOpenGLRenderer : NSObject
{
	CGLContextObj _previousContext;
    CGLContextObj _currentContext;
}

@property GLuint program;
@property CGAffineTransform renderTransform;
@property CVOpenGLTextureCacheRef videoTextureCache;
@property GLuint offscreenBufferHandle;

- (CVOpenGLTextureRef)textureForPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)renderPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer usingForegroundSourceBuffer:(CVPixelBufferRef)foregroundPixelBuffer andBackgroundSourceBuffer:(CVPixelBufferRef)backgroundPixelBuffer forTweenFactor:(float)tween;

@end
