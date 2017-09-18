/*
     File: APLCrossDissolveRenderer.m
 Abstract:  APLCrossDissolveRenderer subclass of APLOpenGLRenderer, renders the given source buffers to perform a cross dissolve over the time range of the transition. 
Version: 1.1 2013 
 */

#import "APLCrossDissolveRenderer.h"

@implementation APLCrossDissolveRenderer

- (instancetype)init
{
    self = [super init];
    
    return self;
}

- (void)renderPixelBuffer:(CVPixelBufferRef)destinationPixelBuffer usingForegroundSourceBuffer:(CVPixelBufferRef)foregroundPixelBuffer andBackgroundSourceBuffer:(CVPixelBufferRef)backgroundPixelBuffer forTweenFactor:(float)tween
{
    CGLSetCurrentContext(_currentContext);
    
    CGLLockContext(_currentContext);
    
    if (foregroundPixelBuffer != NULL || backgroundPixelBuffer != NULL) {
        
        CVOpenGLTextureRef foregroundTexture  = [self textureForPixelBuffer:foregroundPixelBuffer];
        
        CVOpenGLTextureRef backgroundTexture = [self textureForPixelBuffer:backgroundPixelBuffer];
        
        CVOpenGLTextureRef destTexture = [self textureForPixelBuffer:destinationPixelBuffer];
        
        glUseProgram(self.program);
        
        // Set the render transform
        GLfloat preferredRenderTransform [] = {
            self.renderTransform.a, self.renderTransform.b, self.renderTransform.tx, 0.0,
            self.renderTransform.c, self.renderTransform.d, self.renderTransform.ty, 0.0,
            0.0,                       0.0,                                        1.0, 0.0,
            0.0,                       0.0,                                        0.0, 1.0,
        };
        
        glUniformMatrix4fv(uniforms[UNIFORM_RENDER_TRANSFORM], 1, GL_FALSE, preferredRenderTransform);
        
        glBindFramebuffer(GL_FRAMEBUFFER, self.offscreenBufferHandle);
        glViewport(0, 0, (int)CVPixelBufferGetWidth(destinationPixelBuffer), (int)CVPixelBufferGetHeight(destinationPixelBuffer));
        
        // Y planes of foreground and background frame are used to render the Y plane of the destination frame
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(CVOpenGLTextureGetTarget(foregroundTexture), CVOpenGLTextureGetName(foregroundTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(CVOpenGLTextureGetTarget(backgroundTexture), CVOpenGLTextureGetName(backgroundTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(CVOpenGLTextureGetTarget(destTexture), CVOpenGLTextureGetName(destTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR); // GL_NEAREST
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR); // GL_NEAREST
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        // Attach the destination texture as a color attachment to the off screen frame buffer
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, CVOpenGLTextureGetTarget(destTexture), CVOpenGLTextureGetName(destTexture), 0);
        
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            NSLog(@"Failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
            goto bail;
        }
        
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        
        GLfloat quadVertexData1 [] = {
            -1.0, -1.0,
            1.0, -1.0,
            -1.0, 1.0,
            1.0, 1.0,
        };
        
        size_t frameWidth = CVPixelBufferGetWidth(destinationPixelBuffer);
        size_t frameHeight = CVPixelBufferGetHeight(destinationPixelBuffer);
        
        // texture data varies from 0 -> w and 0 -> h, whereas vertex data varies from -1 -> 1
        GLfloat quadTextureData1 [] = {
            (0.5 + quadVertexData1[0]/2) * frameWidth, (0.5 + quadVertexData1[1]/2) * frameHeight,
            (0.5 + quadVertexData1[2]/2) * frameWidth, (0.5 + quadVertexData1[3]/2) * frameHeight,
            (0.5 + quadVertexData1[4]/2) * frameWidth, (0.5 + quadVertexData1[5]/2) * frameHeight,
            (0.5 + quadVertexData1[6]/2) * frameWidth, (0.5 + quadVertexData1[7]/2) * frameHeight,
        };
        
        glUniform1i(uniforms[UNIFORM_RGB], 0);
        
        glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, quadVertexData1);
        glEnableVertexAttribArray(ATTRIB_VERTEX);
        
        glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData1);
        glEnableVertexAttribArray(ATTRIB_TEXCOORD);
        
        // Blend function to draw the foreground frame
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ZERO);
        
        // Draw the foreground frame
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        glUniform1i(uniforms[UNIFORM_RGB], 1);
        
        glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, quadVertexData1);
        glEnableVertexAttribArray(ATTRIB_VERTEX);
        
        glVertexAttribPointer(ATTRIB_TEXCOORD, 2, GL_FLOAT, 0, 0, quadTextureData1);
        glEnableVertexAttribArray(ATTRIB_TEXCOORD);
        
        // Blend function to draw the background frame
        glBlendColor(0, 0, 0, tween);
        glBlendFunc(GL_CONSTANT_ALPHA, GL_ONE_MINUS_CONSTANT_ALPHA);
        
        // Draw the background frame
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        glFlush();
        
    bail:
        CFRelease(foregroundTexture);
        CFRelease(backgroundTexture);
        CFRelease(destTexture);
        
        // Periodic texture cache flush every frame
        CVOpenGLTextureCacheFlush(self.videoTextureCache, 0);
        
        CGLUnlockContext(_currentContext);
        
        CGLSetCurrentContext(_previousContext);
    }
    
}

@end
