//
//  AppController.h
//  Bulkloop_Cocoa_Apps
//
//  Created by USBHSP on 25/11/11.
//  Copyright 2011 Cypress Semiconductior. All rights reserved.
//

#import <Foundation/Foundation.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

#define kCypressVendorID		0x04B4
#define kFX2ProductID			0x8613
#define kBulkloopProductID		0x1004

#define DIALOG_OK				1
#define DIALOG_CANCEL			2

@interface AppController : NSObject {
@private
    
    int result;             //for return values
	ssize_t cnt;            //holds number of devices in list
    NSString *string;       //holds the text to be displayed in the textview
    NSString *infostr;      //holds the specs of the Cypress device
    
	IONotificationPortRef	gNotifyPort;

	IOUSBDeviceInterface245 	**dev;
	IOUSBInterfaceInterface245 	**intf;
	int inout[32];	// not use 0
	unsigned char data1[1024];
	
	io_iterator_t		gFX2AddedIter;
	io_iterator_t		gFX2RemovedIter;
	io_iterator_t		gBulkloopAddedIter;
	io_iterator_t		gBulkloopRemovedIter;

    IBOutlet NSButton *Infobutton_var;
    IBOutlet NSButton *Vndrbutton_var;
    IBOutlet NSButton *BulkXfer_var;
    
    IBOutlet NSTextView *actualtextview_var;
    IBOutlet NSTextField *Statuslabel;
    IBOutlet NSTextField *Data_bye;
    IBOutlet NSTextField *Num_of_bytes;
    IBOutlet NSPopUpButton *Endpointbox_var;
    
    IBOutlet NSTextField *Vndr_Reqcode_var;
    IBOutlet NSTextField *Vndr_Value_var;
    IBOutlet NSTextField *Vndr_Index_var;
    IBOutlet NSTextField *Vndr_Length_var;
    IBOutlet NSPopUpButton *Vndr_Dir_var;

    IBOutlet NSWindow *downLoadDialog;
}

- (NSString*) IOUSB_TransferData:(int) pipeRef d:(int) dir;
- (void) Setup_EndpointBox;
- (IBAction)Infobutton:(id)sender;
- (IBAction)Bulk_Xfer:(id)sender;
- (IBAction)Clear:(id)sender;
- (IBAction)VndrReq_button:(id)sender;

- (void) setStatus:(NSString *)str;
- (IBAction)dialogOk:(id)sender;
- (IBAction)dialogCancel:(id)sender;
- (int) downloadDialog;
- (void) startBulkloop:(IOUSBDeviceInterface245**)adev;
- (void) stopBulkloop;
- (IOReturn) ConfigureAnchorDevice;
- (IOReturn) FindInterfaces;
@end
