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
@property (nonatomic, assign) UDSYState syState;
@end

@implementation UDCalc

- (instancetype)init {
    self = [super init];
    if (self) {
        self.inputBuffer = [[UDInputBuffer alloc] init];
        _isRadians = YES;
        _encodingMode = UDCalcEncodingModeNone;
        [self reset];
    }
    return self;
}

- (void)reset {
    _nodeStack = [NSMutableArray array];
    _opStack = [NSMutableArray array];
    _isTyping = NO;
    _syState = UDSYStateIdle;
    [self.inputBuffer performClearEntry];
}

- (void)performSoftReset {
    if (!self.isRPNMode) {
        [self.nodeStack removeAllObjects];
        [self.opStack removeAllObjects];
    }
    [self.inputBuffer performClearEntry];
    self.syState  = UDSYStateIdle;
    self.isTyping = NO;
}

#pragma mark - Computed helpers (replace individual bool checks)

/// True when the parser just finished a value (number, constant, ), postfix)
- (BOOL)sy_hasValue {
    return self.syState == UDSYStateAfterValue
        || self.syState == UDSYStateAfterResult;
}

/// True when a new digit/constant should implicit-multiply
- (BOOL)sy_shouldImplicitMultiply {
    return self.syState == UDSYStateAfterValue
        || self.syState == UDSYStateAfterResult
        || self.syState == UDSYStateTypingNumber;  // ← add this
}

// Helper: update display to show current X without touching the stack
- (void)sy_refreshDisplayFromStack {
    if (self.nodeStack.count > 0) {
        UDValue val = [self evaluateNode:self.nodeStack.lastObject];
        [self.inputBuffer performClearEntry];
        [self.inputBuffer loadConstant:val];
        self.isTyping = NO;   // ← display only, NOT a typing event
        self.syState = UDSYStateAfterValue;
    } else {
        [self.inputBuffer performClearEntry];
        self.isTyping = NO;
        self.syState = UDSYStateIdle;
    }
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
        self.isTyping = NO;   // ← buffer is committed, no longer live
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

        // pushOnDigit=YES  -> RPN result: next digit replaces, next op pushes first
        // pushOnDigit=NO   -> just showing a value (DROP/SWAP/ROLL), treat as AfterValue
        if (pushOnDigit) {
            self.syState = UDSYStateRPNResult;
        } else {
            self.syState = UDSYStateAfterValue;
            // expectingOperator was YES in the old code for this path,
            // AfterValue carries that meaning in the FSM.
        }
    }
}

- (void)inputEE {
    [self.inputBuffer handleEE];
}

- (void)inputDigit:(NSInteger)digit {
    switch (self.syState) {

        case UDSYStateAfterResult:
            // SY: "=" was pressed -> soft reset, start fresh
            [self performSoftReset];
            break;

        case UDSYStateRPNResult:
            // RPN: result is in buffer; new digit replaces it.
            // First push the displayed result onto the stack (shouldPushOnDigit),
            // then reset the buffer.
            [self flushBufferToStack];
            [self.inputBuffer performClearEntry];
            self.isTyping = NO;
            // State will become TypingNumber below – correct.
            break;

        case UDSYStateAfterValue:
            // SY only: "3! 2" -> implicit multiply
            if (!self.isRPNMode) {
                [self flushBufferToStack];
                [self.opStack addObject:@(UDOpMul)];
                [self.inputBuffer performClearEntry];
            }
            break;

        case UDSYStateIdle:
        case UDSYStateAfterOperator:
        case UDSYStateTypingNumber:
            break;
    }

    self.isTyping = YES;
    [self.inputBuffer handleDigit:(int)digit];
    self.syState = UDSYStateTypingNumber;
}

- (void)inputDecimal {
    if (self.syState == UDSYStateAfterResult) {
        [self performSoftReset];
    }
    if (self.syState == UDSYStateRPNResult) {
        [self flushBufferToStack];
        [self.inputBuffer performClearEntry];
        self.isTyping = NO;
    }
    self.isTyping = YES;
    [self.inputBuffer handleDecimalPoint];
    self.syState = UDSYStateTypingNumber;
}

