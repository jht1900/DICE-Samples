/*
     File: APLAppDelegate.h
 Abstract:  The app delegate which handles setup, playback and export of AVMutableComposition along with other user interactions like scrubbing, toggling play/pause, selecting transition type. 
Version: 1.1 2013 
 */

#import <Cocoa/Cocoa.h>
#import <AVKit/AVPlayerView.h>

@interface APLAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property IBOutlet AVPlayerView *playerView;

@end
