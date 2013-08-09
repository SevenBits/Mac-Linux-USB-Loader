//
//  Document.m
//  Mac Linux USB Loader
//
//  Created by SevenBits on 11/26/12.
//  Copyright (c) 2012 SevenBits. All rights reserved.
//

#import "Document.h"
#import "USBDevice.h"

#import "RHPreferences/RHPreferences.h"
#import "RHPreferences/RHPreferencesWindowController.h"

#import "RHAppDelegate.h"
#import "RHAboutViewController.h"
#import "RHAccountsViewController.h"
#import "RHNotificationViewController.h"

#pragma mark - SBCopyDelegateInfoRelay class

/*
 * A simple class used to store information that we'll pass to the progress bar.
 */
@interface SBCopyDelegateInfoRelay : NSObject

@property NSProgressIndicator *progress;
@property NSString *usbRoot;
@property NSWindow *window;
@property Document *document;

@end

@implementation SBCopyDelegateInfoRelay

@end

#pragma mark - Document class

@implementation Document

@synthesize window;

NSMutableDictionary *usbs;
NSString *isoFilePath;
USBDevice *device;
FSFileOperationClientContext clientContext;
SBCopyDelegateInfoRelay *infoClientContext;

BOOL isCopying = NO;

- (id)init {
    self = [super init];
    if (self) {
        // No initilization needed here.
    }
    return self;
}

- (NSString *)windowNibName {
    return @"Document";
}

- (BOOL)windowShouldClose:(id)sender {
    if (isCopying) {
        return NO;
    } else {
        return YES;
    }
}

- (void)windowControllerDidLoadNib:(NSWindowController *)controller {
    /* I KNOW, progress bar names are totally mixed up. Someone want to fix this for me? */
    [super windowControllerDidLoadNib:controller];
    usbs = [[NSMutableDictionary alloc] initWithCapacity:10]; //A maximum capacity of 10 is fine, nobody has that many ports anyway.
    device = [USBDevice new];
    device.window = window;
    
    isoFilePath = [[self fileURL] absoluteString];
    
    if (isoFilePath == nil) {
        [_makeUSBButton setEnabled:NO];
        [_eraseUSBButton setEnabled:NO];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    bootLoaderName = [defaults stringForKey:@"selectedFirmwareType"];
    automaticallyBless = [defaults boolForKey:@"automaticallyBless"];
    
    [self getUSBDeviceList];
}

- (void)getUSBDeviceList {
    // Fetch the NSArray of strings of mounted media from the shared workspace.
    NSArray *volumes = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];
    
    // Setup target variables for the data to be put into.
    BOOL isRemovable, isWritable, isUnmountable;
    NSString *description, *volumeType;
    
    [_usbDriveDropdown removeAllItems]; // Clear the dropdown list.
    [usbs removeAllObjects];           // Clear the dictionary of the list of USB drives.
    
    // Iterate through the array using fast enumeration.
    for (NSString *volumePath in volumes) {
        // Get filesystem info about each of the mounted volumes.
        if ([[NSWorkspace sharedWorkspace] getFileSystemInfoForPath:volumePath isRemovable:&isRemovable isWritable:&isWritable isUnmountable:&isUnmountable description:&description type:&volumeType]) {
            if ([volumeType isEqualToString:@"msdos"] && isWritable && [volumePath rangeOfString:@"/Volumes/"].location != NSNotFound) {
                // We have a valid mounted media - not necessarily a USB though.
                NSString * title = [NSString stringWithFormat:@"Install to: Drive at %@ of type %@", volumePath, volumeType];
                
#if (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_8)
                usbs[title] = volumePath; // Add the path of the usb to a dictionary so later we can tell what USB
                                          // they are refering to when they select one from a drop down.
#elif
                [usbs setObject:volumePath forKey:title];
#endif
                [_usbDriveDropdown addItemWithTitle:title]; // Add to the dropdown list.
            }
        }
    }
    
    /*
     Basically, this makes sure that you can't make the live USB if you don't have a file open (shouldn't happen, but a
     precaution), or if there are no mounted volumes we can use. If we have a mounted volume, though, and we have an ISO,
     then they can make the live USB.
     */
    if (isoFilePath != nil && [_usbDriveDropdown numberOfItems] != 1) {
        [_makeUSBButton setEnabled:YES];
        [_eraseUSBButton setEnabled:YES];
    } else if ([_usbDriveDropdown numberOfItems] == 0) { // There are no detected USB ports, at least those formatted as FAT.
        [_makeUSBButton setEnabled:NO];
        [_eraseUSBButton setEnabled:NO];
    }
    // Exit.
}

