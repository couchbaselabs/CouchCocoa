//
//  CouchUITableSource.h
//  CouchCocoa
//
//  Created by Jens Alfke on 8/2/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
@class CouchDocument, CouchLiveQuery, CouchQueryRow, RESTOperation;

/** A UITableView data source driven by a CouchLiveQuery. */
@interface CouchUITableSource : NSObject <UITableViewDataSource>

@property (nonatomic, retain) IBOutlet UITableView* tableView;

@property (retain) CouchLiveQuery* query;

/** Rebuilds the table from the query's current .rows property. */
-(void) reloadFromQuery;


#pragma mark Row Accessors:

/** The current array of CouchQueryRows being used as the data source for the table. */
@property (nonatomic, readonly) NSArray* rows;

/** Convenience accessor to get the row object for a given table row index. */
- (CouchQueryRow*) rowAtIndex: (NSUInteger)index;

/** Convenience accessor to find the index path of the row with a given document. */
- (NSIndexPath*) indexPathForDocument: (CouchDocument*)document;

/** Convenience accessor to return the document at a given index path. */
- (CouchDocument*) documentAtIndexPath: (NSIndexPath*)path;


#pragma mark Displaying The Table:

/** If non-nil, specifies the property name of the query row's value that will be used for the table row's visible label.
    If the row's value is not a dictionary, or if the property doesn't exist, the property will next be looked up in the document's properties.
    If this doesn't meet your needs for labeling rows, you should implement -couchTableSource:willUseCell:forRow: in the table's delegate. */
@property (copy) NSString* labelProperty;


#pragma mark Editing The Table:

/** Is the user allowed to delete rows by UI gestures? (Defaults to YES.) */
@property (nonatomic) BOOL deletionAllowed;

/** Asynchronously deletes the documents at the given row indexes, animating the removal from the table. */
- (void) deleteDocumentsAtIndexes: (NSArray*)indexPaths;

/** Asynchronously deletes the given documents, animating the removal from the table. */
- (void) deleteDocuments: (NSArray*)documents;

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