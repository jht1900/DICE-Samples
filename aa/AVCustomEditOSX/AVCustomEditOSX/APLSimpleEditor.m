/*
     File: APLSimpleEditor.m
 Abstract:  Simple editor setups a AVMutableComposition using supplied clips and time ranges. It also setups AVVideoComposition to perform custom compositor rendering. 
Version: 1.1 2013 
 */

#import "APLSimpleEditor.h"
#import "APLCustomVideoCompositor.h"
#import "APLCustomVideoCompositionInstruction.h"
#import <CoreMedia/CoreMedia.h>

@interface APLSimpleEditor ()

@property (nonatomic, readwrite, retain) AVMutableComposition *composition;
@property (nonatomic, readwrite, retain) AVMutableVideoComposition *videoComposition;

@end

@implementation APLSimpleEditor

- (instancetype)init
{
    if ((self = [super init])) {
        // initialization
    }
    return self;
}

- (void)buildTransitionComposition:(AVMutableComposition *)composition andVideoComposition:(AVMutableVideoComposition *)videoComposition
{
    CMTime nextClipStartTime = kCMTimeZero;
    NSInteger i;
    NSUInteger clipsCount = _clips.count;
    
    // Make transitionDuration no greater than half the shortest clip duration.
    CMTime transitionDuration = self.transitionDuration;
    for (i = 0; i < clipsCount; i++ ) {
        NSValue *clipTimeRange = _clipTimeRanges[i];
        if (clipTimeRange) {
            CMTime halfClipDuration = clipTimeRange.CMTimeRangeValue.duration;
            halfClipDuration.timescale *= 2; // You can halve a rational by doubling its denominator.
            transitionDuration = CMTimeMinimum(transitionDuration, halfClipDuration);
        }
    }
    
    // Add two video tracks and two audio tracks.
    AVMutableCompositionTrack *compositionVideoTracks[2];
    AVMutableCompositionTrack *compositionAudioTracks[2];
    compositionVideoTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionVideoTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionAudioTracks[0] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    compositionAudioTracks[1] = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    
    CMTimeRange *passThroughTimeRanges = alloca(sizeof(CMTimeRange) * clipsCount);
    CMTimeRange *transitionTimeRanges = alloca(sizeof(CMTimeRange) * clipsCount);
    
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    for (i = 0; i < clipsCount; i++ ) {
        NSInteger alternatingIndex = i % 2; // alternating targets: 0, 1, 0, 1, ...
        AVURLAsset *asset = _clips[i];
        NSValue *clipTimeRange = _clipTimeRanges[i];
        CMTimeRange timeRangeInAsset;
        if (clipTimeRange)
            timeRangeInAsset = clipTimeRange.CMTimeRangeValue;
        else
            timeRangeInAsset = CMTimeRangeMake(kCMTimeZero, asset.duration);
        
        AVAssetTrack *clipVideoTrack = [asset tracksWithMediaType:AVMediaTypeVideo][0];
        [compositionVideoTracks[alternatingIndex] insertTimeRange:timeRangeInAsset ofTrack:clipVideoTrack atTime:nextClipStartTime error:nil];
        
        AVAssetTrack *clipAudioTrack = [asset tracksWithMediaType:AVMediaTypeAudio][0];
        [compositionAudioTracks[alternatingIndex] insertTimeRange:timeRangeInAsset ofTrack:clipAudioTrack atTime:nextClipStartTime error:nil];
        
        // Remember the time range in which this clip should pass through.
        // Second clip begins with a transition.
        // First clip ends with a transition.
        // Exclude those transitions from the pass through time ranges.
        passThroughTimeRanges[i] = CMTimeRangeMake(nextClipStartTime, timeRangeInAsset.duration);
        if (i > 0) {
            passThroughTimeRanges[i].start = CMTimeAdd(passThroughTimeRanges[i].start, transitionDuration);
            passThroughTimeRanges[i].duration = CMTimeSubtract(passThroughTimeRanges[i].duration, transitionDuration);
        }
        if (i+1 < clipsCount) {
            passThroughTimeRanges[i].duration = CMTimeSubtract(passThroughTimeRanges[i].duration, transitionDuration);
        }
        
        // The end of this clip will overlap the start of the next by transitionDuration.
        // (Note: this arithmetic falls apart if timeRangeInAsset.duration < 2 * transitionDuration.)
        nextClipStartTime = CMTimeAdd(nextClipStartTime, timeRangeInAsset.duration);
        nextClipStartTime = CMTimeSubtract(nextClipStartTime, transitionDuration);
        
        // Remember the time range for the transition to the next item.
        if (i+1 < clipsCount) {
            transitionTimeRanges[i] = CMTimeRangeMake(nextClipStartTime, transitionDuration);
        }
    }
    
    // Set up the video composition if we are to perform crossfade transitions between clips.
    NSMutableArray *instructions = [NSMutableArray array];

    // Cycle between "pass through A", "transition from A to B", "pass through B"
    for (i = 0; i < clipsCount; i++ ) {
        NSInteger alternatingIndex = i % 2; // alternating targets
        
        if (videoComposition.customVideoCompositorClass) {
            APLCustomVideoCompositionInstruction *videoInstruction = [[APLCustomVideoCompositionInstruction alloc] initPassThroughTrackID:compositionVideoTracks[alternatingIndex].trackID forTimeRange:passThroughTimeRanges[i]];
            [instructions addObject:videoInstruction];
        }
        else {
            // Pass through clip i.
            AVMutableVideoCompositionInstruction *passThroughInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
            passThroughInstruction.timeRange = passThroughTimeRanges[i];
            AVMutableVideoCompositionLayerInstruction *passThroughLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTracks[alternatingIndex]];
            
            passThroughInstruction.layerInstructions = @[passThroughLayer];
            [instructions addObject:passThroughInstruction];
        }
        
        if (i+1 < clipsCount) {
            // Add transition from clip i to clip i+1.
            
            if (videoComposition.customVideoCompositorClass) {
                APLCustomVideoCompositionInstruction *videoInstruction = [[APLCustomVideoCompositionInstruction alloc] initTransitionWithSourceTrackIDs:@[@(compositionVideoTracks[0].trackID), @(compositionVideoTracks[1].trackID)] forTimeRange:transitionTimeRanges[i]];
                if (alternatingIndex == 0) {
                    // First track -> Foreground track while compositing
                    videoInstruction.foregroundTrackID = compositionVideoTracks[alternatingIndex].trackID;
                    // Second track -> Background track while compositing
                    videoInstruction.backgroundTrackID = compositionVideoTracks[1-alternatingIndex].trackID;
                }
                
                [instructions addObject:videoInstruction];
            }
            else {
                AVMutableVideoCompositionInstruction *transitionInstruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
                transitionInstruction.timeRange = transitionTimeRanges[i];
                AVMutableVideoCompositionLayerInstruction *fromLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTracks[alternatingIndex]];
                AVMutableVideoCompositionLayerInstruction *toLayer = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTracks[1-alternatingIndex]];
                
                transitionInstruction.layerInstructions = @[fromLayer, toLayer];
                [instructions addObject:transitionInstruction];
            }
        }        
    }
    
    videoComposition.instructions = instructions;
}

