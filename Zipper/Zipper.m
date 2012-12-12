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
- (CGPoint)getBezierPointAndRadians:(double*)radians forT:(double)t p0:(CGPoint)p0 p1:(CGPoint)p1 p2:(CGPoint)p2;
- (double)getTForYBezierPoint:(double)y p0:(CGPoint)p0 p1:(CGPoint)p1 p2:(CGPoint)p2;
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
                    [self getTopOfHandleInRect:self.bounds] - (size.height - handleImage.size.height) / 2.0,
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
  float heightRange = self.bounds.size.height - handleImage.size.height;
  
  CGPoint p = [touch locationInView:self];
  float delta = (p.y - startPoint.y) / heightRange;
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
  topOfHandle += handleImage.size.height / 2.0;
  leftP0.x = rect.origin.x + rect.size.width / 2.0 - EDGE_WIDTH / 2.0,
  leftP0.y = topOfHandle;
  leftCP.x = rect.origin.x + rect.size.width / 2.0;
  leftCP.y = topOfHandle / 2.0;
  leftP1.x = rect.origin.x + (rect.size.width / 2.0) * (1.0 - value);
  leftP1.y = rect.origin.y - EDGE_WIDTH; //we let clipping do work trim the edge at the top of the rect.
  
  /*we use the same control and start endpoints for both curves, but we don't have to*/
  rightCP = leftCP;
  rightP0 = leftP0;
  
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
 they just go straight down, interlocking and on top of each other, like a zipper. the actual
 above/below the handle point is the bottom of the "v" of the bezier curves, this might not
 have anything to do with where we actually draw the handle image. the curves might meet
 in the center of the handle somewhere, we don't care in this method.
 
 when this method is called, the bezier curves are are already re-computed based on the
 handle position.
 */
