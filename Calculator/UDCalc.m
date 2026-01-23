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
@property (strong, readwrite) NSMutableArray<UDASTNode *> *nodeStack; // Output Stack
@property (strong) NSMutableArray<NSNumber *> *opStack;               // Operator Stack
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
    _isTyping = NO; // start in Ready state
    [self.inputBuffer performClearEntry];
}

#pragma mark - Input

// Moves the value from InputBuffer -> NodeStack
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
    self.isTyping = YES;
    [self.inputBuffer handleDigit:(int)digit];
}

- (void)inputDecimal {
    self.isTyping = YES;
    [self.inputBuffer handleDecimalPoint];
}

// Used for Constants (π, e) or Memory Recall
- (void)inputNumber:(double)number {
    self.isTyping = YES;
    [self.inputBuffer loadConstant:number];
}

- (void)performOperation:(UDOp)op {
    
    // 1. INPUT MODIFIERS (EE)
    if (op == UDOpEE) {
        [self inputEE]; // Logic to start appending exponent digits
        return;
    }
    
    // 2. STATE TOGGLES (Rad, 2nd)
    if (op == UDOpRad) {
        self.isRadians = !self.isRadians;
        // Update UI button label "Rad" <-> "Deg"
        return;
    }
    
    // 3. MEMORY COMMANDS (Immediate Side Effects)
    if (op == UDOpMC) {
        self.memoryRegister = 0;
        return;
    }
    if (op == UDOpMAdd) {
        // Evaluate current, add to memory
        double val = [self evaluateCurrentExpression];
        self.memoryRegister += val;
        [self.inputBuffer performClearEntry];
        return;
    }
    if (op == UDOpMSub) {
        double val = [self evaluateCurrentExpression];
        self.memoryRegister -= val;
        [self.inputBuffer performClearEntry];
        return;
    }
    if (op == UDOpNegate) { // +/- Button
        [self.inputBuffer toggleSign];
        return;
    }
    
    // CLEAR
    if (op == UDOpClear) {
        if (self.isTyping) {
            // C: Clear only the buffer
            [self.inputBuffer performClearEntry];
            // Note: We might want to keep isTyping = YES or reset it depending on UX.
            // Usually, 'C' just resets the number to 0 but keeps you in "editing" mode.
        } else {
            // AC: Clear everything
            [self.inputBuffer performClearEntry];
            [self.nodeStack removeAllObjects];
            [self.opStack removeAllObjects];
        }
        [self reset];
        return;
    }
    
    // 1. If the user was typing, save that number first!
    if (self.isTyping) {
        [self flushBufferToStack];
    }
    
    // EQUALS (=)
    // Flush everything to build the final tree.
    if (op == UDOpEq) {
        while (self.opStack.count > 0) {
            [self reduceOp];
        }
        // Calculate the result immediately so UI can show it
        double currentValue = [self evaluateCurrentExpression];
        [self.inputBuffer loadConstant:currentValue];
        return;
    }
    
    // 1. LEFT PARENTHESIS "("
    // Push strictly to OpStack. It waits there as a marker.
    if (op == UDOpParenLeft) {
        // Optional: Implicit Multiply?
        // If user typed "5" then "(", we could inject a * here.
        // For now, let's keep it simple.
        [self.opStack addObject:@(op)];
        return;
    }
    
    // 2. RIGHT PARENTHESIS ")"
    // Collapse everything back to the nearest Left Paren
    if (op == UDOpParenRight) {
        while (self.opStack.count > 0) {
            UDOp top = [self.opStack.lastObject integerValue];
            
            if (top == UDOpParenLeft) {
                [self.opStack removeLastObject]; // Pop the '(' and discard it
                
                // We just finished a group. Wrap the top node in explicit parens.
                if (self.nodeStack.count > 0) {
                    UDASTNode *content = [self.nodeStack lastObject];
                    [self.nodeStack removeLastObject];
                    
                    // Wrap it and push it back
                    [self.nodeStack addObject:[UDParenNode wrap:content]];
                }
                
                return; // Done! We successfully closed the group.
            }
            
            [self reduceOp]; // Build the tree node
        }
        
        // If loop finishes without returning, we missed a '('.
        // (User typed "5 + 2 )"). usually ignore or error.
        NSLog(@"Syntax Error: Mismatched Parentheses");
        return;
    }
    
    // 3. SCIENTIFIC (Unary Postfix: sin, cos, etc.)
    // These act immediately on the node the user just typed.
    UDOpInfo *info = [[UDFrontend shared] infoForOp:op];
    
    if (info.placement == UDOpPlacementPostfix) {
        // Build a Function Node wrapper around the top node
        // e.g. Node(30) becomes FuncNode("sin", args=[Node(30)])
        //[self buildUnaryNode:info.symbol];
        [self buildNode:info];
        
        // Auto-evaluate so the display updates (optional, but standard behavior)
        double currentValue = [self evaluateCurrentExpression];
        [self.inputBuffer loadConstant:currentValue];
        return;
    }
    
    // 4. BINARY OPERATORS (+, -, *, ^)
    // Standard Shunting Yard Precedence Logic
    
    NSInteger myPrec = info.precedence;
    
    while (self.opStack.count > 0) {
        UDOp topOp = [self.opStack.lastObject integerValue];
        
        // BARRIER CHECK:
        if (topOp == UDOpParenLeft)
            break; // Stop! Don't pop the parenthesis yet.
        
        UDOpInfo *topInfo = [[UDFrontend shared] infoForOp:topOp];
        
        // If top operator has greater or equal precedence, pop it and build node
        if (topInfo.precedence >= myPrec) {
            [self reduceOp];
        } else {
            break;
        }
    }
    
    // Push new operator to wait its turn
    [self.opStack addObject:@(op)];
    [self.inputBuffer performClearEntry];
}

