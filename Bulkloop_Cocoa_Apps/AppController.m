//
//  AppController.m
//  Bulkloop_Cocoa_Apps
//
//  Created by USBHSP on 25/11/11.
//  Copyright 2011 Cypress Semiconductior. All rights reserved.
//

#import "AppController.h"

#include "download.h"

// not complite async access code
//#define USE_ASYNC_IO

@implementation AppController

//
// IOUSB c function callback
//

void FX2Added(void *refCon, io_iterator_t iterator)
{
	kern_return_t		kr;
    io_service_t		usbDevice;
	IOCFPlugInInterface 	**plugInInterface=NULL;
    IOUSBDeviceInterface245 	**dev=NULL;
	SInt32 			score;
	HRESULT 			res;

	AppController *appctr;

	appctr = (AppController *)refCon;

    while ( (usbDevice = IOIteratorNext(iterator)) )
    {
        [appctr setStatus:@"FX2 device added."];
		
        if([appctr downloadDialog] == DIALOG_OK) {
			kr = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
			kr = IOObjectRelease(usbDevice);				// done with the device object now that I have the plugin
			if ((kIOReturnSuccess != kr) || !plugInInterface)
			{
				printf("unable to create a plugin (%08x)\n", kr);
				continue;
			}
			
			// I have the device plugin, I need the device interface
			res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID245), (LPVOID)&dev);
			IODestroyPlugInInterface(plugInInterface);			// done with this
			
			DownloadToCypressDevice(dev, [[[NSBundle mainBundle]
										  pathForResource:@"bulkloop"
										  ofType:@"hex"] cStringUsingEncoding:NSUTF8StringEncoding]);
			kr = (*dev)->USBDeviceClose(dev);
			kr = (*dev)->Release(dev);
		}
		
	}
}

void FX2Removed(void *refCon, io_iterator_t iterator)
{
    kern_return_t	kr;
    io_service_t	obj;
	AppController *appctr;
	
	appctr = (AppController *)refCon;
    
    while ( (obj = IOIteratorNext(iterator)) )
    {
        [appctr setStatus:@"FX2 device removed."];
        kr = IOObjectRelease(obj);
    }
}

void BulkloopAdded(void *refCon, io_iterator_t iterator)
{
	kern_return_t		kr;
    io_service_t		usbDevice;
	IOCFPlugInInterface 	**plugInInterface=NULL;
    IOUSBDeviceInterface245 	**dev=NULL;
	SInt32 			score;
	HRESULT 			res;

	AppController *appctr;
	
	appctr = (AppController *)refCon;
	
    while ( (usbDevice = IOIteratorNext(iterator)) )
    {
        [appctr setStatus:@"Bulkloop device added."];
		kr = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
		kr = IOObjectRelease(usbDevice);				// done with the device object now that I have the plugin
		if ((kIOReturnSuccess != kr) || !plugInInterface)
		{
			printf("unable to create a plugin (%08x)\n", kr);
			continue;
		}
		
		// I have the device plugin, I need the device interface
		res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID245), (LPVOID)&dev);
		IODestroyPlugInInterface(plugInInterface);			// done with this
		
		[appctr startBulkloop:dev];
	}
}

void BulkloopRemoved(void *refCon, io_iterator_t iterator)
{
    kern_return_t	kr;
    io_service_t	obj;
	AppController *appctr;
	
	appctr = (AppController *)refCon;
    
    while ( (obj = IOIteratorNext(iterator)) )
    {
        [appctr setStatus:@"Bulkloop device removed."];
		[appctr stopBulkloop];
        kr = IOObjectRelease(obj);
    }
}

#ifdef USE_ASYNC_IO
void ReadCompletion(void *refCon, IOReturn result, void *arg0)
{
    printf("Async bulk read complete.\n");
}

void WriteCompletion(void *refCon, IOReturn result, void *arg0)
{
	printf("Async write complete.\n");
}
#endif

//
// instance method
//

- (void) setStatus:(NSString *)str
{
    [Statuslabel setStringValue:str];
}

- (IBAction)dialogOk:(id)sender
{
    // OK button is pushed
    [[NSApplication sharedApplication] 
	 stopModalWithCode:DIALOG_OK];
}

