/*
     File: SoundEffect.m
 Abstract: SoundEffect is a class that loads and plays sound files.
  Version: 1.13 2014 
*/

#import "SoundEffect.h"

@implementation SoundEffect

// Creates a sound effect object from the specified sound file
+ (instancetype)soundEffectWithContentsOfFile:(NSString *)aPath {
    if (aPath) {
        return [[SoundEffect alloc] initWithContentsOfFile:aPath];
    }
    return nil;
}

// Initializes a sound effect object with the contents of the specified sound file
- (instancetype)initWithContentsOfFile:(NSString *)path {
    self = [super init];
    
	// Gets the file located at the specified path.
    if (self != nil) {
        NSURL *aFileURL = [NSURL fileURLWithPath:path isDirectory:NO];
        
		// If the file exists, calls Core Audio to create a system sound ID.
        if (aFileURL != nil)  {
            SystemSoundID aSoundID;
            OSStatus error = AudioServicesCreateSystemSoundID((__bridge CFURLRef)aFileURL, &aSoundID);
            
            if (error == kAudioServicesNoError) { // success
                _soundID = aSoundID;
            } else {
                NSLog(@"Error %d loading sound at path: %@", (int)error, path);
                self = nil;
            }
        } else {
            NSLog(@"NSURL is nil for path: %@", path);
            self = nil;
        }
    }
    return self;
}

// Releases resouces when no longer needed.
-(void)dealloc {
    AudioServicesDisposeSystemSoundID(_soundID);
}

// Plays the sound associated with a sound effect object.
-(void)play {
	// Calls Core Audio to play the sound for the specified sound ID.
    AudioServicesPlaySystemSound(_soundID);
}

@end
