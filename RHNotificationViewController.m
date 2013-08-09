//
//  RHAboutViewController.m
//  RHPreferencesTester
//
//  Originally created by Richard Heard on 23/05/12. Subsequently modified by SevenBits.
//  Copyright (c) 2012-2013 SevenBits. All rights reserved.
//

#import "RHNotificationViewController.h"

@interface RHNotificationViewController ()

@end

@implementation RHNotificationViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    self = [super initWithNibName:@"RHNotificationViewController" bundle:nibBundleOrNil];
    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults synchronize];
        
        if ([defaults boolForKey:@"ShowNotifications"] == YES) {
            [_displayNotificationsCheckbox setState:NSOnState];
        } else {
            [_displayNotificationsCheckbox setState:NSOffState];
        }
    }
    return self;
}

- (IBAction)showNotificationCenter:(NSButton*)sender {
    NSProcessInfo *pinfo = [NSProcessInfo processInfo];
    NSArray *myarr = [[pinfo operatingSystemVersionString] componentsSeparatedByString:@" "];
    NSString *version = myarr[1];
    
    // Ensure that we are running 10.8 before we display the preferences as we still support Lion, which does not have
    // notifications.
    if ([version rangeOfString:@"10.8"].location == NSNotFound) {
        [sender setEnabled:NO];
    } else {
        [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/Notifications.prefPane"];
    }
}

- (IBAction)setShowNotifications:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
#ifdef DEBUG
    NSLog(@"Setting show notifications to %@", [defaults valueForKey:@"ShowNotifications"]);
#endif
    
    //[defaults setBool:showNotifications forKey:@"ShowNotifications"];
    [defaults synchronize];
}

#pragma mark - RHPreferencesViewControllerProtocol

- (NSString*)identifier {
    return NSStringFromClass(self.class);
}
- (NSImage*)toolbarItemImage {
    return [NSImage imageNamed:@"Notifications"];
}
- (NSString*)toolbarItemLabel {
    return NSLocalizedString(@"Notifications", @"AboutToolbarItemLabel");
}

- (NSView*)initialKeyView{
    return nil;
}

@end
