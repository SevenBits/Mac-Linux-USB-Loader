//
//  RHAppDelegate.h
//  RHPreferencesTester
//
//  Originally created by Richard Heard on 23/05/12. Subsequently modified by SevenBits.
//  Copyright (c) 2012-2013 SevenBits. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <RHPreferences/RHPreferences.h>

#import "RHAboutViewController.h"
#import "RHAccountsViewController.h"
#import "RHNotificationViewController.h"
#import "SBFirmwareViewController.h"

#import "DistributionDownloader.h"
#import "RecentDocumentsTableViewDataSource.h"

@interface RHAppDelegate : NSObject <NSApplicationDelegate> {
    RHPreferencesWindowController *_preferencesWindowController;
    IBOutlet NSPanel *sheet;
    IBOutlet NSPanel *eraseSheet;
    IBOutlet NSPanel *bootSettingsSheet;
    
    NSString *bootLoaderName;
    BOOL automaticallyBless;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSButton *closeDistroDownloadSheetButton;
@property (assign) IBOutlet NSButton *closeEraseDownloadSheetButton;
@property (assign) IBOutlet NSButton *distroDownloadButton;
@property (assign) IBOutlet NSButton *openDownloadedDistroButton;
@property (retain) RHPreferencesWindowController *preferencesWindowController;
@property (retain) IBOutlet NSPopUpButton *distroPopUpSelector;
@property (retain) IBOutlet NSProgressIndicator *distroDownloadProgressIndicator;
@property (retain) IBOutlet NSComboBox *distroSelectorComboBox;
@property (retain) IBOutlet NSPopUpButton *eraseUSBSelector;
@property (retain) IBOutlet NSPopUpButton *bootUSBSelector;
@property (retain) IBOutlet NSTableView *recentFileBrowser;
@property (retain) IBOutlet RecentDocumentsTableViewDataSource *dataSource;

@property BOOL canQuit; // Can the user quit the application?

- (void)blessDrive:(NSString *)path sender:(id)sender;
- (void)respondToRecentFileDoubleClick;

#pragma mark - IBActions
- (IBAction)showPreferences:(id)sender;

- (IBAction)showDownloadDistroSheet:(id)sender;
- (IBAction)closeDownloadDistroSheet:(id)sender;

- (IBAction)showModifyBootSettingsSheet:(id)sender;
- (IBAction)closeModifyBootSettingsSheet:(id)sender;
- (IBAction)blessUSB:(id)sender;
- (IBAction)unbless:(id)sender;

- (IBAction)openDownloadedDistro:(id)sender;
- (IBAction)showEraseDistroSheet:(id)sender;
- (IBAction)closeEraseDistroSheet:(id)sender;

- (IBAction)detectUSBs:(id)sender;
- (IBAction)downloadDistribution:(id)sender;
- (IBAction)eraseSelectedDrive:(id)sender;
- (IBAction)openGithubPage:(id)sender;
- (IBAction)updateRecents:(id)sender;
- (IBAction)openCompatibilityTester:(id)sender;
- (IBAction)openDiskUtility:(id)sender;
- (IBAction)reportBug:(id)sender;

#pragma mark - Delegates
- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)quitSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;

@end