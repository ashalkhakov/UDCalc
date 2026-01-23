//
//  UDCalc.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDFrontend.h"
#import "UDAST.h"        // The AST Nodes
#import "UDInputBuffer.h"

@interface UDCalc : NSObject

// State
@property (nonatomic, strong) UDInputBuffer *inputBuffer;
@property (nonatomic, assign) BOOL isRadians;
@property (nonatomic, assign) double memoryRegister; // The 'M' value
// YES = User is editing the buffer.
// NO = User just hit an Op/Equals, buffer is "fresh".
@property (nonatomic, assign) BOOL isTyping;

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

// Returns what should currently be on screen (Buffer string OR Result string)
- (double)currentInputValue;
- (NSString *)currentDisplayValue;

// The "Run" Button
// Compiles the current AST and executes it on the VM.
- (double)evaluateCurrentExpression;

@end
