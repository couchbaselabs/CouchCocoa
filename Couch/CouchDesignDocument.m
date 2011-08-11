//
//  CouchDesignDocument.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/8/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "CouchDesignDocument.h"
#import "CouchInternal.h"


NSString* const kCouchLanguageJavaScript = @"javascript";
NSString* const kCouchLanguageErlang = @"erlang";


@interface CouchDesignDocument ()
@property (readwrite) BOOL changed;
@end


@implementation CouchDesignDocument


- (void)dealloc {
    [_views release];
    [_viewsRevisionID release];
    [super dealloc];
}


- (CouchQuery*) queryViewNamed: (NSString*)viewName {
    [[self saveChanges] wait];
    NSString* path = [@"_view/" stringByAppendingString: viewName];
    return [[[CouchQuery alloc] initWithParent: self relativePath: path] autorelease];
}


/** Returns a dictionary mapping view names to the dictionaries defining them (as in the design document's JSON source.)
    The first call fetches the entire design document; subsequent calls are cached. */
- (NSDictionary*) views {
    if (_views && !$equal(_viewsRevisionID, self.currentRevisionID)) {
        // cache is invalid now:
        [_views release];
        _views = nil;
        [_viewsRevisionID release];
        _viewsRevisionID = nil;
    }
    if (!_views) {
        NSDictionary* views = $castIf(NSDictionary, [self.properties objectForKey: @"views"]);
        if (views)
            _views = [views mutableCopy];
        else
            _views = [[NSMutableDictionary alloc] init];
        _viewsRevisionID = [self.currentRevisionID copy];
    }
    return _views;
}


- (NSArray*) viewNames {
    return [self.views allKeys];
}


- (NSDictionary*) definitionOfViewNamed: (NSString*)viewName {
    return $castIf(NSDictionary, [self.views objectForKey: viewName]);
}

- (void) setDefinition: (NSDictionary*)definition ofViewNamed: (NSString*)viewName {
    NSDictionary* existingDefinition = [self definitionOfViewNamed: viewName];
    if (definition != existingDefinition && ![definition isEqualToDictionary: existingDefinition]) {
        [_views setValue: definition forKey: viewName];
        self.changed = YES;
    }
}


- (NSString*) mapFunctionOfViewNamed: (NSString*)viewName {
    return [[self definitionOfViewNamed: viewName] objectForKey: @"map"];
}


- (NSString*) reduceFunctionOfViewNamed: (NSString*)viewName {
    return [[self definitionOfViewNamed: viewName] objectForKey: @"reduce"];
}


- (NSString*) languageOfViewNamed: (NSString*)viewName {
    NSDictionary* viewDefn = [self definitionOfViewNamed: viewName];
    if (!viewDefn)
        return nil;
    return [viewDefn objectForKey: @"language"] ?: kCouchLanguageJavaScript;
}


- (void) defineViewNamed: (NSString*)viewName
                     map: (NSString*)mapFunction
                  reduce: (NSString*)reduceFunction
                language: (NSString*)language;
{
    NSMutableDictionary* view = nil;
    if (mapFunction) {
        view = [[[self definitionOfViewNamed: viewName] mutableCopy] autorelease];
        if (!view)
            view = [NSMutableDictionary dictionaryWithCapacity: 3];
        [view setValue: mapFunction forKey: @"map"];
        [view setValue: reduceFunction forKey: @"reduce"];
        [view setValue: language forKey: @"language"];
    }
    [self setDefinition: view ofViewNamed: viewName];
}

- (void) defineViewNamed: (NSString*)viewName
                     map: (NSString*)mapFunction
{
    [self defineViewNamed: viewName map: mapFunction reduce: nil language: nil];
}


@synthesize changed=_changed;


- (RESTOperation*) saveChanges {
    if (!_changed)
        return nil;

    NSMutableDictionary* newProps = [[self.properties mutableCopy] autorelease];
    if (!newProps)
        newProps = [NSMutableDictionary dictionary];
    [newProps setObject: _views forKey: @"views"];
    self.changed = NO;
    return [self putProperties: newProps];
    // TODO: What about conflicts?
}


@end
