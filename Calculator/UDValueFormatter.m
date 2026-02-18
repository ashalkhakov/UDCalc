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
            unsigned long long temp = val;
            
            // Fast-path for zero
            if (temp == 0) return @"0";

            // A 64-bit max unsigned integer is 18,446,744,073,709,551,615.
            // That's 20 digits + 6 separators + 1 null terminator = 27 characters.
            // A 32-byte buffer gives us plenty of room.
            char buffer[32];
            int index = 31;
            buffer[index] = '\0'; // Null-terminate the end of the string
            
            // Figure out the local separator (default to comma)
            NSString *sepStr = [[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator];
            char separator = (sepStr.length > 0) ? (char)[sepStr characterAtIndex:0] : ',';
            int digitCount = 0;
            
            // Loop mathematically to extract digits right-to-left
            while (temp > 0) {
                // Add the separator every 3 digits
                if (digitCount > 0 && digitCount % 3 == 0 && showThousandsSeparators) {
                    index--;
                    buffer[index] = separator;
                }
                
                // Extract lowest digit, convert to ASCII, and move to next
                char digitChar = (char)(temp % 10) + '0';
                index--;
                buffer[index] = digitChar;
                
                temp /= 10;
                digitCount++;
            }
            
            // Return an NSString starting from wherever our index ended up
            return [NSString stringWithUTF8String:&buffer[index]];
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
