//
//  UDValueFormatter.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 31.01.2026.
//

#import "UDValueFormatter.h"

@implementation UDValueFormatter

+ (NSString *)stringForValue:(UDValue)val base:(UDBase)base showThousandsSeparators:(BOOL)showThousandsSeparators decimalPlaces:(NSInteger)places {
    // 1. Handle Errors
    if (val.type == UDValueTypeErr) {
        return @"Error";
    }

    // 2. Handle Doubles (Scientific Mode)
    // Doubles ignore the 'base' and always print as Decimal
    if (val.type == UDValueTypeDouble) {
        NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
        fmt.numberStyle = NSNumberFormatterDecimalStyle;
        fmt.usesGroupingSeparator = showThousandsSeparators;
        
        if (places == -1) {
            // AUTO Mode (Behavior like %.10g)
            fmt.maximumFractionDigits = 10;
        } else {
            // FIXED Mode (Behavior like %.Nf)
            fmt.maximumFractionDigits = places;
        }
        fmt.minimumFractionDigits = 0; // Don't force trailing zeros

        return [fmt stringFromNumber:@(val.v.doubleValue)];
    }

    // 3. Handle Integers (Programmer Mode)
    if (val.type == UDValueTypeInteger) {
        return [self stringForLong:val.v.intValue base:base showThousandsSeparators:showThousandsSeparators];
    }
    
    return @"0";
}

+ (NSString *)stringForLong:(unsigned long long)val base:(UDBase)base showThousandsSeparators:(BOOL)showThousandsSeparators {
    switch (base) {
        case UDBaseDec: {
            if (showThousandsSeparators) {
                // Create a formatter for locale-aware grouping (e.g. 1,000,000)
                NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                formatter.numberStyle = NSNumberFormatterDecimalStyle;
                formatter.usesGroupingSeparator = YES;
                // Optional: Force a specific separator if you don't want Locale defaults
                // formatter.groupingSeparator = @" ";
                
                return [formatter stringFromNumber:@(val)];
            } else {
                return [NSString stringWithFormat:@"%llu", val];
            }
        }
            
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
