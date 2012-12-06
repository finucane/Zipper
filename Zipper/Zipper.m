//
//  Zipper.m
//  Zipper
//
//  Created by finucane on 12/5/12.
//  Copyright (c) 2012 finucane. All rights reserved.
//
//  This should be compiled with ARC enabled

#import "Zipper.h"
#import "insist.h"

#define EDGE_WIDTH 5
#define TOOTH_HEAD_WIDTH 10 //for this to actually work the tooth images have to be pixel accurate
#define MIN_TOUCH_DIMENSION 44

/*so this file can be read topdown.*/
@interface Zipper (PrivateMethods)
- (CGRect)getTouchRectForHandle;
- (float)getTopOfHandleInRect:(CGRect)rect;
- (void)recomputeBeziersInRect:(CGRect)rect;
- (void)drawEdgesToContext:(CGContextRef)context inRect:(CGRect)rect;
- (void)drawBackgroundToContext:(CGContextRef)context inRect:(CGRect)rect;
- (CGPoint)getBezierPointAndRadians:(float*)radians forT:(float)t p0:(CGPoint)p0 p1:(CGPoint)p1 p2:(CGPoint)p2;

@end


@implementation Zipper

@synthesize value;

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self)
  {
    value = 0.0;
    /*get our built-in images*/
    toothImage = [UIImage imageNamed:@"tooth.png"];
    insist (toothImage);
    handleImage = [UIImage imageNamed:@"handle.png"];
    insist (handleImage);
    selectedHandleImage = [UIImage imageNamed:@"handleSelected.png"];
    insist (selectedHandleImage);
    patternImage = [UIImage imageNamed:@"pattern.png"];
    insist (patternImage);
    
    self.opaque = NO;
    isTracking = NO;
    
    /*we are going to hardcode contentMode because we want this thing to
     call drawRect whenever its size changes. we'll override the setter property
     to make it so that this can't be disabled*/
    super.contentMode = UIViewContentModeRedraw;

  }
  return self;
}

-(void)setContentMode:(UIViewContentMode)contentMode
{
  NSLog(@"setContentMode is a no-op");
}

/*setter for value, just clamp it between 0,1 for our little control*/
-(void)setValue:(float)aValue
{
  if (aValue > 1.0)
    value = 1.0;
  
  else if (aValue < 0.0)
    value = 0.0;
  else value = aValue;
  
  [self setNeedsDisplay];
  
}


/*get the active region for the control and make sure it's big enough for fat fingers*/

- (CGRect)getTouchRectForHandle
{
  CGSize size = handleImage.size;
  if (size.width < MIN_TOUCH_DIMENSION)
    size.width = MIN_TOUCH_DIMENSION;
  if (size.height < MIN_TOUCH_DIMENSION)
    size.height = MIN_TOUCH_DIMENSION;
  
  return CGRectMake(self.bounds.size.width / 2.0 - size.width / 2.0,
                                 [self getTopOfHandleInRect:self.bounds] + handleImage.size.height / 2.0 - size.height,
                                 size.width,
                                 size.height);
}
/*
 uicontrol stuff. when we start a touch, we remember the initial position and value
 so we can reposition the handle image exactly throughout the tracking. we don't want
 it to initially jump if the initial touch is not in the center of the handle.
 
 we let tracking begin even if the handle isn't touched, so the user
 can slide into the handle.
 
 apparently none of these have to call super. not sure on this since we are subclassing uicontrol rather
 than uiview.
*/

- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
  /*get the touch position in our coord system*/
  CGPoint touchPoint = [touch locationInView:self];
  
  /*did we touch the handle*/
  isTracking = CGRectContainsPoint([self getTouchRectForHandle], touchPoint);
  
  if (isTracking)
  {
    startPoint = touchPoint;
    startValue = value;
  }
  [self setNeedsDisplay];
  return YES;
}

/*if we are really tracking, adjust the handle by adjusting the value
 programmatically. this will clamp the value in the legal range and trigger a redraw*/

- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
  /*check to see if we slid into the handle, be lazy and just fake a touchdown*/
  if (!isTracking)
  {
    [self beginTrackingWithTouch:touch withEvent:event];
  }
  
  if (!isTracking) return YES;
  
  CGPoint p = [touch locationInView:self];
  float delta = (p.y - startPoint.y) / self.bounds.size.height;
  self.value = startValue + delta;
  
  /*fire any events, this is a control after all*/
  [self sendActionsForControlEvents:UIControlEventValueChanged];
  return YES;
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
  isTracking = NO;
  [self setNeedsDisplay];
}

