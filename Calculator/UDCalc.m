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
@property (readwrite) BOOL typing;
@property (readwrite) double currentValue;
@property (assign) BOOL hasDecimal;
@property (assign) double decimalMultiplier;
@end

@implementation UDCalc

- (instancetype)init {
    self = [super init];
    if (self) {
        [self reset];
    }
    return self;
}

- (void)reset {
    _nodeStack = [NSMutableArray array];
    _opStack = [NSMutableArray array];
    _typing = NO;
    _currentValue = 0;
}

#pragma mark - Input

- (void)inputDigit:(double)digit {
    if (!self.typing) {
        // CASE A: NEW NUMBER (Push)

        // If we have no pending operators (e.g., fresh start or after '='),
        // typing a number should discard the old result/zero.
        if (self.opStack.count == 0) {
            [self.nodeStack removeAllObjects];
        }

        self.typing = YES;
        self.hasDecimal = NO;
        self.decimalMultiplier = 0.1;
        
        self.currentValue = digit;
        
        // PUSH new node
        [self.nodeStack addObject:[UDNumberNode value:self.currentValue]];
        
    } else {
        // CASE B: EDITING (Replace)
        if (self.hasDecimal) {
            self.currentValue += (digit * self.decimalMultiplier);
            self.decimalMultiplier /= 10.0;
        } else {
            self.currentValue = (self.currentValue * 10.0) + digit;
        }
        
        // REPLACE top node
        if (self.nodeStack.count > 0) [self.nodeStack removeLastObject];
        [self.nodeStack addObject:[UDNumberNode value:self.currentValue]];
    }
}

- (void)inputDecimal {
    // If user hits decimal while not typing (e.g., after '=' or fresh start)
    // We treat it as "0."
    if (!self.typing) {
        [self inputDigit:0]; // Start with 0
    }
    
    // Enable decimal mode for subsequent digits
    if (!self.hasDecimal) {
        self.hasDecimal = YES;
        self.decimalMultiplier = 0.1;
    }
}

// Used for Constants (π, e) or Memory Recall
- (void)inputNumber:(double)number {
    self.currentValue = number;
    
    // Push as a complete node
    [self.nodeStack addObject:[UDNumberNode value:number]];
    
    // IMPORTANT: Set typing to NO.
    // Why? If you press Pi, then press '5', it should start a NEW number,
    // not append 5 to 3.14159...
    self.typing = NO;
    
    // Reset decimal state just in case
    self.hasDecimal = NO;
}

- (void)performOperation:(UDOp)op {
    // 1. EQUALS (=)
    // Flush everything to build the final tree.
    if (op == UDOpEq) {
        while (self.opStack.count > 0) {
            [self reduceOp];
        }
        // Calculate the result immediately so UI can show it
        self.currentValue = [self evaluateCurrentExpression];
        self.typing = NO;
        return;
    }
    
    // 2. CLEAR
    if (op == UDOpClear) {
        [self reset];
        return;
    }
    
    // 3. SCIENTIFIC (Unary Postfix: sin, cos, etc.)
    // These act immediately on the node the user just typed.
    UDOpInfo *info = [[UDOpRegistry shared] infoForOp:op];
        
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
        if (self.typing) self.typing = NO;
        
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

    if (info.placement == UDOpPlacementPostfix) {
        // Build a Function Node wrapper around the top node
        // e.g. Node(30) becomes FuncNode("sin", args=[Node(30)])
        [self buildUnaryNode:info.symbol];
        
        // Auto-evaluate so the display updates (optional, but standard behavior)
        self.currentValue = [self evaluateCurrentExpression];
        return;
    }

    // 4. BINARY OPERATORS (+, -, *, ^)
    // Standard Shunting Yard Precedence Logic
    if (self.typing) self.typing = NO;

    NSInteger myPrec = info.precedence;

    while (self.opStack.count > 0) {
        UDOp topOp = [self.opStack.lastObject integerValue];
        
        // BARRIER CHECK:
        if (topOp == UDOpParenLeft) break; // Stop! Don't pop the parenthesis yet.
        
        UDOpInfo *topInfo = [[UDOpRegistry shared] infoForOp:topOp];

        // If top operator has greater or equal precedence, pop it and build node
        if (topInfo.precedence >= myPrec) {
            [self reduceOp];
        } else {
            break;
        }
    }

    // Push new operator to wait its turn
    [self.opStack addObject:@(op)];
}

#pragma mark - AST Construction (The "Reduce" Step)

- (void)reduceOp {
    if (self.opStack.count == 0) return;
    
    UDOp op = [self.opStack.lastObject integerValue];
    [self.opStack removeLastObject];
    
    UDOpInfo *info = [[UDOpRegistry shared] infoForOp:op];
    
    // Safety check
    if (self.nodeStack.count < 2) return;
    
    // Pop Right, then Left (Stack is LIFO)
    UDASTNode *right = [self.nodeStack lastObject]; [self.nodeStack removeLastObject];
    UDASTNode *left  = [self.nodeStack lastObject]; [self.nodeStack removeLastObject];
    
    UDASTNode *newNode = nil;
    
    // Decide if it's a function call (pow) or operator (+)
    // You can customize this logic or add a flag to UDOpInfo
    if (op == UDOpPow) {
        newNode = [UDFunctionNode func:@"pow" args:@[left, right]];
    }
    else if (op == UDOpPow10) {
         // Special case if handled as binary, though usually unary
    }
    else {
        newNode = [UDBinaryOpNode op:info.symbol left:left right:right precedence:info.precedence];
    }
    
    // Push the combined block back
    [self.nodeStack addObject:newNode];
}

- (void)buildUnaryNode:(NSString *)funcName {
    if (self.nodeStack.count == 0) return;
    
    UDASTNode *arg = [self.nodeStack lastObject];
    [self.nodeStack removeLastObject];
    
    UDASTNode *newNode = [UDFunctionNode func:funcName args:@[arg]];
    [self.nodeStack addObject:newNode];
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

@end
