/*
     File: AppController.m
 Abstract: The UIApplication delegate class.
  Version: 1.13 2014 
*/

#import "AppController.h"
#import "PaintingViewController.h"

@implementation AppController

- (void)applicationDidFinishLaunching:(UIApplication*)application
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    
    PaintingViewController *controller = [[PaintingViewController alloc] initWithNibName:@"PaintingViewController" bundle:nil];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
}

@end
