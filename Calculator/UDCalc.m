//
//  UDCalc.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import "UDCalc.h"
#import "UDCompiler.h"
#import "UDVM.h"
#import "UDValueFormatter.h"

@interface UDCalc ()
@property (strong, readwrite) NSMutableArray<UDASTNode *> *nodeStack;
@property (strong) NSMutableArray<NSNumber *> *opStack;
@property (nonatomic, assign) BOOL expectingOperator;
@property (nonatomic, assign) BOOL shouldResetOnDigit;
@property (nonatomic, assign) BOOL shouldPushOnDigit;
@end

@implementation UDCalc

- (instancetype)init {
    self = [super init];
    if (self) {
        self.inputBuffer = [[UDInputBuffer alloc] init];
        [self reset];
    }
    return self;
}

- (void)reset {
    _nodeStack = [NSMutableArray array];
    _opStack = [NSMutableArray array];
    _isRadians = YES;
    _isTyping = NO;
    _expectingOperator = NO;
    _shouldResetOnDigit = NO;
    _shouldPushOnDigit = NO;
    _encodingMode = UDCalcEncodingModeNone;
    [self.inputBuffer performClearEntry];
}

- (void)performSoftReset {
    if (!self.isRPNMode) {
        [self.nodeStack removeAllObjects];
        [self.opStack removeAllObjects];
    }
    [self.inputBuffer performClearEntry];
    self.expectingOperator = NO;
    self.shouldResetOnDigit = NO;
    self.shouldPushOnDigit = NO;
    self.isTyping = NO;
}

#pragma mark - Input

- (void)setMode:(UDCalcMode)newMode {
    _mode = newMode;
    if (_mode == UDCalcModeProgrammer) {
        self.inputBuffer.isIntegerMode = YES;
    } else {
        self.inputBuffer.isIntegerMode = NO;
    }
}

- (UDBase)inputBase {
    return self.inputBuffer.inputBase;
}

- (void)setInputBase:(UDBase)newBase {
    self.inputBuffer.inputBase = newBase;
}

- (void)flushBufferToStack {
    if (!self.isTyping) {
        return;
    }

    UDValue val = [self.inputBuffer finalizeValue];
    [self.nodeStack addObject:[UDNumberNode value:val]];
    [self.inputBuffer performClearEntry];
    self.isTyping = NO;
}

- (void)moveBufferToStack {
    if (self.isTyping) {
        UDValue val = [self.inputBuffer finalizeValue];
        [self.nodeStack addObject:[UDNumberNode value:val]];
    }
}

// put whatever is now on top of stack onto the input buffer
- (void)moveStackToBuffer:(BOOL)pushOnDigit {
    if (self.nodeStack.count > 0) {
        UDASTNode *topNode = self.nodeStack.lastObject;
        [self.nodeStack removeLastObject];

        UDValue val = [self evaluateNode:topNode];
        [self.inputBuffer loadConstant:val];
        self.isTyping = YES;
        self.expectingOperator = YES;
        self.shouldPushOnDigit = pushOnDigit;
        self.shouldResetOnDigit = YES;
    }
}

- (void)inputEE {
    [self.inputBuffer handleEE];
}

- (void)inputDigit:(NSInteger)digit {
    // 1. SOFT RESET (Start new calc after =, M+, M-)
    if (self.shouldResetOnDigit) {
        [self performSoftReset];
    }
    if (self.shouldPushOnDigit) {
        [self flushBufferToStack];
        self.shouldPushOnDigit = NO;
    }

    // 2. IMPLICIT MULTIPLICATION (Bridging: "3! 2", ") 2")
    if (!self.isTyping && self.expectingOperator) {
        [self.opStack addObject:@(UDOpMul)];
    }

    self.isTyping = YES;
    [self.inputBuffer handleDigit:(int)digit];
    
    // We have a digit, so next we expect an operator.
    self.expectingOperator = YES;
}

- (void)inputDecimal {
    if (self.shouldResetOnDigit) {
        [self performSoftReset];
    }
    if (self.shouldPushOnDigit) {
        [self flushBufferToStack];
        self.shouldPushOnDigit = NO;
    }

    self.isTyping = YES;
    [self.inputBuffer handleDecimalPoint];
    _expectingOperator = NO;
}

