//
//  UDCompiler.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDCompiler.h"
#import "UDConstants.h"

@implementation UDCompiler

+ (NSArray<UDInstruction *> *)compile:(UDASTNode *)root withIntegerMode:(BOOL)integerMode {
    NSMutableArray *program = [NSMutableArray array];
    [self visitNode:root into:program withIntegerMode:integerMode];
    return program;
}

+ (void)visitNode:(UDASTNode *)node into:(NSMutableArray *)prog withIntegerMode:(BOOL)integerMode {
    // 1. NUMBER NODE
    if ([node isKindOfClass:[UDNumberNode class]]) {
        UDNumberNode *n = (UDNumberNode *)node;
        [prog addObject:[UDInstruction push:n.value]]; // Access property directly
    }
    else if ([node isKindOfClass:[UDConstantNode class]]) {
        UDConstantNode *n = (UDConstantNode *)node;
        [prog addObject:[UDInstruction push:n.value]];
    }
    else if ([node isKindOfClass:[UDUnaryOpNode class]]) {
        UDUnaryOpNode *un = (UDUnaryOpNode *)node;
        [self visitNode:un.child into:prog withIntegerMode:integerMode];
        
        if ([un.op isEqualToString:UDConstNeg]) [prog addObject:[UDInstruction op:integerMode ? UDOpcodeNegI : UDOpcodeNeg]];
        else if ([un.op isEqualToString:@"~"]) [prog addObject:[UDInstruction op:UDOpcodeBitNot]];
        else NSLog(@"Unhandled unary prefix op: %@", un.op);
    }
    
    else if ([node isKindOfClass:[UDPostfixOpNode class]]) {
        UDPostfixOpNode *pn = (UDPostfixOpNode *)node;
        [self visitNode:pn.child into:prog withIntegerMode:integerMode];
        
        if ([pn.symbol isEqualToString:@"%"]) {
            [prog addObject:[UDInstruction push:UDValueMakeDouble(100.0)]];
            [prog addObject:[UDInstruction op:UDOpcodeDiv]];
        } else if ([pn.symbol isEqualToString:@"!"]) {
            [prog addObject:[UDInstruction op:UDOpcodeFact]];
        }
        else NSLog(@"Unhandled postfix op: %@", pn.symbol);
    }
    
    // 2. BINARY OPERATOR (Recursively visit Left, then Right, then Op)
    else if ([node isKindOfClass:[UDBinaryOpNode class]]) {
        UDBinaryOpNode *bin = (UDBinaryOpNode *)node;
        // Recursion First (Post-Order Traversal)
        [self visitNode:bin.left into:prog withIntegerMode:integerMode];
        [self visitNode:bin.right into:prog withIntegerMode:integerMode];
        
        // Emit Opcode
        if ([bin.op isEqualToString:UDConstAdd]) [prog addObject:[UDInstruction op:integerMode? UDOpcodeAddI : UDOpcodeAdd]];
        else if ([bin.op isEqualToString:UDConstSub]) [prog addObject:[UDInstruction op:integerMode? UDOpcodeSubI : UDOpcodeSub]];
        else if ([bin.op isEqualToString:UDConstMul]) [prog addObject:[UDInstruction op:integerMode? UDOpcodeMulI : UDOpcodeMul]];
        else if ([bin.op isEqualToString:UDConstDiv]) [prog addObject:[UDInstruction op:integerMode? UDOpcodeDivI : UDOpcodeDiv]];
        else if ([bin.op isEqualToString:UDConstBitAnd]) [prog addObject:[UDInstruction op:UDOpcodeBitAnd]];
        else if ([bin.op isEqualToString:UDConstBitOr]) [prog addObject:[UDInstruction op:UDOpcodeBitOr]];
        else if ([bin.op isEqualToString:UDConstBitXor]) [prog addObject:[UDInstruction op:UDOpcodeBitXor]];
        else if ([bin.op isEqualToString:UDConstShiftLeft]) [prog addObject:[UDInstruction op:UDOpcodeShiftLeft]];
        else if ([bin.op isEqualToString:UDConstShiftRight]) [prog addObject:[UDInstruction op:UDOpcodeShiftRight]];
        else if ([bin.op isEqualToString:UDConstRotateLeft]) [prog addObject:[UDInstruction op:UDOpcodeRotateLeft]];
        else if ([bin.op isEqualToString:UDConstRotateRight]) [prog addObject:[UDInstruction op:UDOpcodeRotateRight]];
        else NSLog(@"Unhandled binary op: %@", bin.op);
    }
    
    // 3. FUNCTION CALL
    else if ([node isKindOfClass:[UDFunctionNode class]]) {
        UDFunctionNode *func = (UDFunctionNode *)node;
        // Compile all arguments in order
        for (UDASTNode *arg in func.args) {
            [self visitNode:arg into:prog withIntegerMode:integerMode];
        }
        // Emit Call
        
        NSString *name = func.name;
        UDOpcode opcode;

        if ([name isEqualToString:UDConstPow]) opcode = UDOpcodePow;
        else if ([name isEqualToString:UDConstSqrt]) opcode = UDOpcodeSqrt;
        else if ([name isEqualToString:UDConstLn]) opcode = UDOpcodeLn;

        else if ([name isEqualToString:UDConstSin]) opcode = UDOpcodeSin;
        else if ([name isEqualToString:UDConstSinD]) opcode = UDOpcodeSinD;
        else if ([name isEqualToString:UDConstASin]) opcode = UDOpcodeASin;
        else if ([name isEqualToString:UDConstASinD]) opcode = UDOpcodeASinD;
        else if ([name isEqualToString:UDConstCos]) opcode = UDOpcodeCos;
        else if ([name isEqualToString:UDConstCosD]) opcode = UDOpcodeCosD;
        else if ([name isEqualToString:UDConstACos]) opcode = UDOpcodeACos;
        else if ([name isEqualToString:UDConstACosD]) opcode = UDOpcodeACosD;
        else if ([name isEqualToString:UDConstTan]) opcode = UDOpcodeTan;
        else if ([name isEqualToString:UDConstTanD]) opcode = UDOpcodeTanD;
        else if ([name isEqualToString:UDConstATan]) opcode = UDOpcodeATan;
        else if ([name isEqualToString:UDConstATanD]) opcode = UDOpcodeATanD;

        else if ([name isEqualToString:UDConstSinH]) opcode = UDOpcodeSinH;
        else if ([name isEqualToString:UDConstASinH]) opcode = UDOpcodeASinH;
        else if ([name isEqualToString:UDConstCosH]) opcode = UDOpcodeCosH;
        else if ([name isEqualToString:UDConstACosH]) opcode = UDOpcodeACosH;
        else if ([name isEqualToString:UDConstTanH]) opcode = UDOpcodeTanH;
        else if ([name isEqualToString:UDConstATanH]) opcode = UDOpcodeATanH;

        else if ([name isEqualToString:UDConstLog10]) opcode = UDOpcodeLog10;
        else if ([name isEqualToString:UDConstLog2]) opcode = UDOpcodeLog2;

        else if ([name isEqualToString:UDConstFact]) opcode = UDOpcodeFact;
        
        else if ([name isEqualToString:UDConstFlipB]) opcode = UDOpcodeFlipB;
        else if ([name isEqualToString:UDConstFlipW]) opcode = UDOpcodeFlipW;
        
        else {
            NSLog(@"Unhandled function call %@", name);
            opcode = UDOpcodeSqrt;
        }

        [prog addObject:[UDInstruction op:opcode]];
    }
    
    // 4. PARENS
    else if ([node isKindOfClass:[UDParenNode class]]) {
        UDParenNode *paren = (UDParenNode *)node;
        [self visitNode:paren.child into:prog withIntegerMode:integerMode];
    }
}
@end
