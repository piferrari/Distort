//
//  DistortionAppDelegate.h
//  Distortion
//
//  Created by Ferrari Pierre on 18.04.11.
//  Copyright 2011 piferrari.org. All rights reserved.
//
//  Based on Drew Olbrich, 1992 source code
//  Port to OpenGL Nate Robins, 1997

#import <UIKit/UIKit.h>

@class DistortionViewController;

@interface DistortionAppDelegate : NSObject <UIApplicationDelegate> {

}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet DistortionViewController *viewController;

@end
