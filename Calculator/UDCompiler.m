//
//  UDCompiler.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDCompiler.h"
#import "UDFrontend.h"
#import "UDFrontendContext.h"
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

        if (un.info.tag == UDOpNegate) [prog addObject:[UDInstruction op:integerMode ? UDOpcodeNegI : UDOpcodeNeg]];
        else if (un.info.tag == UDOpComp1) [prog addObject:[UDInstruction op:UDOpcodeBitNot]];
        else NSLog(@"Unhandled unary prefix op: %ld", un.info.tag);
    }
    
    else if ([node isKindOfClass:[UDPostfixOpNode class]]) {
        UDPostfixOpNode *pn = (UDPostfixOpNode *)node;
        [self visitNode:pn.child into:prog withIntegerMode:integerMode];
        
        if (pn.info.tag == UDOpPercent) {
            [prog addObject:[UDInstruction push:UDValueMakeDouble(100.0)]];
            [prog addObject:[UDInstruction op:UDOpcodeDiv]];
        } else if (pn.info.tag == UDOpFactorial) {
            [prog addObject:[UDInstruction op:UDOpcodeFact]];
        }
        else NSLog(@"Unhandled postfix op: %ld", pn.info.tag);
    }
    
    // 2. BINARY OPERATOR (Recursively visit Left, then Right, then Op)
    else if ([node isKindOfClass:[UDBinaryOpNode class]]) {
        UDBinaryOpNode *bin = (UDBinaryOpNode *)node;

        // Recursion First (Post-Order Traversal)
        [self visitNode:bin.left into:prog withIntegerMode:integerMode];

        // if the right operand is a postfix with percent operator, and we are looking at a binary op:
        // e.g. 100 + 5% --> translate into
        //   100
        //   + 100 * 0.05
        if ((bin.info.tag == UDOpAdd || bin.info.tag == UDOpSub)
            && [bin.right isKindOfClass:[UDPostfixOpNode class]]
            && ((UDPostfixOpNode *)bin.right).info.tag == UDOpPercent) {
            UDPostfixOpNode *pn = (UDPostfixOpNode *)bin.right;
            
            [self visitNode:bin.left into:prog withIntegerMode:integerMode];

            [self visitNode:pn.child into:prog withIntegerMode:integerMode];
            [prog addObject:[UDInstruction push:integerMode ? UDValueMakeInt(100) : UDValueMakeDouble(100.0)]];
            [prog addObject:[UDInstruction op:integerMode ? UDOpcodeDivI : UDOpcodeDiv]];
            [prog addObject:[UDInstruction op:integerMode ? UDOpcodeMulI : UDOpcodeMul]];
        } else {
            [self visitNode:bin.right into:prog withIntegerMode:integerMode];
        }

        // Emit Opcode
        if (bin.info.tag == UDOpAdd) [prog addObject:[UDInstruction op:integerMode? UDOpcodeAddI : UDOpcodeAdd]];
        else if (bin.info.tag == UDOpSub) [prog addObject:[UDInstruction op:integerMode? UDOpcodeSubI : UDOpcodeSub]];
        else if (bin.info.tag == UDOpMul) [prog addObject:[UDInstruction op:integerMode? UDOpcodeMulI : UDOpcodeMul]];
        else if (bin.info.tag == UDOpDiv) [prog addObject:[UDInstruction op:integerMode? UDOpcodeDivI : UDOpcodeDiv]];
        else if (bin.info.tag == UDOpBitwiseAnd) [prog addObject:[UDInstruction op:UDOpcodeBitAnd]];
        else if (bin.info.tag == UDOpBitwiseOr) [prog addObject:[UDInstruction op:UDOpcodeBitOr]];
        else if (bin.info.tag == UDOpBitwiseXor) [prog addObject:[UDInstruction op:UDOpcodeBitXor]];
        else if (bin.info.tag == UDOpShiftLeft) [prog addObject:[UDInstruction op:UDOpcodeShiftLeft]];
        else if (bin.info.tag == UDOpShiftRight) [prog addObject:[UDInstruction op:UDOpcodeShiftRight]];
        else if (bin.info.tag == UDOpRotateLeft) [prog addObject:[UDInstruction op:UDOpcodeRotateLeft]];
        else if (bin.info.tag == UDOpRotateRight) [prog addObject:[UDInstruction op:UDOpcodeRotateRight]];
        else NSLog(@"Unhandled binary op: %ld", bin.info.tag);
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
