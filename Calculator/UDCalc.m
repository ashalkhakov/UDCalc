//
//  UDCalc.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <math.h>

#import "UDCalc.h"
#import "UDOpRegistry.h"

// Note: Apple Calc uses Degrees by default for UI, but math.h uses Radians.
// Let's assume Degrees for user friendliness.
#define DEG2RAD(x) ((x) * M_PI / 180.0)
#define RAD2DEG(x) ((x) * 180.0 / M_PI)

@interface UDCalc ()
@property (strong, readwrite) NSMutableArray<NSNumber *> *valueStack;
@property (strong, readwrite) NSMutableArray<NSNumber *> *opStack;
@property (assign) double decMult; // Multiplier for decimal places (0.1, 0.01, etc)
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
    // Always start with [0] so there is something to display/operate on
    _valueStack = [NSMutableArray arrayWithObject:@(0.0)];
    _opStack = [NSMutableArray array];
    _typing = NO;
    _decMult = 0.0;
}

#pragma mark - Value Helpers

- (double)currentValue {
    if (self.valueStack.count == 0) return 0.0;
    return [[self.valueStack lastObject] doubleValue];
}

- (void)setCurrentValue:(double)currentValue {
    [self popValue];
    [self pushValue:currentValue];
}

// Internal helper to push a value safely
- (void)pushValue:(double)val {
    [self.valueStack addObject:@(val)];
}

// Internal helper to pop a value safely
- (double)popValue {
    if (self.valueStack.count == 0) return 0.0;
    double val = [[self.valueStack lastObject] doubleValue];
    [self.valueStack removeLastObject];
    return val;
}

#pragma mark - Input Handling

- (void)digit:(NSInteger)digit {
    double val = self.currentValue;
    
    // CASE A: Start of new number
    if (!self.typing) {
        // If we just finished an Op, the stack might have a "Placeholder" 0.0 on top.
        // We overwrite it.
        self.typing = YES;
        val = digit;
        self.decMult = 0.0;
    }
    // CASE B: Appending to existing number
    else {
        if (self.decMult > 0) {
            // Typing decimals: 5.2 -> 5.23
            val += digit * self.decMult;
            self.decMult /= 10.0;
        } else {
            // Typing integers: 5 -> 53
            val = (val * 10) + digit;
        }
    }
    
    // Update Top of Stack
    if (self.valueStack.count > 0) [self.valueStack removeLastObject];
    [self.valueStack addObject:@(val)];
}

- (void)decimal {
    if (!self.typing) {
        self.typing = YES;
        // Start a new 0.
        if (self.valueStack.count > 0) [self.valueStack removeLastObject];
        [self.valueStack addObject:@(0.0)];
    }
    
    // Initialize decimal multiplier if not already set
    if (self.decMult == 0.0) {
        self.decMult = 0.1;
    }
}

#pragma mark - The Shunting Yard Algorithm

- (void)operation:(UDOp)newOp {

    if (newOp == UDOpClear) {
        [self reset];
        return;
    }
    
    // 1. Commit current input
    if (self.typing) {
        self.typing = NO;
        self.decMult = 0.0;
    }
    
    UDOpRegistry *registry = [UDOpRegistry shared];
    UDOpInfo *newInfo = [registry infoForOp:newOp];
    
    if (!newInfo) return; // Guard against bad ops
    
    // 2. Handle Immediate Ops (Prefix/Postfix)
    // These apply directly to the number currently on the stack top.
    if (newInfo.placement == UDOpPlacementPrefix || newInfo.placement == UDOpPlacementPostfix) {
        [self executeUnaryOp:newOp];
        return;
    }
    
    // 3. Handle Binary Ops & Equals (The Shunt)
    // Loop: While there are ops on the stack that are "stronger" (higher precedence)
    // than the new one, execute them first.
    
    while (self.opStack.count > 0) {
        UDOp topOp = [self.opStack.lastObject integerValue];
        UDOpInfo *topInfo = [registry infoForOp:topOp];
        
        // STOP Conditions:
        
        // A. If New Op is stronger, we stack it (e.g. * on top of +)
        if (newInfo.precedence > topInfo.precedence) {
            break;
        }
        
        // B. Right Associativity check (e.g. ^ operators)
        if (newInfo.precedence == topInfo.precedence && newInfo.associativity == UDOpAssocRight) {
            break;
        }
        
        // C. If the New Op is 'Equals', it has Precedence 0, so it forces
        // everything on the stack to evaluate.
        
        // EXECUTE: The top op is stronger/equal. Do it now.
        [self popAndExecuteTopOp];
    }
    
    // 4. Push the New Op (If it's not Equals)
    if (newOp != UDOpEq) {
        [self.opStack addObject:@(newOp)];
        
        // PRIMING: Push a placeholder 0.0 for the NEXT number the user will type.
        // This emulates standard calculator behavior where the display waits for input.
        [self pushValue:0.0];
    }
}