- (IBAction)dialogCancel:(id)sender
{
    // Cancel button is pushed
    [[NSApplication sharedApplication] 
	 stopModalWithCode:DIALOG_CANCEL];
}

- (int) downloadDialog
{
	int	diares;
	
	diares = (int)[[NSApplication sharedApplication] 
			  runModalForWindow:downLoadDialog];
    [downLoadDialog orderOut:self];	
	
	return diares;
}

- (void) startBulkloop:(IOUSBDeviceInterface245**)adev
{
    kern_return_t		kr;
	
	[BulkXfer_var setEnabled:YES];                     //Bulk Transfers button and Vendor Request button enabled only if Bulkloop device found
	[Vndrbutton_var setEnabled:YES];
    [Infobutton_var setEnabled:YES];          // keeping the various buttons in the GUI disables as default
	infostr = @"";
	
	dev = adev;
	kr = (*dev)->USBDeviceOpen(dev);
	if (kIOReturnSuccess != kr)
	{
		printf("unable to open device: %08x\n", kr);
		(*dev)->Release(dev);
		return;
	}
	kr = [self ConfigureAnchorDevice];
	if (kIOReturnSuccess != kr)
	{
		printf("unable to configure device: %08x\n", kr);
		(*dev)->USBDeviceClose(dev);
		(*dev)->Release(dev);
		return;
	}
	kr = [self FindInterfaces];
	if (kIOReturnSuccess != kr)
	{
		printf("unable to find interfaces on device: %08x\n", kr);
		(*dev)->USBDeviceClose(dev);
		(*dev)->Release(dev);
		return;
	}
}

- (void) stopBulkloop
{
	[BulkXfer_var setEnabled:NO];                     //Bulk Transfers button and Vendor Request button enabled only if Bulkloop device found
	[Vndrbutton_var setEnabled:NO];
    [Infobutton_var setEnabled:NO];          // keeping the various buttons in the GUI disables as default
	[Endpointbox_var removeAllItems];
	
	(*dev)->USBDeviceClose(dev);
	(*dev)->Release(dev);
}

