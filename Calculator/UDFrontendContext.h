//
//  UDElaborationContext.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 20.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDValue.h"

@class UDASTNode;

// Shorter Enum names
typedef NS_ENUM(NSInteger, UDOp) {
    UDOpNone        = -1,

    // Digits
    UDOpDigit0      = 0,
    UDOpDigit9      = 9,
    UDOpDigitA      = 10,
    UDOpDigitF      = 15,
    UDOpDigitFF     = 16,
    UDOpDigit00     = 17,

    // Basic Ops
    UDOpAdd         = 21,
    UDOpSub         = 22,
    UDOpMul         = 23,
    UDOpDiv         = 24,
    UDOpEq          = 25,
    UDOpClear       = 26,
    UDOpPercent     = 27,
    UDOpNegate      = 28,
    UDOpDecimal     = 29,

    // --- ROW 2 (Powers) ---
    UDOpSquare      = 31,       // x^2
    UDOpCube        = 32,       // x^3
    UDOpPow         = 33,       // x^y (Binary)
    UDOpPowRev      = 34,       // y^x (Binary)
    UDOpExp         = 35,       // e^x
    UDOpPow10       = 36,       // 10^x
    UDOpPow2        = 37,       // 2^x
    
    // --- ROW 3 (Roots & Logs) ---
    UDOpInvert      = 41,       // 1/x
    UDOpSqrt        = 42,       // sqrt x
    UDOpCbrt        = 43,       // cbrt x
    UDOpYRoot       = 44,       // root(x, y) (Binary)
    UDOpLn          = 45,       // ln
    UDOpLog10       = 46,       // log 10
    UDOpLog2        = 47,       // log 2
    UDOpLogY        = 48,       // log y(x)
    
    // --- ROW 4 (Trig) ---
    UDOpFactorial   = 51,       // x!
    UDOpSin         = 52,
    UDOpSinInverse  = 53,
    UDOpCos         = 54,
    UDOpCosInverse  = 55,
    UDOpTan         = 56,
    UDOpTanInverse  = 57,
    UDOpConstE      = 58,       // Constant e
    UDOpEE          = 59,       // Scientific Notation (Advanced)
    
    // --- ROW 5 (Hyperbolic & Misc) ---
    UDOpSinh        = 61,
    UDOpSinhInverse = 62,
    UDOpCosh        = 63,
    UDOpCoshInverse = 64,
    UDOpTanh        = 65,
    UDOpTanhInverse = 66,
    UDOpConstPi     = 67,       // Constant π
    UDOpRand        = 68,       // Random Number
    UDOpRad         = 69,       // Rad/Deg Switch
    
    // Memory
    UDOpMR          = 71,
    UDOpMC          = 72,
    UDOpMAdd        = 73,
    UDOpMSub        = 74,

    // --- SPECIAL ---
    UDOpParenLeft   = 81,  // (
    UDOpParenRight  = 82,  // )
    UDOpSecondFunc  = 83,

    // --- RPN ---
    UDOpEnter       = 91,
    UDOpSwap        = 92,
    UDOpDrop        = 93,
    UDOpRollDown    = 94,
    UDOpRollUp      = 95,
    
    // --- Programmer ---
    UDOpBitwiseAnd  = 101,
    UDOpBitwiseOr   = 102,
    UDOpBitwiseNor  = 103,
    UDOpBitwiseXor  = 104,
    UDOpShift1Left  = 105,
    UDOpShift1Right = 106,
    UDOpShiftLeft   = 107,
    UDOpShiftRight  = 108,
    
    UDOpByteFlip    = 111,
    UDOpWordFlip    = 112,
    UDOpRotateLeft  = 113,
    UDOpRotateRight = 114,
    UDOpComp2       = 115,
    UDOpComp1       = 116
};

@interface UDFrontendContext : NSObject
// The current piles of blocks
@property (nonatomic, strong) NSMutableArray<UDASTNode *> *nodeStack;
@property (nonatomic, assign) UDOp pendingOp;

// The Machine Settings (Snapshots)
@property (nonatomic, assign) BOOL isRadians;
@property (nonatomic, assign) double memoryValue; // For MR
@end
