/*
     File: AVVideoWall+TerminalIO.m
 Abstract: An AVVideoWall category, responsible for setting up terminal I/O for the command line application
 Version: 1.1 2011
 
 */

#import "AVVideoWall+TerminalIO.h"

#include <termios.h>

@implementation AVVideoWall (TerminalIO)

struct termios	termsettings_orig;
struct termios	termsettings_cbreak;

static void restoreTermIOState(void)
{
	tcsetattr(0, TCSANOW, &termsettings_orig);
}

static void signalHandler(int sig)
{
	restoreTermIOState();
}

- (BOOL)run
{
	__block  BOOL quit = NO;
	dispatch_queue_t keyboardInputQueue = dispatch_queue_create("keyboard input queue", DISPATCH_QUEUE_SERIAL);
    // Start running the capture session
	[_session startRunning];
	
	dispatch_async(keyboardInputQueue, ^(void) {
		atexit(restoreTermIOState);
		signal(SIGHUP, signalHandler);
		signal(SIGINT, signalHandler);
		
		// stash current termios state, switch to cbreak mode
		tcgetattr(0, &termsettings_orig);
		termsettings_cbreak = termsettings_orig;
		termsettings_cbreak.c_lflag &= ~(ICANON | ECHO); // non-canonical mode, disable echo
		termsettings_cbreak.c_cc[VTIME] = 0; // tenths of seconds between bytes
		termsettings_cbreak.c_cc[VMIN] = 1; // num of chars received before returning
		tcsetattr(0, TCSANOW, &termsettings_cbreak);
		
		while ( !quit ) {
			int curChar = getchar();
			switch (curChar) {
				case ' ':
                    // If the layers are flying around
					if ( _spinningLayers ) {
						dispatch_async(dispatch_get_main_queue(), ^(void) {
							_spinningLayers = NO;
                            // Reset the layers
							[self sendLayersHome];
						});
					}
                    // If the layers are at their initial positions
					else {
						dispatch_async(dispatch_get_main_queue(), ^(void) {
							_spinningLayers = YES;
                            // Spin the layers
							[self spinLayers];
						});
					}
					break;
				case 'q':
				case 'Q':
					quit = YES;
					break;
					
				default:
					break;
			}
		}
	});
	
	while ( !quit ) {
		NSDate* halfASecondFromNow = [[NSDate alloc] initWithTimeIntervalSinceNow:.5];
		[[NSRunLoop currentRunLoop] runUntilDate:halfASecondFromNow];
		halfASecondFromNow = nil;
	}
	NSLog(@"Quitting");
    // Stop running the capture session
	[_session stopRunning];
	dispatch_release(keyboardInputQueue);
	return YES;
}

@end
