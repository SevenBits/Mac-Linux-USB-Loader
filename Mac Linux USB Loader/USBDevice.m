//
//  USBDevice.m
//  Mac Linux USB Loader
//
//  Created by SevenBits on 11/26/12.
//  Copyright (c) 2012 SevenBits. All rights reserved.
//

#import "USBDevice.h"

@implementation USBDevice

- (BOOL)prepareUSB:(NSString *)path {
    // Construct our strings that we need.
    NSString *bootLoaderPath = [[NSBundle mainBundle] pathForResource:@"bootX64" ofType:@"efi" inDirectory:@""];
    NSString *finalPath = [path stringByAppendingPathComponent:@"/efi/boot/bootX64.efi"];
    NSString *tempPath = [path stringByAppendingPathComponent:@"/efi/boot"];
    
    // Check if the EFI bootloader already exists.
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:finalPath];
    
    // Should be relatively self-explanatory. If there's already an EFI executable, show an error message.
    if (fileExists == YES) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Abort"];
        [alert setMessageText:@"Failed to create bootable USB."];
        [alert setInformativeText:@"There is already EFI firmware on this device. If it is from a previous run of Mac Linux USB Loader, you must delete the EFI folder on the USB drive and then run this tool."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        return NO;
        
        [[NSApp delegate] setCanQuit:YES];
    }
    
    // Make the folder to hold the EFI executable and ISO to boot.
    [[NSFileManager new] createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Copy the EFI bootloader.
    if ([[NSFileManager new] copyItemAtPath:bootLoaderPath toPath:finalPath error:nil] == NO) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Abort"];
        [alert setMessageText:@"Failed to create bootable USB."];
        [alert setInformativeText:@"Could not copy the EFI bootloader to the USB device."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        return NO;
    }
    else {
        return YES;
    }
}

/*
 * THIS FUNCTION IS NO LONGER IN USE
 *
 * I don't really want to use this anymore as NSFileManager does not allow you to get the progress of the file
 * copy.
 */
/*- (BOOL)copyISO:(NSString *)path:(NSString *)isoFile:(NSProgressIndicator *)progressBar:(Document *)document {
    NSString *finalPath = [NSString stringWithFormat:@"%@/efi/boot/boot.iso", path];
    
    // Check if the Linux distro ISO already exists.
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:finalPath];
    
    if (fileExists == YES) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Abort"];
        [alert setMessageText:@"Failed to create bootable USB."];
        [alert setInformativeText:@"There is already a Linux distro ISO on this device. If it is from a previous run of Mac Linux USB Loader, you must delete the EFI folder on the USB drive and then run this tool."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        return NO;
    }
    
    // NSLog(@"Writing from %@.", isoFile);
    
    // Copy the Linux distro ISO.
    if ([[NSFileManager new] copyItemAtPath:[[NSURL URLWithString:isoFile] path] toPath:finalPath error:nil] == NO) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Abort"];
        [alert setMessageText:@"Failed to create bootable USB."];
        [alert setInformativeText:@"Could not copy the Linux ISO to the USB device."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        return NO;
    } else {
#if (MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_8)
        // Show a notification for Mountain Lion users.
        NSProcessInfo *pinfo = [NSProcessInfo processInfo];
        NSArray *myarr = [[pinfo operatingSystemVersionString] componentsSeparatedByString:@" "];
        NSString *version = [myarr objectAtIndex:1];
        
        // Ensure that we are running 10.8 before we display the notification as we still support Lion, which does not have
        // them.
        if ([version rangeOfString:@"10.8"].location != NSNotFound) {
            NSUserNotification *notification = [[NSUserNotification alloc] init];
            notification.title = @"Finished Making Live USB";
            notification.informativeText = @"The live USB has been made successfully.";
            notification.soundName = NSUserNotificationDefaultSoundName;
            
            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        } else {
            [NSApp requestUserAttention:NSCriticalRequest];
        }
#else
        [NSApp requestUserAttention:NSCriticalRequest];
#endif
        
        return YES;
    }
}*/

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    // Empty because under normal processing we need not do anything here.
}

@end
