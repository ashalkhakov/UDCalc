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
    UDOpcodeDivI
};

@interface UDInstruction : NSObject
@property (nonatomic, readonly) UDOpcode opcode;
@property (nonatomic, readonly) UDValue payload;         // For PUSH
@property (nonatomic, readonly) NSString *stringPayload; // For CALL

+ (instancetype)push:(UDValue)val;
+ (instancetype)op:(UDOpcode)op;
+ (instancetype)call:(NSString *)funcName;

- (NSString *)debugDescription;
@end
