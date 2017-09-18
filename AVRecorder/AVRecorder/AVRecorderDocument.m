/*
     File: AVRecorderDocument.m
 Abstract: n/a
 Version: 2.1 2012 
 */

#import "AVRecorderDocument.h"
#import <AVFoundation/AVFoundation.h>

@interface AVRecorderDocument () <AVCaptureFileOutputDelegate, AVCaptureFileOutputRecordingDelegate>

// Properties for internal use
@property (strong) AVCaptureDeviceInput *videoDeviceInput;
@property (strong) AVCaptureDeviceInput *audioDeviceInput;
@property (readonly) BOOL selectedVideoDeviceProvidesAudio;
@property (strong) AVCaptureAudioPreviewOutput *audioPreviewOutput;
@property (strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (weak) NSTimer *audioLevelTimer;
@property (strong) NSArray *observers;

// Methods for internal use
- (void)refreshDevices;
- (void)setTransportMode:(AVCaptureDeviceTransportControlsPlaybackMode)playbackMode speed:(AVCaptureDeviceTransportControlsSpeed)speed forDevice:(AVCaptureDevice *)device;

@end

@implementation AVRecorderDocument

@synthesize videoDeviceInput;
@synthesize audioDeviceInput;
@synthesize videoDevices;
@synthesize audioDevices;
@synthesize session;
@synthesize audioLevelMeter;
@synthesize audioPreviewOutput;
@synthesize movieFileOutput;
@synthesize previewView;
@synthesize previewLayer;
@synthesize audioLevelTimer;
@synthesize observers;

- (instancetype)init
{
	self = [super init];
	if (self) {
		// Create a capture session
		session = [[AVCaptureSession alloc] init];
		
		// Capture Notification Observers
		NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
		id runtimeErrorObserver = [notificationCenter addObserverForName:AVCaptureSessionRuntimeErrorNotification
																  object:session
																   queue:[NSOperationQueue mainQueue]
															  usingBlock:^(NSNotification *note) {
																  dispatch_async(dispatch_get_main_queue(), ^(void) {
																	  [self presentError:note.userInfo[AVCaptureSessionErrorKey]];
																  });
															  }];
		id didStartRunningObserver = [notificationCenter addObserverForName:AVCaptureSessionDidStartRunningNotification
																	 object:session
																	  queue:[NSOperationQueue mainQueue]
																 usingBlock:^(NSNotification *note) {
																	 NSLog(@"did start running");
																 }];
		id didStopRunningObserver = [notificationCenter addObserverForName:AVCaptureSessionDidStopRunningNotification
																	object:session
																	 queue:[NSOperationQueue mainQueue]
																usingBlock:^(NSNotification *note) {
																	NSLog(@"did stop running");
																}];
		id deviceWasConnectedObserver = [notificationCenter addObserverForName:AVCaptureDeviceWasConnectedNotification
																		object:nil
																		 queue:[NSOperationQueue mainQueue]
																	usingBlock:^(NSNotification *note) {
																		[self refreshDevices];
																	}];
		id deviceWasDisconnectedObserver = [notificationCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification
																		   object:nil
																			queue:[NSOperationQueue mainQueue]
																	   usingBlock:^(NSNotification *note) {
																		   [self refreshDevices];
																	   }];
		observers = @[runtimeErrorObserver, didStartRunningObserver, didStopRunningObserver, deviceWasConnectedObserver, deviceWasDisconnectedObserver];
		
		// Attach outputs to session
		movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
		movieFileOutput.delegate = self;
		[session addOutput:movieFileOutput];
		
		audioPreviewOutput = [[AVCaptureAudioPreviewOutput alloc] init];
		audioPreviewOutput.volume = 0.f;
		[session addOutput:audioPreviewOutput];
		
		// Select devices if any exist
		AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
		if (videoDevice) {
			self.selectedVideoDevice = videoDevice;
			self.selectedAudioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
		} else {
			self.selectedVideoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeMuxed];
		}
		
		// Initial refresh of device list
		[self refreshDevices];
	}
	return self;
}

