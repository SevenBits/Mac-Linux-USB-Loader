//
//  DistributionDownloader.m
//  Mac Linux USB Loader
//
//  Created by SevenBits on 1/14/13.
//  Copyright (c) 2013 SevenBits. All rights reserved.
//

#import "DistributionDownloader.h"

@implementation DistributionDownloader

NSURLDownload *download;
NSString *destinationPath;
NSURLResponse *downloadResponse;
NSProgressIndicator *progress;

long long bytesReceived = 0;

- (void)downloadLinuxDistribution:(NSURL*)url:(NSString*)destination:(NSProgressIndicator*)progressBar {
    destinationPath = destination;
    progress = progressBar;
    NSURLRequest *request=[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    
    // Create the connection with the request and start loading the data.
    [download setDestination:destination allowOverwrite:YES];
    download=[[NSURLDownload alloc] initWithRequest:request delegate:self];
    
    if (!download) {
        NSLog(@"Download could not be made...");
    }
}

#pragma mark NSURLDownload delegates
- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error {
    // Inform us that the download failed.
    NSLog(@"Download failed! Error - %@ %@",
          [error localizedDescription],
          [error userInfo][NSURLErrorFailingURLStringErrorKey]);
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Okay"];
    [alert setMessageText:@"Download failed."];
    [alert setInformativeText:@"Check the system logs for more information."];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:nil modalDelegate:self didEndSelector:@selector(regularAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
    
#if (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_8)
    // Show a notification for Mountain Lion users.
    Class test = NSClassFromString(@"NSUserNotificationCenter");
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Ensure that we are running 10.8 before we display the notification as we still support Lion, which does not have
    // them.
    if (test != nil && [defaults boolForKey:@"ShowNotifications"] == YES) {
        NSUserNotification *notification = [[NSUserNotification alloc] init];
        notification.title = @"File Download Failure";
        notification.informativeText = @"Could not download the file.";
        notification.soundName = NSUserNotificationDefaultSoundName;
        
        [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
    }
#else
    [NSApp requestUserAttention:NSCriticalRequest];
#endif
    
    [[NSApp delegate] setCanQuit:YES]; // We're done, the user can quit the program.
}

- (void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)filename {
    NSString *destinationFilename;
    NSString *homeDirectory=NSHomeDirectory();
    
    destinationFilename=[[homeDirectory stringByAppendingPathComponent:@"Downloads"] stringByAppendingPathComponent:filename];
    [download setDestination:destinationFilename allowOverwrite:YES];
}

- (void)downloadDidFinish:(NSURLDownload *)download {
    NSLog(@"Downloaded file was downloaded:\n%@", download);
    [[[NSApplication sharedApplication] dockTile] setBadgeLabel:@""];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Okay"];
    [alert setMessageText:@"Download complete."];
    [alert setInformativeText:@"The file was downloaded. You can now install it to your USB drive by opening it with the Create Live USB button in the toolbar."];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:nil modalDelegate:self didEndSelector:@selector(regularAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
    
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
            notification.title = @"File Download Complete";
            notification.informativeText = @"The ISO was successfully downloaded.";
            notification.soundName = NSUserNotificationDefaultSoundName;
            
            [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
        }
    }
#else
    [NSApp requestUserAttention:NSCriticalRequest];
#endif
    
    [[NSApp delegate] setCanQuit:YES]; // We're done, the user can quit the program.
}

/* When the application recieves some data, we get a "download response". Cache it here in an instance variable so that
   the other methods can access it to get the download progress. This could use a bit of tweaking efficency wise but since
   the download progresses in another thread it at least won't slow down the download by any marginal amount. */
- (void)setDownloadResponse:(NSURLResponse *)aDownloadResponse {
    downloadResponse = aDownloadResponse;
}

- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response {
    bytesReceived = 0;
    
    // Retain the response to use later.
    [self setDownloadResponse:response];
}

- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length {
    long long expectedLength = [downloadResponse expectedContentLength];
    
    bytesReceived = bytesReceived + length;
    
    // LOTS of floating point casts and stuff here. This needs to be made more efficent.
    if (expectedLength != NSURLResponseUnknownLength) {
        // Calculate at what percent complete we are.
        float percentComplete = (bytesReceived/(float)expectedLength) * 100.0;
        [progress setDoubleValue:(double)percentComplete];
        
        // Add the progress percent to the dock as an overlay.
        [[[NSApplication sharedApplication] dockTile] setBadgeLabel:[NSString stringWithFormat:@"%ld%%", (long)percentComplete]];
    } else {
        // If the expected content length is unknown, just log the progress.
        NSLog(@"Bytes received - %lld", bytesReceived);
    }
}

#pragma mark NSAlert delegates
- (void)regularAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    // Do nothing.
}

@end
