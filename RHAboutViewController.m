//
//  RHAboutViewController.m
//  RHPreferencesTester
//
//  Originally created by Richard Heard on 23/05/12. Subsequently modified by SevenBits.
//  Copyright (c) 2012-2013 SevenBits. All rights reserved.
//

#import "RHAboutViewController.h"

@interface RHAboutViewController ()

@end

@implementation RHAboutViewController
@synthesize emailTextField = emailTextField;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    self = [super initWithNibName:@"RHAboutViewController" bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    return self;
}

#pragma mark - RHPreferencesViewControllerProtocol

- (NSString*)identifier {
    return NSStringFromClass(self.class);
}
- (NSImage*)toolbarItemImage {
    return [NSImage imageNamed:@"AboutPreferences"];
}
- (NSString*)toolbarItemLabel {
    return NSLocalizedString(@"Acknowledgements", @"AboutToolbarItemLabel");
}

- (NSView*)initialKeyView{
    return self.emailTextField;
}

@end
