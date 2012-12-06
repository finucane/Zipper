//
//  Zipper.h
//  Zipper
//
//  Created by finucane on 12/5/12.
//  Copyright (c) 2012 finucane. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface Zipper : UIControl
{
  @private
  
  /*the control value which is settable and ranges from 0 .. 1*/
  float value;
  
  /*bezier curve points computed in drawRect and used all over for drawing*/
  CGPoint leftP0, leftP1, leftCP;
  CGPoint rightP0, rightP1, rightCP;
  
  /*so we know if the zipper is being moved*/
  BOOL isTracking;
  
  /*so the zipper handle doesn't jump when the user starts to slide it*/
  CGPoint startPoint;
  float startValue;
  
  UIImage*toothImage;
  UIImage*handleImage;
  UIImage*selectedHandleImage;

  UIImage*patternImage;
}
@property (nonatomic) float value;

@end
