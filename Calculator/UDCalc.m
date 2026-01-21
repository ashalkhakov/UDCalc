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

// EE support
@property (assign) double mantissa;         // Stores the base (e.g., 5.0)
@property (assign) BOOL enteringExponent;   // Are we typing after hitting EE?
@property (assign) double exponentValue;    // Stores the typed exponent (e.g., 3)
@property (assign) double exponentSign;     // 1.0 or -1.0
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
    _enteringExponent = NO;
    _exponentValue = 0;
}

#pragma mark - Input

- (void)inputEE {
    // 1. If we aren't typing, start a new number "1 E 0"
    if (!self.typing) {
        self.mantissa = 1.0;
        self.typing = YES;
    } else {
        // Capture what the user has typed so far as the base
        self.mantissa = self.currentValue;
    }

    // 2. Switch modes
    self.enteringExponent = YES;
    self.exponentValue = 0.0;
    self.exponentSign = 1.0;
    
    // 3. Update UI (Visual Feedback is tricky here)
    // Since 'currentValue' is a double, it might not show "E" on the display yet.
    // Usually, you update a separate display string, or just wait for the first digit.
}

- (void)inputDigit:(double)digit {
    // --- CASE A: EXPONENT MODE ---
    if (self.enteringExponent) {
        self.typing = YES;

        // Shift existing exponent left and add digit (Integer logic)
        self.exponentValue = (self.exponentValue * 10.0) + digit;
        
        // Calculate the real value immediately
        // Value = Mantissa * 10^(Sign * Exponent)
        double totalExponent = self.exponentValue * self.exponentSign;
        self.currentValue = self.mantissa * pow(10.0, totalExponent);
        
        // Update AST
        [self updateTopNodeWithValue:self.currentValue];
    }
    
    // --- CASE B: STANDARD MODE (Your existing code) ---
    else {
        
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
            [self updateTopNodeWithValue:self.currentValue];
        }
    }
}

// Helper to keep AST clean
- (void)updateTopNodeWithValue:(double)val {
    if (self.nodeStack.count > 0 && [self.nodeStack.lastObject isKindOfClass:[UDNumberNode class]]) {
        [self.nodeStack removeLastObject];
    }
    [self.nodeStack addObject:[UDNumberNode value:val]];
}

- (void)inputDecimal {
    // Decimal points are forbidden in the exponent (usually)
    if (self.enteringExponent) return;

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
        // Usually, calculators reset the "Typing" state here
        self.typing = NO;
        return;
    }
    if (op == UDOpMSub) {
        double val = [self evaluateCurrentExpression];
        self.memoryRegister -= val;
        self.typing = NO;
        return;
    }
    if (op == UDOpNegate) { // +/- Button
        if (self.enteringExponent) {
            // Toggle Exponent Sign only
            self.exponentSign *= -1.0;
            
            // Recalculate
            double totalExponent = self.exponentValue * self.exponentSign;
            self.currentValue = self.mantissa * pow(10.0, totalExponent);
        } else {
            self.currentValue = -self.currentValue;
        }
        [self updateTopNodeWithValue:self.currentValue];
        return;
    }

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
    
    // When user hits +, -, *, /
    if (self.typing) {
        self.typing = NO;
        self.enteringExponent = NO; // Turn off EE mode
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

@end
