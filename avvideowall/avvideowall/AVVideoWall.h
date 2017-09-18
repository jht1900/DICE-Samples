/*
     File: AVVideoWall.h
 Abstract: The AVVideoWall class, builds a video wall of live capture devices
  Version: 1.1 2011
 
 */

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

@interface AVVideoWall : NSObject
{
	NSWindow *_window;
	CALayer *_rootLayer;
	AVCaptureSession *_session;
	NSMutableArray *_videoPreviewLayers;
	NSMutableArray *_homeLayerRects;
	BOOL _spinningLayers;
}

- (BOOL)configure;
- (void)spinLayers;
- (void)sendLayersHome;

@end
