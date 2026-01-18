//
//  UDTapeToken.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import "UDTapeToken.h"
#import "UDCalc.h"
#import "UDOpRegistry.h" // Import Registry for symbol lookup

@interface UDTapeToken ()
// Redeclare properties as readwrite for internal use
@property (nonatomic, assign, readwrite) UDTokenType type;
@property (nonatomic, assign, readwrite) double doubleValue;
@property (nonatomic, assign, readwrite) UDTapePostfix postfix;
@property (nonatomic, assign, readwrite) NSInteger opValue;
@end

@implementation UDTapeToken

#pragma mark - Factory Methods

+ (instancetype)tokenWithValue:(double)value postfix:(UDTapePostfix)postfix {
    UDTapeToken *token = [[UDTapeToken alloc] init];
    token.type = UDTokenTypeValue;
    token.doubleValue = value;
    token.postfix = postfix;
    return token;
}

+ (instancetype)tokenWithOperator:(NSInteger)op {
    UDTapeToken *token = [[UDTapeToken alloc] init];
    token.type = UDTokenTypeOperator;
    token.opValue = op;
    return token;
}

#pragma mark - String Conversion

- (NSString *)stringValue {
    if (self.type == UDTokenTypeValue) {
        // 1. Format the number
        // %g automatically removes trailing zeros (5.0 -> "5", 5.5 -> "5.5")
        NSString *baseString = [NSString stringWithFormat:@"%g", self.doubleValue];
        
        // 2. Append Postfix if necessary
        if (self.postfix == UDTapePostfixPercent) {
            // Check Registry for the "%" symbol to be perfectly safe?
            // Or just append hardcoded "%" since it's a visual postfix on the number.
            // Let's grab the official symbol from the registry for UDOpPercent:
            UDOpInfo *info = [[UDOpRegistry shared] infoForOp:UDOpPercent];
            NSString *percentSym = info ? info.symbol : @"%";
            
            return [baseString stringByAppendingString:percentSym];
        }
        
        return baseString;
    }
    else {
        // 3. Look up Operator Symbol from Registry
        UDOpInfo *info = [[UDOpRegistry shared] infoForOp:self.opValue];
        
        if (info) {
            return info.symbol;
        } else {
            return @"?"; // Fallback if op code is not found
        }
    }
}

@end
