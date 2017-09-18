/*
     File: AVFrameRateRange_AVRecorderAdditions.m
 Abstract: n/a
 Version: 2.1 2012 
 */

#import "AVFrameRateRange_AVRecorderAdditions.h"

@implementation AVFrameRateRange (AVRecorderAdditions)

- (NSString *)localizedName
{
	if (self.minFrameRate != self.maxFrameRate) {
		NSString *formatString = NSLocalizedString(@"FPS: %0.2f-%0.2f", @"FPS when minFrameRate != maxFrameRate");
		return [NSString stringWithFormat:formatString, self.minFrameRate, self.maxFrameRate];
	}
	NSString *formatString = NSLocalizedString(@"FPS: %0.2f", @"FPS when minFrameRate == maxFrameRate");
	return [NSString stringWithFormat:formatString, self.minFrameRate];
}

@end
