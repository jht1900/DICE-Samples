/*
     File: AVRecorderDocument.h
 Abstract: n/a
 Version: 2.1 2012 
 */

#import <Cocoa/Cocoa.h>

@class AVCaptureVideoPreviewLayer;
@class AVCaptureSession;
@class AVCaptureDeviceInput;
@class AVCaptureMovieFileOutput;
@class AVCaptureAudioPreviewOutput;
@class AVCaptureConnection;
@class AVCaptureDevice;
@class AVCaptureDeviceFormat;
@class AVFrameRateRange;

@interface AVRecorderDocument : NSDocument
{
@private
	NSView						*__weak previewView;
	AVCaptureVideoPreviewLayer	*previewLayer;
	NSLevelIndicator			*__weak audioLevelMeter;
	
	AVCaptureSession			*session;
	AVCaptureDeviceInput		*videoDeviceInput;
	AVCaptureDeviceInput		*audioDeviceInput;
	AVCaptureMovieFileOutput	*movieFileOutput;
	AVCaptureAudioPreviewOutput	*audioPreviewOutput;
	
	NSArray						*videoDevices;
	NSArray						*audioDevices;
	
	NSTimer						*__weak audioLevelTimer;
	
	NSArray						*observers;
}

#pragma mark Device Selection
@property (strong) NSArray *videoDevices;
@property (strong) NSArray *audioDevices;
@property (weak) AVCaptureDevice *selectedVideoDevice;
@property (weak) AVCaptureDevice *selectedAudioDevice;

#pragma mark - Device Properties
@property (weak) AVCaptureDeviceFormat *videoDeviceFormat;
@property (weak) AVCaptureDeviceFormat *audioDeviceFormat;
@property (weak) AVFrameRateRange *frameRateRange;
- (IBAction)lockVideoDeviceForConfiguration:(id)sender;

#pragma mark - Recording
@property (strong) AVCaptureSession *session;
@property (weak, readonly) NSArray *availableSessionPresets;
@property (readonly) BOOL hasRecordingDevice;
@property (assign,getter=isRecording) BOOL recording;

#pragma mark - Preview
@property (weak) IBOutlet NSView *previewView;
@property (assign) float previewVolume;
@property (weak) IBOutlet NSLevelIndicator *audioLevelMeter;

#pragma mark - Transport Controls
@property (readonly,getter=isPlaying) BOOL playing;
@property (readonly,getter=isRewinding) BOOL rewinding;
@property (readonly,getter=isFastForwarding) BOOL fastForwarding;
- (IBAction)stop:(id)sender;

@end
