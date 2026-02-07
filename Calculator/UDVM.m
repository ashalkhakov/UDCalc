//
//  UDVM.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDVM.h"
#import <math.h>

#define MAX_STACK_DEPTH 1024

static inline double Pow(double base, double power) {
    // Check for Odd Root of Negative Number
    // If Base is Negative AND Exponent is a generic "Odd Root" (like 0.33333 or 0.2)
    // A simplistic check is seeing if 1/exp is an odd integer.
    if (base < 0 && fabs(power) < 1.0) {
        long long inverse = (long long)round(1.0 / power);
        if (inverse % 2 != 0) {
            // Calculate using absolute value, then restore sign
            return -pow(fabs(base), power);
        }
    }

    return pow(base, power);
}

static inline uint64_t RotL64(uint64_t value, int shift) {
    // FIXME: incorrect
    if ((shift &= 63) == 0) return value;
    return (value << shift) | (value >> (64 - shift));
}

static inline uint64_t RotR64(uint64_t value, int shift) {
    // FIXME: incorrect
    if ((shift &= 63) == 0) return value;
    return (value >> shift) | (value << (64 - shift));
}

// --- BYTE FLIP ---
// Reverses the entire byte sequence.
// 0x12345678 -> 0x78563412
static inline uint64_t ByteFlip(uint64_t v, int bitWidth) {
    if (bitWidth == 8)  return v; // 1 byte: nothing to flip
    if (bitWidth == 16) return __builtin_bswap16((uint16_t)v);
    if (bitWidth == 32) return __builtin_bswap32((uint32_t)v);
    return __builtin_bswap64(v);
}

