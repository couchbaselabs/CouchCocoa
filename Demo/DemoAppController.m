//
//  DemoAppController.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/1/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "DemoAppController.h"
#import "DemoItem.h"
#import "DemoQuery.h"
#import "CouchCocoa.h"  // in a separate project you would use <CouchCocoa/CouchCocoa.h>


#define kChangeGlowDuration 3.0


int main (int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}


@implementation DemoAppController


@synthesize query = _query;


- (void) applicationDidFinishLaunching: (NSNotification*)n {
    gRESTLogLevel = kRESTLogRequestURLs;
    
    NSDictionary* bundleInfo = [[NSBundle mainBundle] infoDictionary];
    NSString* dbName = [bundleInfo objectForKey: @"DemoDatabase"];
    if (!dbName) {
        NSLog(@"FATAL: Please specify a CouchDB database name in the app's Info.plist under the 'DemoDatabase' key");
        exit(1);
    }

    CouchServer *server = [[CouchServer alloc] init];
    _database = [[server databaseNamed: dbName] retain];
    [server release];
    
    RESTOperation* op = [_database create];
    if (![op wait]) {
        NSAssert(op.error.code == 412, @"Error creating db: %@", op.error);
    }
    
    self.query = [[[DemoQuery alloc] initWithQuery: [_database getAllDocuments]] autorelease];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(databaseChanged:)
                                                 name: kCouchDatabaseChangeNotification 
                                               object: _database];
    
    // Enable continuous sync:
    NSString* otherDbURL = [bundleInfo objectForKey: @"SyncDatabaseURL"];
    if (otherDbURL.length > 0)
        [self startContinuousSyncWith: [NSURL URLWithString: otherDbURL]];
}


- (void) startContinuousSyncWith: (NSURL*)otherDbURL {
    RESTOperation *pull = [_database pullFromDatabaseAtURL: otherDbURL
                                                  options: kCouchReplicationContinuous];
    [pull onCompletion:^() {
		NSLog(@"Pull ended, error=%@", pull.error);
	}];
    [pull start];
    
    RESTOperation *push = [_database pushToDatabaseAtURL: otherDbURL
                                                options: kCouchReplicationContinuous];
    [push onCompletion:^() {
		NSLog(@"Push ended, error=%@", pull.error);
	}];
    [push start];
}


#pragma mark HIGHLIGHTING NEW ITEMS:


- (void) databaseChanged: (NSNotification*)n {
    if (!_glowing) {
        // Wait to redraw the table, else there is a race condition where if the
        // DemoItem gets notified after I do, it won't have updated timeSinceExternallyChanged yet.
        _glowing = YES;
        [self performSelector: @selector(updateTableGlows) withObject: nil afterDelay:0.0];
    }
}


- (void) updateTableGlows {
    BOOL glowing = NO;
    for (DemoItem* item in _tableController.arrangedObjects) {
        if (item.timeSinceExternallyChanged < kChangeGlowDuration) {
            glowing = YES;
            break;
        }
    }
    if (glowing || _glowing)
        [_table setNeedsDisplay: YES];
    _glowing = glowing;
    if (glowing)
        [self performSelector: @selector(updateTableGlows) withObject: nil afterDelay: 0.1];
}


- (void)tableView:(NSTableView *)tableView
  willDisplayCell:(id)cell
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)row 
{
    NSColor* bg = nil;

    DemoItem* item = [_tableController.arrangedObjects objectAtIndex: row];
    NSTimeInterval changedFor = item.timeSinceExternallyChanged;
    if (changedFor > 0 && changedFor < kChangeGlowDuration) {
        float fraction = 1.0 - changedFor / kChangeGlowDuration;
        if (YES || [cell isKindOfClass: [NSButtonCell class]])
            bg = [[NSColor controlBackgroundColor] blendedColorWithFraction: fraction 
                                                        ofColor: [NSColor yellowColor]];
        else
            bg = [[NSColor yellowColor] colorWithAlphaComponent: fraction];
    }
    
    [cell setBackgroundColor: bg];
    [cell setDrawsBackground: (bg != nil)];
}


@end