- (void)popAndExecuteTopOp {
    if (self.opStack.count == 0) return;
    
    UDOp op = [self.opStack.lastObject integerValue];
    [self.opStack removeLastObject];
    
    // IMPORTANT: Pop Right first, then Left (Subtraction/Division order matters!)
    double right = [self popValue];
    double left = [self popValue];
    double result = 0.0;
    
    switch (op) {
        case UDOpAdd: result = left + right; break;
        case UDOpSub: result = left - right; break;
        case UDOpMul: result = left * right; break;
        case UDOpDiv: result = (right != 0) ? (left / right) : 0; break; // Simple div by zero protection
        case UDOpPow: result = pow(left, right); break;
        default: break;
    }
    
    [self pushValue:result];
}

- (void)executeUnaryOp:(UDOp)op {
    // 1. Pop the current value (e.g., 5)
    double val = [self popValue];
    
    switch (op) {
        case UDOpNegate: {
            val = -val;
            break;
        }
        case UDOpPercent: {
            // ACCOUNTING LOGIC:
            // If we are in the middle of an Add/Sub operation (e.g. [2, 5] with Pending '+'),
            // then '%' means "Percent OF the base value".
            
            // Check if we have a base value (Stack has items left) AND a pending Op
            if (self.valueStack.count > 0 && self.opStack.count > 0) {
                
                UDOp pendingOp = [self.opStack.lastObject integerValue];
                
                // This logic typically applies to + and - (Markup / Markdown)
                if (pendingOp == UDOpAdd || pendingOp == UDOpSub) {
                    // Peek at the base value (e.g., 2) WITHOUT popping it
                    double base = [[self.valueStack lastObject] doubleValue];
                    
                    // Calculate percentage relative to base
                    // 5 becomes (2 * 0.05) = 0.1
                    val = base * (val / 100.0);
                } else {
                    // For * and /, standard behavior is usually just raw percentage
                    // e.g. 50 * 10% -> 50 * 0.1 = 5
                    val = val / 100.0;
                }
            } else {
                // No context (just typed "5 %" on a clear screen), standard behavior
                val = val / 100.0;
            }
            break;
        }
        
        // --- TRIGONOMETRY ---
        
        case UDOpSin: val = sin(DEG2RAD(val)); break;
        case UDOpCos: val = cos(DEG2RAD(val)); break;
        case UDOpTan: val = tan(DEG2RAD(val)); break;
        
        case UDOpASin: val = RAD2DEG(asin(val)); break;
        case UDOpACos: val = RAD2DEG(acos(val)); break;
        case UDOpATan: val = RAD2DEG(atan(val)); break;
        
        // --- ROOTS & LOGS ---
        case UDOpSqrt: val = sqrt(val); break;
        case UDOpCbrt: val = cbrt(val); break;
        case UDOpLog10: val = log10(val); break;
        case UDOpLn:    val = log(val); break; // log() in C is natural log (ln)
        
        // --- POWERS ---
        case UDOpSquare: val = val * val; break;
        case UDOpCube:   val = val * val * val; break;
        
        case UDOpInvert: val = (val != 0) ? (1.0 / val) : 0.0; break;
        
        case UDOpFactorial: {
            // Factorial is only defined for non-negative integers
            if (val >= 0 && val == floor(val)) {
                double f = 1;
                for (int i = 1; i <= (int)val; i++) f *= i;
                val = f;
            } else {
                val = NAN; // Or handle error
            }
        } break;
            
        default: break;
    }
    
    // 2. Push the result back
    [self pushValue:val];
}

@end
