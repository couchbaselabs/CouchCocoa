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
    [_validation release];
    [_language release];
    [_views release];
    [_filters release];
    [_viewsRevisionID release];
    [_viewOptions release];
    [super dealloc];
}


- (CouchQuery*) queryViewNamed: (NSString*)viewName {
    [[self saveChanges] wait];
    NSString* path = [@"_view/" stringByAppendingString: viewName];
    return [[[CouchQuery alloc] initWithParent: self relativePath: path] autorelease];
}


- (BOOL) isLanguageAvailable: (NSString*)language {
    // FIX: This should be determined by querying the server (somehow)
    if ([language isEqualToString: kCouchLanguageJavaScript])
        return YES;
    else if ([language isEqualToString: kCouchLanguageErlang])
        return YES;
    else
        return NO;
}


- (NSString*) language {
    if (_language)
        return _language;
    NSString* language = [self.properties objectForKey: @"language"];
    return language ? language : kCouchLanguageJavaScript;
}

- (void) setLanguage:(NSString *)language {
    NSParameterAssert(language != nil);
    if (![language isEqualToString: self.language]) {
        [_language autorelease];
        _language = [language copy];
        _changed = YES;
    }
}


static NSMutableDictionary* mutableCopyProperty(NSDictionary* properties,
                                                NSString* key) 
{
    NSDictionary* dict = $castIf(NSDictionary, [properties objectForKey: key]);
    return dict ? [dict mutableCopy] : [[NSMutableDictionary alloc] init];
}


/** Returns a dictionary mapping view names to the dictionaries defining them (as in the design document's JSON source.)
    The first call fetches the entire design document; subsequent calls are cached. */
- (NSDictionary*) views {
    if (_views && !$equal(_viewsRevisionID, self.currentRevisionID)) {
        // cache is invalid now:
        [_views release];
        _views = nil;
        [_filters release];
        _filters = nil;
        [_viewsRevisionID release];
        _viewsRevisionID = nil;
    }
    if (!_views) {
        NSDictionary* properties = self.properties;
        _views = mutableCopyProperty(properties, @"views");
        _filters = mutableCopyProperty(properties, @"filters");
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


- (void) defineViewNamed: (NSString*)viewName
                     map: (NSString*)mapFunction
                  reduce: (NSString*)reduceFunction
{
    NSMutableDictionary* view = nil;
    if (mapFunction) {
        view = [[[self definitionOfViewNamed: viewName] mutableCopy] autorelease];
        if (!view)
            view = [NSMutableDictionary dictionaryWithCapacity: 3];
        [view setValue: mapFunction forKey: @"map"];
        [view setValue: reduceFunction forKey: @"reduce"];
    }
    [self setDefinition: view ofViewNamed: viewName];
}

- (void) defineViewNamed: (NSString*)viewName
                     map: (NSString*)mapFunction
{
    [self defineViewNamed: viewName map: mapFunction reduce: nil];
}


- (NSDictionary*) filters {
    [self views];  // This also loads/instantiates _filters
    return _filters;
}


- (void) defineFilterNamed: (NSString*)filterName
                asFunction: (NSString*)filterFunction
{
    [self views];  // This also loads/instantiates _filters
    if (!$equal(filterFunction, [_filters objectForKey: filterName])) {
        [_filters setValue: filterFunction forKey: filterName];
        self.changed = YES;
    }
}


- (NSString*) validation {
    if (_changedValidation)
        return _validation;
    return $castIf(NSString, [self.properties objectForKey: @"validate_doc_update"]);
}

- (void) setValidation:(NSString *)validation {
    if (!$equal(validation, self.validation)) {
        [_validation autorelease];
        _validation = [validation copy];
        _changedValidation = YES;
        _changed = YES;
    }
}


- (NSMutableDictionary*) viewOptions {
    if (!_viewOptions) {
        NSDictionary* viewOptions = $castIf(NSDictionary, [self.properties objectForKey: @"options"]);
        if (viewOptions)
            _viewOptions = [viewOptions mutableCopy];
        else
            _viewOptions = [[NSMutableDictionary alloc] init];
    }
    return _viewOptions;
}

- (BOOL) includeLocalSequence {
    return [$castIf(NSNumber, [[self viewOptions] objectForKey: @"local_seq"]) boolValue];
}

- (void) setIncludeLocalSequence:(BOOL)localSeq {
    if (localSeq != self.includeLocalSequence) {
        [_viewOptions setObject: [NSNumber numberWithBool: localSeq] forKey: @"local_seq"];
        _changedViewOptions = YES;
        _changed = YES;
    }
}


@synthesize changed=_changed;


- (RESTOperation*) saveChanges {
    if (_savingOp)
        return _savingOp;
    if (!_changed)
        return nil;
    
    NSMutableDictionary* newProps = [[self.properties mutableCopy] autorelease];
    if (!newProps)
        newProps = [NSMutableDictionary dictionary];
    if (_views)
        [newProps setObject: _views forKey: @"views"];
    if (_filters)
        [newProps setObject: _filters forKey: @"filters"];
    if (_language)
        [newProps setValue: _language forKey: @"language"];
    if (_changedValidation)
        [newProps setValue: _validation forKey: @"validate_doc_update"];
    if (_changedViewOptions)
        [newProps setObject: _viewOptions forKey: @"options"];
    
    _savingOp = [self putProperties: newProps];
    [_savingOp onCompletion: ^{
        if (_savingOp.error)
            Warn(@"Failed to save %@: %@", self, _savingOp.error);
        // TODO: What about conflicts?
        _savingOp = nil;
        _changedValidation = NO;
        _changedViewOptions = NO;
        [_language release];
        _language = nil;
        self.changed = NO;
    }];
    return _savingOp;
}


@end
