/*
     File: main.m
 Abstract: Application main entry point
  Version: 1.1 2011
 
 */

#import "AVVideoWall.h"
#import "AVVideoWall+TerminalIO.h"


#import <AssertMacros.h>

int main(int argc, char **argv) {
	BOOL success = NO;
	
	@autoreleasepool {
    
        // In a command line applicaton, NSApplicationLoad is required to get an NSWindow to become key and forefront.
        (void)NSApplicationLoad();
        
        AVVideoWall *wall = [[AVVideoWall alloc] init];
        success = [wall configure];
        if (success)
            success = [wall run];
    
	}                  
    return ( ! success );
}