// Used for Constants (π, e) and MR
- (void)inputNumber:(UDValue)number {
    if (self.shouldResetOnDigit) {
        [self performSoftReset];
    }
    if (self.shouldPushOnDigit) {
        [self flushBufferToStack];
        self.shouldPushOnDigit = NO;
    }
    
    // Constants and MR also trigger implicit multiplication (e.g. "2 PI" -> "2 * PI")
    if (!self.isTyping && self.expectingOperator) {
        [self.opStack addObject:@(UDOpMul)];
    }
    
    self.isTyping = YES;
    [self.inputBuffer loadConstant:number];
    _expectingOperator = YES;
}

- (void)performOperationShuntingYard:(UDOp)op {
    // -------------------------------------------------------------------------
    // CATEGORY 3: TERMINATORS (=, M+, M-)
    // -------------------------------------------------------------------------
    if (op == UDOpEq || op == UDOpMAdd || op == UDOpMSub) {
        [self flushBufferToStack];
        
        while (self.opStack.count > 0) {
            [self reduceOp];
        }
        
        UDValue result = [self evaluateCurrentExpression];
        double resultDouble = UDValueAsDouble(result);
        
        if (op == UDOpMAdd) {
            self.memoryRegister += resultDouble;
        } else if (op == UDOpMSub) {
            self.memoryRegister -= resultDouble;
        }
        
        // Reload result so "Ans + 2" works
        [self.inputBuffer loadConstant:result];
        self.isTyping = NO; // do NOT  treat result as if user typed it
        
        self.expectingOperator = YES;
        self.shouldResetOnDigit = YES; // If they type a number now, clear Ans
        return;
    }
    

    // -------------------------------------------------------------------------
    // CATEGORY 4: CONSTRUCTIVE OPS
    // -------------------------------------------------------------------------
    self.shouldResetOnDigit = NO;

    // --- LEFT PARENTHESIS ---
    if (op == UDOpParenLeft) {
        [self flushBufferToStack];
        
        // Implicit Multiply: "2 (" -> "2 * ("
        if (self.expectingOperator) {
            [self.opStack addObject:@(UDOpMul)];
        }
        
        [self.opStack addObject:@(op)];
        self.expectingOperator = NO; // We now expect a Number, not an Op
        return;
    }

    // --- RIGHT PARENTHESIS ---
    if (op == UDOpParenRight) {
        [self flushBufferToStack];
        while (self.opStack.count > 0) {
            UDOp top = [self.opStack.lastObject integerValue];
            if (top == UDOpParenLeft) {
                [self.opStack removeLastObject]; // Pop '('
                
                // Wrap content in ParenNode
                if (self.nodeStack.count > 0) {
                    UDASTNode *content = [self.nodeStack lastObject];
                    [self.nodeStack removeLastObject];
                    [self.nodeStack addObject:[UDParenNode wrap:content]];
                }
                
                self.expectingOperator = YES; // Group is a value
                return;
            }
            [self reduceOp];
        }
        return; // Mismatched parens
    }

    // --- POSTFIX & BINARY (INFIX) ---
    UDOpInfo *info = [[UDFrontend shared] infoForOp:op];

    // Capture typing state BEFORE flushing
    BOOL wasTyping = self.isTyping;
    [self moveBufferToStack];

    // Sub-Category: Postfix (Factorial, Square, Percent)
    if (info.placement == UDOpPlacementPostfix) {
        if (self.nodeStack.count == 0) {
            [self.nodeStack addObject:[UDNumberNode value:UDValueMakeDouble(0.0)]];
        }
        [self buildNode:info];
        
        // Auto-evaluate for display
        UDValue val = [self evaluateCurrentExpression];
        [self.inputBuffer loadConstant:val];
        self.isTyping = NO;
        
        self.expectingOperator = YES;
        return;
    }
    
    // Sub-Category: Standard Binary Logic (Infix)

    // SMART GUARD CLAUSE
    // If we are NOT expecting an operator, generally we should ignore this input.
    // EXCEPT when we want to REPLACE the previous operator.
    if (info.placement == UDOpPlacementInfix && !self.expectingOperator) {
        
        // Check what is currently on top of the stack
        BOOL canReplace = NO;
        if (self.opStack.count > 0) {
            UDOp topOp = [self.opStack.lastObject integerValue];
            
            // If the top is NOT a parenthesis, it is an operator we can potentially replace.
            // Example: stack has "+", user types "*". We allow this to pass through to the replacement logic.
            if (topOp != UDOpParenLeft) {
                canReplace = YES;
            }
        }
        
        // If we can't replace (e.g., stack empty, or top is '('), ignore this input.
        if (!canReplace) {
            return;
        }
    }

    // REPLACEMENT LOGIC
    // Scenario: User types "2 *" (Stack: *) then changes mind to "+".
    // "wasTyping" is NO because they haven't typed a number in between.
    if (!wasTyping && self.opStack.count > 0) {
        UDOp topOp = [self.opStack.lastObject integerValue];
        UDOpInfo *topInfo = [[UDFrontend shared] infoForOp:topOp];
        
        // Only replace INFIX operators (don't delete parens!)
        if (topOp != UDOpParenLeft &&
            topInfo.placement == UDOpPlacementInfix &&
            info.placement == UDOpPlacementInfix) {
            
            [self.opStack removeLastObject];
        }
    }
    
    // 3. PRECEDENCE LOOP
    NSInteger myPrec = info.precedence;
    while (self.opStack.count > 0) {
        UDOp topOp = [self.opStack.lastObject integerValue];
        if (topOp == UDOpParenLeft) break;
        
        UDOpInfo *topInfo = [[UDFrontend shared] infoForOp:topOp];
        if (topInfo.precedence >= myPrec) {
            [self reduceOp];
        } else {
            break;
        }
    }
    
    // 4. PUSH NEW OP
    [self.opStack addObject:@(op)];
    [self.inputBuffer performClearEntry];
    
    self.isTyping = NO;
    self.expectingOperator = NO; // After "+", we expect a Number
}

