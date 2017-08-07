//
//  Bulkloop_Cocoa_AppsAppDelegate.h
//  Bulkloop_Cocoa_Apps
//
//  Created by USBHSP on 25/11/11.
//  Copyright 2011 Cypress Semiconductior. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Bulkloop_Cocoa_AppsAppDelegate : NSObject <NSApplicationDelegate> {
@private
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
