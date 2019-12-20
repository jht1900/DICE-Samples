/*
     File: APLCustomVideoCompositionInstruction.h
 Abstract:  Custom video composition instruction class implementing AVVideoCompositionInstruction protocol. 
Version: 1.1 2013 
 */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface APLCustomVideoCompositionInstruction : NSObject <AVVideoCompositionInstruction>

@property CMPersistentTrackID foregroundTrackID;
@property CMPersistentTrackID backgroundTrackID;

- (instancetype)initPassThroughTrackID:(CMPersistentTrackID)passthroughTrackID forTimeRange:(CMTimeRange)timeRange NS_DESIGNATED_INITIALIZER;
- (instancetype)initTransitionWithSourceTrackIDs:(NSArray*)sourceTrackIDs forTimeRange:(CMTimeRange)timeRange NS_DESIGNATED_INITIALIZER;

@end