/*draw the zipper.
 
 we ignore "rect" and just draw into the view's bounds because we wouldn't even know how to be smart enough
 to ever draw into just a dirty subrect.
 
 the zipper curve is just a quadratic bezier where with 1 end point the top of the zipper handle, and the
 other end point moves from the midpoint of the top of the view towards the left or right end of the view
 as the zipper goes down. the control point slides down along the middle of the view halfway between
 the top of the zipper handle and the top of the view.
 
 this could be optimized by just drawing one half of the zipper into an offscreen bitman and mirroring it
 over, but because of the zipper teeth having to line up, that takes some brainpower.
 
 */
- (void)drawRect:(CGRect)rect
{
  rect = self.bounds; //always draw to our entire bounds
  
  /*first of all, recompute the bezier points so we can use these in all the drawing*/
  [self recomputeBeziersInRect:rect];
  
  CGContextRef context = UIGraphicsGetCurrentContext ();
  
  /*paint the entire rectangle transparent first*/
  CGContextClearRect(context, rect);
  
  /*draw the background of the zipper*/
  [self drawBackgroundToContext:context inRect:rect];
  
  /*draw the edges of the zipper on top of the background*/
  [self drawEdgesToContext:context inRect:rect];
  
  /*draw the teeth on top of the edges*/
  [self drawTeethToContext:context inRect:rect];
  
  /*draw the handle down the center of the rect on top of the teeth*/
  [isTracking ? selectedHandleImage : handleImage drawAtPoint: CGPointMake(rect.origin.x + rect.size.width / 2.0 - handleImage.size.width / 2.0, [self getTopOfHandleInRect:rect])];
}


/*get the y position of the top of the handle based on the control's value. this position is clamped so the handle can't run out of bounds*/
-(float) getTopOfHandleInRect:(CGRect)rect
{
  insist (value >= 0.0 && value <= 1.0);
  insist (handleImage);
  
  /*the range of valid Y values for drawing the image*/
  float heightRange = rect.size.height - handleImage.size.height;
  
  return rect.origin.y + heightRange * value;
}


/*compute the points for the left and right bezier curves. quartz2d does the right thing in stroking and filling paths in that
 the stroke thickness straddles the path
 */
- (void)recomputeBeziersInRect:(CGRect)rect
{
  /*get the y position of the top of the handle*/
  float topOfHandle = [self getTopOfHandleInRect:rect];
  
  /*offset it so the curves start under the middle of the fat part of handle*/
  topOfHandle += handleImage.size.height / 4.0;
  leftP0.x = rect.origin.x + rect.size.width / 2.0 - EDGE_WIDTH / 2.0,
  leftP0.y = topOfHandle;
  leftCP.x = rect.origin.x + rect.size.width / 2.0;
  leftCP.y = topOfHandle / 2;
  leftP1.x = rect.origin.x + (rect.size.width / 2.0) * (1.0 - value);
  leftP1.y = rect.origin.y - EDGE_WIDTH; //we let clipping do work trim the edge at the top of the rect.
  
  rightCP = leftCP;
  rightP0.x = rect.origin.x + rect.size.width / 2.0 + EDGE_WIDTH / 2.0;
  rightP0.y = topOfHandle;
  rightP1.x = (rect.origin.x + rect.size.width) - (rect.size.width / 2.0) * (1.0 - value);
  rightP1.y = rect.origin.y - EDGE_WIDTH;
  
  
}

/*
 draw the background of the zipper control, this is basically where, if the zipper were zipping up fabric,
 the fabric would be. the part of the view that the zipper is revealing is never drawn to, it remains
 transparent.
 */

