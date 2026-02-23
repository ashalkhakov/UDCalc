//
//  UDUnitConverter.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <Foundation/Foundation.h>

@interface UDUnitConverter : NSObject

/**
 Returns all available categories (e.g., "Area", "Length", "Mass").
 */
- (NSArray<NSString *> *)availableCategories;

- (NSArray<NSUnit *> *)unitsForCategory:(NSString *)category;
- (NSUnit *)unitForSymbol:(NSString *)symbol ofCategory:(NSString *)category;
- (NSString *)symbolForUnit:(NSUnit *)unit;

- (NSString *)localizedNameForCategory:(NSString *)category;
- (NSString *)localizedNameForUnit:(NSUnit *)unit;

/**
 Converts a value from one unit string to another.
 Returns the original value if conversion is impossible.
 */
- (double)convertValue:(double)value
              fromUnit:(NSUnit *)fromUnit
                toUnit:(NSUnit *)toUnit;

@end
