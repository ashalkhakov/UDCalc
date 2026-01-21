//
//  UDCalc.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDFrontend.h"
#import "UDAST.h"        // The AST Nodes

@interface UDCalc : NSObject

// State
@property (assign, readonly) double currentValue;
@property (assign, readonly) BOOL typing;

@property (nonatomic, assign) BOOL isRadians; // Toggled by 'Rad'
@property (nonatomic, assign) BOOL isEEActive; // Toggled by 'EE'
@property (nonatomic, assign) double memoryRegister; // The 'M' value

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
