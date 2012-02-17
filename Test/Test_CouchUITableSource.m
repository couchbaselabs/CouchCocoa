//
//  Test_CouchUITableSource.m
//  CouchCocoa
//
//  Created by Sven A. Schmidt on 17.02.12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//

#import "CouchQuery.h"
#import "CouchUITableSource.h"

#import <SenTestingKit/SenTestingKit.h>


@interface MockRow : CouchQueryRow

+ (id)rowWithResult:(id)result;
- (id)initWithResult:(id)result;

@end

@implementation MockRow

+ (id)rowWithResult:(id)result {
  return [[MockRow alloc] initWithResult:result];
}


- (id)initWithResult:(id)result {
  CouchQuery *query = [[CouchQuery alloc] init];
  self = [super performSelector:@selector(initWithQuery:result:) withObject:query withObject:result];
  [query release];
  return self;
}

@end


@interface Test_CouchUITableSource : SenTestCase

@property (nonatomic, retain) CouchUITableSource *tsource;

@end


@implementation Test_CouchUITableSource

@synthesize tsource = _tsource;


- (void)setUp {
  self.tsource = [[CouchUITableSource alloc] init];
}


- (void)tearDown {
  self.tsource = nil;
}


- (void)test_newRows {
  NSArray *old = [NSArray array];
  NSDictionary *doc1 = [NSDictionary dictionaryWithObjectsAndKeys:@"id_1", @"_id", @"rev_1", @"_rev", nil];
  NSDictionary *doc2 = [NSDictionary dictionaryWithObjectsAndKeys:@"id_2", @"_id", @"rev_1", @"_rev", nil];
  NSDictionary *doc3 = [NSDictionary dictionaryWithObjectsAndKeys:@"id_3", @"_id", @"rev_1", @"_rev", nil];
  NSDictionary *row1 = [NSDictionary dictionaryWithObjectsAndKeys:doc1, @"doc", nil];
  NSDictionary *row2 = [NSDictionary dictionaryWithObjectsAndKeys:doc2, @"doc", nil];
  NSDictionary *row3 = [NSDictionary dictionaryWithObjectsAndKeys:doc3, @"doc", nil];
  NSArray *new = [NSArray arrayWithObjects:[MockRow rowWithResult:row1], [MockRow rowWithResult:row2], [MockRow rowWithResult:row3], nil];
  
  NSArray *deletedIndexPaths = [self.tsource performSelector:@selector(deletedIndexPathsOldRows:newRows:) withObject:old withObject:new];
  STAssertEquals([deletedIndexPaths count], 0u, nil);

  NSArray *newIndexPaths = [self.tsource performSelector:@selector(addedIndexPathsOldRows:newRows:) withObject:old withObject:new];
  STAssertEquals([newIndexPaths count], 3u, nil);
  NSSet *expected = [NSSet setWithArray:[NSArray arrayWithObjects:
                                         [NSIndexPath indexPathWithIndex:0],
                                         [NSIndexPath indexPathWithIndex:1],
                                         [NSIndexPath indexPathWithIndex:2],
                                         nil]];
  STAssertTrue([expected isEqualToSet:[NSSet setWithArray:newIndexPaths]], nil);
  
  // add more rows
  old = new;
  NSDictionary *doc2a = [NSDictionary dictionaryWithObjectsAndKeys:@"id_2a", @"_id", @"rev_1", @"_rev", nil];
  NSDictionary *doc2b = [NSDictionary dictionaryWithObjectsAndKeys:@"id_2b", @"_id", @"rev_1", @"_rev", nil];
  NSDictionary *row2a = [NSDictionary dictionaryWithObjectsAndKeys:doc2a, @"doc", nil];
  NSDictionary *row2b = [NSDictionary dictionaryWithObjectsAndKeys:doc2b, @"doc", nil];
  new = [NSArray arrayWithObjects:[MockRow rowWithResult:row1], [MockRow rowWithResult:row2], [MockRow rowWithResult:row2a], [MockRow rowWithResult:row2b], [MockRow rowWithResult:row3], nil];
  
  deletedIndexPaths = [self.tsource performSelector:@selector(deletedIndexPathsOldRows:newRows:) withObject:old withObject:new];
  STAssertEquals([deletedIndexPaths count], 0u, nil);

  newIndexPaths = [self.tsource performSelector:@selector(addedIndexPathsOldRows:newRows:) withObject:old withObject:new];
  STAssertEquals([newIndexPaths count], 2u, nil);
  expected = [NSSet setWithArray:[NSArray arrayWithObjects:
                                         [NSIndexPath indexPathWithIndex:2],
                                         [NSIndexPath indexPathWithIndex:3],
                                         nil]];
  STAssertTrue([expected isEqualToSet:[NSSet setWithArray:newIndexPaths]], nil);
  
  // now remove some rows
  old = new;
  new = [NSArray arrayWithObjects:[MockRow rowWithResult:row1], [MockRow rowWithResult:row2b], [MockRow rowWithResult:row3], nil];

  deletedIndexPaths = [self.tsource performSelector:@selector(deletedIndexPathsOldRows:newRows:) withObject:old withObject:new];
  STAssertEquals([deletedIndexPaths count], 2u, nil);
  expected = [NSSet setWithArray:[NSArray arrayWithObjects:
                                  [NSIndexPath indexPathWithIndex:1],
                                  [NSIndexPath indexPathWithIndex:2],
                                  nil]];
  STAssertTrue([expected isEqualToSet:[NSSet setWithArray:deletedIndexPaths]], nil);

  newIndexPaths = [self.tsource performSelector:@selector(addedIndexPathsOldRows:newRows:) withObject:old withObject:new];
  STAssertEquals([newIndexPaths count], 0u, nil);
}


@end