- (IBAction)updateDeviceList:(id)sender {
    [self getUSBDeviceList];
}

// This is too long... this needs to be split up, perhaps with some components in USBDevice like before.
- (IBAction)makeLiveUSB:(id)sender {
    [[NSApp delegate] setCanQuit:NO];
    isCopying = YES;
    
    __block BOOL failure = false;
    
    isoFilePath = [[self fileURL] path];
    
    // Re-read the user's firmware selection in case they've changed it since opening the ISO.
    bootLoaderName = [[NSUserDefaults standardUserDefaults] stringForKey:@"selectedFirmwareType"];
    if (![bootLoaderName isEqualToString:@"Legacy Loader"]) {
        // Enterprise is not currently finished and not bundled with Mac Linux USB Loader, so bail if the user selected
        // it as their firmware to be installed.
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Okay"];
        [alert setMessageText:@"Selected firmware not present."];
        [alert setInformativeText:@"The firmware that you have selected to install is not ready to ship in this pre-release version of Mac Linux USB Loader and therefore cannot be installed. Please choose another firmware selection in the Preferences panel."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(regularAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        
        [_makeUSBButton setEnabled:NO];
        [_eraseUSBButton setEnabled:NO];
        
        [[NSApp delegate] setCanQuit:YES]; // We're done, the user can quit the program.
        isCopying = NO;
        
        return;
    }
    
    // If no USBs available, or if no ISO open, display an error and return.
    if ([_usbDriveDropdown numberOfItems] == 0 || isoFilePath == nil) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Okay"];
        [alert setMessageText:@"No USB devices detected."];
        [alert setInformativeText:@"There are no detected USB devices."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(regularAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        
        [_makeUSBButton setEnabled:NO];
        [_eraseUSBButton setEnabled:NO];
        
        [[NSApp delegate] setCanQuit:YES]; // We're done, the user can quit the program.
        isCopying = NO;
        
        return;
    }
    
    NSString* directoryKey = [_usbDriveDropdown titleOfSelectedItem];
    NSString* usbRoot = [usbs valueForKey:directoryKey];
    NSString* finalPath = [usbRoot stringByAppendingPathComponent:@"/efi/boot/"];
    
    directoryKey = nil; // Tell the garbage collector to release this object.
    
    [_spinner setUsesThreadedAnimation:YES];
    [_spinner setIndeterminate:YES];
    [_spinner setDoubleValue:0.0];
    [_spinner startAnimation:self];
    
    // Check if the Linux distro ISO already exists.
    NSString *temp = [usbRoot stringByAppendingPathComponent:@"/efi/boot/boot.iso"];
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:temp];
    
    if (fileExists == YES) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Abort"];
        [alert setMessageText:@"Failed to create bootable USB."];
        [alert setInformativeText:@"There is already a Linux distro ISO on this device. If it is from a previous run of Mac Linux USB Loader, you must delete the EFI folder on the USB drive and then run this tool."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(regularAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        
        [_spinner stopAnimation:self];
        [[NSApp delegate] setCanQuit:YES];
        isCopying = NO;
        
        return;
    }

    // Now progress with the copy.
    [[NSApp delegate] setCanQuit:NO]; // The user can't quit while we're copying.
    if ([device prepareUSB:usbRoot] == YES) {
        [_spinner setIndeterminate:NO];
        [_spinner setUsesThreadedAnimation:YES];
            
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        // Use the NSFileManager to obtain the size of our source file in bytes.
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDictionary *sourceAttributes = [fileManager fileAttributesAtPath:[[self fileURL] path] traverseLink:YES];
        NSNumber *sourceFileSize;
        
        if ((sourceFileSize = sourceAttributes[NSFileSize])) {
            // Set the max value to our source file size.
            [_spinner setMaxValue:(double)[sourceFileSize unsignedLongLongValue]];
        } else {
            // Couldn't get the file size so we need to bail.
            NSLog(@"Unable to obtain size of file being copied.");
            return;
        }
        [_spinner setDoubleValue:0.0];
            
        // Get the current run loop and schedule our callback
        CFRunLoopRef runLoop = CFRunLoopGetCurrent();
        FSFileOperationRef fileOp = FSFileOperationCreate(kCFAllocatorDefault);
        
        OSStatus status = FSFileOperationScheduleWithRunLoop(fileOp, runLoop, kCFRunLoopDefaultMode);
        if(status) {
            NSLog(@"Failed to schedule operation with run loop: %d", status);
            return;
        }
             
        // Create a filesystem ref structure for the source and destination and
        // populate them with their respective paths.
        FSRef source;
        FSRef destination;
            
        FSPathMakeRef((const UInt8 *)[[[self fileURL] path] fileSystemRepresentation], &source, NULL);
            
        Boolean isDir = true;
        FSPathMakeRef((const UInt8 *)[finalPath fileSystemRepresentation], &destination, &isDir);
        
        // Construct the storage class.
        NSLog(@"Constructing the info client context...");
        infoClientContext = [SBCopyDelegateInfoRelay new];
        infoClientContext.progress = _spinner;
        infoClientContext.usbRoot = usbRoot;
        infoClientContext.window = window;
        infoClientContext.document = self;
        
        // Start the async copy.
        if (_spinner != nil) {
            clientContext.info = (__bridge void *)infoClientContext;
        }
        
        NSLog(@"Performing the copy...");
        status = FSCopyObjectAsync(fileOp,
                                   &source,
                                   &destination, // Full path to destination dir.
                                   CFSTR("boot.iso"), // Copy with the name boot.iso.
                                   kFSFileOperationDefaultOptions,
                                   copyStatusCallback, // Our callback function.
                                   0.5, // How often to fire our callback.
                                   &clientContext); // The class with the objects that we want to use to update.
        
        CFRelease(fileOp);
        
        if(status) {
            NSLog(@"Failed to begin asynchronous object copy: %d", status);
            failure = YES;
        }
        
#pragma clang diagnostic warning "-Wdeprecated-declarations"
        
        if (!failure) {
            [self markUsbAsLive:usbRoot]; // Place a file on the USB to identify it as being created by Mac Linux USB Loader.
        }
    } else {
        // Some form of setup failed. Alert the user.
        [[NSApp delegate] setCanQuit:YES];
        isCopying = NO;
        
        failure = YES;
    }
    
    if (failure) {
        [_spinner setIndeterminate:NO];
        [_spinner setDoubleValue:0.0];
        [_spinner stopAnimation:self];
        
        [_spinner stopAnimation:self];
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"No"];
        [alert addButtonWithTitle:@"Yes"];
        [alert setMessageText:@"Failed to create bootable USB."];
        [alert setInformativeText:@"Do you erase the incomplete EFI boot?"];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(eraseAlertDidEnd:returnCode:contextInfo:) contextInfo:nil]; // Offer to erase the EFI boot since we never completed.
    } else {
    }
}

- (void)markUsbAsLive:(NSString*)path {
    NSLog(@"Marking this USB as a live USB...");
    
    NSError* error;

    NSString *filePath = [path stringByAppendingPathComponent:@"/efi/boot/.MLUL-Live-USB"];
    NSString *str = [NSString stringWithFormat:@"%@\n%@", isoFilePath, path];
    
    [str writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

+ (BOOL)autosavesInPlace
{
    return NO;
}

+ (BOOL)isEntireFileLoaded {
    return YES;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    // If you override either of these, you should also override -isEntireFileLoaded to return NO if the contents are lazily loaded.
    return YES;
}

- (IBAction)eraseLiveBoot:(id)sender {
    if ([_usbDriveDropdown numberOfItems] != 0) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Yes"];
        [alert addButtonWithTitle:@"No"];
        [alert setMessageText:@"Are you sure that you want to erase the live boot?"];
        [alert setInformativeText:@"This will recover space by erasing everything in the EFI folder on the USB drive, but is unrecoverable."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(eraseAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
    } else {
        [sender setEnabled:NO];
    }
}

- (void)regularAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    // Do nothing.
}

- (void)eraseAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) {
        [[NSApp delegate] setCanQuit:NO];

        if ([_usbDriveDropdown numberOfItems] != 0) {
            // Construct the path of the efi folder that we're going to nuke.
            NSString *directoryName = [_usbDriveDropdown titleOfSelectedItem];
            NSString *usbRoot = [usbs valueForKey:directoryName];
            NSString *tempPath = [usbRoot stringByAppendingPathComponent:@"/efi"];
            
            // Need these to recursively delete the folder, because UNIX can't erase a folder without erasing its
            // contents first, apparently.
            NSFileManager* fm = [[NSFileManager alloc] init];
            NSDirectoryEnumerator* en = [fm enumeratorAtPath:tempPath];
            NSError *err = nil;
            BOOL eraseDidSucceed;
            
            // Recursively erase the EFI folder.
            NSString *file;
            while (file = [en nextObject]) { // While there are files to remove...
                eraseDidSucceed = [fm removeItemAtPath:[tempPath stringByAppendingPathComponent:file] error:&err]; // Delete.
                if (!eraseDidSucceed && err) { // If there was an error...
                    NSString *text = [NSString stringWithFormat:@"Error: %@", err];
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert addButtonWithTitle:@"Okay"];
                    [alert setMessageText:@"Failed to erase live USB."];
                    [alert setInformativeText:text];
                    [alert setAlertStyle:NSWarningAlertStyle];
                    [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(regularAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
                    NSLog(@"Could not delete: %@", err);
                }
            }
        }
        
        [[NSApp delegate] setCanQuit:YES];
        isCopying = NO;
    }
}
@end

// Static function for our callback.
static void copyStatusCallback (FSFileOperationRef fileOp, const FSRef *currentItem, FSFileOperationStage stage, OSStatus error,
                            CFDictionaryRef statusDictionary, void *info) {
    /* Grab our instance of the class that we passed in as the void pointer and retrieve all of the needed fields from
     * it.
     */
    SBCopyDelegateInfoRelay *context = (__bridge SBCopyDelegateInfoRelay *)(info);
    NSProgressIndicator *progressIndicator;
    NSWindow *window;
    NSString *usbRoot;
    Document *document;
    if (context.progress != nil && context.window != nil && context.usbRoot != nil && context.document != nil) {
        progressIndicator = context.progress; // The progress bar to update.
        window = context.window; // The document window.
        usbRoot = context.usbRoot; // The path to the USB drive.
        document = context.document; // The document class.
    } else {
        NSLog(@"Some components are nil!");
    }
    
    if (progressIndicator == nil) {
        NSLog(@"Progress bar is nil!");
    }
    
    if (statusDictionary) {
        CFNumberRef bytesCompleted;
        
        bytesCompleted = (CFNumberRef) CFDictionaryGetValue(statusDictionary, kFSOperationBytesCompleteKey);
        
        CGFloat floatBytesCompleted;
        CFNumberGetValue (bytesCompleted, kCFNumberMaxType, &floatBytesCompleted);
        
#ifdef DEBUG
        //NSLog(@"Copied %lld bytes so far.", (unsigned long long)floatBytesCompleted);
#endif
        
        [progressIndicator setDoubleValue:(double)floatBytesCompleted];
        
        if (stage == kFSOperationStageComplete) {
            NSLog(@"Copy operation has completed.");
            
            [progressIndicator setDoubleValue:0];
            
#if (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_8)
            // Show a notification for Mountain Lion users.
            Class test = NSClassFromString(@"NSUserNotificationCenter");
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            
            // Ensure that we are running 10.8 before we display the notification as we still support Lion, which does not have
            // them.
            if (test != nil && [defaults boolForKey:@"ShowNotifications"] == YES) {
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                
                if ([defaults valueForKey:@"ShowNotifications"]) {
                    NSUserNotification *notification = [[NSUserNotification alloc] init];
                    notification.title = @"Finished Making Live USB";
                    notification.informativeText = @"The live USB has been made successfully.";
                    notification.soundName = NSUserNotificationDefaultSoundName;
                    
                    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
                }
                
                NSAlert *alert = [[NSAlert alloc] init];
                [alert addButtonWithTitle:@"Okay"];
                [alert setMessageText:@"Finished Making Live USB"];
                [alert setInformativeText:@"The live USB has been made successfully."];
                [alert setAlertStyle:NSWarningAlertStyle];
                
                if (document != nil || window != nil) {
                    [alert beginSheetModalForWindow:window modalDelegate:document didEndSelector:@selector(regularAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
                } else {
                    [alert runModal];
                }
            } else {
                [NSApp requestUserAttention:NSCriticalRequest];
            }
#else
            [NSApp requestUserAttention:NSCriticalRequest];
#endif
            [[NSApp delegate] setCanQuit:YES]; // We're done, the user can quit the program.
            isCopying = NO;
            
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyBless"] == YES) {
                [[NSApp delegate] blessDrive:usbRoot sender:nil]; // Automatically bless the user's drive.
            }
        }
    }
}

