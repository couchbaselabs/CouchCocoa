## CouchCocoa: An Objective-C API To Apache CouchDB™

CouchCocoa is a medium-level Objective-C API for working with [CouchDB][1] on iOS and Mac OS. By "medium-level" we mean:

* It doesn't require knowledge of the HTTP API, only of CouchDB's architecture. You won't have to remember special paths or URL query parameters.
* But it doesn't provide a full-fledged model layer like CoreData or ActiveRecord. You're still working with CouchDB documents as, basically, NSDictionaries, and you'll need your own mapping between those and your app's object model.

This API is not the only way to access CouchDB on iOS and Mac OS. There are other Objective-C APIs available, such as [Trundle][2], or you can go down to the metal and talk to the HTTP API yourself using NSURLConnection.

### Kick The Tires!

* [Peruse some simple code snippets!][7]
* [Explore the API documentation!][8]

### Join Us

* You can discuss this API or ask questions at the [Mobile Couchbase Google Group][3].

* You might also want to look at the [issue tracker][5] to see known problems and feature requests.

## Build Instructions

### Running The Demo App

There is a very simple demo app included in the Demo/ subfolder. It lets you edit a simple list of names and email addresses. To run it:

0. Start a CouchDB server (such as [CouchBase Server][4]) on localhost.
1. Open CouchDemo.xcodeproj (in Xcode 4.0.2 or later)
2. Select "CouchDemo" from the scheme pop-up in the toolbar
3. Press the Run button

### Viewing API Documentation

1. Open CouchDemo.xcodeproj
2. Select "Documentation" from the scheme pop-up in the toolbar
3. Product > Build
4. Open Documentation/html/index.html in a web browser.

### Building The Mac Framework

1. Open CouchDemo.xcodeproj
2. Select "Mac Library" from the scheme pop-up in the toolbar
3. Product > Build

If you want to run the unit tests, first make sure a CouchDB server is running on localhost, then choose Product > Test.

The framework will be located at build/CouchCocoa/Build/Products/Debug/Couch.framework.

### Using The Framework In Your Apps

_TBD_

## License

Released under the [Apache license, version 2.0][6].

Contributors: [Jens Alfke](mailto:jens@couchbase.com)

Copyright 2011, Couchbase, Inc.



[1]: http://couchdb.apache.org/
[2]: https://github.com/schwa/trundle
[3]: https://groups.google.com/group/mobile-couchbase
[4]: http://www.couchbase.com/downloads/couchbase-single-server/community
[5]: https://github.com/couchbaselabs/CouchCocoa/issues
[6]: http://www.apache.org/licenses/LICENSE-2.0.html
[7]: https://github.com/couchbaselabs/CouchCocoa/wiki/Example-Snippets
[8]: http://couchbaselabs.github.com/CouchCocoa/docs/
