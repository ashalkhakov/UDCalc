//
//  UDInstruction.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDInstruction.h"

@implementation UDInstruction
+ (instancetype)push:(double)val {
    UDInstruction *i = [UDInstruction new];
    i->_opcode = UDOpcodePush; i->_doublePayload = val; return i;
}
+ (instancetype)op:(UDOpcode)op {
    UDInstruction *i = [UDInstruction new];
    i->_opcode = op; return i;
}
+ (instancetype)call:(NSString *)funcName {
    UDInstruction *i = [UDInstruction new];
    i->_opcode = UDOpcodeCall; i->_stringPayload = funcName; return i;
}
- (NSString *)debugDescription {
    if (_opcode == UDOpcodePush) return [NSString stringWithFormat:@"PUSH %.4g", _doublePayload];
    if (_opcode == UDOpcodeCall) return [NSString stringWithFormat:@"CALL %@", _stringPayload];
    return @[@"PUSH", @"ADD", @"SUB", @"MUL", @"DIV", @"NEG", @"CALL"][_opcode];
}
@end
