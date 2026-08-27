#import <Foundation/Foundation.h>

#include <stdint.h>

typedef struct {
    uint64_t x;
} MachObjCStruct8;

typedef struct {
    uint64_t x;
    uint64_t y;
} MachObjCStruct16;

typedef struct {
    uint64_t x;
    uint64_t y;
    uint64_t z;
} MachObjCStruct24;

typedef struct {
    uint64_t x;
    uint64_t y;
    uint64_t z;
    uint64_t w;
} MachObjCStruct32;

@interface MachObjCABIBase : NSObject
- (uint64_t)baseValue;
- (MachObjCStruct24)baseStructWithSeed:(uint64_t)seed;
- (uint64_t)threadedSuperValue;
@end

@implementation MachObjCABIBase
- (uint64_t)baseValue {
    return 41;
}

- (MachObjCStruct24)baseStructWithSeed:(uint64_t)seed {
    return (MachObjCStruct24){ seed, seed + 1, seed + 2 };
}

- (uint64_t)threadedSuperValue {
    return UINT64_C(0xa11ce5afe600d123);
}
@end

@interface MachObjCABIFixture : MachObjCABIBase
+ (uint64_t)classValue;
+ (MachObjCStruct32)classStructWithSeed:(uint64_t)seed;
- (uint64_t)addValue:(uint64_t)lhs toValue:(uint64_t)rhs;
- (BOOL)negateBool:(BOOL)value;
- (float)addFloat:(float)lhs toFloat:(float)rhs;
- (double)addDouble:(double)lhs toDouble:(double)rhs;
- (id)identity:(id)value;
- (MachObjCStruct8)struct8WithSeed:(uint64_t)seed;
- (MachObjCStruct16)struct16WithSeed:(uint64_t)seed;
- (MachObjCStruct24)struct24WithSeed:(uint64_t)seed;
- (MachObjCStruct32)struct32WithSeed:(uint64_t)seed;
- (uint64_t)threadedSelectorValue;
- (uint64_t)threadedSuperValue;
@end

@implementation MachObjCABIFixture
+ (uint64_t)classValue {
    return 84;
}

+ (MachObjCStruct32)classStructWithSeed:(uint64_t)seed {
    return (MachObjCStruct32){ seed, seed + 1, seed + 2, seed + 3 };
}

- (uint64_t)addValue:(uint64_t)lhs toValue:(uint64_t)rhs {
    return lhs + rhs;
}

- (BOOL)negateBool:(BOOL)value {
    return !value;
}

- (float)addFloat:(float)lhs toFloat:(float)rhs {
    return lhs + rhs;
}

- (double)addDouble:(double)lhs toDouble:(double)rhs {
    return lhs + rhs;
}

- (id)identity:(id)value {
    return value;
}

- (MachObjCStruct8)struct8WithSeed:(uint64_t)seed {
    return (MachObjCStruct8){ seed };
}

- (MachObjCStruct16)struct16WithSeed:(uint64_t)seed {
    return (MachObjCStruct16){ seed, seed + 1 };
}

- (MachObjCStruct24)struct24WithSeed:(uint64_t)seed {
    return (MachObjCStruct24){ seed, seed + 1, seed + 2 };
}

- (MachObjCStruct32)struct32WithSeed:(uint64_t)seed {
    return (MachObjCStruct32){ seed, seed + 1, seed + 2, seed + 3 };
}

- (uint64_t)baseValue {
    return 99;
}

- (MachObjCStruct24)baseStructWithSeed:(uint64_t)seed {
    return (MachObjCStruct24){ seed + 100, seed + 101, seed + 102 };
}

- (uint64_t)threadedSelectorValue {
    return UINT64_C(0xc001cafe5afe600d);
}

- (uint64_t)threadedSuperValue {
    return UINT64_C(0xb22ce5afe600d456);
}
@end

void *MachObjCABIFixtureCreate(void) {
    return [[MachObjCABIFixture alloc] init];
}

void *MachObjCABIFixtureClass(void) {
    return (void *)[MachObjCABIFixture class];
}
