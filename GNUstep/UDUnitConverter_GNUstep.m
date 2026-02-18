/*
 * UDUnitConverter_GNUstep.m
 *
 * GNUstep-compatible implementation of UDUnitConverter.
 * Uses manual conversion factors instead of NSMeasurement/NSMeasurementFormatter
 * which are not available in GNUstep.
 *
 * The public interface (UDUnitConverter.h) is unchanged.
 */

#import "UDUnitConverter.h"

/* Internal structure for a unit definition */
@interface UDUnitDef : NSObject
@property (copy) NSString *name;
@property (assign) double factor;   /* multiply by this to get base unit */
@property (assign) double offset;   /* add this after factor (for temperature) */
+ (instancetype)name:(NSString *)n factor:(double)f;
+ (instancetype)name:(NSString *)n factor:(double)f offset:(double)o;
@end

@implementation UDUnitDef
+ (instancetype)name:(NSString *)n factor:(double)f {
    return [self name:n factor:f offset:0.0];
}
+ (instancetype)name:(NSString *)n factor:(double)f offset:(double)o {
    UDUnitDef *d = [[UDUnitDef alloc] init];
    d.name = n;
    d.factor = f;
    d.offset = o;
    return d;
}
@end

/* ============================================================ */

@interface UDUnitConverter ()
@property (strong) NSDictionary<NSString *, NSArray<UDUnitDef *> *> *unitData;
@end

@implementation UDUnitConverter

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupUnits];
    }
    return self;
}

- (NSArray<NSString *> *)availableCategories {
    return [self.unitData.allKeys sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<NSString *> *)unitNamesForCategory:(NSString *)category {
    NSArray<UDUnitDef *> *units = self.unitData[category];
    if (!units) return @[];
    NSMutableArray *names = [NSMutableArray array];
    for (UDUnitDef *u in units) {
        [names addObject:u.name];
    }
    return names;
}

- (double)convertValue:(double)value
               category:(NSString *)category
               fromUnit:(NSString *)fromName
                 toUnit:(NSString *)toName
{
    NSArray<UDUnitDef *> *units = self.unitData[category];
    if (!units) return value;

    UDUnitDef *fromDef = nil;
    UDUnitDef *toDef = nil;
    for (UDUnitDef *u in units) {
        if ([u.name isEqualToString:fromName]) fromDef = u;
        if ([u.name isEqualToString:toName]) toDef = u;
    }

    if (!fromDef || !toDef) return value;

    /* Convert: source -> base unit -> target */
    /* For most units: base = value * fromFactor; result = base / toFactor */
    /* For temperature: base = (value + fromOffset) * fromFactor;
                        result = base / toFactor - toOffset */
    double base = (value + fromDef.offset) * fromDef.factor;
    double result = base / toDef.factor - toDef.offset;
    return result;
}

- (void)setupUnits {
    self.unitData = @{
        @"Length" : @[
            [UDUnitDef name:@"m"  factor:1.0],
            [UDUnitDef name:@"km" factor:1000.0],
            [UDUnitDef name:@"cm" factor:0.01],
            [UDUnitDef name:@"ft" factor:0.3048],
            [UDUnitDef name:@"in" factor:0.0254],
            [UDUnitDef name:@"mi" factor:1609.344],
            [UDUnitDef name:@"yd" factor:0.9144],
        ],
        @"Area" : @[
            [UDUnitDef name:@"m\u00B2"  factor:1.0],
            [UDUnitDef name:@"km\u00B2" factor:1e6],
            [UDUnitDef name:@"ft\u00B2" factor:0.09290304],
            [UDUnitDef name:@"mi\u00B2" factor:2589988.110336],
            [UDUnitDef name:@"ac"       factor:4046.8564224],
            [UDUnitDef name:@"ha"       factor:10000.0],
        ],
        @"Mass" : @[
            [UDUnitDef name:@"kg"  factor:1.0],
            [UDUnitDef name:@"g"   factor:0.001],
            [UDUnitDef name:@"lb"  factor:0.45359237],
            [UDUnitDef name:@"oz"  factor:0.028349523125],
            [UDUnitDef name:@"st"  factor:6.35029318],
        ],
        @"Temperature" : @[
            /* Conversion via Kelvin as base:
             * C -> K: (value + 273.15) * 1.0
             * F -> K: (value + 459.67) * 5.0/9.0
             * K -> K: (value + 0) * 1.0 */
            [UDUnitDef name:@"\u00B0C" factor:1.0   offset:273.15],
            [UDUnitDef name:@"\u00B0F" factor:5.0/9.0 offset:459.67],
            [UDUnitDef name:@"K"       factor:1.0   offset:0.0],
        ],
        @"Speed" : @[
            [UDUnitDef name:@"m/s"  factor:1.0],
            [UDUnitDef name:@"km/h" factor:1.0/3.6],
            [UDUnitDef name:@"mph"  factor:0.44704],
            [UDUnitDef name:@"kn"   factor:0.514444],
        ],
        @"Energy" : @[
            [UDUnitDef name:@"J"    factor:1.0],
            [UDUnitDef name:@"kJ"   factor:1000.0],
            [UDUnitDef name:@"cal"  factor:4.184],
            [UDUnitDef name:@"kCal" factor:4184.0],
        ],
        @"Pressure" : @[
            [UDUnitDef name:@"Pa"   factor:1.0],
            [UDUnitDef name:@"bar"  factor:100000.0],
            [UDUnitDef name:@"mmHg" factor:133.322],
            [UDUnitDef name:@"psi"  factor:6894.757],
        ],
        @"Volume" : @[
            [UDUnitDef name:@"L"    factor:1.0],
            [UDUnitDef name:@"mL"   factor:0.001],
            [UDUnitDef name:@"m\u00B3" factor:1000.0],
            [UDUnitDef name:@"gal"  factor:3.78541],
            [UDUnitDef name:@"cup"  factor:0.236588],
            [UDUnitDef name:@"pt"   factor:0.473176],
        ],
        @"Power" : @[
            [UDUnitDef name:@"W"  factor:1.0],
            [UDUnitDef name:@"kW" factor:1000.0],
            [UDUnitDef name:@"hp" factor:745.7],
        ],
        @"Time" : @[
            [UDUnitDef name:@"s"   factor:1.0],
            [UDUnitDef name:@"min" factor:60.0],
            [UDUnitDef name:@"hr"  factor:3600.0],
        ],
    };
}

@end
