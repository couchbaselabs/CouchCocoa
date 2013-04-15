## CouchCocoa: An Objective-C API To TouchDB and Apache CouchDB™

CouchCocoa is a medium-level Objective-C API for working with [TouchDB][10] and [CouchDB][1] on iOS and Mac OS. By "medium-level" we mean:

* It doesn't require knowledge of the HTTP API, only of CouchDB's architecture. You won't have to remember special paths or URL query parameters.
* But it doesn't completely abstract away the fact that you're working with a database, the way CoreData does. You still work with CouchDB-style documents and queries, although there is a CouchModel class that does some of the dirty work of mapping between documents and native objects.

This API is not the only way to access CouchDB or TouchDB; just the most convenient one. If you prefer, you can go down to the metal and talk to the HTTP API yourself using NSURLConnection.

### Kick The Tires!

* [Peruse some simple code snippets!][7]
* [Explore the API documentation!][8]

### Join Us

* You can discuss this API or ask questions at the [Couchbase Mobile Google Group][3].
* You might also want to look at the [issue tracker][5] to see known problems and feature requests.

## Build Instructions

### Binary Builds

Pre-built libraries are available. The latest build is always at [this address](http://files.couchbase.com/developer-previews/mobile/ios/couchcocoa/CouchCocoa.zip). If you need them, [earlier versions](http://files.couchbase.com/developer-previews/mobile/ios/couchcocoa/) are available too.

### Prerequisite

Xcode 4.3 or later, with the SDK for iOS 4.3 or later.

### One-Time Repository Setup

If you cloned the CouchCocoa Git repository, as opposed to downloading a precompiled framework, then you'll next need to initialize Git "submodules". This will clone the dependency JSONKit into the "vendor" subfolder:

    cd CouchCocoa
    git submodule init
    git submodule update

### Running The iOS Demo App

Our iOS demo, "Grocery Sync", has [its own GitHub repository][12]. Check it out and look at its README for instructions.

### Running The Mac OS Demo Apps

There are two simple Mac demo apps included in the Demo/ subfolder. One lets you edit a simple list of names and email addresses, the other is a shopping list. (They actually share most of the same source code; all the differences are in their model classes and .xib files, thanks to the magic of Cocoa bindings.) To run them:

0. Start a CouchDB server on localhost. (You can use a package manager like [HomeBrew][11] to install CouchDB.)
1. Open CouchCocoa.xcodeproj (in Xcode 4.2 or later)
2. Select "Demo-Addresses" or "Demo-Shopping" from the scheme pop-up in the toolbar
3. Press the Run button

### Building The Framework

(You only need to do this if you checked out the CouchCocoa source code and want to build it yourself. If you downloaded a precompiled framework, just go onto the next section.)

1. Open CouchCocoa.xcodeproj
2. Select "Mac Framework" or "iOS Framework" from the scheme pop-up in the toolbar
3. Product > Build

If you want to run the unit tests, first make sure a CouchDB server is running on localhost, then choose Product > Test.

The framework will be located at:

* Mac: build/CouchCocoa/Build/Products/Debug/CouchCocoa.framework
* iOS: build/CouchCocoa/Build/Products/Debug-universal/CouchCocoa.framework

(The exact location of `build` itself will depend on your Xcode preferences. It may be a subdirectory of the project folder, or it may be located down in an Xcode "DerivedData" folder. One way to find the framework is to open up the `Products` group in the project navigator, right-click on the appropriate `CouchCocoa.framework`, and choose "Show In Finder".)

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

## License

Released under the [Apache license, version 2.0][6].

Author: [Jens Alfke](https://github.com/snej/)

With contributions from: [J Chris Anderson](https://github.com/jchris/), [David Venable](https://github.com/dlvenable), [Alex McArthur](https://github.com/alexmcarthur), [Jonathon Mah](https://github.com/jmah), [Pierre Metrailler](https://github.com/pimetrai), [Sven A. Schmidt](https://github.com/sas71), [Katrin Apel](https://github.com/kaalita).

Copyright 2012, Couchbase, Inc.



[1]: http://couchdb.apache.org/
[2]: https://github.com/schwa/trundle
[3]: https://groups.google.com/group/mobile-couchbase
[4]: http://www.couchbase.com/downloads/couchbase-single-server/community
[5]: http://www.couchbase.org/issues/secure/IssueNavigator.jspa
[6]: http://www.apache.org/licenses/LICENSE-2.0.html
[7]: https://github.com/couchbaselabs/CouchCocoa/wiki/Example-Snippets
[8]: http://couchbaselabs.github.com/CouchCocoa/docs/
[10]: https://github.com/couchbaselabs/TouchDB-iOS
[11]: http://mxcl.github.com/homebrew/
[12]: https://github.com/couchbaselabs/iOS-Couchbase-Demo
