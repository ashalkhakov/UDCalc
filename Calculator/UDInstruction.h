//
//  UDInstruction.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDValue.h"

typedef NS_ENUM(NSInteger, UDOpcode) {
    // double opcodes
    UDOpcodePush, // Push a number onto stack
    UDOpcodeAdd,  // Pop 2, Add, Push result
    UDOpcodeSub,
    UDOpcodeMul,
    UDOpcodeDiv,
    UDOpcodeNeg,  // unary -
    UDOpcodeCall,  // Call a named function (sin, pow, etc.)

    // integer opcodes
    UDOpcodeAddI,
    UDOpcodeSubI,
    UDOpcodeMulI,
    UDOpcodeDivI,
    UDOpcodeNegI,  // unary -
    UDOpcodeBitAnd,
    UDOpcodeBitOr,
    UDOpcodeBitXor,
    UDOpcodeBitNot,
    UDOpcodeShiftLeft,
    UDOpcodeShiftRight,
    UDOpcodeRotateLeft,
    UDOpcodeRotateRight,
    
    // functions
    UDOpcodePow,
    UDOpcodeSqrt,
    UDOpcodeLn,
    UDOpcodeSin,
    UDOpcodeSinD,
    UDOpcodeASin,
    UDOpcodeASinD,
    UDOpcodeCos,
    UDOpcodeCosD,
    UDOpcodeACos,
    UDOpcodeACosD,
    UDOpcodeTan,
    UDOpcodeTanD,
    UDOpcodeATan,
    UDOpcodeATanD,
    UDOpcodeSinH,
    UDOpcodeASinH,
    UDOpcodeCosH,
    UDOpcodeACosH,
    UDOpcodeTanH,
    UDOpcodeATanH,
    UDOpcodeLog10,
    UDOpcodeLog2,
    UDOpcodeFact,
    UDOpcodeFlipB,
    UDOpcodeFlipW
};

@interface UDInstruction : NSObject
@property (nonatomic, readonly) UDOpcode opcode;
@property (nonatomic, readonly) UDValue payload;         // For PUSH

+ (instancetype)push:(UDValue)val;
+ (instancetype)op:(UDOpcode)op;

- (NSString *)debugDescription;
@end
