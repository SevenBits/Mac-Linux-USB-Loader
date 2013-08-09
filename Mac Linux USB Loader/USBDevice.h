//
//  USBDevice.h
//  Mac Linux USB Loader
//
//  Created by SevenBits on 11/26/12.
//  Copyright (c) 2012 SevenBits. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RHAppDelegate.h"

@interface USBDevice : NSObject

@property NSString *volumePath;
@property NSWindow *window;

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (BOOL)prepareUSB:(NSString *)path;
//- (BOOL)copyISO:(NSString *)path:(NSString *)isoFile:(NSProgressIndicator *)progressBar:(Document *)document;

@end