//
//  AppDelegate.h
//  Zipper
//
//  Created by finucane on 12/5/12.
//  Copyright (c) 2012 finucane. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Zipper.h"
@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate>
{
  @private
  Zipper*zipper;
}
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) ViewController *viewController;
@end
