//
//  CouchbaseMobile.h
//  Couchbase Mobile
//
//  Created by J Chris Anderson on 3/2/11.
//  Copyright 2011 Couchbase, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not
// use this file except in compliance with the License. You may obtain a copy of
// the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
// License for the specific language governing permissions and limitations under
// the License.


#import <Foundation/Foundation.h>
@class CouchbaseMobile;


@protocol CouchbaseDelegate
@required
/** Called after a CouchbaseMobile instance finishes starting up.
    @param couchbase  The instance of CouchbaseMobile.
    @param serverURL  The URL at which the Couchbase server is listening. */
-(void)couchbaseMobile:(CouchbaseMobile*)couchbase didStart:(NSURL*)serverURL;

/** Called after a CouchbaseMobile instance fails to start up.
    @param couchbase  The instance of CouchbaseMobile.
    @param error  The error that occurred. */
-(void)couchbaseMobile:(CouchbaseMobile*)couchbase failedToStart:(NSError*)error;
@end


/** Manages an embedded instance of CouchDB that runs in a background thread. */
@interface CouchbaseMobile : NSObject
{
    @private
    id<CouchbaseDelegate> _delegate;
    CFAbsoluteTime _timeStarted;
    NSString* _rootDirectory;
    NSString* _bundlePath;
    NSString* _iniFilePath;
    NSURL* _serverURL;
    NSError* _error;
    uint8_t _logLevel;
    BOOL _autoRestart;
    BOOL _started;
}

/** Convenience to instantiate and start a new instance. */
+ (CouchbaseMobile*) startCouchbase: (id<CouchbaseDelegate>)delegate;

/** Initializes the instance. */
- (id) init;

/** The delegate object, which will be notified when the server starts. */
@property (assign) id<CouchbaseDelegate> delegate;

/** Starts the server, asynchronously. The delegate will be called when it's ready.
    @return  YES if the server is starting, NO if it failed to start. */
- (BOOL) start;

/** Restart the server, necessary if app being suspended closes its listening socket */
- (void) restart;

/** The HTTP URL the server is listening on.
    Will be nil until the server has finished starting up, some time after -start is called.
    This property is KV-observable, so an alternative to setting a delegate is to observe this
    property and the -error property and wait for one of them to become non-nil. */
@property (readonly, retain) NSURL* serverURL;

/** If the server fails to start up, this will be set to a description of the error.
    This is KV-observable. */
@property (readonly, retain) NSError* error;

/** Defaults to YES, set to NO to prevent auto-restart behavior when app returns from background */
@property (assign) BOOL autoRestart;

/** A credential containing the admin username and password of the server.
    These are required in any requests sent to the server. The password is generated randomly on first launch. */
@property (readonly) NSURLCredential* adminCredential;

#pragma mark CONFIGURATION:

/** Initializes the instance with a nonstandard location for the runtime resources.
    (The default location is Resources/CouchbaseResources, but some application frameworks
    require resources to go elsewhere, so in that case you might need to use a custom path.) */
- (id) initWithBundlePath: (NSString*)bundlePath;

/** The root directory where Couchbase Mobile will store data files.
    This defaults to ~/CouchbaseMobile.
    You may NOT change this after starting the server. */
@property (copy) NSString* rootDirectory;

/** The directory where CouchDB writes its log files. */
@property (readonly) NSString* logDirectory;

/** The directory where CouchDB stores its database files. */
@property (readonly) NSString* databaseDirectory;

/** The path to an app-specific CouchDB configuration (".ini") file.
    Optional; defaults to nil.
    The settings in this file will override the default CouchDB settings in default.ini, but
    will in turn be overridden by any locally-made settings (see -localIniFilePath). */
@property (copy) NSString* iniFilePath;

/** The path to the mutable local configuration file.
    This starts out empty, but will be modified if the app sends PUT requests to the server's
    _config URI. The app can restore the default configuration at launch by deleting or
    emptying the file at this path before calling -start.*/
@property (readonly) NSString* localIniFilePath;

/** Controls the amount of logging by Erlang and CouchDB.
    Defaults to 0, meaning none.
    1 logs errors only, 2 also logs CouchDB info (like HTTP requests), 3 logs Erlang 'progress'. */
@property uint8_t logLevel;

/** Copies a database file into the databaseDirectory if no such file exists there already.
    Call this before -start, to set up initial contents of one or more databases on first run. */
- (BOOL) installDefaultDatabase: (NSString*)databasePath;

@end
