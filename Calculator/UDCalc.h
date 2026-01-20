//
//  UDCalc.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDOpRegistry.h"
#import "UDAST.h"        // The AST Nodes

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
    UDOpE,          // Constant e
    UDOpEE,         // Scientific Notation (Advanced)
    
    // --- ROW 5 (Hyperbolic & Misc) ---
    UDOpSinh,
    UDOpCosh,
    UDOpTanh,
    UDOpPi,         // Constant π
    UDOpRand,       // Random Number

    // --- SPECIAL ---
    UDOpParenLeft,  // (
    UDOpParenRight,  // )
};

@interface UDCalc : NSObject

// State
@property (assign, readonly) double currentValue;
@property (assign, readonly) BOOL typing;

// The "Forest" of trees.
// Usually holds just 1 item if the equation is done.
// Holds multiple items if we are in the middle of parsing (e.g. "5", "3").
@property (strong, readonly) NSMutableArray<UDASTNode *> *nodeStack;

// Core Actions
- (void)inputDigit:(double)digit;
- (void)inputDecimal;
- (void)inputNumber:(double)number;
- (void)performOperation:(UDOp)op;
- (void)reset;

// The "Run" Button
// Compiles the current AST and executes it on the VM.
- (double)evaluateCurrentExpression;

@end
