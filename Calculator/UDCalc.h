//
//  UDCalc.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <Foundation/Foundation.h>

// Shorter Enum names
typedef NS_ENUM(NSInteger, UDOp) {
    UDOpNone,
    UDOpAdd,
    UDOpSub,
    UDOpMul,
    UDOpDiv,
    UDOpEq,
    UDOpClear,
    UDOpPercent,
    UDOpNegate,

    // --- SCIENTIFIC EXTENSIONS ---
    UDOpSin, UDOpCos, UDOpTan,
    UDOpASin, UDOpACos, UDOpATan, // Inverse Trig
    UDOpSqrt, UDOpCbrt,           // Roots
    UDOpLog10, UDOpLn,            // Logarithms
    UDOpPow,                      // x to the power of y (Binary!)
    UDOpSquare, UDOpCube,         // x^2, x^3 (Unary)
    UDOpInvert,                   // 1/x
    UDOpFactorial                 // x!
};

@interface UDCalc : NSObject

// DATA STRUCTURES
// 1. The Numbers: [3, 5, 2]
@property (nonatomic, strong, readonly) NSMutableArray<NSNumber *> *valueStack;
// 2. The Pending Operators: [+, *]
@property (nonatomic, strong, readonly) NSMutableArray<NSNumber *> *opStack;

/**
 Contains a description if the last operation failed (e.g., "Error").
 Is nil if everything is fine.
 */
@property (nonatomic, readonly, strong) NSString *errorMessage;

// STATE
@property (nonatomic, assign) BOOL typing; // Is the user currently editing the top number?

// HELPERS
// Returns the top of the valueStack (or 0 if empty) for display
@property (nonatomic, assign) double currentValue;

// PUBLIC API
- (void)digit:(NSInteger)digit;
- (void)decimal; // Optional: Call this when '.' is pressed
- (void)operation:(UDOp)op;
- (void)reset;

@end