- (void)inputNumber:(UDValue)number {           // Constants, MR
    switch (self.syState) {
        case UDSYStateAfterResult:
            [self performSoftReset];
            break;

        case UDSYStateRPNResult:
            // RPN: treat like RPNResult -> digit: push current value, start fresh
            [self flushBufferToStack];
            [self.inputBuffer performClearEntry];
            self.isTyping = NO;
            break;

        case UDSYStateTypingNumber:
        case UDSYStateAfterValue:
            if (!self.isRPNMode) {
                // SY only: implicit multiply
                // "2 π"  ->  implicit multiply
                [self flushBufferToStack];
                [self.opStack addObject:@(UDOpMul)];
                [self.inputBuffer performClearEntry];
            }
            break;

        default:
            break;
    }

    self.isTyping = YES;
    [self.inputBuffer loadConstant:number];
    self.syState = UDSYStateAfterValue;         // constant is a complete value
}

- (void)performOperationShuntingYard:(UDOp)op {

    // -----------------------------------------------------------------------
    // TERMINATORS  (=, M+, M-)
    // -----------------------------------------------------------------------
    if (op == UDOpEq || op == UDOpMAdd || op == UDOpMSub) {
        [self flushBufferToStack];

        while (self.opStack.count > 0) [self reduceOp];

        if (op == UDOpEq && self.syState == UDSYStateAfterResult) {
            // repeat
            UDASTNode *lastResult = self.nodeStack.lastObject;
            UDBinaryOpNode *lastNode = [self extractLastInfixActionFromAST:lastResult];
            if (lastResult && lastNode) {
                [self.nodeStack removeLastObject];
                [self.nodeStack addObject:[UDBinaryOpNode info:lastNode.info left:lastResult right:[lastNode.right copy]]];
            }
        }

        UDValue result = [self evaluateCurrentExpression];
        double  d      = UDValueAsDouble(result);

        if      (op == UDOpMAdd) self.memoryRegister += d;
        else if (op == UDOpMSub) self.memoryRegister -= d;

        [self.inputBuffer loadConstant:result];
        self.isTyping = NO;
        self.syState  = UDSYStateAfterResult;
        return;
    }

    // -----------------------------------------------------------------------
    // LEFT PARENTHESIS
    // -----------------------------------------------------------------------
    if (op == UDOpParenLeft) {
        [self flushBufferToStack];

        // Implicit multiply: "2 ("  ->  "2 * ("
        if ([self sy_shouldImplicitMultiply]) {
            [self.opStack addObject:@(UDOpMul)];
        }

        [self.opStack addObject:@(op)];
        [self.inputBuffer performClearEntry];   // ← clear display-only buffer
        self.isTyping = NO;
        self.syState = UDSYStateAfterOperator;  // expect a new operand inside
        return;
    }

    // -----------------------------------------------------------------------
    // RIGHT PARENTHESIS
    // -----------------------------------------------------------------------
    if (op == UDOpParenRight) {
        [self flushBufferToStack];

        while (self.opStack.count > 0) {
            UDOp top = [self.opStack.lastObject integerValue];
            if (top == UDOpParenLeft) {
                [self.opStack removeLastObject];

                if (self.nodeStack.count > 0) {
                    UDASTNode *content = self.nodeStack.lastObject;
                    [self.nodeStack removeLastObject];
                    [self.nodeStack addObject:[UDParenNode wrap:content]];
                }

                self.syState = UDSYStateAfterValue; // closed group is a value
                return;
            }
            [self reduceOp];
        }
        // Mismatched paren – leave state unchanged
        return;
    }

    // -----------------------------------------------------------------------
    // POSTFIX  (!, x², %)
    // -----------------------------------------------------------------------
    UDOpInfo *info = [[UDFrontend shared] infoForOp:op];

    if (info.placement == UDOpPlacementPostfix) {
        // AfterOperator means there is no value to the right of the last infix op.
        // e.g. "2 + !" is invalid. Idle is fine — it means "0!".
        if (self.syState == UDSYStateAfterOperator) {
            return;
        }

        [self flushBufferToStack];

        if (self.nodeStack.count == 0) {
            // Implicit 0: bare "!" -> "0!"
            [self.nodeStack addObject:[UDNumberNode value:UDValueMakeDouble(0.0)]];
        }

        [self buildNode:info];

        // Auto-eval for display only — load result into buffer but
        // mark isTyping=NO so the buffer is NEVER flushed back to the stack.
        // Also clear the buffer first so no stale digits remain.
        UDValue val = [self evaluateCurrentExpression];
        [self.inputBuffer performClearEntry];   // ← clear stale content first
        [self.inputBuffer loadConstant:val];    // ← display value
        self.isTyping = NO;                     // ← buffer is display-only
        self.syState  = UDSYStateAfterValue;
        return;
    }

    // -----------------------------------------------------------------------
    // INFIX (BINARY)
    // -----------------------------------------------------------------------
    if (info.placement == UDOpPlacementInfix) {

        // A binary op is only valid when there is a value to its left:
        //   - a completed value/result, OR
        //   - a number currently in the buffer (TypingNumber), OR
        //   - AfterOperator ONLY if we can replace the top op
        //     (i.e. top is not a parenthesis).
        BOOL hasValueOnLeft = (self.syState == UDSYStateAfterValue
                            || self.syState == UDSYStateAfterResult
                            || self.syState == UDSYStateTypingNumber);

        BOOL canReplaceTopOp = NO;
        if (self.syState == UDSYStateAfterOperator && self.opStack.count > 0) {
            UDOp topOp = [self.opStack.lastObject integerValue];
            canReplaceTopOp = (topOp != UDOpParenLeft);  // can't replace a '('
        }

        if (!hasValueOnLeft && !canReplaceTopOp) {
            return;  // ignore: "( *" or empty expression
        }

        BOOL wasTyping = self.isTyping;
        [self moveBufferToStack];

        // Operator replacement: "2 + *" -> replace "+" with "*"
        if (canReplaceTopOp && !wasTyping) {
            UDOp     topOp   = [self.opStack.lastObject integerValue];
            UDOpInfo *topInfo = [[UDFrontend shared] infoForOp:topOp];
            if (topInfo.placement == UDOpPlacementInfix) {
                [self.opStack removeLastObject];
            }
        }

        // Precedence-based reduction
        NSInteger myPrec = info.precedence;
        while (self.opStack.count > 0) {
            UDOp     topOp   = [self.opStack.lastObject integerValue];
            UDOpInfo *topInfo = [[UDFrontend shared] infoForOp:topOp];
            if (topOp == UDOpParenLeft) break;
            if (topInfo.precedence >= myPrec) [self reduceOp];
            else break;
        }

        [self.opStack addObject:@(op)];
        [self.inputBuffer performClearEntry];

        self.isTyping = NO;
        self.syState  = UDSYStateAfterOperator;
    }
}

