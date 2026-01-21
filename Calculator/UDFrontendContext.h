//
//  UDElaborationContext.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 20.01.2026.
//

#import <Foundation/Foundation.h>

@class UDASTNode;

// Shorter Enum names
typedef NS_ENUM(NSInteger, UDOp) {
    UDOpNone = 0,
    UDOpAdd = 1,
    UDOpSub,
    UDOpMul,
    UDOpDiv,
    UDOpEq,
    UDOpClear,
    UDOpPercent,
    UDOpNegate,

    // --- ROW 2 (Powers) ---
    UDOpSquare,     // x^2
    UDOpCube,       // x^3
    UDOpPow,        // x^y (Binary)
    UDOpExp,        // e^x
    UDOpPow10,      // 10^x
    UDOpPow2,       // 2^x
    
    // --- ROW 3 (Roots & Logs) ---
    UDOpInvert,     // 1/x
    UDOpSqrt,       // sqrt x
    UDOpCbrt,       // cbrt x
    UDOpYRoot,      // root(x, y) (Binary)
    UDOpLn,         // ln
    UDOpLog10,      // log 10
    
    // --- ROW 4 (Trig) ---
    UDOpFactorial,  // x!
    UDOpSin,
    UDOpCos,
    UDOpTan,
    UDOpConstE,     // Constant e
    UDOpEE,         // Scientific Notation (Advanced)
    
    // --- ROW 5 (Hyperbolic & Misc) ---
    UDOpSinh,
    UDOpCosh,
    UDOpTanh,
    UDOpConstPi,    // Constant π
    UDOpRand,       // Random Number
    UDOpRad,        // Rad/Deg Switch
    
    // Memory
    UDOpMR,
    UDOpMC,
    UDOpMAdd,
    UDOpMSub,

    // --- SPECIAL ---
    UDOpParenLeft,  // (
    UDOpParenRight,  // )
};

@interface UDFrontendContext : NSObject
// The current piles of blocks
@property (nonatomic, strong) NSMutableArray<UDASTNode *> *nodeStack;
@property (nonatomic, assign) UDOp pendingOp;

// The Machine Settings (Snapshots)
@property (nonatomic, assign) BOOL isRadians;
@property (nonatomic, assign) double memoryValue; // For MR
@end
