/*
     File: APLSimpleEditor.h
 Abstract:  Simple editor setups a AVMutableComposition using supplied clips and time ranges. It also setups AVVideoComposition to perform custom compositor rendering. 
Version: 1.1 2013 
 */

#import <Foundation/Foundation.h>

#import <CoreMedia/CMTime.h>
#import <AVFoundation/AVFoundation.h>

@interface APLSimpleEditor : NSObject

// Set these properties before building the composition objects.
@property (nonatomic, copy) NSArray *clips; // array of AVURLAssets
@property (nonatomic, copy) NSArray *clipTimeRanges; // array of CMTimeRanges stored in NSValues.

@property (nonatomic) NSInteger transitionType;
@property (nonatomic) CMTime transitionDuration;

@property (nonatomic, readonly, retain) AVMutableComposition *composition;
@property (nonatomic, readonly, retain) AVMutableVideoComposition *videoComposition;

// Builds the composition and videoComposition
- (void)buildCompositionObjectsForPlayback;

@property (NS_NONATOMIC_IOSONLY, getter=getPlayerItem, readonly, copy) AVPlayerItem *playerItem;

@end

