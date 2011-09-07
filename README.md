## CouchCocoa: An Objective-C API To Apache CouchDB™

CouchCocoa is a medium-level Objective-C API for working with [CouchDB][1] on iOS and Mac OS. By "medium-level" we mean:

* It doesn't require knowledge of the HTTP API, only of CouchDB's architecture. You won't have to remember special paths or URL query parameters.
* But it doesn't provide a full-fledged model layer like CoreData or ActiveRecord. You're still working with CouchDB documents as, basically, NSDictionaries, and you'll need your own mapping between those and your app's object model.

This API is not the only way to access CouchDB on iOS and Mac OS. There are other Objective-C APIs available, such as [Trundle][2], or you can go down to the metal and talk to the HTTP API yourself using NSURLConnection.

### Kick The Tires!

* [Peruse some simple code snippets!][7]
* [Explore the API documentation!][8]

### Join Us

* You can discuss this API or ask questions at the [Couchbase Mobile Google Group][3].
* You might also want to look at the [issue tracker][5] to see known problems and feature requests.

## Build Instructions

### Prerequisite

Xcode 4.1 or later, with the SDK for iOS 4 or later. (It's possible the project might still work with Xcode 3, but we're not testing or supporting this.)

### One-Time Repository Setup

If you cloned the CouchCocoa Git repository, aso opposed to downloading a precompiled framework, then you'll next need to initialize Git "submodules". This will clone the dependency JSONKit into the "vendor" subfolder:

    cd CouchCocoa
    git submodule init
    git submodule update

### Running The Mac OS Demo Apps

There are two simple Mac demo apps included in the Demo/ subfolder. One lets you edit a simple list of names and email addresses, the other is a shopping list. (They actually share most of the same source code; all the differences are in their model classes and .xib files, thanks to the magic of Cocoa bindings.) To run them:

0. Start a CouchDB server (such as [Couchbase Server][4]) on localhost.
1. Open CouchDemo.xcodeproj (in Xcode 4.0.2 or later)
2. Select "Demo-Addresses" or "Demo-Shopping" from the scheme pop-up in the toolbar
3. Press the Run button

### Building The Framework

(You only need to do this if you checked out the CouchCocoa source code and want to build it yourself. If you downloaded a precompiled framework, just go onto the next section.)

1. Open CouchDemo.xcodeproj
2. Select "Mac Framework" or "iOS Framework" from the scheme pop-up in the toolbar
3. Product > Build

If you want to run the unit tests, first make sure a CouchDB server is running on localhost, then choose Product > Test.

The framework will be located at:

* Mac: build/CouchCocoa/Build/Products/Debug/CouchCocoa.framework
* iOS: build/CouchCocoa/Build/Products/Debug-universal/CouchCocoa.framework

## Using The Framework In Your Apps

### Mac OS:

1. Build the Mac framework (see above).
2. Copy CouchCocoa.framework somewhere, either into your project's folder or into a location shared between all your projects.
3. Open your Xcode project.
4. Drag the copied framework into the project window's file list.
5. Add the framework to your target (if you weren't already prompted to in the previous step.)
6. Edit your target and add a new Copy Files build phase.
7. Set the build phase's destination to Frameworks, and drag CouchCocoa.framework into its list from the main project file list.

### iOS:

1. Build the iOS framework (see above).
2. Copy CouchCocoa.framework somewhere, either into your project's folder or into a location shared between all your projects.
3. Open your Xcode project.
4. Drag the copied framework into the project window's file list.
5. Add the framework to your target (if you weren't already prompted to in the previous step.)

You'll probably want to run a local database server on your iOS device, since it'll allow your app to work offline (and improves performance.) CouchCocoa.framework doesn't contain CouchDB itself, so you should also add the [Couchbase Mobile][9] framework to your app. Using the two together is very simple: when the CouchbaseMobile object calls your delegate method to tell you the server's up and running, just use the URL it gives you to instantiate a CouchServer object.

## License

Released under the [Apache license, version 2.0][6].

Contributors: [Jens Alfke](https://github.com/snej/), [J Chris Anderson](https://github.com/jchris/)

Copyright 2011, Couchbase, Inc.



[1]: http://couchdb.apache.org/
[2]: https://github.com/schwa/trundle
[3]: https://groups.google.com/group/mobile-couchbase
[4]: http://www.couchbase.com/downloads/couchbase-single-server/community
[5]: https://github.com/couchbaselabs/CouchCocoa/issues
[6]: http://www.apache.org/licenses/LICENSE-2.0.html
[7]: https://github.com/couchbaselabs/CouchCocoa/wiki/Example-Snippets
[8]: http://couchbaselabs.github.com/CouchCocoa/docs/
[9]: http://www.couchbase.org/get/couchbase-mobile-for-ios/current
