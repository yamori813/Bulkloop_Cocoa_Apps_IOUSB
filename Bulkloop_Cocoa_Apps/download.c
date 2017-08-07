/*
 * Copyright (c) 2003 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*
 * © Copyright 2001 Apple Computer, Inc. All rights reserved.
 *
 * IMPORTANT:  This Apple software is supplied to you by Apple Computer, Inc. (“Apple”) in 
 * consideration of your agreement to the following terms, and your use, installation, 
 * modification or redistribution of this Apple software constitutes acceptance of these
 * terms.  If you do not agree with these terms, please do not use, install, modify or 
 * redistribute this Apple software.
 *
 * In consideration of your agreement to abide by the following terms, and subject to these 
 * terms, Apple grants you a personal, non exclusive license, under Apple’s copyrights in this 
 * original Apple software (the “Apple Software”), to use, reproduce, modify and redistribute 
 * the Apple Software, with or without modifications, in source and/or binary forms; provided 
 * that if you redistribute the Apple Software in its entirety and without modifications, you 
 * must retain this notice and the following text and disclaimers in all such redistributions 
 * of the Apple Software.  Neither the name, trademarks, service marks or logos of Apple 
 * Computer, Inc. may be used to endorse or promote products derived from the Apple Software 
 * without specific prior written permission from Apple. Except as expressly stated in this 
 * notice, no other rights or licenses, express or implied, are granted by Apple herein, 
 * including but not limited to any patent rights that may be infringed by your derivative 
 * works or by other works in which the Apple Software may be incorporated.
 * 
 * The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO WARRANTIES, 
 * EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-
 * INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE 
 * SOFTWARE OR ITS USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS. 
 *
 * IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL 
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
 * OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, 
 * REPRODUCTION, MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND 
 * WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR 
 * OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/* copy from EZload */

#include <stdio.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/IOUSBLib.h>

#include <mach/mach.h>

#include "download.h"

#define kFX2_USBCS		0xe600

#define MAX_INTEL_HEX_RECORD_LENGTH 32

typedef struct _INTEL_HEX_RECORD
{
	UInt32  	Length;
	UInt32 	Address;
	UInt32  	Type;
	UInt8  	Data[MAX_INTEL_HEX_RECORD_LENGTH];
} INTEL_HEX_RECORD, *PINTEL_HEX_RECORD;

IOReturn hexRead(INTEL_HEX_RECORD *record, FILE *hexFile)
{	// Read the next hex record from the file into the structure
	
    // **** Need to impliment checksum checking ****
    
    
	char c;
	UInt16 i;
	int n, c1, check, len;
    c = getc(hexFile);
    
    if(c != ':')
    {
        printf("Line does not start with colon (%d)\n", c);
        return(kIOReturnNotAligned);
    }
    n = fscanf(hexFile, "%2lX%4lX%2lX", &record->Length, &record->Address, &record->Type);
    if(n != 3)
    {
        printf("Could not read line preamble %d\n", c);
        return(kIOReturnNotAligned);
    }
    
    len = record->Length;
    if(len > MAX_INTEL_HEX_RECORD_LENGTH)
    {
        printf("length is more than can fit %d, %d\n", len, MAX_INTEL_HEX_RECORD_LENGTH);
        return(kIOReturnNotAligned);
	}
    for(i = 0; i<len; i++)
    {
        n = fscanf(hexFile, "%2X", &c1);
        if(n != 1)
        {
            if(i != record->Length)
            {
                printf("Line finished at wrong time %d, %ld\n", i, record->Length);
                return(kIOReturnNotAligned);
            }
        }
        record->Data[i] = c1;
		
    }
    n = fscanf(hexFile, "%2X\n", &check);
    if(n != 1)
    {
        printf("Check not found\n");
        return(kIOReturnNotAligned);
    }
    return(kIOReturnSuccess);
}

IOReturn CypressWrite(IOUSBDeviceInterface245 **dev, UInt16 CypressAddress, UInt16 count, UInt8 writeBuffer[])
{
    IOUSBDevRequest 		request;
    
    request.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice);
    request.bRequest = 0xa0;
    request.wValue = CypressAddress;
    request.wIndex = 0;
    request.wLength = count;
    request.pData = writeBuffer;
	
    return (*dev)->DeviceRequest(dev, &request);
}

IOReturn DownloadToCypressDevice(IOUSBDeviceInterface245 **dev, char *filename)
{
    UInt8 	writeVal;
    IOReturn	kr;
	FILE *hexFile;
	INTEL_HEX_RECORD CypressCode;
    
	hexFile = fopen(filename, "r");
	
    if(hexFile == nil)
    {
        printf("File open failed\n");
        return(kIOReturnNotOpen);
    }
	
    // Assert reset
    writeVal = 1;
	kr = CypressWrite(dev, kFX2_USBCS, 1, &writeVal);
	
    if (kIOReturnSuccess != kr) 
    {
        printf("CypressWrite reset returned err 0x%x!\n", kr);
		
		//	Don't do this, the calling function does this on error.
		//        (*dev)->USBDeviceClose(dev);
		//        (*dev)->Release(dev);
        return kr;
    }
    
    // Download code
    while (1) 
    {
		kr = hexRead(&CypressCode, hexFile);
		if(CypressCode.Type != 0)
		{
			break;
		}
        if(kr == kIOReturnSuccess)
        {
            kr = CypressWrite(dev, CypressCode.Address, CypressCode.Length, CypressCode.Data);
        }
        if (kIOReturnSuccess != kr) 
        {
            printf("CypressWrite download %lx returned err 0x%x!\n", CypressCode.Address, kr);
			//	Don't do this, the calling function does this on error.
			//            (*dev)->USBDeviceClose(dev);
			//            (*dev)->Release(dev);
            return kr;
        }
    }
	
    // De-assert reset
    writeVal = 0;
	kr = CypressWrite(dev, kFX2_USBCS, 1, &writeVal);
    if (kIOReturnSuccess != kr) 
    {
        printf("CypressWrite run returned err 0x%x!\n", kr);
    }
    
    return kr;
}
