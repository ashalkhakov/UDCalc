//
//  UDVM.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDVM.h"
#import <math.h>

#define MAX_STACK_DEPTH 1024

@implementation UDVM

+ (UDValue)execute:(NSArray<UDInstruction *> *)program {
    UDValue stack[MAX_STACK_DEPTH];
    int sp = 0;
    
    for (UDInstruction *inst in program) {
        switch (inst.opcode) {
            case UDOpcodePush:
                if (sp >= MAX_STACK_DEPTH)
                    return UDValueMakeError(UDValueErrorTypeOverflow);
                stack[sp++] = inst.payload;
                break;
                
            case UDOpcodeAdd: {
                if (sp - 2 < 0)
                    goto err;
                double b = UDValueAsDouble(stack[--sp]);
                double a = UDValueAsDouble(stack[--sp]);
                stack[sp++] = UDValueMakeDouble(a + b);
            } break;
                
            case UDOpcodeMul: {
                if (sp - 2 < 0)
                    goto err;
                double b = UDValueAsDouble(stack[--sp]);
                double a = UDValueAsDouble(stack[--sp]);
                stack[sp++] = UDValueMakeDouble(a * b);
            } break;
                
            case UDOpcodeSub: {
                if (sp - 2 < 0)
                    goto err;
                double b = UDValueAsDouble(stack[--sp]);
                double a = UDValueAsDouble(stack[--sp]);
                stack[sp++] = UDValueMakeDouble(a - b);
            } break;
                
            case UDOpcodeDiv: {
                if (sp - 2 < 0)
                    goto err;
                double b = UDValueAsDouble(stack[--sp]);
                double a = UDValueAsDouble(stack[--sp]);
                
                if (b == 0) {
                    return UDValueMakeError(UDValueErrorTypeDivideByZero);
                }

                stack[sp++] = UDValueMakeDouble(a / b);
            } break;

            case UDOpcodeAddI: {
                if (sp - 2 < 0)
                    goto err;
                unsigned long long b = UDValueAsInt(stack[--sp]);
                unsigned long long a = UDValueAsInt(stack[--sp]);
                stack[sp++] = UDValueMakeInt(a + b);
            } break;
                
            case UDOpcodeMulI: {
                if (sp - 2 < 0)
                    goto err;
                unsigned long long b = UDValueAsInt(stack[--sp]);
                unsigned long long a = UDValueAsInt(stack[--sp]);
                stack[sp++] = UDValueMakeInt(a * b);
            } break;
                
            case UDOpcodeSubI: {
                if (sp - 2 < 0)
                    goto err;
                unsigned long long b = UDValueAsInt(stack[--sp]);
                unsigned long long a = UDValueAsInt(stack[--sp]);
                stack[sp++] = UDValueMakeInt(a - b);
            } break;
                
            case UDOpcodeDivI: {
                if (sp - 2 < 0)
                    goto err;
                unsigned long long b = UDValueAsInt(stack[--sp]);
                unsigned long long a = UDValueAsInt(stack[--sp]);

                if (b == 0) {
                    return UDValueMakeError(UDValueErrorTypeDivideByZero);
                }

                stack[sp++] = UDValueMakeInt(a / b);
            } break;

            case UDOpcodeCall: {
                NSString *name = inst.stringPayload;

                // 2-Argument Functions
                if ([name isEqualToString:@"pow"]) {
                    if (sp - 2 < 0)
                        goto err;
                    
                    double power = UDValueAsDouble(stack[--sp]);
                    double base  = UDValueAsDouble(stack[--sp]);

                    stack[sp++] = UDValueMakeDouble(pow(base, power));
                }
                else
                // 1-Argument Functions
                {
                    if (sp - 1 < 0)
                        goto err;

                    double val = UDValueAsDouble(stack[--sp]);
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

                    stack[sp++] = UDValueMakeDouble(res);
                }
            } break;

            default: break;
        }
    }
    
    return stack[--sp];

err:
    return UDValueMakeError(UDValueErrorTypeUnderflow);
}


@end