- (void)performOperationRPN:(UDOp)op {
    // -------------------------------------------------------------------------
    // CATEGORY 1: STACK MANIPULATION OPS
    // -------------------------------------------------------------------------

    // ENTER (Commit or Duplicate)
    if (op == UDOpEnter) {
        
        // Case 1: Committing user input
        // User types "5" -> Buffer has "5"
        // User hits Enter -> Stack gets Node(5), Buffer clears.
        if (self.isTyping) {
            [self moveBufferToStack];
            self.shouldResetOnDigit = YES; // If they type a number now, clear Ans
            return;
        }
        
        // Case 2: Duplicating X (Standard HP behavior)
        // User hits Enter again -> Stack gets another copy of Top.
        // Stack: [5] -> [5, 5]
        if (self.nodeStack.count > 0) {
            UDASTNode *topNode = [self.nodeStack lastObject];
            
            // IMPORTANT: Create a COPY of the node.
            // If nodes are shared pointers, modifying one might affect the other
            // in complex operations. If your nodes assume immutability,
            // sharing the pointer is fine, but copy is safer.
            UDASTNode *newNode;
            if ([topNode conformsToProtocol:@protocol(NSCopying)]) {
                newNode = [topNode copy];
            } else {
                // Fallback if NSCopying isn't implemented (Assuming immutable number node)
                // Ideally, implement NSCopying on UDASTNode subclasses.
                newNode = topNode;
            }
            
            [self.nodeStack addObject:newNode];
            self.shouldResetOnDigit = YES; // If they type a number now, clear Ans
            return;
        }
        
        // duplicate a zero
        [self.nodeStack addObject:[UDNumberNode value:UDValueMakeDouble(0.0)]];
        return;
    }

    // DROP (Pop X)
    if (op == UDOpDrop) {
        [self flushBufferToStack];

        // Remove the X register (Top of stack)
        if (self.nodeStack.count > 0) {
            [self.nodeStack removeLastObject];
        }

        [self moveStackToBuffer:NO];
        return;
    }

    // SWAP (X <-> Y)
    if (op == UDOpSwap) {
        [self flushBufferToStack];

        if (self.nodeStack.count >= 2) {
            NSInteger count = self.nodeStack.count;
            [self.nodeStack exchangeObjectAtIndex:(count - 1)
                                withObjectAtIndex:(count - 2)];
            
            [self moveStackToBuffer:NO];
        }
        return;
    }
    
    // ROLL DOWN (X moves to Top/History)
    // [A, B, C, D] -> [D, A, B, C]
    if (op == UDOpRollDown) {
        [self flushBufferToStack];
        
        if (self.nodeStack.count > 1) {
            // Take X (Last)
            UDASTNode *xNode = [self.nodeStack lastObject];
            // Remove it
            [self.nodeStack removeLastObject];
            // Insert it at Bottom (Index 0)
            [self.nodeStack insertObject:xNode atIndex:0];
            
            [self moveStackToBuffer:NO];
        }
        return;
    }

    // ROLL UP (Top/History moves to X)
    // [A, B, C, D] -> [B, C, D, A]
    if (op == UDOpRollUp) {
        [self flushBufferToStack];
        
        if (self.nodeStack.count > 1) {
            // Take Top (Index 0)
            UDASTNode *topNode = [self.nodeStack objectAtIndex:0];
            // Remove it
            [self.nodeStack removeObjectAtIndex:0];
            // Add to X (End)
            [self.nodeStack addObject:topNode];

            [self moveStackToBuffer:NO];
        }
        return;
    }
    
    // -------------------------------------------------------------------------
    // CATEGORY 2: CONSTRUCTIVE OPS
    // -------------------------------------------------------------------------

    UDOpInfo *info = [[UDFrontend shared] infoForOp:op];

    // -------------------------------------------------------------------------
    // CASE 1: BINARY OPERATORS (+, -, *, /, ^)
    // Needs 2 operands. Consumes them, pushes result.
    // -------------------------------------------------------------------------
    if (info.placement == UDOpPlacementInfix) {
        
        // Safety Check (Stack Underflow)
        if (self.nodeStack.count == 0) {
            // Optional: Blink display or beep
            return;
        }

        // Implicit Enter: "3 Enter 4 +" -> "+" acts as Enter for "4" first.
        if (!self.isTyping) {
            [self.nodeStack addObject:[UDNumberNode value:UDValueMakeDouble(0.0)]];
        } else {
            [self flushBufferToStack];
        }

        [self buildNode:info];

        [self reportCalculationResult];

        // Auto-evaluate for display
        [self moveStackToBuffer:YES];
        return;
    }

    // -------------------------------------------------------------------------
    // CASE 2: UNARY / POSTFIX / FUNCTION (sin, cos, !, √)
    // Needs 1 operand. Consumes it, pushes result.
    // -------------------------------------------------------------------------

        
    // 1. Implicit Enter
    if (!self.isTyping) {
        [self.nodeStack addObject:[UDNumberNode value:UDValueMakeDouble(0.0)]];
    } else {
        [self flushBufferToStack];
    }
        
    // 2. Safety Check
    if (self.nodeStack.count < 1) {
        return;
    }
    
    [self buildNode:info];
    
    [self reportCalculationResult];
    // Auto-evaluate for display
    [self moveStackToBuffer:YES];
}

