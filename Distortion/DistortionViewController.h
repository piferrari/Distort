//
//  DistortionViewController.h
//  Distortion
//
//  Created by Ferrari Pierre on 18.04.11.
//  Copyright 2011 piferrari.org. All rights reserved.
//
//  Based on Drew Olbrich, 1992 source code
//  Port to OpenGL Nate Robins, 1997

#import <UIKit/UIKit.h>

#import <OpenGLES/EAGL.h>

#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#define GRID_SIZE_X  32
#define GRID_SIZE_Y  32
#define CLIP_NEAR  0.01
#define CLIP_FAR   1000.0
#define SPRING_KS  0.3
#define DRAG	   0.5

typedef struct {
  float x[3];
  float v[3];
  float t[2];
  int nail;
} MASS;

typedef struct {
  int i, j;
  float r;
} SPRING;

@interface DistortionViewController : UIViewController {
@private
  EAGLContext *context;
  GLuint program;
  
  BOOL animating;
  NSInteger animationFrameInterval;
  CADisplayLink *displayLink;
    
  GLuint texture[1];
  int grab;
  int spring_count;
  MASS *mass;
  SPRING *spring;
  int mousex;
  int mousey;
}

@property (readonly, nonatomic, getter=isAnimating) BOOL animating;
@property (nonatomic) NSInteger animationFrameInterval;

@property (nonatomic, readwrite) int grab;
@property (nonatomic, readwrite) int spring_count;
@property (nonatomic, readwrite) MASS *mass;
@property (nonatomic, readwrite) SPRING *spring;
@property (nonatomic, readwrite) int mousex;
@property (nonatomic, readwrite) int mousey;

- (void)startAnimation;
- (void)stopAnimation;

- (int)rubber_grab:(int)x:(int)y;
- (void)rubber_init;
- (void)rubber_dynamics:(int)x:(int)y;

- (void)setupView;
@end
