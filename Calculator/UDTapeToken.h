//
//  UDTapeToken.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import <Foundation/Foundation.h>

// Distinguish between a raw number and an operator
typedef NS_ENUM(NSInteger, UDTokenType) {
    UDTokenTypeValue,
    UDTokenTypeOperator
};

// Modifiers attached directly to a value (e.g., user typed 5 then %)
typedef NS_ENUM(NSInteger, UDTapePostfix) {
    UDTapePostfixNone = 0,
    UDTapePostfixPercent // Displays as "%"
};

@interface UDTapeToken : NSObject

// --- Properties (Read Only) ---

@property (nonatomic, assign, readonly) UDTokenType type;

// Valid if type == UDTokenTypeValue
@property (nonatomic, assign, readonly) double doubleValue;
@property (nonatomic, assign, readonly) UDTapePostfix postfix;

// Valid if type == UDTokenTypeOperator
@property (nonatomic, assign, readonly) NSInteger opValue; // Maps to UDOp enum

// --- Factory Methods ---

+ (instancetype)tokenWithValue:(double)value postfix:(UDTapePostfix)postfix;
+ (instancetype)tokenWithOperator:(NSInteger)op;

// --- Output ---

/**
 Returns the string representation.
 For values: returns formatted number (e.g. "5" or "5%").
 For operators: Looks up the symbol in UDOpRegistry (e.g. "+").
 */
- (NSString *)stringValue;

@end