#pragma mark - AST Construction (The "Reduce" Step)

- (void)reduceOp {
    if (self.opStack.count == 0) return;
    
    UDOp op = [self.opStack.lastObject integerValue];
    [self.opStack removeLastObject];
    
    UDOpInfo *info = [[UDFrontend shared] infoForOp:op];
    
    [self buildNode:info];
}

-(void)buildNode:(UDOpInfo *)info {
    if (!info) {
        NSLog(@"No operator info supplied");
        return;
    }
    
    if (info.action) {
        UDFrontendContext *context = [[UDFrontendContext alloc] init];
        
        context.nodeStack = self.nodeStack;
        context.pendingOp = UDOpNone;
        context.isRadians = self.isRadians;
        context.memoryValue = self.memoryRegister;
        
        UDASTNode *node = info.action(context);
        
        [self.nodeStack addObject:node];
    }
}

#pragma mark - Execution Pipeline

- (double)evaluateCurrentExpression {
    if (self.nodeStack.count == 0) return 0.0;
    
    // 1. Get the Tree (Root is top of stack)
    UDASTNode *root = [self.nodeStack lastObject];
    
    // 2. Compile (Tree -> Instruction List)
    NSArray *bytecode = [UDCompiler compile:root];
    
    // 3. Run VM (Instruction List -> Double)
    return [UDVM execute:bytecode];
}

#pragma mark - Display Logic

- (double)currentInputValue {
    // Priority 1: If user is typing, show the buffer
    if (self.isTyping) {
        return [self.inputBuffer finalizeValue];
    }
    
    // Priority 2: If we just calculated something (or pushed an op),
    // show the top of the stack (the running total).
    if (self.nodeStack.count > 0) {
        return [self evaluateCurrentExpression];
    }
    
    // Priority 3: Default empty state
    return 0;
}

- (NSString *)currentDisplayValue {
    double value = [self currentInputValue];
    return [NSString stringWithFormat:@"%.10g", value];
}

@end
