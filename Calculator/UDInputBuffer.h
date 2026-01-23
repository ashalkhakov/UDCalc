//
//  UDInputBuffer.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 23.01.2026.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UDInputBuffer : NSObject

// --- Properties (Exposed for debugging/UI if needed) ---
@property (nonatomic, assign, readonly) long long mantissaBuffer;
@property (nonatomic, assign, readonly) long long exponentBuffer;
@property (nonatomic, assign, readonly) NSInteger decimalShift;
@property (nonatomic, assign, readonly) BOOL inExponentMode;
@property (nonatomic, assign, readonly) BOOL isMantissaNegative;
@property (nonatomic, assign, readonly) BOOL isExponentNegative;
@property (nonatomic, assign, readonly) BOOL hasHitDecimal;

// --- Public Methods ---

// Force-loads a value (like Pi or Ans) by simulating user input
- (void)loadConstant:(double)constant;

// Adds a digit (0-9) to the current active buffer (mantissa or exponent)
- (void)handleDigit:(int)digit;

// Transitions state to Decimal mode (if valid)
- (void)handleDecimalPoint;

// Transitions state to Exponent mode
- (void)handleEE;

// Context-aware deletion of the last entry
- (void)handleBackspace;

// Toggles positive/negative for Mantissa or Exponent based on state
- (void)toggleSign;

// Resets the buffer to 0 (Clear Entry behavior)
- (void)performClearEntry;

// Converts the internal integer structures into a final double for the Node Stack
- (double)finalizeValue;

// Returns the string representation for the Calculator Display
- (NSString *)displayString;

@end

NS_ASSUME_NONNULL_END
