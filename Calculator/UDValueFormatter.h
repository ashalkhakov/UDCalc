//
//  UDValueFormatter.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 31.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDValue.h" // Needs access to your Tagged Union
#import "UDInputBuffer.h" // Needs access to UDBase enum

@interface UDValueFormatter : NSObject

// Main method: Converts a UDValue to a string in the given base
+ (NSString *)stringForValue:(UDValue)value base:(UDBase)base showThousandsSeparators:(BOOL)showThousandsSeparators decimalPlaces:(NSInteger)decimalPlaces;

// Helper: Converts a raw long long (useful for the InputBuffer display)
+ (NSString *)stringForLong:(unsigned long long)val base:(UDBase)base showThousandsSeparators:(BOOL)showThousandsSeparators;

@end