- (void) awakeFromNib{
    
    [Infobutton_var setEnabled:NO];          // keeping the various buttons in the GUI disables as default
    [BulkXfer_var setEnabled:NO];
    [Vndrbutton_var setEnabled:NO];
    
    string = @"";
    [Vndr_Dir_var selectItemAtIndex:0];
	
    CFRunLoopSourceRef		runLoopSource;
    CFMutableDictionaryRef 	fx2Dict;
    CFMutableDictionaryRef 	bulkloopDict;
    mach_port_t 		masterPort;
	kern_return_t		kr;
    SInt32			usbVendor;
    SInt32			usbProduct;

	usbVendor = kCypressVendorID;
	usbProduct = kFX2ProductID;

	kr = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (kr || !masterPort)
    {
        printf("ERR: Couldn't create a master IOKit Port(%08x)\n", kr);
        return;
    }
	
    printf("\nLooking for devices matching vendor ID=0x%04x and product ID=0x%04x\n", usbVendor, usbProduct);
	
    // Set up the matching criteria for the devices we're interested in
    fx2Dict = IOServiceMatching(kIOUSBDeviceClassName);	// Interested in instances of class IOUSBDevice and its subclasses
    if (!fx2Dict)
    {
        printf("Can't create a USB matching dictionary\n");
        mach_port_deallocate(mach_task_self(), masterPort);
        return;
    }
    
    // Add our vendor and product IDs to the matching criteria
    CFDictionarySetValue( 
						 fx2Dict, 
						 CFSTR(kUSBVendorID), 
						 CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &usbVendor)); 
    CFDictionarySetValue( 
						 fx2Dict, 
						 CFSTR(kUSBProductID), 
						 CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &usbProduct)); 
	
    
    gNotifyPort = IONotificationPortCreate(masterPort);
    runLoopSource = IONotificationPortGetRunLoopSource(gNotifyPort);
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);

    fx2Dict = (CFMutableDictionaryRef) CFRetain( fx2Dict ); 

    kr = IOServiceAddMatchingNotification(  gNotifyPort,
										  kIOFirstMatchNotification,
										  fx2Dict,
										  FX2Added,
										  self,
										  &gFX2AddedIter );

    FX2Added(self, gFX2AddedIter);	// Iterate once to get already-present devices and

	usbVendor = kCypressVendorID;
	usbProduct = kBulkloopProductID;

	kr = IOServiceAddMatchingNotification(  gNotifyPort,
										  kIOTerminatedNotification,
										  fx2Dict,
										  FX2Removed,
										  self,
										  &gFX2RemovedIter );
	
	FX2Removed(self, gFX2RemovedIter);	// Iterate once to arm the notification
	
	bulkloopDict = IOServiceMatching(kIOUSBDeviceClassName);	// Interested in instances of class IOUSBDevice and its subclasses
    if (!fx2Dict)
    {
        printf("Can't create a USB matching dictionary\n");
        mach_port_deallocate(mach_task_self(), masterPort);
        return;
    }
    
    // Add our vendor and product IDs to the matching criteria
    CFDictionarySetValue( 
						 bulkloopDict, 
						 CFSTR(kUSBVendorID), 
						 CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &usbVendor)); 
    CFDictionarySetValue( 
						 bulkloopDict,
						 CFSTR(kUSBProductID), 
						 CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &usbProduct)); 	
	
    bulkloopDict = (CFMutableDictionaryRef) CFRetain( bulkloopDict ); 
	
	kr = IOServiceAddMatchingNotification(  gNotifyPort,
										  kIOFirstMatchNotification,
										  bulkloopDict,
										  BulkloopAdded,
										  self,
										  &gBulkloopAddedIter );
	
	BulkloopAdded(self, gBulkloopAddedIter);	// Iterate once to get already-present devices and

	// arm the notification
	
	kr = IOServiceAddMatchingNotification(  gNotifyPort,
										  kIOTerminatedNotification,
										  bulkloopDict,
										  BulkloopRemoved,
										  self,
										  &gBulkloopRemovedIter );
	
	BulkloopRemoved(self, gBulkloopRemovedIter); 	// Iterate once to arm the notification
	
	mach_port_deallocate(mach_task_self(), masterPort);
    masterPort = 0;

}

- (void) applicationWillTerminate{
	if(intf != NULL) {
		(*intf)->USBInterfaceClose(intf);
		(*intf)->Release(intf);
	}
	if(dev != NULL) {
		(*dev)->USBDeviceClose(dev);
		(*dev)->Release(dev);
	}
}

/*
  Method "print" returns the specs of the Cypress device (VID = kCypressVendorID), if found
 */

- (IOReturn) ConfigureAnchorDevice
{
    UInt8				numConf;
    IOReturn				kr;
    IOUSBConfigurationDescriptorPtr	confDesc;
    
    kr = (*dev)->GetNumberOfConfigurations(dev, &numConf);
    if (!numConf)
        return -1;
	printf("GetNumberOfConfigurations %d\n", numConf);
    
    // get the configuration descriptor for index 0
    kr = (*dev)->GetConfigurationDescriptorPtr(dev, 0, &confDesc);
    if (kr)
    {
        printf("\tunable to get config descriptor for index %d (err = %08x)\n", 0, kr);
        return -1;
    }
/*
    kr = (*dev)->SetConfiguration(dev, confDesc->bConfigurationValue);
    if (kr)
    {
        printf("\tunable to set configuration to value %d (err=%08x)\n", 0, kr);
        return -1;
    }
*/    
    return kIOReturnSuccess;
}

