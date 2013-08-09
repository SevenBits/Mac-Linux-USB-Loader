//
//  RHAppDelegate.m
//  RHPreferencesTester
//
//  Originally created by Richard Heard on 23/05/12. Subsequently modified by SevenBits.
//  Copyright (c) 2012-2013 SevenBits. All rights reserved.
//

#import "RHAppDelegate.h"

@implementation RHAppDelegate

NSWindow *downloadLinuxDistroSheet;
BOOL canQuit = YES;

DistributionDownloader *distributionDownloader;

/*
 * This array of NSStrings will be full of URLs to ISOs that the user can download.
 */
NSString *urlArray[] = {
    @"http://releases.ubuntu.com/13.04/ubuntu-13.04-desktop-amd64+mac.iso", // Ubuntu 13.04 for Mac
    @"http://linuxfreedom.com/linuxmint/stable/14/linuxmint-14.1-cinnamon-dvd-64bit.iso", // Mint 14.1 US
    @"http://linuxfreedom.com/linuxmint/stable/15/linuxmint-15-cinnamon-dvd-64bit.iso", // Mint 15 US
    @"http://distro.ibiblio.org/zorin/6/zorin-os-6.3-core-64.iso" // Zorin OS 6.3 US
    };

- (void)dealloc {
    _preferencesWindowController = nil;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application.
    // Load default defaults.
    [[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"defaults" ofType:@"plist"]]];
    
    [_eraseUSBSelector removeAllItems];
    [self detectUSBs:nil];
    
    NSArray *myArray = [[NSDocumentController sharedDocumentController] recentDocumentURLs];
    [_dataSource setArray:myArray];
    [_recentFileBrowser setDataSource:_dataSource];
    [_recentFileBrowser setDoubleAction:@selector(respondToRecentFileDoubleClick)];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    bootLoaderName = [defaults stringForKey:@"selectedFirmwareType"];
    automaticallyBless = [defaults boolForKey:@"automaticallyBless"];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    [_window makeKeyAndOrderFront:nil];
    return YES;
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
    [_window makeKeyAndOrderFront:nil];
    return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    // Once we get any operation going, do this to not let the user quit the app until it finishes.
    if (canQuit) {
        return YES;
    } else {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Yes"];
        [alert addButtonWithTitle:@"No"];
        [alert setMessageText:@"Operation in progress."];
        [alert setInformativeText:@"Mac Linux USB Loader is currently in the middle of an operation. Quitting the application at this time could result in corrupted data. Do you want to quit anyway?"];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(quitSheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
        return NO;
    }
}

- (void)respondToRecentFileDoubleClick {
    NSInteger clickedRow = [_recentFileBrowser clickedRow];
    
    if (clickedRow != -1) { // We're in the row.
        NSDocumentController *docControl = [NSDocumentController sharedDocumentController];
        NSURL *selectedDocument = (NSURL *)[docControl recentDocumentURLs][clickedRow];
        NSLog(@"Selected row %ld.", (long)clickedRow);
        [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:selectedDocument display:YES completionHandler:nil];
    }
}

- (void)blessDrive:(NSString *)path sender:(id)sender {
    // Create authorization reference.
    OSStatus status;
    AuthorizationRef authorizationRef;
    
    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
    if (status != errAuthorizationSuccess) {
        NSLog(@"Error Creating Initial Authorization: %d", status);
        return;
    }
    
    /*
     * Set the rights we want for our authorization request. The rights we request primarily determine the message
     * shown on the authentication window, in our case, "Mac Linux USB Loader wants to make changes".
     */
    // kAuthorizationRightExecute == "system.privilege.admin"
    AuthorizationItem right = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights rights = {1, &right};
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
    kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    // Call AuthorizationCopyRights to determine or extend the allowable rights.
    status = AuthorizationCopyRights(authorizationRef, &rights, NULL, flags, NULL);
    if (status != errAuthorizationSuccess) {
#ifdef DEBUG
        NSLog(@"Copy Rights Unsuccessful: %d", status);
#endif
        return;
    }
    
    // Set up the command line arguments.
    char *efiFile = (char *)[[path stringByAppendingPathComponent:@"/efi/boot/bootx64.efi"] UTF8String]; // Create the path to the EFI file.
    char *tool = "/usr/sbin/bless";
    char *args[] = {"--mount", (char *)[[_bootUSBSelector titleOfSelectedItem] UTF8String], "--file", efiFile, "--setBoot", NULL};
    FILE *pipe = NULL;
    
    /*
     * I know that AuthorizationExecuteWithPrivileges is deprecated since Lion, however, using a helper tool to simply
     * call bless seems to be overkill at this stage, and since bless is a relatively innocuous tool it should be safe
     * to do this for the time being.
     */
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    status = AuthorizationExecuteWithPrivileges(authorizationRef, tool, kAuthorizationFlagDefaults, args, &pipe);
#pragma clang diagnostic warning "-Wdeprecated-declarations"
    
    if (status != errAuthorizationSuccess) {
        NSLog(@"Error: %d", status);
        return;
    }
    
    status = AuthorizationFree(authorizationRef, kAuthorizationFlagDestroyRights);
}

