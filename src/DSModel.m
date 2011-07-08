
#import "DSModel.h"
#import "iDrone.h"

#import "NSString+SHA.h"

static NSMutableDictionary *dsModelRegistry = nil;
static NSMutableDictionary *dsAttributeRegistry = nil;


//------------------------------------------------------------------------------
@implementation DSModel

@synthesize key, version, created;

- (id) init {
  [NSException raise:@"DSInvalidModelConstruction" format:@"DSModel requires"
    "a Key or a Version to initialize."];
  return nil;
}

- (id) initWithKeyName:(NSString *)keyName {
  DSKey *_key = [[self class] keyWithName:keyName];
  return [self initWithVersion:[DSVersion blankVersionWithKey:_key]];
}

- (id) initWithKeyName:(NSString *)keyName andParent:(DSKey *)parent {
  DSKey *_key = [[self class] keyWithName:keyName];
  return [self initWithVersion:[DSVersion blankVersionWithKey:_key]];
}

- (id) initWithVersion:(DSVersion *)_version {
  if ((self = [super init])) {
    version = [_version retain];
    key = [[version key] retain];

    attributeData = [[NSMutableDictionary alloc] init];
    [self initializeAttributes];
  }
  return self;
}

+ (DSModel *) modelWithVersion:(DSVersion *)version {
  Class model = [self modelWithDSType:version.type];
  return [[[model alloc] initWithVersion:version] autorelease];
}

- (void) dealloc {
  [attributeData release];
  [version release];
  [key release];
  [super dealloc];
}

//------------------------------------------------------------------------------

- (NSString *) description {
  return [NSString stringWithFormat:@"<%@ %@>", [[self class] dstype], key];
}

// Unfortunately, we don't have a decorator so we cant keep tabs on this.
// decorators would be too confusing for users...
// - (BOOL) isDirty {
//   NSMutableDictionary *attrs = [self attributeData];
// }

- (BOOL) isCommitted {
  return !version.isBlank;
}

- (NSDate *) created {
  return version.createdDate;
}

//------------------------------------------------------------------------------

- (BOOL) isEqualToModel:(DSModel *)model {
  if (![key isEqualToKey:model.key])
    return NO;

  if (![version isEqualToVersion:model.version])
    return NO;

  return [attributeData isEqual:[model attributeData]];
}


//------------------------------------------------------------------------------

- (void) commit {
  NSMutableString *hashB = [[NSMutableString alloc] init];
  [hashB appendFormat:@"%@,%@,", key, [self dstype]];

  NSMutableDictionary *attrData = [[NSMutableDictionary alloc] init];
  NSDictionary *attrs = [[self class] attributes];
  for (DSAttribute *attr in [attrs allValues]) {
    [attr updateValueForInstance:self];
    [attrData setValue:[attr dataForInstance:self] forKey:attr.name];
    [hashB appendFormat:@"%@=%@,", attr.name, [attrData valueForKey:attr.name]];
  }

  NSString *hash = [hashB sha1HexDigest];
  if ([hash isEqualToString:version.hashstr]) {
    DSLog(@"[%@] committing unmodified version.", self.key);
    return;
  }

  nanotime now = nanotime_now();
  nanotime created_nt = ([version isBlank] ? now : version.created);
  NSNumber *committed_num = [NSNumber numberWithLongLong:now.ns];
  NSNumber *created_num = [NSNumber numberWithLongLong:created_nt.ns];

  DSMutableSerialRep *serialRep = [[DSMutableSerialRep alloc] init];
  [serialRep setValue:hash forKey:@"hash"];
  [serialRep setValue:[key string] forKey:@"key"];
  [serialRep setValue:[self dstype] forKey:@"type"];
  [serialRep setValue:version.hashstr forKey:@"parent"];
  [serialRep setValue:committed_num forKey:@"committed"];
  [serialRep setValue:created_num forKey:@"created"];
  [serialRep setValue:attrData forKey:@"attributes"];

  NSLog(@"%@", serialRep.contents);

  @synchronized(self) { // just in case.
    [version release];
    version = [[DSVersion alloc] initWithSerialRep:serialRep];
  }
}