- (void)drawTeethToContext:(CGContextRef)context inRect:(CGRect)rect
{
  
  /*draw the teeth under the "v" of the bezier curves, starting with the left side*/
  
  CGPoint p;
  int tooth;
  for (tooth = 0; ; tooth++)
  {
    /*save the context because we are doing translations and rotations*/
    CGContextSaveGState(context);
    
    /*left*/
    
    if (tooth % 2 == 0)
    {
      p = CGPointMake (rect.origin.x + rect.size.width / 2.0 - (toothImage.size.width - TOOTH_HEAD_WIDTH),
                       rect.origin.y + rect.size.height - (tooth+1) * toothImage.size.height);
      
      CGContextTranslateCTM (context, p.x, p.y);
    }
    else
    {
      p = CGPointMake (rect.origin.x + rect.size.width / 2.0 + (toothImage.size.width - TOOTH_HEAD_WIDTH),
                       rect.origin.y + rect.size.height - tooth * toothImage.size.height);
      
      CGContextTranslateCTM (context, p.x, p.y);
      
      /*we drew our tooth image to be a left-hand tooth, so for the right side, the tooth needs to be flipped around*/
      CGContextRotateCTM (context, M_PI);
      
    }
    
    /*draw the tooth*/
    [toothImage drawAtPoint: CGPointMake(0,0)];
    CGContextRestoreGState (context);
    
    /*if we drew any part of the tooth above the bezier start point, we are done with the lower teeth. p is the upper-left hand corner
     of whatever tooth we were drawing.*/
    if (p.y < leftP0.y)
      break;
  }
  
  /*
   draw the upper teeth. we do this by going up along each bezier curve, adding each tooth where it should be. measuring the
   fixed distance between teeth along the bezier curves themselves. we know the slope of each point on the curve, and the distance
   between teeth is just the tooth height, so with some trigonometry we can step up along the curves. we stop when we
   start drawing off screen.
   
   since we care about the vertical dimension because the teeth are stacking up on top of each other, we compute the y's from
   slopes and whatnot, then we compute the corresponding x's to make sure we stay on the curve by using math on the beziers.
   
   that way we stay on the curve and our initial y point can be an easy approximation rather than a calculation. we know
   we are starting out vertical, so the first "y" is just the tooth height above the last "y" from the topmost bottom tooth.
   */
  
  
  /*make the initial points that will track up the curves. these are all going to be top-left hand corners of the tooth images
   as if the curves were staight lines going up and we didn't need to do translation and rotation.*/
  
  CGPoint leftP, rightP;
  
  /*the initial tooth is on the opposite side of the last one. we will always have drawn at least one tooth by now*/
  tooth++;
  
  leftP.y = p.y - toothImage.size.height;
  leftP.x = leftP0.x;
  rightP.y = p.y - toothImage.size.height;
  rightP.x = rightP0.x;
  
  /*
    as we go along, we can place each tooth with existing leftP, or rightP and then compute the next leftP or rightP values.
    the loop condition is such that we stop drawing when there's nothing more to draw, we can't easily compute this in advance.
    our math code will really really hate it if we do computations outside the range of the bezier curves we have set up.
   */
  for (; leftP.y >= 0.0 || rightP.y >= 0.0; tooth++)
  {
    /*left*/
    if (tooth % 2 == 0)
    {
      CGContextSaveGState(context);
      
      /*figure out where our "t" is for this point. we need this for slope.*/
      double t = [self getTForYBezierPoint:leftP.y p0:leftP0 p1:leftCP p2:leftP1];
      
      /*get slope. "p" should be the same as leftP actually*/
      double radians;
      CGPoint p = [self getBezierPointAndRadians:&radians forT:t p0:leftP0 p1:leftCP p2:leftP1];

      /*fabs is our favorite function. there is one corner case where for the left hand side we are getting a wrong sign. it might be due to
        our initial leftP.y approximation, deal with it the easy way.*/
      radians = fabs (radians);
      
      CGContextTranslateCTM (context, leftP.x - (toothImage.size.width - TOOTH_HEAD_WIDTH), leftP.y);
      CGContextRotateCTM (context, radians - M_PI / 2.0);
      
      [toothImage drawAtPoint: CGPointMake(0,0)];
      
      CGContextRestoreGState (context);
      
      /*use 8th grade trigonometry to get the next "y" point based on the slope and the hypotenuse distance, which
       is the distance between teeth along the curve*/
      
      leftP.y = p.y - 2 * toothImage.size.height * fabs (sin (radians));
      
      /*we might be out of left teeth to draw, if so we can't compute the next one without triggering assertions in our math code*/
      if (leftP.y < 0)
        continue;
      
      /*get the "t" value for this y*/
      t = [self getTForYBezierPoint:leftP.y p0:leftP0 p1:leftCP p2:leftP1];
      
      /*move the point up along the curve to "t"*/
      leftP = [self getBezierPointAndRadians:&radians forT:t p0:leftP0 p1:leftCP p2:leftP1];
    }
    else
    {
      /*this is shamelessly the mirror image of the above code, it could be refactored to be fewer lines, but that would be more confusing
        than it would be worth*/
      
      CGContextSaveGState(context);
      
      /*figure out where our "t" is for this point. we need this for slope.*/
      double t = [self getTForYBezierPoint:rightP.y p0:rightP0 p1:rightCP p2:rightP1];
      
      /*get slope. "p" should be the same as rightP actually*/
      double radians;
      CGPoint p = [self getBezierPointAndRadians:&radians forT:t p0:rightP0 p1:rightCP p2:rightP1];
  
      CGContextTranslateCTM (context, rightP.x + (toothImage.size.width - TOOTH_HEAD_WIDTH), rightP.y);
      CGContextRotateCTM (context, radians - M_PI / 2.0);
  
      [toothImage drawAtPoint: CGPointMake(0,0)];
      
      CGContextRestoreGState (context);
      
      /*use 8th grade trigonometry to get the next "y" point based on the slope and the hypotenuse distance, which
       is the distance between teeth along the curve*/
      
      rightP.y = p.y - 2 * toothImage.size.height * fabs (sin (radians));
      
      /*don't compute the next tooth if there isn't one*/
      if (rightP.y < 0)
        continue;
      
      /*get the "t" value for this y*/
      t = [self getTForYBezierPoint:rightP.y p0:rightP0 p1:rightCP p2:rightP1];
      
      /*move the point up along the curve to "t"*/
      rightP = [self getBezierPointAndRadians:&radians forT:t p0:rightP0 p1:rightCP p2:rightP1];
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
 
 slope is returned as radians, that's really the angle of how much the curve deviates from the horizontal. so vertical curve
 is pi/2, horizontal curve is 0. now the we have to do trigonometry we suddenly care.
 
 because we are going to use this angle to rotate teeth.
 
 */

- (CGPoint)getBezierPointAndRadians:(double*)radians forT:(double)t p0:(CGPoint)p0 p1:(CGPoint)p1 p2:(CGPoint)p2
{
  insist (radians);
  insist (t >= 0.0 && t <= 1.0);
  
  /*point interpolation*/
  double x, y;
  x = (1.0 - t) * (1.0 - t) * p0.x + 2.0 * (1.0 - t) * t * p1.x + t * t * p2.x;
  y = (1.0 - t) * (1.0 - t) * p0.y + 2.0 * (1.0 - t) * t * p1.y + t * t * p2.y;
  
  /*derivative*/
  
  double dx, dy;
  dx = 2 * (1.0 - t) * (p1.x - p0.x) + 2 * t * (p2.x - p1.x);
  dy = 2 * (1.0 - t) * (p1.y - p0.y) + 2 * t * (p2.y - p1.y);
  
  *radians = dx == 0.0 ? M_PI / 2.0 : atan (dy/dx);
  return CGPointMake(x, y);
}

/*
 solve a quadratic bezier for "t" given a y point. we return whichever "t" gives us a value
 between 0 and 1.
 
 the formulas come from typing this into wolfram alpha since we can't remember high school math
 solve y = ((1 - t) ^ 2) p0 + 2 (1 - t) * t p1 + (t ^ 2) p2 for t
 
 2 answers, copied from wolfram and mindlessly converted into C. the formulas are the same except for
 the - in front of the square root term but don't bother with subfactors to abuse the machine and for visual
 double checking.
 
 p0-2 p1+p2!=0 and t = (-sqrt(-p0 p2+p0 y+p1^2-2 p1 y+p2 y)-p0+p1)/(-p0+2 p1-p2)
 p0-2 p1+p2!=0 and t =  (sqrt(-p0 p2+p0 y+p1^2-2 p1 y+p2 y)-p0+p1)/(-p0+2 p1-p2)
 
 */

- (double)getTForYBezierPoint:(double)y p0:(CGPoint)p0 p1:(CGPoint)p1 p2:(CGPoint)p2
{
  insist (p0.y -2 * p1.y + p2.y != 0.0);
  
  double t1 = (-sqrt(-p0.y*p2.y + p0.y*y + p1.y*p1.y - 2*p1.y*y + p2.y*y) -p0.y+p1.y)/(-p0.y + 2*p1.y - p2.y);
  double t2 = ( sqrt(-p0.y*p2.y + p0.y*y + p1.y*p1.y - 2*p1.y*y + p2.y*y) -p0.y+p1.y)/(-p0.y + 2*p1.y - p2.y);
  
  if (t1 >= 0.0 && t1 <= 1.0)
    return t1;
  insist (t2 >= 0.0 && t2 <= 1.0);
  return t2;
}


@end
