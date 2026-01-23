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
        else if ([name isEqualToString:@"ln"]) res = log(val);

        else if ([name isEqualToString:@"sin"]) res = sin(val);
        else if ([name isEqualToString:@"sinD"]) res = sin(val * M_PI / 180.0);
        else if ([name isEqualToString:@"asin"]) res = asin(val);
        else if ([name isEqualToString:@"asinD"]) res = sin(val * M_PI / 180.0);
        else if ([name isEqualToString:@"cos"]) res = cos(val);
        else if ([name isEqualToString:@"cosD"]) res = cos(val * M_PI / 180.0);
        else if ([name isEqualToString:@"acos"]) res = acos(val);
        else if ([name isEqualToString:@"acosD"]) res = acos(val * M_PI / 180.0);
        else if ([name isEqualToString:@"tan"]) res = tan(val);
        else if ([name isEqualToString:@"tanD"]) res = tan(val * M_PI / 180.0);
        else if ([name isEqualToString:@"atan"]) res = atan(val);
        else if ([name isEqualToString:@"atanD"]) res = atan(val * M_PI / 180.0);

        else if ([name isEqualToString:@"sinh"]) res = sinh(val);
        else if ([name isEqualToString:@"asinh"]) res = asinh(val);
        else if ([name isEqualToString:@"cosh"]) res = cosh(val);
        else if ([name isEqualToString:@"acosh"]) res = acosh(val);
        else if ([name isEqualToString:@"tanh"]) res = tanh(val);
        else if ([name isEqualToString:@"atanh"]) res = atanh(val);

        else if ([name isEqualToString:@"log10"]) res = log10(val);

        else if ([name isEqualToString:@"fact"])  res = tgamma(val + 1); // Gamma function for factorial
        else NSLog(@"Unhandled function call %@", name);

        [stack addObject:@(res)];
        return;
    }
}

@end
