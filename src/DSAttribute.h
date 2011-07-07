
#import <Foundation/Foundation.h>

// Attributes define and compose a Model. A Model can be seen as a collection
// of attributes.
//
// An Attribute primarily defines a name, an associated data type, and a
// particular merge strategy.
//
// Attributes can have other options, including defining a default value, and
// validation for the data they hold.
//

@class DSMergeStrategy;
@class DSModel;

#define __STRINGIFY2( x) #x
#define __STRINGIFY(x) __STRINGIFY2(x)

#define PRINTTHIS(text) \
    NSLog(PASTE( @, STRINGIFY(text)));

#define DSRegisterAttribute(NAME, TYPE, VALUE, STRAT) { \
  DSAttribute *attr; \
  attr = [DSAttribute attributeWithName:@__STRINGIFY(NAME) \
    type:[TYPE class]]; \
  attr.strategy = [STRAT strategy]; \
  attr.defaultValue = VALUE; \
  [self registerAttribute:attr];  \
}

#define DSRegisterPrimitiveAttribute(NAME, TYPE, VALUE, STRAT) { \
  DSPrimitiveAttribute *attr; \
  attr = [DSPrimitiveAttribute attributeWithName:@__STRINGIFY(NAME) \
    objCType:@encode(TYPE)]; \
  attr.strategy = [STRAT strategy]; \
  TYPE buf = VALUE; \
  attr.defaultValue = [[NSValue classForObjCType:@encode(TYPE)] \
    value:&buf withObjCType:@encode(TYPE)]; \
  [self registerAttribute:attr];  \
}



@interface DSAttribute : NSObject {
  NSString *name;

  Class type;
  DSMergeStrategy *strategy;

  SEL getter;
  SEL setter;
  // DSModel *model; // necessary?
  id defaultValue;
}

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) Class type;
@property (nonatomic, retain) DSMergeStrategy *strategy;
@property (nonatomic, retain) id defaultValue;

// ADD Defaults.
- (id) initWithName:(NSString *)name type:(Class)type;

- (void) setValue:(id)value forInstance:(DSModel *)instance;
- (void) setDefaultValue:(id)value forInstance:(DSModel *)instance;
- (id) valueForInstance:(DSModel *)instance;

- (void) setData:(NSDictionary *)data forInstance:(DSModel *)instance;
- (void) setDefaultValue:(id)value forInstance:(DSModel *)instance;
- (NSDictionary *) dataForInstance:(DSModel *)instance;

+ (id) attributeWithName:(NSString *)name type:(Class)type;

@end



@interface DSPrimitiveAttribute : DSAttribute  {

  const char *objCType;

}

// for type, use @encode(int) or @encode(float), et-cetera.
- (id) initWithName:(NSString *)name objCType:(const char *)objCType;
+ (id) attributeWithName:(NSString *)name objCType:(const char *)type;

@end


@interface NSValue (DSAttribute)
+ (Class) classForObjCType:(const char *)objCType;
@end

@interface NSNumber (DSAttribute)
+ (id) value:(const void *)buf withObjCType:(const char *)type;
@end

