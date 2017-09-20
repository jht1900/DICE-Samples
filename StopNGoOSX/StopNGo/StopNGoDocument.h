/*
     File: StopNGoDocument.h
 Abstract: Document that captures stills to a QuickTime movie
  Version: 1.0 2011 
 */

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

@interface StopNGoDocument : NSDocument
{
	IBOutlet NSView *previewView;
	IBOutlet NSButton *takePictureButton;
	AVCaptureSession *session;
  AVCaptureVideoPreviewLayer *previewLayer;
	AVCaptureStillImageOutput *stillImageOutput;
	BOOL started;
	NSURL *outputURL;
	AVAssetWriter *assetWriter;
	AVAssetWriterInput *videoInput;
	CMTime frameDuration;
	CMTime nextPresentationTime;
}

@property (nonatomic) float framesPerSecond;
@property (strong) NSURL *outputURL;
- (IBAction)startStop:(id)sender;
- (IBAction)takePicture:(id)sender;
- (IBAction)togglePreviewMirrored:(id)sender;
@end
