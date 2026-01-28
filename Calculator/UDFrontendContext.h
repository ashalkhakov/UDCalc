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
    UDOpSub = 2,
    UDOpMul = 3,
    UDOpDiv = 4,
    UDOpEq = 5,
    UDOpClear = 6,
    UDOpPercent = 7,
    UDOpNegate = 8,

    // --- ROW 2 (Powers) ---
    UDOpSquare = 9,     // x^2
    UDOpCube = 10,      // x^3
    UDOpPow = 11,       // x^y (Binary)
    UDOpPowRev = 12,    // y^x (Binary)
    UDOpExp = 13,       // e^x
    UDOpPow10 = 14,     // 10^x
    UDOpPow2 = 15,      // 2^x
    
    // --- ROW 3 (Roots & Logs) ---
    UDOpInvert = 16,   // 1/x
    UDOpSqrt = 17,     // sqrt x
    UDOpCbrt = 18,     // cbrt x
    UDOpYRoot = 19,    // root(x, y) (Binary)
    UDOpLn = 20,       // ln
    UDOpLog10 = 21,    // log 10
    UDOpLog2 = 22,     // log 2
    UDOpLogY = 23,     // log y(x)
    
    // --- ROW 4 (Trig) ---
    UDOpFactorial = 24,  // x!
    UDOpSin = 25,
    UDOpSinInverse = 26,
    UDOpCos = 27,
    UDOpCosInverse = 28,
    UDOpTan = 29,
    UDOpTanInverse = 30,
    UDOpConstE = 31,     // Constant e
    UDOpEE = 32,         // Scientific Notation (Advanced)
    
    // --- ROW 5 (Hyperbolic & Misc) ---
    UDOpSinh = 33,
    UDOpSinhInverse = 34,
    UDOpCosh = 35,
    UDOpCoshInverse = 36,
    UDOpTanh = 37,
    UDOpTanhInverse = 38,
    UDOpConstPi = 39,    // Constant π
    UDOpRand = 40,       // Random Number
    UDOpRad = 41,        // Rad/Deg Switch
    
    // Memory
    UDOpMR = 42,
    UDOpMC = 43,
    UDOpMAdd = 44,
    UDOpMSub = 45,

    // --- SPECIAL ---
    UDOpParenLeft = 46,  // (
    UDOpParenRight = 47,  // )
    
    // --- RPN ---
    UDOpEnter = 48,
    UDOpSwap = 49,
    UDOpDrop = 50,
    UDOpRollDown = 51,
    UDOpRollUp = 52
};

@interface UDFrontendContext : NSObject
// The current piles of blocks
@property (nonatomic, strong) NSMutableArray<UDASTNode *> *nodeStack;
@property (nonatomic, assign) UDOp pendingOp;

// The Machine Settings (Snapshots)
@property (nonatomic, assign) BOOL isRadians;
@property (nonatomic, assign) double memoryValue; // For MR
@end
