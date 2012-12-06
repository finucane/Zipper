//
//  AppDelegate.m
//  Zipper
//
//  Created by finucane on 12/5/12.
//  Copyright (c) 2012 finucane. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "insist.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  // Override point for customization after application launch.
  self.viewController = [[ViewController alloc] initWithNibName:@"ViewController" bundle:nil];
  self.window.rootViewController = self.viewController;
  [self.window makeKeyAndVisible];
  
  /*make a zipper control. this ranges from 0.0 to 1.0 for simplicty*/
  zipper = [[Zipper alloc] initWithFrame:self.viewController.view.bounds];
  zipper.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [self.viewController.view addSubview:zipper];
  
  /*make sure we can't mess with content mode on this control*/
  zipper.contentMode = UIViewContentModeBottom;
  insist (zipper.contentMode == UIViewContentModeRedraw);
  
  /*add an action to the zipper control so we can see that it's working as a control*/
  [zipper addTarget:self action:@selector (updateLabel:) forControlEvents:UIControlEventValueChanged];
  
  return YES;
}

- (void)updateLabel:(Zipper*)id
{
  insist (id == zipper && zipper);
  insist (self.viewController.zipperValueLabel);
  
  self.viewController.zipperValueLabel.text = [NSString stringWithFormat:@"%f", zipper.value];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
  // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
  // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
  // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
  // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
  // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
