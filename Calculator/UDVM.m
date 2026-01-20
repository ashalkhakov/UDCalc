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
                
            // ... implement SUB and DIV similarly ...
            
            case UDOpcodeCall:
                [self performCall:inst.stringPayload onStack:stack];
                break;
                
            default: break;
        }
    }
    
    return [[stack lastObject] doubleValue];
}

+ (void)performCall:(NSString *)name onStack:(NSMutableArray *)stack {
    // 1-Argument Functions
    if ([name isEqualToString:@"sin"] || [name isEqualToString:@"cos"] ||
        [name isEqualToString:@"sqrt"] || [name isEqualToString:@"ln"]) {
        
        double val = [[stack lastObject] doubleValue]; [stack removeLastObject];
        double res = 0;
        
        if ([name isEqualToString:@"sin"]) res = sin(val * M_PI / 180.0); // Degrees!
        else if ([name isEqualToString:@"cos"]) res = cos(val * M_PI / 180.0);
        else if ([name isEqualToString:@"sqrt"]) res = sqrt(val);
        else if ([name isEqualToString:@"ln"]) res = log(val);
        
        [stack addObject:@(res)];
        return;
    }
    
    // 2-Argument Functions (pow)
    if ([name isEqualToString:@"pow"]) {
        double power = [[stack lastObject] doubleValue]; [stack removeLastObject];
        double base  = [[stack lastObject] doubleValue]; [stack removeLastObject];
        
        [stack addObject:@(pow(base, power))];
        return;
    }
}

@end
