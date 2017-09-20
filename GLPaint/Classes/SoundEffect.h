/*
     File: SoundEffect.h
 Abstract: SoundEffect is a class that loads and plays sound files.
  Version: 1.13 2014 
*/

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioServices.h>

@interface SoundEffect : NSObject {
    SystemSoundID _soundID;
}

+ (instancetype)soundEffectWithContentsOfFile:(NSString *)aPath;
- (instancetype)initWithContentsOfFile:(NSString *)path NS_DESIGNATED_INITIALIZER;
- (void)play;

@end