- (void)windowWillClose:(NSNotification *)notification
{
	// Invalidate the level meter timer here to avoid a retain cycle
	[self.audioLevelTimer invalidate];
	
	// Stop the session
	[self.session stopRunning];
	
	// Set movie file output delegate to nil to avoid a dangling pointer
	[self.movieFileOutput setDelegate:nil];
	
	// Remove Observers
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	for (id observer in self.observers)
		[notificationCenter removeObserver:observer];
}


- (NSString *)windowNibName
{
	return @"AVRecorderDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
	[super windowControllerDidLoadNib:aController];
	
	// Attach preview to session
	CALayer *previewViewLayer = self.previewView.layer;
	previewViewLayer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
	AVCaptureVideoPreviewLayer *newPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
	newPreviewLayer.frame = previewViewLayer.bounds;
	newPreviewLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
	[previewViewLayer addSublayer:newPreviewLayer];
	self.previewLayer = newPreviewLayer;
	
	// Start the session
	[self.session startRunning];
	
	// Start updating the audio level meter
	self.audioLevelTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f target:self selector:@selector(updateAudioLevels:) userInfo:nil repeats:YES];
}

- (void)didPresentErrorWithRecovery:(BOOL)didRecover contextInfo:(void  *)contextInfo
{
	// Do nothing
}

#pragma mark - Device selection
- (void)refreshDevices
{
	self.videoDevices = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] arrayByAddingObjectsFromArray:[AVCaptureDevice devicesWithMediaType:AVMediaTypeMuxed]];
	self.audioDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
	
	[self.session beginConfiguration];
	
	if (![self.videoDevices containsObject:self.selectedVideoDevice])
		[self setSelectedVideoDevice:nil];
	
	if (![self.audioDevices containsObject:self.selectedAudioDevice])
		[self setSelectedAudioDevice:nil];
	
	[self.session commitConfiguration];
}

- (AVCaptureDevice *)selectedVideoDevice
{
	return videoDeviceInput.device;
}

- (void)setSelectedVideoDevice:(AVCaptureDevice *)selectedVideoDevice
{
	[self.session beginConfiguration];
	
	if (self.videoDeviceInput) {
		// Remove the old device input from the session
		[session removeInput:self.videoDeviceInput];
		[self setVideoDeviceInput:nil];
	}
	
	if (selectedVideoDevice) {
		NSError *error = nil;
		
		// Create a device input for the device and add it to the session
		AVCaptureDeviceInput *newVideoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:selectedVideoDevice error:&error];
		if (newVideoDeviceInput == nil) {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self presentError:error];
			});
		} else {
			if (![selectedVideoDevice supportsAVCaptureSessionPreset:session.sessionPreset])
				self.session.sessionPreset = AVCaptureSessionPresetHigh;
			
			[self.session addInput:newVideoDeviceInput];
			self.videoDeviceInput = newVideoDeviceInput;
		}
	}
	
	// If this video device also provides audio, don't use another audio device
	if (self.selectedVideoDeviceProvidesAudio)
		[self setSelectedAudioDevice:nil];
	
	[self.session commitConfiguration];
}

- (AVCaptureDevice *)selectedAudioDevice
{
	return audioDeviceInput.device;
}

- (void)setSelectedAudioDevice:(AVCaptureDevice *)selectedAudioDevice
{
	[self.session beginConfiguration];
	
	if (self.audioDeviceInput) {
		// Remove the old device input from the session
		[session removeInput:self.audioDeviceInput];
		[self setAudioDeviceInput:nil];
	}
	
	if (selectedAudioDevice && !self.selectedVideoDeviceProvidesAudio) {
		NSError *error = nil;
		
		// Create a device input for the device and add it to the session
		AVCaptureDeviceInput *newAudioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:selectedAudioDevice error:&error];
		if (newAudioDeviceInput == nil) {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self presentError:error];
			});
		} else {
			if (![selectedAudioDevice supportsAVCaptureSessionPreset:session.sessionPreset])
				self.session.sessionPreset = AVCaptureSessionPresetHigh;
			
			[self.session addInput:newAudioDeviceInput];
			self.audioDeviceInput = newAudioDeviceInput;
		}
	}
	
	[self.session commitConfiguration];
}

