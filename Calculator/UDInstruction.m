//
//  UDInstruction.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDInstruction.h"

@implementation UDInstruction
+ (instancetype)push:(UDValue)val {
    UDInstruction *i = [UDInstruction new];
    i->_opcode = UDOpcodePush; i->_payload = val; return i;
}
+ (instancetype)op:(UDOpcode)op {
    UDInstruction *i = [UDInstruction new];
    i->_opcode = op; return i;
}
- (NSString *)debugDescription {
    switch (_opcode) {
        case UDOpcodeAdd:
            return @"ADD";
        case UDOpcodeSub:
            return @"SUB";
        case UDOpcodeMul:
            return @"MUL";
        case UDOpcodeDiv:
            return @"DIV";
        case UDOpcodeNeg:
            return @"NEG";
        case UDOpcodeAddI:
            return @"ADDI";
        case UDOpcodeSubI:
            return @"SUBI";
        case UDOpcodeMulI:
            return @"MULI";
        case UDOpcodeDivI:
            return @"DIVI";
        default:
            return @"UNKNOWN";
    }
}
@end