// --- WORD FLIP ---
// Swaps the upper and lower halves of the current word size.
// 32-bit: [High 16] [Low 16] -> [Low 16] [High 16]
static inline uint64_t WordFlip(uint64_t v, int bitWidth) {
    if (bitWidth <= 16) return v; // 16-bit or less: can't swap words
    
    if (bitWidth == 32) {
        // Swap High 16 and Low 16
        uint32_t v32 = (uint32_t)v;
        return (v32 >> 16) | (v32 << 16);
    }
    
    // 64-bit: Swap High 32 and Low 32
    return (v >> 32) | (v << 32);
}

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
                
            case UDOpcodeNegI: {
                if (sp - 1 < 0)
                    goto err;
                unsigned long long a = UDValueAsInt(stack[--sp]);
                
                stack[sp++] = UDValueMakeInt(-a);
            } break;
                
            case UDOpcodeBitAnd: {
                if (sp - 2 < 0)
                    goto err;
                unsigned long long b = UDValueAsInt(stack[--sp]);
                unsigned long long a = UDValueAsInt(stack[--sp]);

                stack[sp++] = UDValueMakeInt(a & b);
            } break;
                
            case UDOpcodeBitOr: {
                if (sp - 2 < 0)
                    goto err;
                unsigned long long b = UDValueAsInt(stack[--sp]);
                unsigned long long a = UDValueAsInt(stack[--sp]);

                stack[sp++] = UDValueMakeInt(a | b);
            } break;

            case UDOpcodeBitXor: {
                if (sp - 2 < 0)
                    goto err;
                unsigned long long b = UDValueAsInt(stack[--sp]);
                unsigned long long a = UDValueAsInt(stack[--sp]);

                stack[sp++] = UDValueMakeInt(a ^ b);
            } break;

            case UDOpcodeBitNot: {
                if (sp - 1 < 0)
                    goto err;
                unsigned long long a = UDValueAsInt(stack[--sp]);

                stack[sp++] = UDValueMakeInt(~a);
            } break;

            case UDOpcodeShiftLeft: {
                if (sp - 2 < 0)
                    goto err;
                unsigned long long b = UDValueAsInt(stack[--sp]);
                unsigned long long a = UDValueAsInt(stack[--sp]);

                stack[sp++] = UDValueMakeInt(a << b);
            } break;
            
            case UDOpcodeShiftRight: {
                if (sp - 2 < 0)
                    goto err;
                unsigned long long b = UDValueAsInt(stack[--sp]);
                unsigned long long a = UDValueAsInt(stack[--sp]);

                stack[sp++] = UDValueMakeInt(a >> b);
            } break;
            
            case UDOpcodeRotateLeft: {
                if (sp - 1 < 0)
                    goto err;
                unsigned long long b = UDValueAsInt(stack[--sp]);
                unsigned long long a = UDValueAsInt(stack[--sp]);

                stack[sp++] = UDValueMakeInt(RotL64(a, (int)b));
            } break;

            case UDOpcodeRotateRight: {
                if (sp - 1 < 0)
                    goto err;
                unsigned long long b = UDValueAsInt(stack[--sp]);
                unsigned long long a = UDValueAsInt(stack[--sp]);

                stack[sp++] = UDValueMakeInt(RotR64(a, (int)b));
            } break;

            case UDOpcodePow: {
                if (sp - 2 < 0)
                    goto err;
                
                double power = UDValueAsDouble(stack[--sp]);
                double base  = UDValueAsDouble(stack[--sp]);

                stack[sp++] = UDValueMakeDouble(Pow(base, power));
            } break;

            case UDOpcodeSqrt: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(sqrt(val));
            } break;

            case UDOpcodeLn: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(log(val));
            } break;

            case UDOpcodeSin: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(sin(val));
            } break;

            case UDOpcodeSinD: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(sin(val * M_PI / 180.0));
            } break;

            case UDOpcodeASin: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(asin(val));
            } break;

            case UDOpcodeASinD: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(asin(val * M_PI / 180.0));
            } break;

            case UDOpcodeCos: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(cos(val));
            } break;

            case UDOpcodeCosD: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(cos(val * M_PI / 180.0));
            } break;

            case UDOpcodeACos: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(acos(val));
            } break;

            case UDOpcodeACosD: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(acos(val * M_PI / 180.0));
            } break;

            case UDOpcodeTan: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(tan(val));
            } break;

            case UDOpcodeTanD: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(tan(val * M_PI / 180.0));
            } break;

            case UDOpcodeATan: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(atan(val));
            } break;

            case UDOpcodeATanD: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(atan(val * M_PI / 180.0));
            } break;

            case UDOpcodeSinH: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(sinh(val));
            } break;

            case UDOpcodeASinH: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(asinh(val));
            } break;

            case UDOpcodeCosH: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(cosh(val));
            } break;

            case UDOpcodeACosH: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(acosh(val));
            } break;

            case UDOpcodeTanH: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(tanh(val));
            } break;

            case UDOpcodeATanH: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(atanh(val));
            } break;

            case UDOpcodeLog10: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(log10(val));
            } break;

            case UDOpcodeLog2: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(log2(val));
            } break;

            case UDOpcodeFact: {
                if (sp - 1 < 0)
                    goto err;

                double val = UDValueAsDouble(stack[--sp]);
                
                stack[sp++] = UDValueMakeDouble(tgamma(val + 1));
            } break;

            case UDOpcodeFlipB: {
                if (sp - 1 < 0) goto err;
                                
                unsigned long long val = UDValueAsInt(stack[--sp]);

                // Heuristic: Guess size based on magnitude
                int width = 64;
                if (val <= 0xFF) width = 8;
                else if (val <= 0xFFFF) width = 16;
                else if (val <= 0xFFFFFFFF) width = 32;
                
                stack[sp++] = UDValueMakeInt(ByteFlip(val, width));

            } break;

            case UDOpcodeFlipW: {
                if (sp - 1 < 0) goto err;

                unsigned long long val = UDValueAsInt(stack[--sp]);
                int width = 64;
                if (val <= 0xFFFF) width = 16;
                else if (val <= 0xFFFFFFFF) width = 32;
                
                stack[sp++] = UDValueMakeInt(WordFlip(val, width));
            } break;

            default: break;
        }
    }
    
    return stack[--sp];

err:
    return UDValueMakeError(UDValueErrorTypeUnderflow);
}


@end
