//
//  DistortionViewController.m
//  Distortion
//
//  Created by Ferrari Pierre on 18.04.11.
//  Copyright 2011 piferrari.org. All rights reserved.
//
//  Based on Drew Olbrich, 1992 source code
//  Port to OpenGL Nate Robins, 1997

#import <QuartzCore/QuartzCore.h>

#import "DistortionViewController.h"
#import "EAGLView.h"

// Uniform index.
enum {
  UNIFORM_TRANSLATE,
  NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum {
  ATTRIB_VERTEX,
  ATTRIB_COLOR,
  NUM_ATTRIBUTES
};

@interface DistortionViewController ()
@property (nonatomic, retain) EAGLContext *context;
@property (nonatomic, assign) CADisplayLink *displayLink;

@end

@implementation DistortionViewController

@synthesize animating, context, displayLink, grab, mass, spring, spring_count, mousex, mousey, imagePicker;

/*
 Do the dynamics simulation for the next frame.
 */
-(void)rubber_dynamics:(int)x:(int)y
{
  int k;
  float d[3];
  int i, j;
  float l;
  float a;
  
  /* calculate all the spring forces acting on the mass points */
  
  for (k = 0; k < spring_count; k++)
  {
    i = spring[k].i;
    j = spring[k].j;
    
    d[0] = mass[i].x[0] - mass[j].x[0];
    d[1] = mass[i].x[1] - mass[j].x[1];
    d[2] = mass[i].x[2] - mass[j].x[2];
    
    l = sqrt(d[0]*d[0] + d[1]*d[1] + d[2]*d[2]);
    
    if (l != 0.0)
    {
      d[0] /= l;
      d[1] /= l;
      d[2] /= l;
      
      a = l - spring[k].r;
      
      mass[i].v[0] -= d[0]*a*SPRING_KS;
      mass[i].v[1] -= d[1]*a*SPRING_KS;
      mass[i].v[2] -= d[2]*a*SPRING_KS;
      
      mass[j].v[0] += d[0]*a*SPRING_KS;
      mass[j].v[1] += d[1]*a*SPRING_KS;
      mass[j].v[2] += d[2]*a*SPRING_KS;
    }
  }
  
  /* update the state of the mass points */
  
  for (k = 0; k < GRID_SIZE_X*GRID_SIZE_Y; k++)
    if (!mass[k].nail)
    {
      mass[k].x[0] += mass[k].v[0];
      mass[k].x[1] += mass[k].v[1];
      mass[k].x[2] += mass[k].v[2];
      
      mass[k].v[0] *= (1.0 - DRAG);
      mass[k].v[1] *= (1.0 - DRAG);
      mass[k].v[2] *= (1.0 - DRAG);
      
      if (mass[k].x[2] > -CLIP_NEAR - 0.01)
        mass[k].x[2] = -CLIP_NEAR - 0.01;
      if (mass[k].x[2] < -CLIP_FAR + 0.01)
        mass[k].x[2] = -CLIP_FAR + 0.01;
    }
  
  /* if a mass point is grabbed, attach it to the mouse */
  
  if (grab != -1 && !mass[grab].nail)
  {
    mass[grab].x[0] = x;
    mass[grab].x[1] = y;
    mass[grab].x[2] = -(CLIP_FAR - CLIP_NEAR)/4.0;
  }
}

/*
 Draw the next frame of animation.
 */

-(void)rubber_redraw
{
  int k;
  int i, j;
  if(mass == NULL) {
    NSLog(@"mass is null");
    return;
  }
  
  k = 0;
  for (i = 0; i < GRID_SIZE_X - 1; i++)
  {
    for (j = 0; j < GRID_SIZE_Y - 1; j++)
    {
      GLfloat vertices[]= {
        mass[k].x[0],mass[k].x[1],mass[k].x[2], 
        mass[k + 1].x[0],mass[k + 1].x[1],mass[k + 1].x[2],
        mass[k + GRID_SIZE_Y + 1].x[0],mass[k + GRID_SIZE_Y + 1].x[1],mass[k + GRID_SIZE_Y + 1].x[2], 
        mass[k + GRID_SIZE_Y].x[0],mass[k + GRID_SIZE_Y].x[1],mass[k + GRID_SIZE_Y].x[2]
      };
      GLfloat tex[]={
        mass[k].t[0], mass[k].t[1], 
        mass[k + 1].t[0], mass[k + 1].t[1],
        mass[k + GRID_SIZE_Y + 1].t[0], mass[k + GRID_SIZE_Y + 1].t[1],
        mass[k + GRID_SIZE_Y].t[0], mass[k + GRID_SIZE_Y].t[1]
      };
      
      glVertexPointer(3, GL_FLOAT, 0, vertices);
      glTexCoordPointer(2, GL_FLOAT, 0, tex);
      
      glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
      k++;
    }
    k++;
  }
}

- (int)rubber_grab:(int)x:(int)y
{
  float dx[2];
  float d;
  float min_d;
  float min_i;
  int i;
  
  for (i = 0; i < GRID_SIZE_X*GRID_SIZE_Y; i++)
  {
    dx[0] = mass[i].x[0] - x;
    dx[1] = mass[i].x[1] - y;
    d = sqrt(dx[0]*dx[0] + dx[1]*dx[1]);
    if (i == 0 || d < min_d)
    {
      min_i = i;
      min_d = d;
    }
  }
  
  return min_i;
}

- (void)rubber_init
{
  CGRect rect = self.view.bounds;
  //glEnable(GL_DEPTH_TEST);
  int i, j;
  int k;
  int m;
  
  if (mass == NULL)
  {
    mass = (MASS *) malloc(sizeof(MASS)*GRID_SIZE_X*GRID_SIZE_Y);
    if (mass == NULL)
    {
      fprintf(stderr, "rubber: Can't allocate memory.\n");	
      exit(-1);
    }
  }
  
  k = 0;
  for (i = 0; i < GRID_SIZE_X; i++)
    for (j = 0; j < GRID_SIZE_Y; j++)
    {
      mass[k].nail = (i == 0 || j == 0 || i == GRID_SIZE_X - 1
                      || j == GRID_SIZE_Y - 1);
      mass[k].x[0] = i/(GRID_SIZE_X - 1.0)*rect.size.width;
      mass[k].x[1] = j/(GRID_SIZE_Y - 1.0)*rect.size.height;
      mass[k].x[2] = -(CLIP_FAR - CLIP_NEAR)/2.0;
      
      mass[k].v[0] = 0.0;
      mass[k].v[1] = 0.0;
      mass[k].v[2] = 0.0;
      
      mass[k].t[0] = i/(GRID_SIZE_X - 1.0);
      mass[k].t[1] = j/(GRID_SIZE_Y - 1.0);
      
      k++;
    }
  
  if (spring == NULL)
  {
    spring_count = (GRID_SIZE_X - 1)*(GRID_SIZE_Y - 2)
    + (GRID_SIZE_Y - 1)*(GRID_SIZE_X - 2);
    
    spring = (SPRING *) malloc(sizeof(SPRING)*spring_count);
    if (spring == NULL)
    {
      fprintf(stderr, "rubber: Can't allocate memory.\n");	
      exit(-1);
    }
  }
  
  k = 0;
  for (i = 1; i < GRID_SIZE_X - 1; i++)
    for (j = 0; j < GRID_SIZE_Y - 1; j++)
    {
      m = GRID_SIZE_Y*i + j;
      spring[k].i = m;
      spring[k].j = m + 1;
      spring[k].r = (rect.size.height - 1.0)/(GRID_SIZE_Y - 1.0);
      k++;
    }
  
  for (j = 1; j < GRID_SIZE_Y - 1; j++)
    for (i = 0; i < GRID_SIZE_X - 1; i++)
    {
      m = GRID_SIZE_Y*i + j;
      spring[k].i = m;
      spring[k].j = m + GRID_SIZE_X;
      spring[k].r = (rect.size.width - 1.0)/(GRID_SIZE_X - 1.0);
      k++;
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info 
{
  UIImage *image = [[info objectForKey:UIImagePickerControllerOriginalImage] retain];
  if (image == nil) {
    NSLog(@"Image is nil");
  }
  [self loadTexture:image];
  [image release];
  [imagePicker dismissModalViewControllerAnimated:YES];
  [imagePicker release];
  pause = NO;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
  [imagePicker dismissModalViewControllerAnimated:YES];
  [imagePicker release];
}

- (void)takeImage
{
  if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
  {
    pause = YES;
    imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary|UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    imagePicker.delegate = self;
    imagePicker.allowsEditing = NO;
    [self presentModalViewController:imagePicker animated:YES];
  } 
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{
  UITouch *touch = [[touches allObjects] objectAtIndex:0];
  CGPoint pt = [touch locationInView:self.view];
  mousex = pt.x;
  mousey = self.view.bounds.size.height-pt.y;
  grab = [self rubber_grab:mousex:mousey];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event 
{
  UITouch *touch = [[touches allObjects] objectAtIndex:0];
  CGPoint pt = [touch locationInView:self.view];
  mousex = pt.x;
  mousey = self.view.bounds.size.height-pt.y;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
  grab = -1;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event 
{
}

- (void)loadTexture:(UIImage *)image
{
  if (image == nil)
  {
    NSLog(@"Image is null");
    return;
  }

  GLuint width = CGImageGetWidth(image.CGImage);
  GLuint height = CGImageGetHeight(image.CGImage);
  
  bool hasAlpha = CGImageGetAlphaInfo(image.CGImage) != kCGImageAlphaNone;
  
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  unsigned char *data = (unsigned char*)malloc(height * width * 4);
  CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
  CGContextRef cgContext = CGBitmapContextCreate(data, width, height, 8, 4 * width, colorSpace, bitmapInfo);
  CGColorSpaceRelease(colorSpace);
  
  CGRect rect = CGRectMake(0, 0, width, height);
  CGContextClearRect(cgContext, rect);
  // Flip the Y-axis
  CGContextTranslateCTM (cgContext, 0, height);
  CGContextScaleCTM (cgContext, 1.0, -1.0);
  CGContextDrawImage(cgContext, rect, image.CGImage);
  
  CGContextRelease(cgContext);
  
  NSData *imageData = [NSData dataWithBytesNoCopy:data length:(height * width * 4) freeWhenDone:YES];

  glGenTextures(1, &texture);
  glBindTexture(GL_TEXTURE_2D, texture);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
  glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
  if (!hasAlpha) {
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
  }
  else {
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, imageData);
  }
  free(data);
}

- (void)setupView
{
  glEnable(GL_DEPTH_TEST);
  glMatrixMode(GL_PROJECTION); 
  CGRect rect = self.view.bounds;
  glOrthof(-0.5, rect.size.width - 0.5, -0.5, rect.size.height - 0.5, CLIP_NEAR, CLIP_FAR);
  glViewport(0, 0, rect.size.width, rect.size.height);
  glMatrixMode(GL_MODELVIEW);
  
  // Turn necessary features on
  glEnable(GL_TEXTURE_2D);
  glEnable(GL_BLEND);
  glBlendFunc(GL_ONE, GL_SRC_COLOR);
    
  NSString *path = [[NSBundle mainBundle] pathForResource:@"distort" ofType:@"png"];
  NSData *texData = [[NSData alloc] initWithContentsOfFile:path];
  UIImage *image = [[UIImage alloc] initWithData:texData];
  
  [self loadTexture:image];
  
  [image release];
  [texData release];
  
  glEnable(GL_LIGHTING);
  
  // Turn the first light on
  glEnable(GL_LIGHT0);
  
  // Define the ambient component of the first light
  static const Color3D light0Ambient[] = {{0.4, 0.4, 0.4, 1.0}};
  glLightfv(GL_LIGHT0, GL_AMBIENT, (const GLfloat *)light0Ambient);
  
  // Define the diffuse component of the first light
  static const Color3D light0Diffuse[] = {{0.8, 0.8, 0.8, 1.0}};
  glLightfv(GL_LIGHT0, GL_DIFFUSE, (const GLfloat *)light0Diffuse);
  
  // Define the position of the first light
  // const GLfloat light0Position[] = {10.0, 10.0, 10.0}; 
  static const Vertex3D light0Position[] = {{10.0, 10.0, 10.0}};
  glLightfv(GL_LIGHT0, GL_POSITION, (const GLfloat *)light0Position);
}

- (IBAction)tapDetected:(UIGestureRecognizer *)sender
{
	[self takeImage];
}

- (void)awakeFromNib
{
  EAGLContext *aContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
  
  if (!aContext)
    NSLog(@"Failed to create ES context");
  else if (![EAGLContext setCurrentContext:aContext])
    NSLog(@"Failed to set ES context current");
  
	self.context = aContext;
	[aContext release];
	
  [(EAGLView *)self.view setContext:context];
  [(EAGLView *)self.view setFramebuffer];

  [self setupView];
  [self rubber_init];
  
  animating = FALSE;
  animationFrameInterval = 1;
  self.displayLink = nil;
  
  UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapDetected:)];
  doubleTap.numberOfTapsRequired = 2;
  [self.view addGestureRecognizer:doubleTap];
  [doubleTap release];
}

- (void)dealloc
{
  if (program) {
    glDeleteProgram(program);
    program = 0;
  }
  
  // Tear down context.
  if ([EAGLContext currentContext] == context)
    [EAGLContext setCurrentContext:nil];
  
  [context release];
  
  [super dealloc];
}

- (void)didReceiveMemoryWarning
{
  // Releases the view if it doesn't have a superview.
  [super didReceiveMemoryWarning];
  
  // Release any cached data, images, etc. that aren't in use.
}

- (void)viewWillAppear:(BOOL)animated
{
  [self startAnimation];
  
  [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [self stopAnimation];
  
  [super viewWillDisappear:animated];
}

- (void)viewDidUnload
{
	[super viewDidUnload];
	
  if (program) {
    glDeleteProgram(program);
    program = 0;
  }
  
  // Tear down context.
  if ([EAGLContext currentContext] == context)
    [EAGLContext setCurrentContext:nil];
	self.context = nil;	
}

- (NSInteger)animationFrameInterval
{
  return animationFrameInterval;
}

- (void)setAnimationFrameInterval:(NSInteger)frameInterval
{
  /*
	 Frame interval defines how many display frames must pass between each time the display link fires.
	 The display link will only fire 30 times a second when the frame internal is two on a display that refreshes 60 times a second. The default frame interval setting of one will fire 60 times a second when the display refreshes at 60 times a second. A frame interval setting of less than one results in undefined behavior.
	 */
  if (frameInterval >= 1) {
    animationFrameInterval = frameInterval;
    
    if (animating) {
      [self stopAnimation];
      [self startAnimation];
    }
  }
}

- (void)startAnimation
{
  if (!animating) {
    CADisplayLink *aDisplayLink = [[UIScreen mainScreen] displayLinkWithTarget:self selector:@selector(drawFrame)];
    [aDisplayLink setFrameInterval:animationFrameInterval];
    [aDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    self.displayLink = aDisplayLink;
    
    animating = TRUE;
  }
}

- (void)stopAnimation
{
  if (animating) {
    [self.displayLink invalidate];
    self.displayLink = nil;
    animating = FALSE;
  }
}

- (void)drawFrame
{
  [(EAGLView *)self.view setFramebuffer];
  if (!pause) {
    [self rubber_dynamics:mousex:mousey];
    
    glColor4f(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_NORMAL_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);
    
    static const Vector3D normals[] = {
      {0.0, 0.0, 1.0},
      {0.0, 0.0, 1.0},
      {0.0, 0.0, 1.0},
      {0.0, 0.0, 1.0}
    };
    
    glLoadIdentity();
    glTranslatef(0.0, 0.0, -3.0);
    
    glBindTexture(GL_TEXTURE_2D, texture);
    glNormalPointer(GL_FLOAT, 0, normals);
    [self rubber_redraw];  
    glDisableClientState(GL_VERTEX_ARRAY);
    glDisableClientState(GL_NORMAL_ARRAY);
    glDisableClientState(GL_TEXTURE_COORD_ARRAY);
  }
  [(EAGLView *)self.view presentFramebuffer];
}

@end
