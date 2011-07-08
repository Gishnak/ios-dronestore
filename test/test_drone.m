
#import "DSKey.h"
#import "DSDrone.h"
#import "DSVersion.h"
#import "DSAttribute.h"
#import "DSDatastore.h"
#import "TestPerson.h"

#import <GHUnit/GHUnit.h>
#import "NSString+SHA.h"

@interface DroneTest : GHTestCase {
}
@end

@implementation DroneTest

- (BOOL)shouldRunOnMainThread {
  return NO;
}


- (void) test_basic {

  DSDatastore *ds = [[DSDictionaryDatastore alloc] init];
  DSDrone *drone = [[DSDrone alloc] initWithId:DSKey(@"/DroneA/")
    andDatastore:ds];
  [ds release];


  TestPerson *person = [[TestPerson alloc] initWithKeyName:@"A"];
  person.first = @"A";
  person.last = @"B";
  [person commit];

  GHAssertFalse([drone contains:person.key], @"Should not contain it");
  GHAssertNil([drone get:person.key], @"Should not contain it");

  [drone put:person];

  GHAssertTrue([drone contains:person.key], @"should contain it");
  GHAssertTrue([[drone get:person.key] isEqualToModel:person], @"should eq.");

  for (int i = 0; i < 100; i++) {
    [drone delete:person.key];

    GHAssertFalse([drone contains:person.key], @"Should not contain it");
    GHAssertNil([drone get:person.key], @"Should not contain it");

    [drone put:person];

    GHAssertTrue([drone contains:person.key], @"should contain it");
    GHAssertTrue([[drone get:person.key] isEqualToModel:person], @"should eq.");
  }

  TestPerson *person2 = [[TestPerson alloc] initWithVersion:person.version];
  GHAssertTrue([drone contains:person2.key], @"should contain it");
  GHAssertTrue([person isEqualToModel:person2], @"should eq.");
  GHAssertTrue([[drone get:person2.key] isEqualToModel:person2], @"should eq.");

  person2.first = @"C";
  [person2 commit];


  GHAssertTrue([drone contains:person2.key], @"should contain it");
  GHAssertFalse([person isEqualToModel:person2], @"!eq.");
  GHAssertFalse([[drone get:person2.key] isEqualToModel:person2], @"!eq.");
  GHAssertNotEqualStrings(person2.first, person.first, @"should not eq.");

  person2 = [drone merge:person2];

  GHAssertTrue([drone contains:person2.key], @"should contain it");
  GHAssertFalse([person isEqualToModel:person2], @"!eq.");
  GHAssertTrue([[drone get:person2.key] isEqualToModel:person2], @"should eq.");


  [drone release];
}


- (void) updateAttr:(DSAttribute *)attr drones:(NSArray *)drones
  people:(int)people iteration:(int)iteration {
  DSDrone *d = [drones objectAtIndex:rand() % 5];
  NSString *str = [NSString stringWithFormat:@"%d", (rand() % people)];
  DSKey *key = [TestPerson keyWithName:str];

  TestPerson *p = [d get:key];
  if (p == nil)
    return; //

  if ([attr.name isEqualToString:@"age"]) {
    p.age += 1;
  } else if ([attr.name isEqualToString:@"awesome"]) {
    p.awesome += 0.00001;
  } else {
    NSString *oldVal = [attr valueForInstance:p];
    NSString *newVal = [NSString stringWithFormat:@"%@%d", oldVal, iteration];
    [attr setValue:newVal forInstance:p];
  }
  [p commit];
  [d merge:p];
}

- (void) shuffleRandomPersonInDrones:(NSArray *)drones people:(int)people {

  int d1, d2;
  d1 = rand() % 5;
  do {
    d2 = rand() % 5;
  } while (d1 == d2);

  DSDrone *drone1 = [drones objectAtIndex:d1];
  DSDrone *drone2 = [drones objectAtIndex:d2];

  NSString *str = [NSString stringWithFormat:@"%d", (rand() % people)];
  DSKey *key = [TestPerson keyWithName:str];

  TestPerson *p = [drone1 get:key];
  if (p == nil)
    return; //

  [drone2 merge:p];
}

