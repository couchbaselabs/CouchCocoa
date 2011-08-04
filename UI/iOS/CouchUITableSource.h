//
//  CouchUITableSource.h
//  CouchCocoa
//
//  Created by Jens Alfke on 8/2/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
@class CouchLiveQuery, CouchQueryRow, RESTOperation;

/** A UITableView data source driven by a CouchLiveQuery. */
@interface CouchUITableSource : NSObject <UITableViewDataSource>
{
    @private
    UITableView* _tableView;
    CouchLiveQuery* _query;
	NSMutableArray* _rows;
    NSString* _labelProperty;
    BOOL _deletionAllowed;
}

@property (nonatomic, retain) IBOutlet UITableView* tableView;

@property (retain) CouchLiveQuery* query;

-(void) reloadFromQuery;

@property (nonatomic, readonly) NSArray* rows;
- (CouchQueryRow*) rowAtIndex: (NSUInteger)index;

#pragma mark Displaying The Table:

@property (copy) NSString* labelProperty;

- (NSString*) labelForRow: (CouchQueryRow*)row;

/** Is the user allowed to delete rows? (Defaults to YES.) */
@property (nonatomic) BOOL deletionAllowed;

@end


/** Additional methods for the table view's delegate, that will be invoked by the CouchUITableSource. */
@protocol CouchUITableDelegate <UITableViewDelegate>
@optional

/** Called after the query's results change, before the table view is reloaded. */
- (void)couchTableSource:(CouchUITableSource*)source
     willUpdateFromQuery:(CouchLiveQuery*)query;

/** Called from -tableView:cellForRowAtIndexPath: just before it returns, giving the delegate a chance to customize the new cell. */
- (void)couchTableSource:(CouchUITableSource*)source
             willUseCell:(UITableViewCell*)cell
                  forRow:(CouchQueryRow*)row;

/** Called if a CouchDB operation invoked by the source (e.g. deleting a document) fails. */
- (void)couchTableSource:(CouchUITableSource*)source
         operationFailed:(RESTOperation*)op;

@end