//
//  UDUnitConverter.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import "UDUnitConverter.h"
#import "UDConstants.h"

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

- (NSArray<NSUnit *> *)unitsForCategory:(NSString *)category {
    return _unitData[category] ?: @[];
}

- (NSString *)localizedNameForCategory:(NSString *)categoryKey {
    return NSLocalizedString(categoryKey, @"Unit conversion category");
}

- (NSString *)localizedNameForUnit:(NSUnit *)unit {
    NSMeasurementFormatter *fmt = [[NSMeasurementFormatter alloc] init];
    // This ensures we get the full name (e.g. "meters") instead of just "m"
    fmt.unitOptions = NSMeasurementFormatterUnitOptionsProvidedUnit;
    return [fmt stringFromUnit:unit];
}

- (NSUnit *)unitForSymbol:(NSString *)symbol ofCategory:(NSString *)category {
    NSArray<NSUnit *> *units = self.unitData[category];
    if (!units) return nil;
    
    for (NSInteger i = 0; i < units.count; i++) {
        NSUnit *u = units[i];

        if ([u.symbol isEqualToString:symbol]) {
            return u;
        }
    }

    return nil;
}

- (NSString *)symbolForUnit:(NSUnit *)unit {
    return unit.symbol;
}

- (double)convertValue:(double)value fromUnit:(NSUnit *)fromUnit toUnit:(NSUnit *)toUnit {
    if (!fromUnit || !toUnit) return value;

#ifdef GNUSTEP
    // Fix for GNUstep: NSMeasurement conversion is currently limited.
    // We manually use the NSDimension converters.
    if ([fromUnit isKindOfClass:[NSDimension class]] && [toUnit isKindOfClass:[NSDimension class]]) {
        NSUnitConverter *fromConv = [(NSDimension *)fromUnit converter];
        NSUnitConverter *toConv   = [(NSDimension *)toUnit converter];
        double baseValue = [fromConv baseUnitValueFromValue:value];
        return [toConv valueFromBaseUnitValue:baseValue];
    }
#else
    // Standard Apple Cocoa path
    NSMeasurement *measurement = [[NSMeasurement alloc] initWithDoubleValue:value unit:fromUnit];
    if ([measurement canBeConvertedToUnit:toUnit]) {
        return [measurement measurementByConvertingToUnit:toUnit].doubleValue;
    }
#endif
    return value;
}

- (void)setupUnits {
    // Populate with all standard Apple NSUnit types
    self.unitData = @{
        UDConstLength : @[
            [NSUnitLength meters], [NSUnitLength kilometers], [NSUnitLength centimeters],
            [NSUnitLength feet], [NSUnitLength inches], [NSUnitLength miles], [NSUnitLength yards]
        ],
        UDConstArea : @[
            [NSUnitArea squareMeters], [NSUnitArea squareKilometers], [NSUnitArea squareFeet],
            [NSUnitArea squareMiles], [NSUnitArea acres], [NSUnitArea hectares]
        ],
        UDConstMass : @[
            [NSUnitMass kilograms], [NSUnitMass grams],
#ifdef GNUSTEP
            [NSUnitMass pounds],
#else
            [NSUnitMass poundsMass],
#endif
            [NSUnitMass ounces], [NSUnitMass stones]
        ],
        UDConstTemperature : @[
            [NSUnitTemperature celsius], [NSUnitTemperature fahrenheit], [NSUnitTemperature kelvin]
        ],
        UDConstSpeed : @[
            [NSUnitSpeed metersPerSecond], [NSUnitSpeed kilometersPerHour],
            [NSUnitSpeed milesPerHour], [NSUnitSpeed knots]
        ],
        UDConstEnergy : @[
            [NSUnitEnergy joules], [NSUnitEnergy kilojoules], [NSUnitEnergy calories], [NSUnitEnergy kilocalories]
        ],
        UDConstPressure : @[
            [NSUnitPressure newtonsPerMetersSquared], [NSUnitPressure bars], [NSUnitPressure millimetersOfMercury],
            [NSUnitPressure poundsForcePerSquareInch]
        ],
        UDConstVolume : @[
            [NSUnitVolume liters], [NSUnitVolume milliliters], [NSUnitVolume cubicMeters],
            [NSUnitVolume gallons], [NSUnitVolume cups], [NSUnitVolume pints]
        ],
        UDConstPower : @[
            [NSUnitPower watts], [NSUnitPower kilowatts], [NSUnitPower horsepower]
        ],
        UDConstTime : @[
            [NSUnitDuration seconds], [NSUnitDuration minutes], [NSUnitDuration hours]
        ]
    };
}

@end