- (void)performOperation:(UDOp)op {
    
    // -------------------------------------------------------------------------
    // CATEGORY 1: NEUTRAL OPS
    // -------------------------------------------------------------------------
    if (op == UDOpMC || op == UDOpNegate || op == UDOpRad || op == UDOpEE || op == UDOpMR) {
        switch (op) {
            case UDOpEE: [self inputEE]; break;
            case UDOpRad: self.isRadians = !self.isRadians; break;
            case UDOpMC: self.memoryRegister = 0.0; break;
            case UDOpNegate: [self.inputBuffer toggleSign]; break;
            case UDOpMR: [self inputNumber:UDValueMakeDouble(self.memoryRegister)]; break;
            default: break;
        }
        return;
    }
    
    // -------------------------------------------------------------------------
    // CATEGORY 2: CLEAR OPS
    // -------------------------------------------------------------------------
    if (op == UDOpClear) {
        if (self.isTyping) {
            [self.inputBuffer performClearEntry];
            self.isTyping = NO;
        } else {
            [self reset];
        }
        return;
    }

    if (self.isRPNMode) {
        [self performOperationRPN:op];
    } else {
        [self performOperationShuntingYard:op];

        if (op == UDOpEq) {
            [self reportCalculationResult];
        }
    }
}

- (void)reportCalculationResult {
    if ([self.delegate respondsToSelector:@selector(calculator:didCalculateResult:forTree:)]) {
        UDASTNode *resultTree = [self.nodeStack lastObject];

        UDValue val = [self evaluateCurrentExpression];
        
        [self.delegate calculator:self didCalculateResult:val forTree:resultTree];
    }
}