- (void)performOperationRPN:(UDOp)op {

    // -----------------------------------------------------------------------
    // ENTER
    // -----------------------------------------------------------------------
    if (op == UDOpEnter) {
        if (self.isTyping) {
            [self moveBufferToStack];
            self.syState = UDSYStateRPNResult;
            return;
        }

        // Ensure there is always something in X to duplicate
        if (self.nodeStack.count == 0) {
            [self.nodeStack addObject:[UDNumberNode value:UDValueMakeDouble(0.0)]];
        }

        // Duplicate X
        UDASTNode *topNode = (self.nodeStack.count > 0)
            ? self.nodeStack.lastObject
            : [UDNumberNode value:UDValueMakeDouble(0.0)];

        UDASTNode *copy = [topNode conformsToProtocol:@protocol(NSCopying)]
            ? [topNode copy]
            : topNode;

        [self.nodeStack addObject:copy];
        self.syState = UDSYStateRPNResult;
        return;
    }

    if (op == UDOpDrop) {
        [self flushBufferToStack];
        if (self.nodeStack.count > 0) [self.nodeStack removeLastObject];
        [self sy_refreshDisplayFromStack];
        return;
    }

    if (op == UDOpSwap) {
        [self flushBufferToStack];
        if (self.nodeStack.count >= 2) {
            NSInteger n = self.nodeStack.count;
            [self.nodeStack exchangeObjectAtIndex:(n-1) withObjectAtIndex:(n-2)];
        }
        [self sy_refreshDisplayFromStack];
        return;
    }

    if (op == UDOpRollDown) {
        [self flushBufferToStack];
        if (self.nodeStack.count > 1) {
            UDASTNode *x = self.nodeStack.lastObject;
            [self.nodeStack removeLastObject];
            [self.nodeStack insertObject:x atIndex:0];
        }
        [self sy_refreshDisplayFromStack];
        return;
    }

    if (op == UDOpRollUp) {
        [self flushBufferToStack];
        if (self.nodeStack.count > 1) {
            UDASTNode *top = self.nodeStack.firstObject;
            [self.nodeStack removeObjectAtIndex:0];
            [self.nodeStack addObject:top];
        }
        [self sy_refreshDisplayFromStack];
        return;
    }

    // -----------------------------------------------------------------------
    // BINARY / UNARY / POSTFIX / FUNCTION
    // -----------------------------------------------------------------------
    UDOpInfo *info = [[UDFrontend shared] infoForOp:op];

    if (info.placement == UDOpPlacementInfix) {
        if (self.nodeStack.count == 0) return; // stack underflow

        if (self.isTyping) {
            // User typed a number without pressing Enter first — flush it now
            [self flushBufferToStack];
        }
        // If !isTyping, X is already on the stack (committed by Enter or
        // a stack-manipulation op via sy_refreshDisplayFromStack) — use it as-is.

        [self buildNode:info];
        [self reportCalculationResult];
        [self moveStackToBuffer:YES];   // -> UDSYStateRPNResult
        return;
    }

    // Unary / postfix / function
    if (self.isTyping) {
        [self flushBufferToStack];
    } else if (self.nodeStack.count == 0) {
        // Nothing at all — implicit zero
        [self.nodeStack addObject:[UDNumberNode value:UDValueMakeDouble(0.0)]];
    }

    if (self.nodeStack.count < 1) return;

    [self buildNode:info];
    [self reportCalculationResult];
    [self moveStackToBuffer:YES];   // -> UDSYStateRPNResult
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
        }
        return;
    }

    if (op == UDOpClearAll) {
        [self reset];
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
    if (self.mode != UDCalcModeProgrammer && [self.delegate respondsToSelector:@selector(calculator:didCalculateResult:forTree:)]) {
        UDASTNode *resultTree = [self.nodeStack lastObject];

        UDValue val = [self evaluateCurrentExpression];
        
        [self.delegate calculator:self didCalculateResult:val forTree:resultTree];
    }
}