#pragma mark - Device Properties

+ (NSSet *)keyPathsForValuesAffectingSelectedVideoDeviceProvidesAudio
{
	return [NSSet setWithObjects:@"selectedVideoDevice", nil];
}

- (BOOL)selectedVideoDeviceProvidesAudio
{
	return ([self.selectedVideoDevice hasMediaType:AVMediaTypeMuxed] || [self.selectedVideoDevice hasMediaType:AVMediaTypeAudio]);
}

+ (NSSet *)keyPathsForValuesAffectingVideoDeviceFormat
{
	return [NSSet setWithObjects:@"selectedVideoDevice.activeFormat", nil];
}

- (AVCaptureDeviceFormat *)videoDeviceFormat
{
	return self.selectedVideoDevice.activeFormat;
}

- (void)setVideoDeviceFormat:(AVCaptureDeviceFormat *)deviceFormat
{
	NSError *error = nil;
	AVCaptureDevice *videoDevice = self.selectedVideoDevice;
	if ([videoDevice lockForConfiguration:&error]) {
		videoDevice.activeFormat = deviceFormat;
		[videoDevice unlockForConfiguration];
	} else {
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self presentError:error];
		});
	}
}

+ (NSSet *)keyPathsForValuesAffectingAudioDeviceFormat
{
	return [NSSet setWithObjects:@"selectedAudioDevice.activeFormat", nil];
}

- (AVCaptureDeviceFormat *)audioDeviceFormat
{
	return self.selectedAudioDevice.activeFormat;
}

- (void)setAudioDeviceFormat:(AVCaptureDeviceFormat *)deviceFormat
{
	NSError *error = nil;
	AVCaptureDevice *audioDevice = self.selectedAudioDevice;
	if ([audioDevice lockForConfiguration:&error]) {
		audioDevice.activeFormat = deviceFormat;
		[audioDevice unlockForConfiguration];
	} else {
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self presentError:error];
		});
	}
}

+ (NSSet *)keyPathsForValuesAffectingFrameRateRange
{
	return [NSSet setWithObjects:@"selectedVideoDevice.activeFormat.videoSupportedFrameRateRanges", @"selectedVideoDevice.activeVideoMinFrameDuration", nil];
}

- (AVFrameRateRange *)frameRateRange
{
	AVFrameRateRange *activeFrameRateRange = nil;
	for (AVFrameRateRange *frameRateRange in self.selectedVideoDevice.activeFormat.videoSupportedFrameRateRanges)
	{
		if (CMTIME_COMPARE_INLINE([frameRateRange minFrameDuration], ==, [[self selectedVideoDevice] activeVideoMinFrameDuration]))
		{
			activeFrameRateRange = frameRateRange;
			break;
		}
	}
	
	return activeFrameRateRange;
}

- (void)setFrameRateRange:(AVFrameRateRange *)frameRateRange
{
	NSError *error = nil;
	if ([self.selectedVideoDevice.activeFormat.videoSupportedFrameRateRanges containsObject:frameRateRange])
	{
		if ([self.selectedVideoDevice lockForConfiguration:&error]) {
			self.selectedVideoDevice.activeVideoMinFrameDuration = frameRateRange.minFrameDuration;
			[self.selectedVideoDevice unlockForConfiguration];
		} else {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self presentError:error];
			});
		}
	}
}

- (IBAction)lockVideoDeviceForConfiguration:(id)sender
{
	if (((NSButton *)sender).state == NSOnState)
	{
		[self.selectedVideoDevice lockForConfiguration:nil];
	}
	else
	{
		[self.selectedVideoDevice unlockForConfiguration];
	}
}

#pragma mark - Recording