#pragma mark - AST Construction & Exec

- (void)reduceOp {
    if (self.opStack.count == 0) return;
    UDOp op = [self.opStack.lastObject integerValue];
    [self.opStack removeLastObject];
    UDOpInfo *info = [[UDFrontend shared] infoForOp:op];
    [self buildNode:info];
}

-(UDASTNode *)createNode:(UDOpInfo *)info {
    if (!info || !info.action) return nil;
    
    UDFrontendContext *context = [[UDFrontendContext alloc] init];
    context.nodeStack = self.nodeStack;
    context.pendingOp = UDOpNone;
    context.isRadians = self.isRadians;
    context.memoryValue = self.memoryRegister;
    
    UDASTNode *node = info.action(context);
    return node;
}

-(void)buildNode:(UDOpInfo *)info {
    UDASTNode *node = [self createNode:info];
    if (node) [self.nodeStack addObject:node];
}

- (UDValue)evaluateNode:(UDASTNode *)node {
    NSArray *bytecode = [UDCompiler compile:node withIntegerMode:self.inputBuffer.isIntegerMode];
    return [UDVM execute:bytecode];
}

- (UDValue)evaluateCurrentExpression {
    if (self.nodeStack.count == 0) return UDValueMakeDouble(0.0);
    UDASTNode *root = [self.nodeStack lastObject];
    return [self evaluateNode:root];
}

- (UDValue)currentInputValue {
    if (self.isTyping) return [self.inputBuffer finalizeValue];
    if (self.nodeStack.count > 0) return [self evaluateCurrentExpression];
    return UDValueMakeDouble(0.0);
}

- (NSString *)currentDisplayValue {
    return [self stringForValue:[self currentInputValue]];
}

- (NSArray<UDNumberNode *> *)currentStackValues {
    NSMutableArray<UDNumberNode *> *values = [NSMutableArray array];
    
    // Iterate through the entire node stack
    for (UDASTNode *node in self.nodeStack) {
        // Resolve the tree (e.g., "3 + 5") into a number (8.0)
        UDValue val = [self evaluateNode:node];
        [values addObject:[UDNumberNode value:val]];
    }

    if (self.isTyping) {
        [values addObject:[UDNumberNode value:[self.inputBuffer finalizeValue]]];
    } else {
        [values addObject:[UDNumberNode value:UDValueMakeDouble(0.0)]];
    }

    return [values copy];
}

- (NSString *)stringForValue:(UDValue)value {
    return [self.inputBuffer stringForValue:value];
}

- (NSString *)currentValueEncoded {
    switch (_encodingMode) {
        case UDCalcEncodingModeNone:
            return @"";
        case UDCalcEncodingModeASCII: {
            unsigned long long val = UDValueAsInt([self currentInputValue]);

            // ASCII is valid from 32 (Space) to 126 (~).
            // We can optionally show extended ASCII (128-255) if desired.
            if (val >= 32 && val <= 126) {
                return [NSString stringWithFormat:@"%c", (char)val];
            } else if (val < 32) {
                return @"·"; // Control char placeholder
            } else {
                return @""; // Out of bounds
            }
        }
        case UDCalcEncodingModeUnicode: {
            unsigned long long val = UDValueAsInt([self currentInputValue]);

            // Check for valid Unicode range (ignoring surrogates for simplicity)
            if (val <= 0x10FFFF) {
                // Convert uint32 to NSString
                uint32_t c = (uint32_t)val;
                return [[NSString alloc] initWithBytes:&c length:4 encoding:NSUTF32LittleEndianStringEncoding];
            } else {
                return @"";
            }
        }
        default:
            NSLog(@"Unknown encoding value %@", @(_encodingMode));
            return @"";
    }
}

@end
