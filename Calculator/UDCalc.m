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
    // Do not affect calculation flow or reset state flags.
    // -------------------------------------------------------------------------
    if (op == UDOpMC || op == UDOpNegate || op == UDOpRad || op == UDOpEE || op == UDOpMR) {
        switch (op) {
            case UDOpEE: [self inputEE]; break;
            case UDOpRad: self.isRadians = !self.isRadians; break;
            case UDOpMC: self.memoryRegister = 0; break;
            case UDOpNegate: [self.inputBuffer toggleSign]; break;
            case UDOpMR: [self inputNumber:self.memoryRegister]; break; // Routes to inputNumber
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
            // 'C' does not reset the parser state logic, just the current buffer
        } else {
            [self reset];
        }
        return;
    }

    // -------------------------------------------------------------------------
    // CATEGORY 3: TERMINATORS (=, M+, M-)
    // Calculate result, STORE IT, then flag for "Soft Reset".
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
        
        // CRITICAL: Reload result into buffer so calculator stays "alive".
        // Allows "Ans + 2" (Continues) or "Ans 2" (Resets).
        [self.inputBuffer loadConstant:result];
        self.isTyping = YES;
        
        self.expectingOperator = YES;
        self.shouldResetOnDigit = YES;
        return;
    }
    
    // -------------------------------------------------------------------------
    // CATEGORY 4: CONSTRUCTIVE OPS
    // Any other operator means we are continuing the calculation.
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
        self.expectingOperator = NO;
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
                
                // Group is a Value. Next input is operator.
                self.expectingOperator = YES;
                return;
            }
            [self reduceOp];
        }
        // If loop exits, we have mismatched parens (ignore or error)
        return;
    }

    // --- POSTFIX & BINARY (INFIX) ---
    UDOpInfo *info = [[UDFrontend shared] infoForOp:op];

    // Capture typing state BEFORE flushing!
    // We need to know if the user JUST finished typing a number (like "3")
    // or if they are chaining operators (like "+ *").
    BOOL wasTyping = self.isTyping;
    [self flushBufferToStack];

    // Sub-Category: Postfix (Factorial, Square, Percent)
    if (info.placement == UDOpPlacementPostfix) {
        [self buildNode:info];
        
        // Auto-evaluate for display
        double val = [self evaluateCurrentExpression];
        [self.inputBuffer loadConstant:val];
        self.isTyping = NO;
        
        // Postfix result is a Value. "3! *" is valid.
        self.expectingOperator = YES;
        return;
    }
    
    // Sub-Category: Standard Binary Logic (Infix)
    
    // 1. REPLACEMENT CHECK (Must happen BEFORE reduction)
    // Scenario: User types "2 *" then changes mind to "+".
    // We must swap * for + immediately.
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
    
    // 2. PRECEDENCE LOOP
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
    
    // 3. PUSH NEW OP
    [self.opStack addObject:@(op)];
    [self.inputBuffer performClearEntry];
    self.isTyping = NO;
    self.expectingOperator = NO;
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
