/*
     File: APLCustomVideoCompositor.m
 Abstract:  Custom video compositor class implementing the AVVideoCompositing protocol. 
Version: 1.1 2013 
 */

#import "APLCustomVideoCompositor.h"
#import "APLCustomVideoCompositionInstruction.h"
#import "APLDiagonalWipeRenderer.h"
#import "APLCrossDissolveRenderer.h"

#import <CoreVideo/CoreVideo.h>

@interface APLCustomVideoCompositor()
{
    BOOL                                _shouldCancelAllRequests;
    BOOL                                _renderContextDidChange;
    dispatch_queue_t                    _renderingQueue;
    dispatch_queue_t                    _renderContextQueue;
    AVVideoCompositionRenderContext*    _renderContext;
    CVPixelBufferRef                    _previousBuffer;
}

@property (nonatomic, retain) APLOpenGLRenderer *oglRenderer;

@end

@implementation APLCrossDissolveCompositor

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        self.oglRenderer = [[APLCrossDissolveRenderer alloc] init];
    }
    
    return self;
}

@end

@implementation APLDiagonalWipeCompositor

- (instancetype)init
{
    self = [super init];
    
    if (self) {
        self.oglRenderer = [[APLDiagonalWipeRenderer alloc] init];
    }
    
    return self;
}

@end

@implementation APLCustomVideoCompositor

#pragma mark - AVVideoCompositing protocol

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _renderingQueue = dispatch_queue_create("com.apple.aplcustomvideocompositor.renderingqueue", DISPATCH_QUEUE_SERIAL); 
        _renderContextQueue = dispatch_queue_create("com.apple.aplcustomvideocompositor.rendercontextqueue", DISPATCH_QUEUE_SERIAL);
        _previousBuffer = nil;
        _renderContextDidChange = NO;
    }
    
    return self;
}

- (NSDictionary *)sourcePixelBufferAttributes
{
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
              (NSString *)kCVPixelBufferOpenGLCompatibilityKey : @YES,
              (NSString *)kCVPixelBufferIOSurfacePropertiesKey : @{}};
}

- (NSDictionary *)requiredPixelBufferAttributesForRenderContext
{
    return @{ (NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
              (NSString *)kCVPixelBufferOpenGLCompatibilityKey : @YES,
              (NSString *)kCVPixelBufferIOSurfacePropertiesKey : @{}};
}

- (void)renderContextChanged:(AVVideoCompositionRenderContext *)newRenderContext
{
    dispatch_sync(_renderContextQueue, ^() {
        _renderContext = newRenderContext;
        _renderContextDidChange = YES;
    });
}

- (void)startVideoCompositionRequest:(AVAsynchronousVideoCompositionRequest *)request
{
    @autoreleasepool {
        dispatch_async(_renderingQueue,^() {
            
            // Check if all pending requests have been cancelled
            if (_shouldCancelAllRequests) {
                [request finishCancelledRequest];
            }
            else {
                NSError *err = nil;
                // Get the next rendererd pixel buffer
                CVPixelBufferRef resultPixels = [self newRenderedPixelBufferForRequest:request error:&err];
                
                if (resultPixels) {
                    // The resulting pixelbuffer from OpenGL renderer is passed along to the request
                    [request finishWithComposedVideoFrame:resultPixels];
                    CFRelease(resultPixels);
                } else {
                    [request finishWithError:err];
                }
            }
        });
    }
}

- (void)cancelAllPendingVideoCompositionRequests
{
    // pending requests will call finishCancelledRequest, those already rendering will call finishWithComposedVideoFrame
    _shouldCancelAllRequests = YES;
    
    // block until all cancelled or finished
    dispatch_barrier_async(_renderingQueue, ^() {
        // start accepting requests again
        _shouldCancelAllRequests = NO;
    });
}

#pragma mark - Utilities

static Float64 factorForTimeInRange(CMTime time, CMTimeRange range) /* 0.0 -> 1.0 */
{
    CMTime elapsed = CMTimeSubtract(time, range.start);
    return CMTimeGetSeconds(elapsed) / CMTimeGetSeconds(range.duration);
}

- (CVPixelBufferRef)newRenderedPixelBufferForRequest:(AVAsynchronousVideoCompositionRequest *)request error:(NSError **)errOut
{
    CVPixelBufferRef dstPixels = nil;
    
    // tweenFactor indicates how far within that timeRange we are rendering this frame. This is normalized to vary between 0.0 and 1.0.
    // 0.0 indicates the time at first frame in that videoComposition timeRange
    // 1.0 indicates the time at last frame in that videoComposition timeRange
    float tweenFactor = factorForTimeInRange(request.compositionTime, request.videoCompositionInstruction.timeRange);
    
    APLCustomVideoCompositionInstruction *currentInstruction = request.videoCompositionInstruction;
    
    // Source pixel buffers are used as inputs while rendering the transition
    CVPixelBufferRef foregroundSourceBuffer = [request sourceFrameByTrackID:currentInstruction.foregroundTrackID];
    CVPixelBufferRef backgroundSourceBuffer = [request sourceFrameByTrackID:currentInstruction.backgroundTrackID];
    
    // Destination pixel buffer into which we render the output
    dstPixels = [_renderContext newPixelBuffer];
    
    // Recompute normalized render transform everytime the render context changes
    if (_renderContextDidChange) {
        // The renderTransform returned by the renderContext is in X: [0, w] and Y: [0, h] coordinate system
        _oglRenderer.renderTransform = _renderContext.renderTransform;
        
        _renderContextDidChange = NO;
    }
    
    [_oglRenderer renderPixelBuffer:dstPixels usingForegroundSourceBuffer:foregroundSourceBuffer andBackgroundSourceBuffer:backgroundSourceBuffer forTweenFactor:tweenFactor];
    
    return dstPixels;
}

@end
