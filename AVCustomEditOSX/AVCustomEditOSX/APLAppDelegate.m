/*
     File: APLAppDelegate.m
 Abstract:  The app delegate which handles setup, playback and export of AVMutableComposition along with other user interactions like scrubbing, toggling play/pause, selecting transition type. 
Version: 1.1 2013 
 */

#import "APLAppDelegate.h"
#import "APLSimpleEditor.h"
#import <AVFoundation/AVFoundation.h>

#define kDiagonalWipeTransition 0
#define kCrossDissolveTransition 1

@interface APLAppDelegate ()
{    
    float        _transitionDuration;
    NSInteger    _transitionType;
}

@property APLSimpleEditor *editor;
@property NSMutableArray *clips;
@property NSMutableArray *clipTimeRanges;

@property AVPlayer *player;
@property AVPlayerItem *playerItem;

@end

@implementation APLAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _editor = [[APLSimpleEditor alloc] init];
    _clips = [[NSMutableArray alloc] initWithCapacity:2];
    _clipTimeRanges = [[NSMutableArray alloc] initWithCapacity:2];
    
    // Default cross fade duration is set to 2.0 seconds
    _transitionDuration = 2.0;
    _transitionType = kDiagonalWipeTransition; // Default transition type is set Diagonal Wipe
    
    // Add clips to pass to the editor
    [self addClipsToEditor];
    
    // Initialize an AVPlayer and set it as the player on the AVPlayerView
    if (!self.player) {
        self.player = [[AVPlayer alloc] init];
        self.playerView.player = self.player;
    }
    
    // Synchronize the player with editor
    [self synchronizePlayerWithEditor];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:self.window];
    
    NSMenu *transitionMenu = [[NSMenu alloc] initWithTitle:@"Transitions Menu"];
    [transitionMenu insertItemWithTitle:@"Diagonal Wipe" action:@selector(respondToTransitionSelection:) keyEquivalent:@"" atIndex:kDiagonalWipeTransition];
    [transitionMenu insertItemWithTitle:@"Cross Dissolve" action:@selector(respondToTransitionSelection:) keyEquivalent:@"" atIndex:kCrossDissolveTransition];
    ((NSMenuItem *)transitionMenu.itemArray[kDiagonalWipeTransition]).state = NSOnState;
    self.playerView.actionPopUpButtonMenu = transitionMenu;
    
}

- (void)addClipsToEditor
{
    // The two assets in the projects bundle are used
    AVURLAsset *asset1 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"sample_clip1" ofType:@"m4v"]]];
    AVURLAsset *asset2 = [AVURLAsset assetWithURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"sample_clip2" ofType:@"mov"]]];
    
    // Set the timeRanges to 5 seconds each. Note: that we set our default transitionDuration to 2.0 seconds.
    [self.clips addObject:asset1];
    [self.clipTimeRanges addObject:[NSValue valueWithCMTimeRange:CMTimeRangeMake(CMTimeMakeWithSeconds(0, 1), CMTimeMakeWithSeconds(5, 1))]];
    
    [self.clips addObject:asset2];
    [self.clipTimeRanges addObject:[NSValue valueWithCMTimeRange:CMTimeRangeMake(CMTimeMakeWithSeconds(0, 1), CMTimeMakeWithSeconds(5, 1))]];
    
    // Synchronize these clips with the editor object.
    [self synchronizeWithEditor];
}

- (void)synchronizePlayerWithEditor
{
    AVPlayerItem *playerItem = nil;
    
    if ( self.player == nil )
        return;
    
    playerItem = [self.editor getPlayerItem];
    
    // Replace the currentItem with our playerItem on the player
    if (self.playerItem != playerItem) {
        self.playerItem = playerItem;
        [self.player replaceCurrentItemWithPlayerItem:playerItem];
    }
}

- (void)synchronizeWithEditor
{
    // Clips
    [self synchronizeEditorClipsWithOurClips];
    [self synchronizeEditorClipTimeRangesWithOurClipTimeRanges];
    
    // Transition
    self.editor.transitionDuration = CMTimeMakeWithSeconds(_transitionDuration, 600);
    self.editor.transitionType = _transitionType;
    
    [self.editor buildCompositionObjectsForPlayback];
    [self synchronizePlayerWithEditor];
}

- (void)synchronizeEditorClipsWithOurClips
{
    NSMutableArray *validClips = [NSMutableArray arrayWithCapacity:3];
    for (AVURLAsset *asset in self.clips) {
        if (![asset isKindOfClass:[NSNull class]]) {
            [validClips addObject:asset];
        }
    }
    
    self.editor.clips = validClips;
}

- (void)synchronizeEditorClipTimeRangesWithOurClipTimeRanges
{
    NSMutableArray *validClipTimeRanges = [NSMutableArray arrayWithCapacity:3];
    for (NSValue *timeRange in self.clipTimeRanges) {
        if (! [timeRange isKindOfClass:[NSNull class]]) {
            [validClipTimeRanges addObject:timeRange];
        }
    }
    
    self.editor.clipTimeRanges = validClipTimeRanges;
}

- (void)windowWillClose:(NSNotification*)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillCloseNotification object:self.window];
    self.window = nil;
    self.player = nil;
    self.editor = nil;
    self.playerView = nil;
}

- (void)respondToTransitionSelection:(NSMenuItem *)item
{
    for (NSMenuItem *menuItem in (self.playerView.actionPopUpButtonMenu).itemArray) {
        if (menuItem == item) {
            menuItem.state = NSOnState;
        } else {
            menuItem.state = NSOffState;
        }
    }
    
    // Index 0 is Diagonal Wipe
    // Index 1 is Cross Dissolve
    _transitionType = [self.playerView.actionPopUpButtonMenu indexOfItem:item];
    
    [self synchronizeWithEditor];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}

@end
