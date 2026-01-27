//
//  UDCalc.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import "UDCalc.h"
#import "UDCompiler.h"
#import "UDVM.h"

@interface UDCalc ()
@property (strong, readwrite) NSMutableArray<UDASTNode *> *nodeStack;
@property (strong) NSMutableArray<NSNumber *> *opStack;
@property (nonatomic, assign) BOOL expectingOperator;
@property (nonatomic, assign) BOOL shouldResetOnDigit;
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
    _isRadians = NO;
    _isTyping = NO;
    _expectingOperator = NO;
    _shouldResetOnDigit = NO;
    [self.inputBuffer performClearEntry];
}

- (void)performSoftReset {
    [self.nodeStack removeAllObjects];
    [self.opStack removeAllObjects];
    [self.inputBuffer performClearEntry];
    self.expectingOperator = NO;
    self.shouldResetOnDigit = NO;
    self.isTyping = NO;
}

#pragma mark - Input

- (void)flushBufferToStack {
    if (self.isTyping) {
        double val = [self.inputBuffer finalizeValue];
        [self.nodeStack addObject:[UDNumberNode value:val]];
        [self.inputBuffer performClearEntry];
        self.isTyping = NO;
    }
}

- (void)inputEE {
    [self.inputBuffer handleEE];
}

- (void)inputDigit:(double)digit {
    // 1. SOFT RESET (Start new calc after =, M+, M-)
    if (self.shouldResetOnDigit) {
        [self performSoftReset];
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
    self.isTyping = YES;
    [self.inputBuffer handleDecimalPoint];
    _expectingOperator = NO;
}

// Used for Constants (π, e) and MR
- (void)inputNumber:(double)number {
    if (self.shouldResetOnDigit) {
        [self performSoftReset];
    }
    
    // Constants and MR also trigger implicit multiplication (e.g. "2 PI" -> "2 * PI")
    if (!self.isTyping && self.expectingOperator) {
        [self.opStack addObject:@(UDOpMul)];
    }
    
    self.isTyping = YES;
    [self.inputBuffer loadConstant:number];
    _expectingOperator = YES;
}

- (void)performOperation:(UDOp)op {
    
    // -------------------------------------------------------------------------
    // CATEGORY 1: NEUTRAL OPS
    // -------------------------------------------------------------------------
    if (op == UDOpMC || op == UDOpNegate || op == UDOpRad || op == UDOpEE || op == UDOpMR) {
        switch (op) {
            case UDOpEE: [self inputEE]; break;
            case UDOpRad: self.isRadians = !self.isRadians; break;
            case UDOpMC: self.memoryRegister = 0; break;
            case UDOpNegate: [self.inputBuffer toggleSign]; break;
            case UDOpMR: [self inputNumber:self.memoryRegister]; break;
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
        } else {
            [self reset];
        }
        return;
    }

    // -------------------------------------------------------------------------
    // CATEGORY 3: TERMINATORS (=, M+, M-)
    // -------------------------------------------------------------------------
    if (op == UDOpEq || op == UDOpMAdd || op == UDOpMSub) {
        if (self.isTyping) [self flushBufferToStack];
        
        while (self.opStack.count > 0) {
            [self reduceOp];
        }
        
        double result = [self evaluateCurrentExpression];
        
        if (op == UDOpMAdd) {
            self.memoryRegister += result;
        } else if (op == UDOpMSub) {
            self.memoryRegister -= result;
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
        if (self.isTyping) [self flushBufferToStack];
        
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
    [self flushBufferToStack];

    // Sub-Category: Postfix (Factorial, Square, Percent)
    if (info.placement == UDOpPlacementPostfix) {
        [self buildNode:info];
        
        // Auto-evaluate for display
        double val = [self evaluateCurrentExpression];
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

#pragma mark - AST Construction & Exec

- (void)reduceOp {
    if (self.opStack.count == 0) return;
    UDOp op = [self.opStack.lastObject integerValue];
    [self.opStack removeLastObject];
    UDOpInfo *info = [[UDFrontend shared] infoForOp:op];
    [self buildNode:info];
}

-(void)buildNode:(UDOpInfo *)info {
    if (!info || !info.action) return;
    
    UDFrontendContext *context = [[UDFrontendContext alloc] init];
    context.nodeStack = self.nodeStack;
    context.pendingOp = UDOpNone;
    context.isRadians = self.isRadians;
    context.memoryValue = self.memoryRegister;
    
    UDASTNode *node = info.action(context);
    if (node) [self.nodeStack addObject:node];
}

- (double)evaluateCurrentExpression {
    if (self.nodeStack.count == 0) return 0.0;
    UDASTNode *root = [self.nodeStack lastObject];
    NSArray *bytecode = [UDCompiler compile:root];
    return [UDVM execute:bytecode];
}

- (double)currentInputValue {
    if (self.isTyping) return [self.inputBuffer finalizeValue];
    if (self.nodeStack.count > 0) return [self evaluateCurrentExpression];
    return 0;
}

- (NSString *)currentDisplayValue {
    return [NSString stringWithFormat:@"%.10g", [self currentInputValue]];
}

@end