- (void) mergeVersion:(DSVersion *)other {
  [DSMerge mergeInstance:self withVersion:other];
}



//------------------------------------------------------------------------------

- (void) initializeAttributes {
  [attributeData removeAllObjects];
  NSArray *attrs = [[[self class] attributes] allValues];
  for (DSAttribute *attr in attrs) {
    [attributeData setValue:[NSMutableDictionary dictionary] forKey:attr.name];

    NSDictionary *data = [version dataForAttribute:attr.name];
    if (data)
      [attr setData:data forInstance:self];
    else
      [attr setDefaultValue:attr.defaultValue forInstance:self];
  }

}

- (void) setData:(NSDictionary *)dict forAttribute:(NSString *)attrName {
  NSMutableDictionary *data = [attributeData valueForKey:attrName];
  [data removeAllObjects];
  [data addEntriesFromDictionary:dict];
}


- (NSDictionary *) dataForAttribute:(NSString *)attrName {
  return [attributeData valueForKey:attrName];
}

- (NSMutableDictionary *) mutableDataForAttribute:(NSString *)attrName{
  return [attributeData valueForKey:attrName];
}

- (NSDictionary *) attributeData {
  return attributeData;
}

+ (NSDictionary *) attributes {
  return [dsAttributeRegistry valueForKey:[self dstype]];
}

+ (DSAttribute *) attributeNamed:(NSString *)name {
  return [[self attributes] valueForKey:name];
}

//------------------------------------------------------------------------------


+ (void) registerAttribute:(DSAttribute *)attr {

  if (![attr isKindOfClass:[DSAttribute class]]) {
    [NSException raise:@"DSInvalidAttribute" format:@"%@ is not"
      "derived from %@", attr, [DSAttribute class]];
  }


  if (![attr.strategy isKindOfClass:[DSMergeStrategy class]]) {
    [NSException raise:@"DSInvalidStrategy" format:@"%@ is not"
      "derived from %@", attr.strategy, [DSMergeStrategy class]];
  }

  NSMutableDictionary *attrs = [dsAttributeRegistry valueForKey:[self dstype]];
  if (!attrs) {
    [NSException raise:@"DSAttributeRegisteryMissing" format:@"Attribute "
      "registry for %@ is missing. (did you call [super registerAttributes] "
      "first?).", self];
  }

  DSLog(@"[%@] registered attribute %@", self, attr.name);
  // ok register it!
  [attrs setValue:attr forKey:attr.name];
}

+ (void) registerAttributes {

  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  [dsAttributeRegistry setValue:dict forKey:[self dstype]];
}


+ (void) initialize {

  if (dsModelRegistry == nil)
    dsModelRegistry = [[NSMutableDictionary alloc] init];
  if (dsAttributeRegistry == nil)
    dsAttributeRegistry = [[NSMutableDictionary alloc] init];

  [self registerAttributes];

  NSString *dstype = [self dstype];

  if ([dsAttributeRegistry valueForKey:dstype] == nil) {
    [NSException raise:@"DSAttributeRegisteryMissing" format:@"Attribute "
    "registry for %@ is missing. (did you override [DSModel "
    "registerAttributes] without calling [super registerAttributes]?).", self];
  }
  [dsModelRegistry setValue:[self class] forKey:dstype];

}
//------------------------------------------------------------------------------

// override this to name model something different than its Class name.
- (NSString *) dstype {
  return [[self class] dstype];
}

+ (NSString *) dstype {
  return NSStringFromClass([self class]);
}

+ (DSKey *) keyWithName:(NSString *)name {
  NSString *s = [NSString stringWithFormat:@"/%@/%@", [self dstype], name];
  return [DSKey keyWithString:s];
}

+ (Class) modelWithDSType:(NSString *)type {
  //TODO(jbenet): synch here? shouldnt need to... its basically immutable now.
  return [dsModelRegistry valueForKey:type];
}

@end



