//
//  CouchDynamicObject.h
//  CouchCocoa
//
//  Created by Jens Alfke on 8/6/09.
//  Copyright 2009 Jens Alfke. All rights reserved.
//

#import <Foundation/Foundation.h>


/** A generic class with runtime support for dynamic properties.
    You can subclass this and declare properties in the subclass without needing to implement them or make instance variables; simply note them as '@dynamic' in the @implementation.
    The dynamic accessors will be bridged to calls to -getValueOfProperty: and setValue:ofProperty:, allowing you to easily store property values in an NSDictionary or other container. */
@interface CouchDynamicObject : NSObject

+ (NSSet*) propertyNames;
+ (NSSet*) propertyNamesForClass: (Class)currentClass;

/** Returns the value of a named property.
    This method will only be called for properties that have been declared in the class's @interface using @property.
    You must override this method -- the base implementation just raises an exception.*/
- (id) getValueOfProperty: (NSString*)property;

/** Sets the value of a named property.
    This method will only be called for properties that have been declared in the class's @interface using @property, and are not declared readonly.
    You must override this method -- the base implementation just raises an exception.
    @return YES if the property was set, NO if it isn't settable; an exception will be raised.
    Default implementation returns NO. */
- (BOOL) setValue: (id)value ofProperty: (NSString*)property;


// ADVANCED STUFF FOR SUBCLASSES TO OVERRIDE:

+ (IMP) impForGetterOfClass: (Class)propertyClass;
+ (IMP) impForSetterOfClass: (Class)propertyClass;
+ (IMP) impForGetterOfType: (const char*)propertyType;
+ (IMP) impForSetterOfType: (const char*)propertyType;

@end
