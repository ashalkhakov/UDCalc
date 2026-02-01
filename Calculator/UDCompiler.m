//
//  UDCompiler.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDCompiler.h"

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
    
    else if ([node isKindOfClass:[UDUnaryOpNode class]]) {
        UDUnaryOpNode *un = (UDUnaryOpNode *)node;
        [self visitNode:un.child into:prog withIntegerMode:integerMode];
        
        if (!integerMode && [un.op isEqualToString:@"-"]) [prog addObject:[UDInstruction op:UDOpcodeNeg]];
        else NSLog(@"Unhandled unary prefix op: %@", un.op);
    }
    
    else if ([node isKindOfClass:[UDPostfixOpNode class]]) {
        UDPostfixOpNode *pn = (UDPostfixOpNode *)node;
        [self visitNode:pn.child into:prog withIntegerMode:integerMode];
        
        if ([pn.symbol isEqualToString:@"%"]) NSLog(@"Not implemented yet: percentage");
        else if ([pn.symbol isEqualToString:@"!"]) [prog addObject:[UDInstruction call:@"fact"]];
        else NSLog(@"Unhandled postfix op: %@", pn.symbol);
    }
    
    // 2. BINARY OPERATOR (Recursively visit Left, then Right, then Op)
    else if ([node isKindOfClass:[UDBinaryOpNode class]]) {
        UDBinaryOpNode *bin = (UDBinaryOpNode *)node;
        // Recursion First (Post-Order Traversal)
        [self visitNode:bin.left into:prog withIntegerMode:integerMode];
        [self visitNode:bin.right into:prog withIntegerMode:integerMode];
        
        // Emit Opcode
        if ([bin.op isEqualToString:@"+"]) [prog addObject:[UDInstruction op:integerMode? UDOpcodeAddI : UDOpcodeAdd]];
        else if ([bin.op isEqualToString:@"-"]) [prog addObject:[UDInstruction op:integerMode? UDOpcodeSubI : UDOpcodeSub]];
        else if ([bin.op isEqualToString:@"*"]) [prog addObject:[UDInstruction op:integerMode? UDOpcodeMulI : UDOpcodeMul]];
        else if ([bin.op isEqualToString:@"/"]) [prog addObject:[UDInstruction op:integerMode? UDOpcodeDivI : UDOpcodeDiv]];
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
        [prog addObject:[UDInstruction call:func.name]];
    }
    
    // 4. PARENS
    else if ([node isKindOfClass:[UDParenNode class]]) {
        UDParenNode *paren = (UDParenNode *)node;
        [self visitNode:paren.child into:prog withIntegerMode:integerMode];
    }
}
@end