- (IOReturn) FindInterfaces
{
    IOReturn			kr;
    IOUSBFindInterfaceRequest	request;
    io_iterator_t		iterator;
    io_service_t		usbInterface;
    IOCFPlugInInterface 	**plugInInterface = NULL;
    HRESULT 			res;
    SInt32 			score;
    UInt8			intfClass;
    UInt8			intfSubClass;
    UInt8			intfNumEndpoints;
    int				pipeRef;
    
	intf = NULL;

    request.bInterfaceClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    request.bAlternateSetting = kIOUSBFindInterfaceDontCare;
	
    kr = (*dev)->CreateInterfaceIterator(dev, &request, &iterator);
    
    while ( (usbInterface = IOIteratorNext(iterator)) )
    {
        infostr = [infostr stringByAppendingFormat:@"Interface found.\n"];
		
        kr = IOCreatePlugInInterfaceForService(usbInterface, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        kr = IOObjectRelease(usbInterface);				// done with the usbInterface object now that I have the plugin
        if ((kIOReturnSuccess != kr) || !plugInInterface)
        {
            printf("unable to create a plugin (%08x)\n", kr);
            break;
        }
		
        // I have the interface plugin. I need the interface interface
        res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID245), (LPVOID) &intf);
        IODestroyPlugInInterface(plugInInterface);			// done with this
		
        if (res || !intf)
        {
            printf("couldn't create an IOUSBInterfaceInterface245 (%08x)\n", (int) res);
            break;
        }
        
        kr = (*intf)->GetInterfaceClass(intf, &intfClass);
        kr = (*intf)->GetInterfaceSubClass(intf, &intfSubClass);
        
        infostr = [infostr stringByAppendingFormat:@"Interface class %d, subclass %d\n", intfClass, intfSubClass];
        
        // Now open the interface. This will cause the pipes to be instantiated that are 
        // associated with the endpoints defined in the interface descriptor.
        kr = (*intf)->USBInterfaceOpen(intf);
        if (kIOReturnSuccess != kr)
        {
            printf("unable to open interface (%08x)\n", kr);
            (void) (*intf)->Release(intf);
            break;
        }
        
    	kr = (*intf)->GetNumEndpoints(intf, &intfNumEndpoints);
        if (kIOReturnSuccess != kr)
        {
            printf("unable to get number of endpoints (%08x)\n", kr);
            (void) (*intf)->USBInterfaceClose(intf);
            (void) (*intf)->Release(intf);
            break;
        }
        
        infostr = [infostr stringByAppendingFormat:@"Interface has %d endpoints.\n", intfNumEndpoints];
		
        for (pipeRef = 1; pipeRef <= intfNumEndpoints; pipeRef++)
        {
            IOReturn	kr2;
            UInt8	direction;
            UInt8	number;
            UInt8	transferType;
            UInt16	maxPacketSize;
            UInt8	interval;
            char	*message;
            
            kr2 = (*intf)->GetPipeProperties(intf, pipeRef, &direction, &number, &transferType, &maxPacketSize, &interval);
            if (kIOReturnSuccess != kr)
                printf("unable to get properties of pipe %d (%08x)\n", pipeRef, kr2);
            else {
                switch (direction) {
                    case kUSBOut:
                        message = "out";
                        break;
                    case kUSBIn:
                        message = "in";
                        break;
                    case kUSBNone:
                        message = "none";
                        break;
                    case kUSBAnyDirn:
                        message = "any";
                        break;
                    default:
                        message = "???";
                }
				infostr = [infostr stringByAppendingFormat:@"direction %s, ", message];
                
                switch (transferType) {
                    case kUSBControl:
                        message = "control";
                        break;
                    case kUSBIsoc:
                        message = "isoc";
                        break;
                    case kUSBBulk:
                        message = "bulk";
                        break;
                    case kUSBInterrupt:
                        message = "interrupt";
                        break;
                    case kUSBAnyType:
                        message = "any";
                        break;
                    default:
                        message = "???";
                }
				infostr = [infostr stringByAppendingFormat:@"transfer type %s, maxPacketSize %d\n", message, maxPacketSize];
            }
        }
         
		[self Setup_EndpointBox];                          //Calls method "Setup_EndpointBox" as to set up combobox(EndPointBox) with the endpoints available in the bulkloop device
		
        // For this test we just want to use the first interface, so exit the loop.
        break;
    }
    
    return kr;
}

/*
   Method " LibUsb_TransferData: d:" . Intiates bulk data transfers from/to the endpoint which is passed as parameter.
 
 */

