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

@class UDCalc;

@protocol UDCalcDelegate <NSObject>
@optional
- (void)calculator:(UDCalc *)calc didCalculateResult:(UDValue)result forTree:(UDASTNode *)tree;
@end

@interface UDCalc : NSObject

// State
@property (nonatomic, weak) id<UDCalcDelegate> delegate;
@property (nonatomic, strong) UDInputBuffer *inputBuffer;
@property (nonatomic, assign) BOOL isRadians;
@property (nonatomic, assign) BOOL isRPNMode;
@property (nonatomic, assign) BOOL isIntegerMode;
@property (nonatomic, assign) double memoryRegister; // The 'M' value
// YES = User is editing the buffer.
// NO = User just hit an Op/Equals, buffer is "fresh".
@property (nonatomic, assign) BOOL isTyping;

// The "Forest" of trees.
// Usually holds just 1 item if the equation is done.
// Holds multiple items if we are in the middle of parsing (e.g. "5", "3").
@property (strong, readonly) NSMutableArray<UDASTNode *> *nodeStack;

// Core Actions
- (void)inputDigit:(NSInteger)digit;
- (void)inputDecimal;
- (void)inputNumber:(UDValue)number;
- (void)performOperation:(UDOp)op;
- (void)reset;

// Returns what should currently be on screen (Buffer string OR Result string)
- (UDValue)currentInputValue;
- (NSString *)currentDisplayValue;
- (NSArray<UDNumberNode *> *)currentStackValues; // Returns evaluated numbers for X, Y, Z...

// The "Run" Button
// Compiles the current AST and executes it on the VM.
- (UDValue)evaluateNode:(UDASTNode *)node;
- (UDValue)evaluateCurrentExpression;

@end