- (void) test_stress {

  srand((unsigned int)time(NULL)); // make sure rand is seeded.

  int numPeople = 10;

  DSDrone *d1 = [[DSDrone alloc] initWithId:DSKey(@"/Drone1/")
    andDatastore:[[[DSDictionaryDatastore alloc] init] autorelease]];
  DSDrone *d2 = [[DSDrone alloc] initWithId:DSKey(@"/Drone2/")
    andDatastore:[[[DSDictionaryDatastore alloc] init] autorelease]];
  DSDrone *d3 = [[DSDrone alloc] initWithId:DSKey(@"/Drone3/")
    andDatastore:[[[DSDictionaryDatastore alloc] init] autorelease]];
  DSDrone *d4 = [[DSDrone alloc] initWithId:DSKey(@"/Drone4/")
    andDatastore:[[[DSDictionaryDatastore alloc] init] autorelease]];
  DSDrone *d5 = [[DSDrone alloc] initWithId:DSKey(@"/Drone5/")
    andDatastore:[[[DSDictionaryDatastore alloc] init] autorelease]];

  NSArray *drones = [NSArray arrayWithObjects:d1, d2, d3, d4, d5, nil];

  for (int i = 0; i < numPeople; i++) {
    NSString *str = [NSString stringWithFormat:@"%d", i];
    TestPerson *p = [[TestPerson alloc] initWithKeyName:str];
    p.first = [NSString stringWithFormat:@"first%d", i];
    p.last = [NSString stringWithFormat:@"last%d", i];
    p.phone = [NSString stringWithFormat:@"phone%d", i];
    p.age = 0;
    p.awesome = i / numPeople;
    [p commit];

    DSDrone *d = [drones objectAtIndex:rand() % 5];
    [d put:p];
    NSLog(@"Added person %@", p);
  }


  for (int i = 0; i < numPeople * 10; i++) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    for (DSAttribute *attr in [[TestPerson attributes] allValues])
      [self updateAttr:attr drones:drones people:numPeople iteration:i];

    [self shuffleRandomPersonInDrones:drones people:numPeople];
    [self shuffleRandomPersonInDrones:drones people:numPeople];
    [self shuffleRandomPersonInDrones:drones people:numPeople];
    [self shuffleRandomPersonInDrones:drones people:numPeople];
    [self shuffleRandomPersonInDrones:drones people:numPeople];

    [pool drain];
  }

  for (DSDrone *drone in drones) {
    NSLog(@"Drone Contents: %@", drone);
    for (int i = 0; i < numPeople; i++) {
      DSKey *k = [TestPerson keyWithName:[NSString stringWithFormat:@"%d", i]];
      TestPerson *p = [drone get:k];
      NSLog(@"person %d: %@", i, (p == nil ? @"not found" : p));
    }
  }

  for (int i = 0; i < numPeople; i++) {
    DSKey *k = [TestPerson keyWithName:[NSString stringWithFormat:@"%d", i]];
    TestPerson *p = [[drones objectAtIndex:0] get:k];
    for (DSDrone *drone in drones)
      p = [drone merge:p];

    for (DSDrone *drone in drones) {
      p = [drone merge:p];

      TestPerson *o = [drone get:p.key];
      GHAssertTrue([p isEqualToModel:o], @"equal");
      GHAssertEqualStrings(p.first, o.first, @"first");
      GHAssertEqualStrings(p.last, o.last, @"last");
      GHAssertEqualStrings(p.phone, o.phone, @"phone");
      GHAssertTrue(p.age == o.age, @"age");
      GHAssertTrue(fabs(p.awesome - o.awesome) < 0.00001, @"awesome");

      GHAssertTrue([p.version isEqualToVersion:o.version], @"version");
    }
  }

  [d1 release];
  [d2 release];
  [d3 release];
  [d4 release];
  [d5 release];
}




@end
