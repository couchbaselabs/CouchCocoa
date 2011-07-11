//
//  CouchDesignDocument.m
//  CouchCocoa
//
//  Created by Jens Alfke on 6/8/11.
//  Copyright 2011 Couchbase, Inc. All rights reserved.
//

#import "CouchDesignDocument.h"
#import "CouchInternal.h"


NSString* const kCouchLanguageJavaScript = @"javascript";


@interface CouchDesignDocument ()
@property (readwrite) BOOL changed;
@end


@implementation CouchDesignDocument


- (CouchQuery*) queryViewNamed: (NSString*)viewName {
    NSString* path = [@"_view/" stringByAppendingString: viewName];
    return [[[CouchQuery alloc] initWithParent: self relativePath: path] autorelease];
}


- (NSDictionary*) properties {
    return self.currentRevision.properties;
}


/** Returns a dictionary mapping view names to the dictionaries defining them (as in the design document's JSON source.)
    The first call fetches the entire design document; subsequent calls are cached. */
- (NSDictionary*) views {
    //FIX: How/when to invalidate the cache?
    if (!_views) {
        if (![[self GET] wait])
            return nil;
        NSDictionary* views = $castIf(NSDictionary, [self.properties objectForKey: @"views"]);
        if (views)
            _views = [views mutableCopy];
        else
            _views = [[NSMutableDictionary alloc] init];
    }
    return _views;
}

- (NSArray*) viewNames {
    return [self.views allKeys];
}

- (CouchViewDefinition) getViewNamed: (NSString*)viewName
{
    CouchViewDefinition defn = {nil, nil, nil};
    NSDictionary* view = $castIf(NSDictionary, [self.views objectForKey: viewName]);
    if (view) {
        defn.mapFunction = [view objectForKey: @"map"];
        defn.reduceFunction = [view objectForKey: @"reduce"];
        defn.language = [self.properties objectForKey: @"language"];
        if (!defn.language)
            defn.language = kCouchLanguageJavaScript;
    }
    return defn;
}

- (BOOL) setDefinition: (const CouchViewDefinition*)definition
           ofViewNamed: (NSString*)viewName
{
    if (!self.views)
        return NO;

    if (definition) {
        NSParameterAssert(definition->mapFunction);
        NSDictionary* viewDefinition = [NSDictionary dictionaryWithObjectsAndKeys:
                                            definition->mapFunction, @"map",
                                            definition->reduceFunction, @"reduce", // may be nil
                                            nil];
        [_views setObject: viewDefinition forKey: viewName];
        //TODO: Remember the language
    } else {
        [_views removeObjectForKey: viewName];
    }
    self.changed = YES;
    return YES;
}


@synthesize changed=_changed;


- (RESTOperation*) saveChanges {
    if (!_changed)
        return nil;

    NSMutableDictionary* newProps = [[self.properties mutableCopy] autorelease];
    [newProps setObject: _views forKey: @"views"];
    self.changed = NO;
    return [self.currentRevision putProperties: newProps];
    // TODO: What about conflicts?
}


@end
