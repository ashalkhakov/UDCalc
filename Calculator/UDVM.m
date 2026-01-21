//
//  UDVM.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDVM.h"
#import <math.h>

@implementation UDVM

+ (double)execute:(NSArray<UDInstruction *> *)program {
    NSMutableArray *stack = [NSMutableArray array];
    
    for (UDInstruction *inst in program) {
        switch (inst.opcode) {
            case UDOpcodePush:
                [stack addObject:@(inst.doublePayload)];
                break;
                
            case UDOpcodeAdd: {
                double b = [[stack lastObject] doubleValue]; [stack removeLastObject];
                double a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@(a + b)];
            } break;
                
            case UDOpcodeMul: {
                double b = [[stack lastObject] doubleValue]; [stack removeLastObject];
                double a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@(a * b)];
            } break;
                
            case UDOpcodeSub: {
                double b = [[stack lastObject] doubleValue]; [stack removeLastObject];
                double a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@(a - b)];
            } break;
                
            case UDOpcodeDiv: {
                double b = [[stack lastObject] doubleValue]; [stack removeLastObject];
                double a = [[stack lastObject] doubleValue]; [stack removeLastObject];
                [stack addObject:@(b == 0 ? NAN : a / b)];
            } break;
            
            case UDOpcodeCall:
                [self performCall:inst.stringPayload onStack:stack];
                break;
                
            default: break;
        }
    }
    
    return [[stack lastObject] doubleValue];
}

+ (void)performCall:(NSString *)name onStack:(NSMutableArray *)stack {
    // 2-Argument Functions (pow)
    if ([name isEqualToString:@"pow"]) {
        double power = [[stack lastObject] doubleValue]; [stack removeLastObject];
        double base  = [[stack lastObject] doubleValue]; [stack removeLastObject];
        
        [stack addObject:@(pow(base, power))];
        return;
    }
    else
    // 1-Argument Functions
    {
        double val = [[stack lastObject] doubleValue]; [stack removeLastObject];
        double res = 0;
        
        if ([name isEqualToString:@"sqrt"]) res = sqrt(val);
        if ([name isEqualToString:@"ln"]) res = log(val);
        if ([name isEqualToString:@"sinD"]) res = sin(val * M_PI / 180.0);
        if ([name isEqualToString:@"cosD"]) res = cos(val * M_PI / 180.0);
        if ([name isEqualToString:@"tanD"]) res = tan(val * M_PI / 180.0);

        if ([name isEqualToString:@"sinh"]) res = sinh(val);
        if ([name isEqualToString:@"cosh"]) res = cosh(val);
        if ([name isEqualToString:@"tanh"]) res = tanh(val);

        if ([name isEqualToString:@"log10"]) res = log10(val);
        if ([name isEqualToString:@"ln"])    res = log(val);

        if ([name isEqualToString:@"fact"])  res = tgamma(val + 1); // Gamma function for factorial

        [stack addObject:@(res)];
        return;
    }
}

@end