+ (NSSet *)keyPathsForValuesAffectingHasRecordingDevice
{
	return [NSSet setWithObjects:@"selectedVideoDevice", @"selectedAudioDevice", nil];
}

- (BOOL)hasRecordingDevice
{
	return ((videoDeviceInput != nil) || (audioDeviceInput != nil));
}

+ (NSSet *)keyPathsForValuesAffectingRecording
{
	return [NSSet setWithObject:@"movieFileOutput.recording"];
}

- (BOOL)isRecording
{
	return self.movieFileOutput.recording;
}

- (void)setRecording:(BOOL)record
{
	if (record) {
		// Record to a temporary file, which the user will relocate when recording is finished
		char *tempNameBytes = tempnam(NSTemporaryDirectory().fileSystemRepresentation, "AVRecorder_");
		NSString *tempName = [[NSString alloc] initWithBytesNoCopy:tempNameBytes length:strlen(tempNameBytes) encoding:NSUTF8StringEncoding freeWhenDone:YES];
		
		[self.movieFileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:[tempName stringByAppendingPathExtension:@"mov"]]
											recordingDelegate:self];
	} else {
		[self.movieFileOutput stopRecording];
	}
}

+ (NSSet *)keyPathsForValuesAffectingAvailableSessionPresets
{
	return [NSSet setWithObjects:@"selectedVideoDevice", @"selectedAudioDevice", nil];
}

- (NSArray *)availableSessionPresets
{
	NSArray *allSessionPresets = @[AVCaptureSessionPresetLow,
								  AVCaptureSessionPresetMedium,
								  AVCaptureSessionPresetHigh,
								  AVCaptureSessionPreset320x240,
								  AVCaptureSessionPreset352x288,
								  AVCaptureSessionPreset640x480,
								  AVCaptureSessionPreset960x540,
								  AVCaptureSessionPreset1280x720,
								  AVCaptureSessionPresetPhoto];
	
	NSMutableArray *availableSessionPresets = [NSMutableArray arrayWithCapacity:9];
	for (NSString *sessionPreset in allSessionPresets) {
		if ([self.session canSetSessionPreset:sessionPreset])
			[availableSessionPresets addObject:sessionPreset];
	}
	
	return availableSessionPresets;
}

#pragma mark - Audio Preview

- (float)previewVolume
{
	return self.audioPreviewOutput.volume;
}

- (void)setPreviewVolume:(float)newPreviewVolume
{
	self.audioPreviewOutput.volume = newPreviewVolume;
}

- (void)updateAudioLevels:(NSTimer *)timer
{
	NSInteger channelCount = 0;
	float decibels = 0.f;
	
	// Sum all of the average power levels and divide by the number of channels
	for (AVCaptureConnection *connection in self.movieFileOutput.connections) {
		for (AVCaptureAudioChannel *audioChannel in connection.audioChannels) {
			decibels += audioChannel.averagePowerLevel;
			channelCount += 1;
		}
	}
	
	decibels /= channelCount;
	
	self.audioLevelMeter.floatValue = (pow(10.f, 0.05f * decibels) * 20.0f);
}

#pragma mark - Transport Controls

- (IBAction)stop:(id)sender
{
	[self setTransportMode:AVCaptureDeviceTransportControlsNotPlayingMode speed:0.f forDevice:self.selectedVideoDevice];
}

+ (NSSet *)keyPathsForValuesAffectingPlaying
{
	return [NSSet setWithObjects:@"selectedVideoDevice.transportControlsPlaybackMode", @"selectedVideoDevice.transportControlsSpeed",nil];
}

- (BOOL)isPlaying
{
	AVCaptureDevice *device = self.selectedVideoDevice;
	return (device.transportControlsSupported &&
			device.transportControlsPlaybackMode == AVCaptureDeviceTransportControlsPlayingMode &&
			device.transportControlsSpeed == 1.f);
}

- (void)setPlaying:(BOOL)play
{
	AVCaptureDevice *device = self.selectedVideoDevice;
	[self setTransportMode:AVCaptureDeviceTransportControlsPlayingMode speed:play ? 1.f : 0.f forDevice:device];
}