#pragma mark - AST Construction & Exec

- (UDBinaryOpNode *)extractLastInfixActionFromAST:(UDASTNode *)root {
    if (!root) return nil;

    // Case 1: Binary Operation (e.g., 2 + 3)
    if ([root isKindOfClass:[UDBinaryOpNode class]]) {
        UDBinaryOpNode *bin = (UDBinaryOpNode *)root;
        
        // If the right side is another operation, we drill down
        // to find the 'leaf' action (the last thing typed)
        if ([bin.right isKindOfClass:[UDBinaryOpNode class]]) {
            return [self extractLastInfixActionFromAST:bin.right];
        }
        
        return bin;
    }

    return nil;
}

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
    // In RPN mode, the displayed result lives in the input buffer
    // (moveStackToBuffer: pops the node off the stack after every op).
    // The buffer is the authoritative current value whenever it is loaded.
    if (self.isRPNMode && self.isTyping) {
        return [self.inputBuffer finalizeValue];
    }

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
    UDValue val = [self currentInputValue];

    if (self.isTyping) {
        return [self.inputBuffer stringForValue:val showThousandsSeparators:self.showThousandsSeparators decimalPlaces:15];
    } else {
        return [self stringForValue:val];
    }
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
    return [self.inputBuffer stringForValue:value showThousandsSeparators:self.showThousandsSeparators decimalPlaces:self.decimalPlaces];
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
