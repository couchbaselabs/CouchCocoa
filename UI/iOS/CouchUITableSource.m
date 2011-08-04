//
//  CouchUITableSource.m
//  CouchCocoa
//
//  Created by Jens Alfke on 8/2/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchUITableSource.h"
#import <CouchCocoa/CouchCocoa.h>


@implementation CouchUITableSource


- (id)init {
    self = [super init];
    if (self) {
        _deletionAllowed = YES;
    }
    return self;
}


- (void)dealloc {
    [_rows release];
    [_query removeObserver: self forKeyPath: @"rows"];
    [_query release];
    [super dealloc];
}


@synthesize tableView=_tableView;
@synthesize rows=_rows;


- (CouchQueryRow*) rowAtIndex: (NSUInteger)index {
    return [_rows objectAtIndex: index];
}


- (void)tellDelegate: (SEL)selector withObject: (id)object {
    id delegate = _tableView.delegate;
    if ([delegate respondsToSelector: selector])
        [delegate performSelector: selector withObject: self withObject: object];
}


#pragma mark -
#pragma mark QUERY HANDLING:


- (CouchLiveQuery*) query {
    return _query;
}

- (void) setQuery:(CouchLiveQuery *)query {
    if (query != _query) {
        [_query removeObserver: self forKeyPath: @"rows"];
        [_query autorelease];
        _query = [query retain];
        [_query addObserver: self forKeyPath: @"rows" options: 0 context: NULL];
        [self reloadFromQuery];
    }
}


-(void) reloadFromQuery {
    CouchQueryEnumerator* rowEnum = _query.rows;
    if (rowEnum) {
        [_rows release];
        _rows = [rowEnum.allObjects mutableCopy];
        [self tellDelegate: @selector(couchTableSource:willUpdateFromQuery:) withObject: _query];
        [self.tableView reloadData];
    }
}


- (void) observeValueForKeyPath: (NSString*)keyPath ofObject: (id)object
                         change: (NSDictionary*)change context: (void*)context 
{
    if (object == _query)
        [self reloadFromQuery];
}


#pragma mark -
#pragma mark DATA SOURCE PROTOCOL:


@synthesize labelProperty=_labelProperty;


- (NSString*) labelForRow: (CouchQueryRow*)row {
    id value = row.value;
    if (_labelProperty) {
        if ([value isKindOfClass: [NSDictionary class]])
            value = [value objectForKey: _labelProperty];
        else
            value = nil;
        if (!value)
            value = [row.document propertyForKey: _labelProperty];
    }
    return [value description];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _rows.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier: @"CouchUITableDelegate"];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle: UITableViewCellStyleDefault
                                      reuseIdentifier: @"CouchUITableDelegate"];
    
    CouchQueryRow* row = [self rowAtIndex: indexPath.row];
    cell.textLabel.text = [self labelForRow: row];
    
    // Allow the delegate to customize the cell:
    id<UITableViewDelegate> delegate = _tableView.delegate;
    if ([delegate respondsToSelector: @selector(couchTableSource:willUseCell:forRow:)])
        [(id<CouchUITableDelegate>)delegate couchTableSource: self willUseCell: cell forRow: row];
    
    return cell;
}


#pragma mark -
#pragma mark EDITING:


@synthesize deletionAllowed=_deletionAllowed;


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return _deletionAllowed;
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Queries have a sort order so reordering doesn't generally make sense.
    return NO;
}


- (void)tableView:(UITableView *)tableView
        commitEditingStyle:(UITableViewCellEditingStyle)editingStyle 
         forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the document from the database, asynchronously.
        RESTOperation* op = [[[self rowAtIndex:indexPath.row] document] DELETE];
        [op onCompletion: ^{
            if (!op.isSuccessful) {
                // If the delete failed, undo the table row deletion by reloading from the db:
                [self tellDelegate: @selector(couchTableSource:operationFailed:) withObject: op];
                [self reloadFromQuery];
            }
        }];
        [op start];
        
        // Delete the row from the table data source.
        [_rows removeObjectAtIndex:indexPath.row];
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
    }
}


@end
