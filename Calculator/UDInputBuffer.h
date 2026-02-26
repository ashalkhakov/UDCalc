//
//  UDInputBuffer.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 23.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDValue.h"

// Add to your UDBase enum if not already visible here
typedef NS_ENUM(NSInteger, UDBase) {
    UDBaseDec = 10,
    UDBaseHex = 16,
    UDBaseOct = 8,
    UDBaseBin = 2
};

NS_ASSUME_NONNULL_BEGIN

@interface UDInputBuffer : NSObject

// --- Properties (Exposed for debugging/UI if needed) ---
@property (nonatomic, assign, readonly) unsigned long long mantissaBuffer;
@property (nonatomic, assign, readonly) unsigned long long exponentBuffer;
@property (nonatomic, assign, readonly) NSInteger decimalShift;
@property (nonatomic, assign, readonly) BOOL inExponentMode;
@property (nonatomic, assign, readonly) BOOL isMantissaNegative;
@property (nonatomic, assign, readonly) BOOL isExponentNegative;
@property (nonatomic, assign, readonly) BOOL hasHitDecimal;

@property (nonatomic, assign) UDBase inputBase;
@property (nonatomic, assign) BOOL isIntegerMode; // If YES, ignores Decimal/EE logic

// --- Public Methods ---

// Force-loads a value (like Pi or Ans) by simulating user input
- (void)loadConstant:(UDValue)constant;

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
- (UDValue)finalizeValue;

// Returns the string representation for the Calculator Display
- (NSString *)displayStringWithThousandsSeparators:(BOOL)showThousandsSeparators;

@end

NS_ASSUME_NONNULL_END
