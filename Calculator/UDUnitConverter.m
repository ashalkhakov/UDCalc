//
//  UDUnitConverter.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import "UDUnitConverter.h"

@interface UDUnitConverter()
@property (strong) NSDictionary<NSString *, NSArray<NSUnit *> *> *unitData;
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
    NSArray *units = self.unitData[category];
    if (!units) return @[];
    
    NSMutableArray *names = [NSMutableArray array];
    NSMeasurementFormatter *fmt = [[NSMeasurementFormatter alloc] init];
    fmt.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
    
    for (NSUnit *u in units) {
        [names addObject:[fmt stringFromUnit:u]];
    }
    return names;
}

- (double)convertValue:(double)value category:(NSString *)category fromUnit:(NSString *)fromName toUnit:(NSString *)toName {
    NSArray *units = self.unitData[category];
    if (!units) return value;
    
    NSMeasurementFormatter *fmt = [[NSMeasurementFormatter alloc] init];
    fmt.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
    
    NSUnit *fromUnit = nil;
    NSUnit *toUnit = nil;
    
    // Find the NSUnit objects matching the names
    for (NSUnit *u in units) {
        NSString *name = [fmt stringFromUnit:u];
        if ([name isEqualToString:fromName]) fromUnit = u;
        if ([name isEqualToString:toName]) toUnit = u;
    }
    
    if (fromUnit && toUnit) {
#ifdef GNUSTEP
        // GNUstep's NSMeasurement.measurementByConvertingToUnit: is broken
        // (calls -converter on NSUnit which only exists on NSDimension).
        // Use NSDimension's converter directly instead.
        if ([fromUnit isKindOfClass:[NSDimension class]] && [toUnit isKindOfClass:[NSDimension class]]) {
            NSUnitConverter *fromConv = [(NSDimension *)fromUnit converter];
            NSUnitConverter *toConv   = [(NSDimension *)toUnit converter];
            double baseValue = [fromConv baseUnitValueFromValue:value];
            return [toConv valueFromBaseUnitValue:baseValue];
        }
#else
        NSMeasurement *measurement = [[NSMeasurement alloc] initWithDoubleValue:value unit:fromUnit];
        if ([measurement canBeConvertedToUnit:toUnit]) {
            NSMeasurement *result = [measurement measurementByConvertingToUnit:toUnit];
            return result.doubleValue;
        }
#endif
    }
    
    return value;
}

- (void)setupUnits {
    // Populate with all standard Apple NSUnit types
    self.unitData = @{
        @"Length" : @[
            [NSUnitLength meters], [NSUnitLength kilometers], [NSUnitLength centimeters],
            [NSUnitLength feet], [NSUnitLength inches], [NSUnitLength miles], [NSUnitLength yards]
        ],
        @"Area" : @[
            [NSUnitArea squareMeters], [NSUnitArea squareKilometers], [NSUnitArea squareFeet],
            [NSUnitArea squareMiles], [NSUnitArea acres], [NSUnitArea hectares]
        ],
        @"Mass" : @[
            [NSUnitMass kilograms], [NSUnitMass grams],
#ifdef GNUSTEP
            [NSUnitMass pounds],
#else
            [NSUnitMass poundsMass],
#endif
            [NSUnitMass ounces], [NSUnitMass stones]
        ],
        @"Temperature" : @[
            [NSUnitTemperature celsius], [NSUnitTemperature fahrenheit], [NSUnitTemperature kelvin]
        ],
        @"Speed" : @[
            [NSUnitSpeed metersPerSecond], [NSUnitSpeed kilometersPerHour],
            [NSUnitSpeed milesPerHour], [NSUnitSpeed knots]
        ],
        @"Energy" : @[
            [NSUnitEnergy joules], [NSUnitEnergy kilojoules], [NSUnitEnergy calories], [NSUnitEnergy kilocalories]
        ],
        @"Pressure" : @[
            [NSUnitPressure newtonsPerMetersSquared], [NSUnitPressure bars], [NSUnitPressure millimetersOfMercury],
            [NSUnitPressure poundsForcePerSquareInch]
        ],
        @"Volume" : @[
            [NSUnitVolume liters], [NSUnitVolume milliliters], [NSUnitVolume cubicMeters],
            [NSUnitVolume gallons], [NSUnitVolume cups], [NSUnitVolume pints]
        ],
        @"Power" : @[
            [NSUnitPower watts], [NSUnitPower kilowatts], [NSUnitPower horsepower]
        ],
        @"Time" : @[
            [NSUnitDuration seconds], [NSUnitDuration minutes], [NSUnitDuration hours]
        ]
    };
}

@end