- (void)drawBackgroundToContext:(CGContextRef)context inRect:(CGRect)rect
{
  /*save the graphic state because we are going to be setting the clipping path*/
  CGContextSaveGState(context);
  
  /*compute the background region by making a path that's the rectangle minus the little V shaped part between the bezier curves*/
  CGContextBeginPath (context);
  CGContextMoveToPoint(context, rect.origin.x, rect.origin.y + rect.size.height); //lower left
  CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y); //top left;
  
  CGContextAddLineToPoint(context, leftP1.x, leftP1.y); //top of left bezier
  CGContextAddQuadCurveToPoint (context,leftCP.x, leftCP.y, leftP0.x, leftP0.y); //bottom of left bezier
  CGContextAddLineToPoint(context, rightP0.x,rightP0.y); //bottom of right bezier
  CGContextAddQuadCurveToPoint (context, rightCP.x, rightCP.y, rightP1.x, rightP1.y); //top of right bezier
  CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y); //top right
  
  CGContextAddLineToPoint(context, rect.origin.x + rect.size.width, rect.origin.y + rect.size.height); //bottom right
  
  CGContextMoveToPoint(context, rect.origin.x, rect.origin.y + rect.size.height); //lower left again
  CGContextClosePath(context);
  CGContextClip (context); //clears path
  
  /*paint the pattern. ARC is fine with CGImage here.*/
  CGContextDrawTiledImage(context, rect, patternImage.CGImage);
  
  /*restore the gc*/
  CGContextRestoreGState (context);
}

/*draw the 2 edges of the zipper using thick black bezier curves going up to the right and left from above the handle,
 and below the handle straight down the rect*/
- (void)drawEdgesToContext:(CGContextRef)context inRect:(CGRect)rect
{
  /*save the graphic state because we are going to be setting line attribute stuff*/
  CGContextSaveGState(context);
  
  /*set line width and color*/
  CGContextSetLineWidth (context, EDGE_WIDTH);  //EDGE_WIDTH pixels thick
  CGContextSetRGBStrokeColor(context, 0, 0, 0, 1.0);//black
  
  /*draw left hand zipper edge*/
  CGContextMoveToPoint(context, leftP0.x,leftP0.y);
  CGContextAddQuadCurveToPoint (context,leftCP.x, leftCP.y, leftP1.x, leftP1.y);
  CGContextStrokePath (context); // clears path
  
  /*draw the right hand zipper edge*/
  CGContextMoveToPoint(context, rightP0.x,rightP0.y);
  CGContextAddQuadCurveToPoint (context, rightCP.x, rightCP.y, rightP1.x, rightP1.y);
  CGContextStrokePath (context); //clears path
  
  /*draw the zipper edges below the handle, they are just 2 straight lines going down*/
  
  /*left*/
  CGContextMoveToPoint(context, leftP0.x, leftP0.y);
  CGContextAddLineToPoint(context, leftP0.x, rect.origin.y + rect.size.height);
  CGContextStrokePath (context); //clears path
  
  /*right*/
  CGContextMoveToPoint(context, rightP0.x, rightP0.y);
  CGContextAddLineToPoint(context, rightP0.x, rect.origin.y + rect.size.height);
  CGContextStrokePath (context); //clears path
  
  /*restore the gc*/
  CGContextRestoreGState (context);
}

/*
 draw the teeth. the teeth above the handle go along the bezier curves. below the handle
 they just go straight down, interlocking and on top of each other, like a zipper
 */