- (void)buildCompositionObjectsForPlayback
{
    if ( (_clips == nil) || _clips.count == 0 ) {
        self.composition = nil;
        self.videoComposition = nil;
        return;
    }
    
    CGSize videoSize = [_clips[0] naturalSize];
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVMutableVideoComposition *videoComposition = nil;
        
    composition.naturalSize = videoSize;
    
    // With transitions:
    // Place clips into alternating video & audio tracks in composition, overlapped by transitionDuration.
    // Set up the video composition to cycle between "pass through A", "transition from A to B",
    // "pass through B"
    
    videoComposition = [AVMutableVideoComposition videoComposition];
    
    if (self.transitionType == 0) { // Diagonal Wipe
        videoComposition.customVideoCompositorClass = [APLDiagonalWipeCompositor class];
    } else { // Cross Dissolve
        videoComposition.customVideoCompositorClass = [APLCrossDissolveCompositor class];
    }
    
    [self buildTransitionComposition:composition andVideoComposition:videoComposition];

    if (videoComposition) {
        // Every videoComposition needs these properties to be set:
        videoComposition.frameDuration = CMTimeMake(1, 30); // 30 fps
        videoComposition.renderSize = videoSize;
    }
    
    self.composition = composition;
    self.videoComposition = videoComposition;
}

- (AVPlayerItem *)getPlayerItem
{
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:self.composition];
    playerItem.videoComposition = self.videoComposition;
    
    return playerItem;
}

@end