- (NSString*) IOUSB_TransferData:(int) pipeRef d:(int) dir
{
    IOReturn			kr;
	int i, len;
    NSString *str = @"";
    UInt32			numBytesRead;

	len = [[Num_of_bytes stringValue] intValue];
	if(dir == 0) {
#ifndef USE_ASYNC_IO
        for(i=0;i < len;i++)
        {
            data1[i] = strtol((char *) [[Data_bye stringValue] UTF8String], NULL, 16);                      //to convert hex string into binary
        }

		kr = (*intf)->WritePipe(intf, pipeRef, data1, len);
		if (kIOReturnSuccess != kr)
		{
			(void) (*intf)->USBInterfaceClose(intf);
			(void) (*intf)->Release(intf);
			return [NSString stringWithFormat:@"unable to do bulk write (%08x)\n", kr];
		}
		
        for(i=0;i<len;i++)
        {
            if(!(i%16))
                str = [str stringByAppendingFormat:@"\n %04x   ", i];
            
            str = [str stringByAppendingFormat:@"%02x  ",data1[i]];
        }
		str = [str stringByAppendingFormat:@"\n"];
#else
		CFRunLoopSourceRef		runLoopSource;

		kr = (*intf)->CreateInterfaceAsyncEventSource(intf, &runLoopSource);
        if (kIOReturnSuccess != kr)
        {
            (void) (*intf)->USBInterfaceClose(intf);
            (void) (*intf)->Release(intf);
            return [NSString stringWithFormat:@"unable to create async event source (%08x)\n", kr];

        }
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
        
        printf("Async event source added to run loop.\n");
        
        for(i=0;i < len;i++)
        {
            data1[i] = strtol((char *) [[Data_bye stringValue] UTF8String], NULL, 16);                      //to convert hex string into binary
        }
        kr = (*intf)->WritePipeAsync(intf, pipeRef, data1, len, WriteCompletion, (void *) intf);
        if (kIOReturnSuccess != kr)
        {
            (void) (*intf)->USBInterfaceClose(intf);
            (void) (*intf)->Release(intf);
            return [NSString stringWithFormat:@"unable to do async bulk write (%08x)\n", kr];
        }
#endif		
		return str;		
	} else {
#ifndef USE_ASYNC_IO
		UInt32 noDataTimeout = 50;
		UInt32 completiomTimeout = 500;
		numBytesRead = len;
		kr = (*intf)->ReadPipeTO(intf, pipeRef, data1, &numBytesRead, noDataTimeout, completiomTimeout);
		if (kIOReturnSuccess != kr)
		{
//			(void) (*intf)->USBInterfaceClose(intf);
//			(void) (*intf)->Release(intf);
			return [NSString stringWithFormat:@"unable to do bulk read (%08x)\n", kr];
		}
		
        for(i=0;i<len;i++)
        {
            if(!(i%16))
                str = [str stringByAppendingFormat:@"\n %04x   ", i];
            
            str = [str stringByAppendingFormat:@"%02x  ",data1[i]];
        }
		str = [str stringByAppendingFormat:@"\n"];
#else
        printf("Async event source added to run loop.\n");

		kr = (*intf)->ReadPipeAsync(intf, pipeRef, data1, len, ReadCompletion,(void *) intf);
		if (kIOReturnSuccess != kr)
		{
			printf("unable to do async bulk read (%08x)\n", result);
			(void) (*intf)->USBInterfaceClose(intf);
			(void) (*intf)->Release(intf);
		}		
#endif
		return str;
	}
}

/*
    IBAction linked with "Show Cypress Device Info" button. Appends the infostr to the textview display that contains the specs of the Cypress device found, which is computed in the "print" method. 
 */

- (IBAction)Infobutton:(id)sender{
    
	string = [string stringByAppendingFormat:infostr];
	[actualtextview_var setString:string]; 
}

/*
 IBAction linked with Bulk Transfers button: "Bulk_Xfer:". Depending on the endpoint selected from the combobox, "EndpointBox", calls LibUsb_TransferData method, with appropriate parameters.
 
 */

- (IBAction)Bulk_Xfer:(id)sender {
    

	int selitem = (int)[Endpointbox_var indexOfSelectedItem] + 1;
	string = [string stringByAppendingFormat:[self IOUSB_TransferData:selitem d:inout[selitem]]];

    [actualtextview_var setString:string];                                                      // update textview with result of transfer, data bytes transferred
    
}

