//
//  CTAppDelegate.m
//  Compatibility Tester
//
//  Created by SevenBits on 4/18/13.
//
//

#import "CTAppDelegate.h"

@implementation CTAppDelegate

@synthesize window;

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    [_spinner startAnimation:self];
    [self performSelector:@selector(performSystemCheck)];
}

- (IBAction)refresh:(id)sender {
    [_textView setString:@""];
    [_label setStringValue:@"Performing compatibility check..."];
    [self performSelector:@selector(performSystemCheck)];
}

- (void)performSystemCheck {
    NSTextStorage *storage = [_textView textStorage];
    [storage beginEditing];
    
    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    
    if (len) {
        char *model = malloc(len*sizeof(char));
        sysctlbyname("hw.model", model, &len, NULL, 0);
        NSString *model_ns = @(model);
        free(model);
        
        NSAttributedString *string = [[NSAttributedString alloc]
                                      initWithString:[NSString stringWithFormat:@"Computer Model: %@\n", model_ns]];
        [storage appendAttributedString:string];
    }
    
    // We've got the computer model, now get everything else.
    [self findGraphicsCard:storage];
    [self findWirelessCard:storage];
    
    [storage appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\n"]];
    BOOL issue = [self checkForCompatibility:storage];
    NSAttributedString *string;
    
    if (issue) {
        string = [[NSAttributedString alloc]
                                      initWithString:@"You may have issues booting Linux on this computer.\n"];
        [storage appendAttributedString:string];
    } else {
        string = [[NSAttributedString alloc]
                                      initWithString:@"Everything appears to be alright. You should be good to go.\n"];
        [storage appendAttributedString:string];
    }
    
    [storage endEditing];
    [_spinner stopAnimation:self];
    [_label setStringValue:@""];
}

/* Not currently working. Displays graphics card. I am investigating an approach to get the wireless controller. */
- (void)findWirelessCard:(NSTextStorage*)storage {
    // Check the PCI devices for video cards.
    CFMutableDictionaryRef match_dictionary = IOServiceMatching("IOPCIDevice");
    
    // Create a iterator to go through the found devices.
    io_iterator_t entry_iterator;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault,
                                     match_dictionary,
                                     &entry_iterator) == kIOReturnSuccess) {
        // Actually iterate through the found devices.
        io_registry_entry_t serviceObject;
        while ((serviceObject = IOIteratorNext(entry_iterator))) {
            // Put this services object into a dictionary object.
            CFMutableDictionaryRef serviceDictionary;
            if (IORegistryEntryCreateCFProperties(serviceObject,
                                                  &serviceDictionary,
                                                  kCFAllocatorDefault,
                                                  kNilOptions) != kIOReturnSuccess) {
                // Failed to create a service dictionary, release and go on.
                IOObjectRelease(serviceObject);
                continue;
            }
            
            //NSLog(@"%@", serviceDictionary);
            // If this is a GPU listing, it will have a "model" key
            // that points to a CFDataRef.
            const void *model = CFDictionaryGetValue(serviceDictionary, @"model");
            if (model != nil) {
                if (CFGetTypeID(model) == CFDataGetTypeID()) {
                    // Create a string from the CFDataRef.
                    NSString *s = [[NSString alloc] initWithData:(__bridge NSData *)model encoding:NSASCIIStringEncoding];
#ifdef DEBUG
                    //NSLog(@"Found wireless chip: %@", s);
#endif
                    
                    // Append this GPU to the list of detected hardware.
                    NSAttributedString *string = [[NSAttributedString alloc]
                                                  initWithString:[NSString stringWithFormat:@"Wireless: %@\n", s]];
                    [storage appendAttributedString:string];
                }
            }
            
            // Release the dictionary created by IORegistryEntryCreateCFProperties.
            CFRelease(serviceDictionary);
            
            // Release the serviceObject returned by IOIteratorNext.
            IOObjectRelease(serviceObject);
        }
        
        // Release the entry_iterator created by IOServiceGetMatchingServices.
        IOObjectRelease(entry_iterator);
    }
}

- (void)findGraphicsCard:(NSTextStorage*)storage {
    // Check the PCI devices for video cards.
    CFMutableDictionaryRef match_dictionary = IOServiceMatching("IOPCIDevice");
    
    // Create a iterator to go through the found devices.
    io_iterator_t entry_iterator;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault,
                                     match_dictionary,
                                     &entry_iterator) == kIOReturnSuccess) {
        // Actually iterate through the found devices.
        io_registry_entry_t serviceObject;
        while ((serviceObject = IOIteratorNext(entry_iterator))) {
            // Put this services object into a dictionary object.
            CFMutableDictionaryRef serviceDictionary;
            if (IORegistryEntryCreateCFProperties(serviceObject,
                                                  &serviceDictionary,
                                                  kCFAllocatorDefault,
                                                  kNilOptions) != kIOReturnSuccess) {
                // Failed to create a service dictionary, release and go on.
                IOObjectRelease(serviceObject);
                continue;
            }
            
            // If this is a GPU listing, it will have a "model" key
            // that points to a CFDataRef.
            const void *model = CFDictionaryGetValue(serviceDictionary, @"model");
            if (model != nil) {
                if (CFGetTypeID(model) == CFDataGetTypeID()) {
                    // Create a string from the CFDataRef.
                    NSString *s = [[NSString alloc] initWithData:(__bridge NSData *)model encoding:NSASCIIStringEncoding];
#ifdef DEBUG
                    //NSLog(@"Found GPU: %@", s);
#endif
                    
                    // Append this GPU to the list of detected hardware.
                    NSAttributedString *string = [[NSAttributedString alloc]
                                                  initWithString:[NSString stringWithFormat:@"Graphics: %@\n", s]];
                    [storage appendAttributedString:string];
                }
            }
            
            // Release the dictionary created by IORegistryEntryCreateCFProperties.
            CFRelease(serviceDictionary);
            
            // Release the serviceObject returned by IOIteratorNext.
            IOObjectRelease(serviceObject);
        }
        
        // Release the entry_iterator created by IOServiceGetMatchingServices.
        IOObjectRelease(entry_iterator);
    }
}

- (BOOL)checkForCompatibility:(NSTextStorage*)storage {
    /*
     * Scan the system report we just recieved for troublesome hardware components.
     */
    BOOL issue = NO;
    if ([[_textView string] rangeOfString:@"Graphics: GeForce"].location != NSNotFound) {
        NSAttributedString *string = [[NSAttributedString alloc] initWithString:@"WARNING: Possible issue with video card and/or proprietary drivers. "];
        [storage appendAttributedString:string];
        
        issue = YES;
    }
    return issue;
}

@end