- (void)drawTeethToContext:(CGContextRef)context inRect:(CGRect)rect
{
  /*get how many teeth the zipper has*/
  float totalTeeth = rect.size.height  / toothImage.size.height;
  
  /*
    get how many teeth are above the zipper handle. the height of the handle is
    already taken into account because of what "value" is allowed to be based.
   */
  
  float numTopTeeth = value * totalTeeth;
  
  /*we use the handle itself to hide how the teeth actually mate between
   the bezier and the straight part, these floats are for that sloppage */
  
  float numHandleTeeth = 1 + handleImage.size.height / toothImage.size.height;
  float numBottomTeeth = totalTeeth - numTopTeeth + numHandleTeeth;
  float middleOfHandle = [self getTopOfHandleInRect:rect] + handleImage.size.height / 2.0;
  
  
  /*draw the teeth under the handle, starting w/ the left side*/
  for (int i = 0; i < numBottomTeeth; i++)
  {
    CGContextSaveGState(context);
    
    /*left*/
    if (i % 2 == 0)
    {
      CGPoint p = CGPointMake (rect.origin.x + rect.size.width / 2.0 - (toothImage.size.width - TOOTH_HEAD_WIDTH),
                               rect.origin.y + rect.size.height - (i+1) * toothImage.size.height);
      
      if (p.y < middleOfHandle) continue;
      CGContextTranslateCTM (context, p.x, p.y);
    }
    else
    {
      CGPoint p = CGPointMake (rect.origin.x + rect.size.width / 2.0 + (toothImage.size.width - TOOTH_HEAD_WIDTH),
                               rect.origin.y + rect.size.height - i * toothImage.size.height);
      
      if (p.y < middleOfHandle) continue;

      CGContextTranslateCTM (context, p.x, p.y);
      CGContextRotateCTM (context, M_PI);
      
    }
    
    [toothImage drawAtPoint: CGPointMake(0,0)];
    
    CGContextRestoreGState (context);
  }
  
  /*draw the teeth above the handle*/
  for (int i = 0; i < numTopTeeth; i++)
  {
    /*left*/
    if (i % 2 == 0)
    {
      float t = (float) i * 1.0 / numTopTeeth;

      float radians;
      CGPoint p = [self getBezierPointAndRadians:&radians forT:t p0:leftP0 p1:leftCP p2:leftP1];
      
      /*nice corner case on our slope stuff*/
      if (i == 0)
        radians *= -1;
      CGContextSaveGState(context);
      
      CGContextTranslateCTM (context, p.x - (toothImage.size.width - TOOTH_HEAD_WIDTH), p.y);
      CGContextRotateCTM (context, radians - M_PI / 2.0);
      
      [toothImage drawAtPoint: CGPointMake(0,0)];
      
      CGContextRestoreGState (context);
    }
    else
    {
      CGContextSaveGState(context);
      
      /*the right hand teeth are staggered up one, do this and handle the out of bounds case*/
      float t = (float) (i+1) * 1.0 / numTopTeeth;
      if (t > 1.0) t = 1.0;
      
      float radians;
      CGPoint p = [self getBezierPointAndRadians:&radians forT:t p0:rightP0 p1:rightCP p2:rightP1];
      
      CGContextTranslateCTM (context, p.x + (toothImage.size.width - TOOTH_HEAD_WIDTH), p.y);
      CGContextRotateCTM (context, radians - M_PI / 2.0);
      
      [toothImage drawAtPoint: CGPointMake(0,0)];
      
      CGContextRestoreGState (context);
      
    }
  }
}


/*
 bezier stuff, see en.wikipedia.org/wiki/Bézier_curve#Quadratic_B.C3.A9zier_curves. this is all the math we need, and
 actually it's not painful at all. this assumes we have all bezier points already computed, and these functions return
 interpolated points along each bezier curve (right and left), as well as the derivate (slope) of each point.
 the interpolation for this paramaterized functions stuff just means "t" ranges from 0 to 1 as the curve goes from p0,
 through cp (control point), and to p1. we should have read this wpedo stuff first, then we would have named
 our variables p0, p1, and p2.
 
 for readablity and trusting the compiler etc we have no problem passing in all these point structs by value instead of by
 reference. same as repeating tons of common factors, this is so we can check w/ the wpedo formulas by eye.
 
 slope is returned as radians, how much does a line segment intersectng an perpendicular to the curve at the point deviate from
 the horizontal. in other words 0 means the curve is vertical at the point and M_PI / 2 means the curve is horizontal.
 
 one reason to do slope this way is so we can deal with "infinite" slope, dividing by zero and all that stuff. but also
 because we are going to use this angle to rotate teeth.
 
 */

- (CGPoint)getBezierPointAndRadians:(float*)radians forT:(float)t p0:(CGPoint)p0 p1:(CGPoint)p1 p2:(CGPoint)p2
{
  insist (radians);
  insist (t >= 0.0 && t <= 1.0);
  
  /*point interpolation*/
  float x, y;
  x = (1.0 - t) * (1.0 - t) * p0.x + 2.0 * (1.0 - t) * t * p1.x + t * t * p2.x;
  y = (1.0 - t) * (1.0 - t) * p0.y + 2.0 * (1.0 - t) * t * p1.y + t * t * p2.y;
  
  /*derivative*/
  
  float dx, dy;
  dx = 2 * (1.0 - t) * (p1.x - p0.x) + 2 * t * (p2.x - p1.x);
  dy = 2 * (1.0 - t) * (p1.y - p0.y) + 2 * t * (p2.y - p1.y);
  
  
  *radians = dy == 0.0 ? M_PI : atan (dy/dx);
  return CGPointMake(x, y);
}

@end