/*
 IBAction linked with Clear button: "Clear:". Clears the "textview" text.
 */


- (IBAction)Clear:(id)sender {
    string = @"";
    [actualtextview_var setString:string]; 
    
}

/*
  IBAction linked with Vendor Requests button: "VndrReq_button:". Initiates the Vendor command to the device, with appropriate parameters as entered by the user.
 */

- (IBAction)VndrReq_button:(id)sender {    
    IOReturn			kr;
	IOUSBDevRequest     request;
    unsigned char  	ret_data[64];
    
    request.bRequest = strtol((char *) [[Vndr_Reqcode_var stringValue] UTF8String], NULL, 16);
    request.wValue = strtol((char *) [[Vndr_Value_var stringValue] UTF8String], NULL, 16);
    request.wIndex = strtol((char *) [[Vndr_Index_var stringValue] UTF8String], NULL, 16);
    request.wLength = strtol((char *) [[Vndr_Length_var stringValue] UTF8String], NULL, 10);
    request.pData = ret_data;

	
    request.bmRequestType = USBmakebmRequestType([Vndr_Dir_var indexOfSelectedItem] == 0 ? kUSBOut : kUSBIn,
												 kUSBVendor,
												 kUSBDevice);

	kr = (*dev)->DeviceRequest(dev, &request);
	if (kIOReturnSuccess != kr)
	{
        string = [string stringByAppendingFormat:@"Vendor command failed \n"];
	} else {
        string = [string stringByAppendingFormat:@"\n Vendor Command Successful \n %02x \n ", ret_data[0]];
	}

    [actualtextview_var setString:string];                                                          //displays the result of the Vendor command.
    
}


/*
 Method "Setup_EndpointBox" - sets up the combobox "EndpointBox" with endpoints available in the bulkloop device
 */

- (void) Setup_EndpointBox
{
    IOReturn			kr;
    IOUSBFindInterfaceRequest	request;
	UInt8			intfNumEndpoints;
    int				pipeRef;
	
    request.bInterfaceClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    request.bAlternateSetting = kIOUSBFindInterfaceDontCare;

	kr = (*intf)->GetNumEndpoints(intf, &intfNumEndpoints);
	if (kIOReturnSuccess != kr)
	{
		printf("unable to get number of endpoints (%08x)\n", kr);
		(void) (*intf)->USBInterfaceClose(intf);
		(void) (*intf)->Release(intf);
		return;
	}
	
	printf("Interface has %d endpoints.\n", intfNumEndpoints);
	
	for (pipeRef = 1; pipeRef <= intfNumEndpoints; pipeRef++)
	{
		IOReturn	kr2;
		UInt8	direction;
		UInt8	number;
		UInt8	transferType;
		UInt16	maxPacketSize;
		UInt8	interval;
		char	*dirstr;
		char	*typestr;
		
		kr2 = (*intf)->GetPipeProperties(intf, pipeRef, &direction, &number, &transferType, &maxPacketSize, &interval);
		if (kIOReturnSuccess != kr)
			printf("unable to get properties of pipe %d (%08x)\n", pipeRef, kr2);
		else {
			
			switch (direction) {
				case kUSBOut:
					inout[pipeRef] = 0;
					dirstr = "OUT";
					break;
				case kUSBIn:
					inout[pipeRef] = 1;
					dirstr = "IN";
					break;
				case kUSBNone:
					dirstr = "NONE";
					break;
				case kUSBAnyDirn:
					dirstr = "ANY";
					break;
				default:
					dirstr = "???";
			}
			
			switch (transferType) {
				case kUSBControl:
					typestr = "control";
					break;
				case kUSBIsoc:
					typestr = "Isochronous";
					break;
				case kUSBBulk:
					typestr = "Bulk";
					break;
				case kUSBInterrupt:
					typestr = "Interrupt";
					break;
				case kUSBAnyType:
					typestr = "any";
					break;
				default:
					typestr = "???";
			}
			[Endpointbox_var addItemWithTitle:
			 [NSString stringWithFormat:@"EP Address %02x  %s %s Endpoint", number, typestr, dirstr]];
		}
	}
	    
    [Endpointbox_var selectItemAtIndex:0];
    
}

@end
