//
//  Document.h
//  Mac Linux USB Loader
//
//  Created by SevenBits on 11/26/12.
//  Copyright (c) 2012 SevenBits. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RHPreferences/RHPreferences.h"

// A (C!) callback to get the progress of the copy operation.
static void copyStatusCallback (FSFileOperationRef fileOp, const FSRef *currentItem, FSFileOperationStage stage, OSStatus error,
                                CFDictionaryRef statusDictionary, void *info);

@interface Document : NSDocument {
    NSString *bootLoaderName;
    BOOL automaticallyBless;
}
@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSPanel *prefsWindow;
@property (strong) IBOutlet NSButton *makeUSBButton;
@property (strong) IBOutlet NSButton *eraseUSBButton;
@property (strong) IBOutlet NSProgressIndicator *spinner;
@property (strong) RHPreferencesWindowController *preferencesWindowController;
@property (strong) IBOutlet NSPopUpButton *usbDriveDropdown;

- (IBAction)eraseLiveBoot:(id)sender;
- (void)getUSBDeviceList;
- (void)regularAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (IBAction)updateDeviceList:(id)sender;
- (IBAction)makeLiveUSB:(id)sender;
- (void)markUsbAsLive:(NSString*)path;
@end
