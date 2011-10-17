//
//  CouchCocoa.h
//  CouchCocoa
//
//  Created by Jens Alfke on 6/12/11.
//  Copyright 2011 Couchbase, Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "REST.h"
#import "CouchAttachment.h"
#import "CouchDatabase.h"
#import "CouchDesignDocument.h"
#import "CouchDocument.h"
#import "CouchModel.h"
#import "CouchPersistentReplication.h"
#import "CouchQuery.h"
#import "CouchRevision.h"
#import "CouchServer.h"
#import "CouchEmbeddedServer.h"


/** @mainpage About CouchCocoa
 
 @section intro_sec  Introduction
 
 CouchCocoa is a medium-level Objective-C API for working with <a href="http://couchdb.apache.org/">CouchDB</a> on iOS and Mac OS. By "medium-level" we mean:
 
    @li It doesn't require knowledge of the HTTP API, only of CouchDB's architecture. You won't have to remember special paths or URL query parameters.
    @li But it doesn't provide a full-fledged model layer like CoreData or ActiveRecord. You're still working with CouchDB documents as, basically, NSDictionaries, and you'll need your own mapping between those and your app's object model.
 
 This API is not the only way to access CouchDB on iOS and Mac OS. There are other Objective-C APIs available, such as <a href="https://github.com/schwa/trundle">Trundle</a>, or you can go down to the metal and talk to CouchDB's HTTP interface yourself using NSURLConnection.
 
 The source code, Git repository and wiki are available on <a href="https://github.com/couchbaselabs/CouchCocoa">Github</a>.
 
 @section concepts_sec  Basic Concepts
 
 CouchCocoa has two layers. The lower layer, called "REST", implements a service-agnostic interface to web applications that follow the REST architectural style. It wraps NSURLConnection to make it easy to represent a REST API's endpoint URLs as a hierarchy of RESTResource objects and perform the basic get/put/create/delete operations on them. Operations are represented by the RESTOperation class, which can be used either synchronously or asynchronously. This layer knows nothing about CouchDB in particular.
 
 The upper layer, whose classes are prefixed with "Couch", extends the REST layer with a class hierarchy representing CouchDB abstractions like servers, databases, documents and views. Each of these has its own subclass of RESTResource, and so each instance represents a particular URL on the CouchDB server. However, this API relieves you of having to know about the details of the CouchDB URL structure.
 
 Most of the time you'll be working with methods declared in the Couch classes, but don't forget that they inherit from the REST classes. In particular, there are some commonly used methods declared in RESTResource, like -URL and -DELETE, that are easy to overlook if you forget about inheritance.
 
 Some <a href="https://github.com/couchbaselabs/CouchCocoa/wiki/Example-Snippets">example code snippets</a> are available.
 
 @section restrictions_sec  Restrictions
 
 @subsection compatibility_sec  Compatibility

 This library supports both iOS 4.0+ and Mac OS X 10.6+ (32- and 64-bit).
 
 It uses the traditional reference-counted memory model. It has not yet been adapted to work with either garbage collection or Automatic Reference Counting.
 
 @subsection threads_sec  Thread Safety
 
 This library is @b not fully thread-safe. It @em can be used on multiple threads, with certain precautions.
 
 Any individual CouchServer instance, and all the objects created directly or indirectly by it (databases, documents, queries, operations, etc.) must be accessed only on the thread that created it. In particular, you should never pass any CouchCocoa object pointer to code running on another thread.
 
 However, you can create multiple CouchServer instances (and object trees based on them) on different threads. They'll be completely independent of each other, so they won't step on each other's toes. It's even OK if they have the same server URL -- they'll be different clients as far as the server is concerned. (This means that changes made by one will show up as external change notifications to the others.)
 
*/
