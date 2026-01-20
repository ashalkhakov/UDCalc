//
//  UDCompiler.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDCompiler.h"

@implementation UDCompiler

+ (NSArray<UDInstruction *> *)compile:(UDASTNode *)root {
    NSMutableArray *program = [NSMutableArray array];
    [self visitNode:root into:program];
    return program;
}

+ (void)visitNode:(UDASTNode *)node into:(NSMutableArray *)prog {
    // 1. NUMBER NODE
    if ([node isKindOfClass:[UDNumberNode class]]) {
        UDNumberNode *n = (UDNumberNode *)node;
        [prog addObject:[UDInstruction push:n.value]]; // Access property directly
    }
    
    // 2. BINARY OPERATOR (Recursively visit Left, then Right, then Op)
    else if ([node isKindOfClass:[UDBinaryOpNode class]]) {
        UDBinaryOpNode *bin = (UDBinaryOpNode *)node;
        // Recursion First (Post-Order Traversal)
        [self visitNode:bin.left into:prog];
        [self visitNode:bin.right into:prog];
        
        // Emit Opcode
        if ([bin.op isEqualToString:@"+"]) [prog addObject:[UDInstruction op:UDOpcodeAdd]];
        else if ([bin.op isEqualToString:@"−"]) [prog addObject:[UDInstruction op:UDOpcodeSub]];
        else if ([bin.op isEqualToString:@"×"]) [prog addObject:[UDInstruction op:UDOpcodeMul]];
        else if ([bin.op isEqualToString:@"÷"]) [prog addObject:[UDInstruction op:UDOpcodeDiv]];
    }
    
    // 3. FUNCTION CALL
    else if ([node isKindOfClass:[UDFunctionNode class]]) {
        UDFunctionNode *func = (UDFunctionNode *)node;
        // Compile all arguments in order
        for (UDASTNode *arg in func.args) {
            [self visitNode:arg into:prog];
        }
        // Emit Call
        [prog addObject:[UDInstruction call:func.name]];
    }
    
    // 4. PARENS
    else if ([node isKindOfClass:[UDParenNode class]]) {
        UDParenNode *paren = (UDParenNode *)node;
        [self visitNode:paren.child into:prog];
    }
}
@end
