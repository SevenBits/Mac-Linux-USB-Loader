//
//  SBFirmwareViewController.m
//  Mac Linux USB Loader
//
//  Created by SevenBits on 11/26/12.
//  Copyright (c) 2013 SevenBits. All rights reserved.
//

#import "SBFirmwareViewController.h"

@implementation SBFirmwareViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:@"SBFirmwareViewController" bundle:nibBundleOrNil];
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
    return [NSImage imageNamed:@"Boot"];
}
- (NSString*)toolbarItemLabel {
    return NSLocalizedString(@"Firmware", @"AboutToolbarItemLabel");
}

- (NSView*)initialKeyView{
    return nil;
}

@end