+ (NSSet *)keyPathsForValuesAffectingRewinding
{
	return [NSSet setWithObjects:@"selectedVideoDevice.transportControlsPlaybackMode", @"selectedVideoDevice.transportControlsSpeed",nil];
}

- (BOOL)isRewinding
{
	AVCaptureDevice *device = self.selectedVideoDevice;
	return device.transportControlsSupported && (device.transportControlsSpeed < -1.f);
}

- (void)setRewinding:(BOOL)rewind
{
	AVCaptureDevice *device = self.selectedVideoDevice;
	[self setTransportMode:device.transportControlsPlaybackMode speed:rewind ? -2.f : 0.f forDevice:device];
}

+ (NSSet *)keyPathsForValuesAffectingFastForwarding
{
	return [NSSet setWithObjects:@"selectedVideoDevice.transportControlsPlaybackMode", @"selectedVideoDevice.transportControlsSpeed",nil];
}

- (BOOL)isFastForwarding
{
	AVCaptureDevice *device = self.selectedVideoDevice;
	return device.transportControlsSupported && (device.transportControlsSpeed > 1.f);
}

- (void)setFastForwarding:(BOOL)fastforward
{
	AVCaptureDevice *device = self.selectedVideoDevice;
	[self setTransportMode:device.transportControlsPlaybackMode speed:fastforward ? 2.f : 0.f forDevice:device];
}

- (void)setTransportMode:(AVCaptureDeviceTransportControlsPlaybackMode)playbackMode speed:(AVCaptureDeviceTransportControlsSpeed)speed forDevice:(AVCaptureDevice *)device
{
	NSError *error = nil;
	if (device.transportControlsSupported) {
		if ([device lockForConfiguration:&error]) {
			[device setTransportControlsPlaybackMode:playbackMode speed:speed];
			[device unlockForConfiguration];
		} else {
			dispatch_async(dispatch_get_main_queue(), ^(void) {
				[self presentError:error];
			});
		}
	}
}

#pragma mark - Delegate methods

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
	NSLog(@"Did start recording to %@", fileURL.description);
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didPauseRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
	NSLog(@"Did pause recording to %@", fileURL.description);
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didResumeRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
	NSLog(@"Did resume recording to %@", fileURL.description);
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput willFinishRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections dueToError:(NSError *)error
{
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self presentError:error];
	});
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)recordError
{
	if (recordError != nil && [recordError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] boolValue] == NO) {
		[[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self presentError:recordError];
		});
	} else {
		// Move the recorded temporary file to a user-specified location
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		savePanel.allowedFileTypes = @[AVFileTypeQuickTimeMovie];
		[savePanel setCanSelectHiddenExtension:YES];
		[savePanel beginSheetModalForWindow:self.windowForSheet completionHandler:^(NSInteger result) {
			NSError *error = nil;
			if (result == NSOKButton) {
				[[NSFileManager defaultManager] removeItemAtURL:savePanel.URL error:nil]; // attempt to remove file at the desired save location before moving the recorded file to that location
				if ([[NSFileManager defaultManager] moveItemAtURL:outputFileURL toURL:savePanel.URL error:&error]) {
					[[NSWorkspace sharedWorkspace] openURL:savePanel.URL];
				} else {
					[savePanel orderOut:self];
					[self presentError:error modalForWindow:self.windowForSheet delegate:self didPresentSelector:@selector(didPresentErrorWithRecovery:contextInfo:) contextInfo:NULL];
				}
			} else {
				// remove the temporary recording file if it's not being saved
				[[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
			}
		}];
	}
}

- (BOOL)captureOutputShouldProvideSampleAccurateRecordingStart:(AVCaptureOutput *)captureOutput
{
    // We don't require frame accurate start when we start a recording. If we answer YES, the capture output
    // applies outputSettings immediately when the session starts previewing, resulting in higher CPU usage
    // and shorter battery life.
    return NO;
}

@end
