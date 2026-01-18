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

/**
 Returns localized unit names for a specific category.
 */
- (NSArray<NSString *> *)unitNamesForCategory:(NSString *)category;

/**
 Converts a value from one unit string to another.
 Returns the original value if conversion is impossible.
 */
- (double)convertValue:(double)value
              category:(NSString *)category
              fromUnit:(NSString *)fromName
                toUnit:(NSString *)toName;

@end
