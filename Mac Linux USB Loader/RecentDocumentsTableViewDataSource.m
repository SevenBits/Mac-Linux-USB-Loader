//
//  RecentDocumentsTableViewDataSource.m
//  Mac Linux USB Loader
//
//  Created by SevenBits on 4/10/13.
//
//

#import "RecentDocumentsTableViewDataSource.h"

@implementation RecentDocumentsTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [_array count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    [tableColumn setEditable:NO];
    return [_array[row] lastPathComponent];
}

@end
