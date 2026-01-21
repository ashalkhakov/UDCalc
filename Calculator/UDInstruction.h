//
//  UDInstruction.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UDOpcode) {
    UDOpcodePush, // Push a number onto stack
    UDOpcodeAdd,  // Pop 2, Add, Push result
    UDOpcodeSub,
    UDOpcodeMul,
    UDOpcodeDiv,
    UDOpcodeNeg,  // unary -
    UDOpcodeCall  // Call a named function (sin, pow, etc.)
};

@interface UDInstruction : NSObject
@property (nonatomic, readonly) UDOpcode opcode;
@property (nonatomic, readonly) double doublePayload;   // For PUSH
@property (nonatomic, readonly) NSString *stringPayload; // For CALL

+ (instancetype)push:(double)val;
+ (instancetype)op:(UDOpcode)op;
+ (instancetype)call:(NSString *)funcName;

- (NSString *)debugDescription;
@end