#pragma mark - IBActions
- (IBAction)showPreferences:(id)sender {
    // If we have not created the window controller yet, create it now.
    if (!_preferencesWindowController) {
        RHAccountsViewController *accounts = [[RHAccountsViewController alloc] init];
        RHAboutViewController *about = [[RHAboutViewController alloc] init];
        RHNotificationViewController *notifications = [[RHNotificationViewController alloc] init];
        SBFirmwareViewController *firmwareController = [[SBFirmwareViewController alloc] init];
        
        NSArray *controllers = @[accounts, notifications, firmwareController,
                                [RHPreferencesWindowController flexibleSpacePlaceholderController], 
                                about];
        
        _preferencesWindowController = [[RHPreferencesWindowController alloc] initWithViewControllers:controllers andTitle:NSLocalizedString(@"Preferences", @"Preferences Window Title")];
    }
    
    [_preferencesWindowController showWindow:self];
}

#pragma mark - USB Live Eraser

- (IBAction)showEraseDistroSheet:(id)sender {
    [NSApp beginSheet:eraseSheet modalForWindow:(NSWindow *)_window modalDelegate:self
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)closeEraseDistroSheet:(id)sender {
    [NSApp endSheet:eraseSheet];
    [eraseSheet orderOut:sender];
}

- (IBAction)detectUSBs:(id)sender {
    // Fetch the NSArray of strings of mounted media from the shared workspace.
    NSArray *volumes = [[NSWorkspace sharedWorkspace] mountedRemovableMedia];
    
    // Setup target variables for the data to be put into.
    BOOL isRemovable, isWritable, isUnmountable;
    NSString *description, *volumeType;
    
    [_eraseUSBSelector removeAllItems]; // Clear the dropdown list.
    [_bootUSBSelector removeAllItems];
    
    // Iterate through the array using fast enumeration.
    for (NSString *volumePath in volumes) {
        // Get filesystem info about each of the mounted volumes.
        if ([[NSWorkspace sharedWorkspace] getFileSystemInfoForPath:volumePath isRemovable:&isRemovable isWritable:&isWritable isUnmountable:&isUnmountable description:&description type:&volumeType]) {
            if ([volumeType isEqualToString:@"msdos"] && isWritable && [volumePath rangeOfString:@"/Volumes/"].location != NSNotFound) {
                if([[NSFileManager defaultManager] fileExistsAtPath:[volumePath stringByAppendingPathComponent:@"/efi/boot/.MLUL-Live-USB"]]) {
                    // We have a valid mounted media - not necessarily a USB though.
                    [_eraseUSBSelector addItemWithTitle:volumePath]; // Add to the dropdown lists.
                    [_bootUSBSelector addItemWithTitle:volumePath];
                }
            }
        }
    }
}

- (IBAction)eraseSelectedDrive:(id)sender {
    [[NSApp delegate] setCanQuit:NO];
    
    if ([_eraseUSBSelector numberOfItems] != 0) {
        [_eraseUSBSelector setEnabled:NO];

        // Construct the path of the efi folder that we're going to nuke.
        NSString *usbRoot = [_eraseUSBSelector titleOfSelectedItem];
        NSString *tempPath = [usbRoot stringByAppendingPathComponent:@"/efi"];
        
        // Need these to recursively delete the folder, because UNIX can't erase a folder without erasing its
        // contents first, apparently.
        NSFileManager* fm = [[NSFileManager alloc] init];
        NSDirectoryEnumerator* en = [fm enumeratorAtPath:tempPath];
        NSError *err = nil;
        BOOL eraseDidSucceed;
        
        // Recursively erase the efi folder.
        NSString *file;
        while (file = [en nextObject]) { // While there are files to remove...
            eraseDidSucceed = [fm removeItemAtPath:[tempPath stringByAppendingPathComponent:file] error:&err]; // Delete.
            
            NSAlert *alert = [[NSAlert alloc] init];
            
            if (!eraseDidSucceed && err) { // If there was an error...
                NSString *text = [NSString stringWithFormat:@"Error: %@", err];
                [alert addButtonWithTitle:@"Okay"];
                [alert setMessageText:@"Failed to erase live USB."];
                [alert setInformativeText:text];
                [alert setAlertStyle:NSWarningAlertStyle];
                [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(regularAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
                NSLog(@"Could not delete: %@", err);
            } else {
                [alert addButtonWithTitle:@"Okay"];
                [alert setMessageText:@"Erase successful."];
                [alert setInformativeText:@"The live USB has been erased."];
                [alert setAlertStyle:NSWarningAlertStyle];
                [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(regularAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
            }
        }
        
        [_eraseUSBSelector setEnabled:YES];
    }
    
    [self detectUSBs:nil]; // Reload the list of USB drives for all main menu functions (eraser, blesser, etc)
    [[NSApp delegate] setCanQuit:YES];
}

#pragma mark - Modify Boot Settings
- (IBAction)showModifyBootSettingsSheet:(id)sender {
    [NSApp beginSheet:bootSettingsSheet modalForWindow:_window modalDelegate:self
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)closeModifyBootSettingsSheet:(id)sender {
    [NSApp endSheet:bootSettingsSheet];
    [bootSettingsSheet orderOut:sender];
}

- (IBAction)blessUSB:(id)sender {
    // Check if the user has actually selected a USB drive.
    if ([_bootUSBSelector numberOfItems] == 0 || [[_bootUSBSelector titleOfSelectedItem] isEqualToString:@""]) {
#ifdef DEBUG
        NSLog(@"The user doesn't have any USB drives plugged in.");
#endif
        [NSApp endSheet:bootSettingsSheet];
        [bootSettingsSheet orderOut:sender];
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Okay"];
        [alert setMessageText:@"No USB drives are plugged in."];
        [alert setInformativeText:@"You do not have any USB drives plugged in that contain a portable Linux distribution created by Mac Linux USB Loader. Plug one in and either restart Mac Linux USB Loader or click the Refresh button the panel."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
        return;
    }
    
    [self blessDrive:[_bootUSBSelector titleOfSelectedItem] sender:sender];
    
    [self detectUSBs:sender];
    [self closeModifyBootSettingsSheet:sender];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Okay"];
    [alert setMessageText:@"Bless complete."];
    [alert setInformativeText:@"Leave the USB drive in its slot and restart the computer. Your Mac will boot directly into the Linux distribution installed on your USB drives."];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)unbless:(id)sender {
    // Check if the user has actually selected a USB drive.
    if ([_bootUSBSelector numberOfItems] == 0 || [[_bootUSBSelector titleOfSelectedItem] isEqualToString:@""]) {
#ifdef DEBUG
        NSLog(@"The user doesn't have any USB drives plugged in.");
#endif
        [NSApp endSheet:bootSettingsSheet];
        [bootSettingsSheet orderOut:sender];
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Okay"];
        [alert setMessageText:@"No USB drives are plugged in."];
        [alert setInformativeText:@"You do not have any USB drives plugged in that contain a portable Linux distribution created by Mac Linux USB Loader. Plug one in and either restart Mac Linux USB Loader or click the Refresh button the panel."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
        return;
    }
    // Create authorization reference.
    OSStatus status;
    AuthorizationRef authorizationRef;
    
    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
    if (status != errAuthorizationSuccess) {
        NSLog(@"Error Creating Initial Authorization: %d", status);
        return;
    }
    
    // kAuthorizationRightExecute == "system.privilege.admin"
    AuthorizationItem right = {kAuthorizationRightExecute, 0, NULL, 0};
    AuthorizationRights rights = {1, &right};
    AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
    kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
    
    // Call AuthorizationCopyRights to determine or extend the allowable rights.
    status = AuthorizationCopyRights(authorizationRef, &rights, kAuthorizationEmptyEnvironment, flags, NULL);
    if (status != errAuthorizationSuccess) {
#ifdef DEBUG
        NSLog(@"Copy Rights Unsuccessful: %d", status);
#endif
        return;
    }
    
    /* Set up the command line arguments. */
    char *tool = "/usr/sbin/bless";
    char *args[] = {"--unbless", (char *)[[_bootUSBSelector titleOfSelectedItem] UTF8String], NULL};
    FILE *pipe = NULL;
    
    /*
     * I know that AuthorizationExecuteWithPrivileges is deprecated since Lion, however, using a helper tool to simply
     * call bless seems to be overkill at this stage, and since bless is a relatively innocuous tool it should be safe
     * to do this for the time being.
     */
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    status = AuthorizationExecuteWithPrivileges(authorizationRef, tool, kAuthorizationFlagDefaults, args, &pipe);
#pragma clang diagnostic warning "-Wdeprecated-declarations"
    
    if (status != errAuthorizationSuccess) {
        NSLog(@"Error: %d", status);
        return;
    }
    
    status = AuthorizationFree(authorizationRef, kAuthorizationFlagDestroyRights);
    [self detectUSBs:sender];
    
    [self closeModifyBootSettingsSheet:sender];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Okay"];
    [alert setMessageText:@"Unbless complete."];
    [alert setInformativeText:@"Your USB drive has been unblessed. Your Mac will not longer boot directly into it. Instead, to boot from it, hold down the Option/Alt key after the startup chimes and select your drive when it appears."];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

#pragma mark - Distribution Downloader
- (IBAction)showDownloadDistroSheet:(id)sender {
    [NSApp beginSheet:sheet modalForWindow:_window modalDelegate:self
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)closeDownloadDistroSheet:(id)sender {
    [NSApp endSheet:sheet];
    [sheet orderOut:sender];
}

- (IBAction)openDownloadedDistro:(id)sender {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"/Downloads/"];
    NSString *isoName = [[[NSURL URLWithString:urlArray[_distroSelectorComboBox.indexOfSelectedItem]] path] lastPathComponent];
    path = [NSString stringWithFormat:@"%@/%@", path, isoName];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
    } else {
        // ISO file not downloaded yet?
        [self closeDownloadDistroSheet:sender];
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Okay"];
        [alert setMessageText:@"File not found."];
        [alert setInformativeText:@"That distribution's ISO file was not found in your Downloads folder."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
    }
}

- (IBAction)downloadDistribution:(id)sender {
    if (_distroSelectorComboBox != nil && _distroSelectorComboBox.indexOfSelectedItem != -1) {
        [self setCanQuit:NO]; // Prevent the user from quiting the application until the download has finished.
        
        [_distroDownloadButton setEnabled:NO];
        [_distroDownloadProgressIndicator startAnimation:self];
        [_distroDownloadProgressIndicator setDoubleValue:0.0];
        
#ifdef DEBUG
        NSLog(@"URL: %@", [NSURL URLWithString:urlArray[_distroSelectorComboBox.indexOfSelectedItem]]);
#endif
        NSURL *downloadLocation = [NSURL URLWithString:urlArray[_distroSelectorComboBox.indexOfSelectedItem]];
        
        distributionDownloader = [DistributionDownloader new];
        [distributionDownloader downloadLinuxDistribution:downloadLocation:
         [NSHomeDirectory() stringByAppendingPathComponent:@"/Downloads/"]:_distroDownloadProgressIndicator];
        
        // The program calls the setCanQuit method in the download delegates. We don't call it here, as this function returns
        // immediately.
    } else {
        [self closeDownloadDistroSheet:sender];
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Okay"];
        [alert setMessageText:@"No distribution selected."];
        [alert setInformativeText:@"Please select a distribution first before clicking the download button."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert beginSheetModalForWindow:_window modalDelegate:self didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:nil];
    }
}

#pragma mark - Delegates and User Actions

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    // Empty
}

- (void)quitSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if (returnCode == NSAlertFirstButtonReturn) {
        [[NSApp delegate] setCanQuit:YES];
        [NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
    }
}

- (IBAction)openDiskUtility:(id)sender {
    [[NSWorkspace sharedWorkspace] launchApplication:@"/Applications/Utilities/Disk Utility.app"];
}

- (IBAction)updateRecents:(id)sender {
    NSArray *myArray = [[NSDocumentController sharedDocumentController] recentDocumentURLs];
    
    _dataSource = [[RecentDocumentsTableViewDataSource new] init];
    [_dataSource setArray:myArray];
    [_recentFileBrowser setDataSource:_dataSource];
}

- (IBAction)openCompatibilityTester:(id)sender {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *helperAppPath = [[mainBundle bundlePath] stringByAppendingString:@"/Contents/Resources/Tools/Compatibility Tester.app"];
    
    [[NSWorkspace sharedWorkspace] launchApplication:helperAppPath];
}

- (IBAction)openGithubPage:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/SevenBits/Mac-Linux-USB-Loader"]];
}

- (IBAction)reportBug:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sevenbits.github.io/tools/bugs/report-mlul.html"]];
}

@end
