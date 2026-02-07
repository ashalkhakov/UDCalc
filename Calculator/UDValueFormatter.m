//
//  UDValueFormatter.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 31.01.2026.
//

#import "UDValueFormatter.h"

@implementation UDValueFormatter

+ (NSString *)stringForValue:(UDValue)val base:(UDBase)base {
    // 1. Handle Errors
    if (val.type == UDValueTypeErr) {
        return @"Error";
    }

    // 2. Handle Doubles (Scientific Mode)
    // Doubles ignore the 'base' and always print as Decimal
    if (val.type == UDValueTypeDouble) {
        // Remove trailing zeros (e.g., "5.00" -> "5")
        NSString *s = [NSString stringWithFormat:@"%.10g", val.v.doubleValue];
        return s;
    }

    // 3. Handle Integers (Programmer Mode)
    if (val.type == UDValueTypeInteger) {
        return [self stringForLong:val.v.intValue base:base];
    }
    
    return @"0";
}

+ (NSString *)stringForLong:(unsigned long long)val base:(UDBase)base {
    switch (base) {
        case UDBaseDec:
            return [NSString stringWithFormat:@"%llu", val];
            
        case UDBaseHex:
            // %llX formats as uppercase Hex
            return [NSString stringWithFormat:@"0x%llX", val];
            
        case UDBaseOct:
            // %llo formats as Octal
            return [NSString stringWithFormat:@"%llo", val];
            
        case UDBaseBin:
            return [self binaryStringForLong:val];
    }
    return @"0";
}

// Private Helper for Binary (Objective-C doesn't have a %b formatter)
+ (NSString *)binaryStringForLong:(long long)val {
    if (val == 0) return @"0";
    
    NSMutableString *str = [NSMutableString string];
    unsigned long long uVal = (unsigned long long)val; // Use unsigned to handle bit shifts safely
    
    // Simple algorithm: Read the last bit, prepend it, shift right.
    // Limit to 64 bits to prevent infinite loops if something goes wrong,
    // though 'uVal > 0' usually catches it.
    int bits = 0;
    while (uVal > 0 && bits < 64) {
        [str insertString:((uVal & 1) ? @"1" : @"0") atIndex:0];
        uVal >>= 1;
        bits++;
    }
    return str;
}

@end
