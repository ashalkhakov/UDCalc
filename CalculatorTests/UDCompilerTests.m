//
//  UDCompilerTests.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 07.02.2026.
//

#import <XCTest/XCTest.h>
#import "UDCompiler.h"
#import "UDAST.h"
#import "UDInstruction.h"
#import "UDConstants.h"
#import "UDFrontend.h"

@interface UDCompilerTests : XCTestCase
@end

@implementation UDCompilerTests

// Helper to construct a Number Node
- (UDNumberNode *)num:(double)val {
    return [UDNumberNode value:UDValueMakeDouble(val)];
}

// Helper to check if an instruction matches expected opcode
- (void)assertOpcode:(UDOpcode)expectedOp atIndex:(NSUInteger)index inProgram:(NSArray *)prog {
    XCTAssertTrue(index < prog.count, @"Program too short");
    UDInstruction *inst = prog[index];
    XCTAssertEqual(inst.opcode, expectedOp, @"Instruction at index %lu should be opcode %lu", (unsigned long)index, (unsigned long)expectedOp);
}

// Helper to check if instruction is a PUSH with specific value
- (void)assertPush:(double)val atIndex:(NSUInteger)index inProgram:(NSArray *)prog {
    XCTAssertTrue(index < prog.count);
    UDInstruction *inst = prog[index];
    XCTAssertEqual(inst.opcode, UDOpcodePush);
    XCTAssertEqualWithAccuracy(UDValueAsDouble(inst.payload), val, 0.0001);
}

// =========================================================================
// TEST CASES
// =========================================================================

- (void)testCompileSingleNumber {
    // AST: 42
    UDASTNode *root = [self num:42];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:NO];
    
    XCTAssertEqual(prog.count, 1);
    [self assertPush:42 atIndex:0 inProgram:prog];
}

- (void)testCompileNamedConstant {
    UDASTNode *root = [UDConstantNode value:UDValueMakeDouble(5.0) symbol:@"x"];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:NO];
    
    XCTAssertEqual(prog.count, 1);
    [self assertPush:5 atIndex:0 inProgram:prog];
}

- (void)testSimpleArithmeticFloat {
    // AST: 10 + 20
    UDASTNode *root = [UDBinaryOpNode info:[[UDFrontend shared] infoForOp:UDOpAdd] left:[self num:10] right:[self num:20]];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:NO];
    
    // Expected: PUSH 10, PUSH 20, ADD
    XCTAssertEqual(prog.count, 3);
    [self assertPush:10 atIndex:0 inProgram:prog];
    [self assertPush:20 atIndex:1 inProgram:prog];
    [self assertOpcode:UDOpcodeAdd atIndex:2 inProgram:prog];
}

- (void)testSimpleArithmeticInteger {
    // AST: 10 + 20 (Integer Mode)
    UDASTNode *root = [UDBinaryOpNode info:[[UDFrontend shared] infoForOp:UDOpAdd] left:[self num:10] right:[self num:20]];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:YES];
    
    // Expected: PUSH 10, PUSH 20, ADDI (Integer Add)
    XCTAssertEqual(prog.count, 3);
    [self assertOpcode:UDOpcodeAddI atIndex:2 inProgram:prog];
}

- (void)testOrderOfOperations {
    // AST: (3 + 4) * 5
    // Structure:
    //      *
    //     / \
    //    +   5
    //   / \
    //  3   4
    
    UDASTNode *addNode = [UDBinaryOpNode info:[[UDFrontend shared] infoForOp:UDOpAdd] left:[self num:3] right:[self num:4]];
    UDASTNode *root = [UDBinaryOpNode info:[[UDFrontend shared] infoForOp:UDOpMul] left:addNode right:[self num:5]];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:NO];
    
    // Expected Stack: 3, 4, ADD, 5, MUL
    XCTAssertEqual(prog.count, 5);
    [self assertPush:3 atIndex:0 inProgram:prog];
    [self assertPush:4 atIndex:1 inProgram:prog];
    [self assertOpcode:UDOpcodeAdd atIndex:2 inProgram:prog];
    [self assertPush:5 atIndex:3 inProgram:prog];
    [self assertOpcode:UDOpcodeMul atIndex:4 inProgram:prog];
}

- (void)testUnaryOperations {
    // AST: -5 (Negate)
    UDASTNode *root = [UDUnaryOpNode info:[[UDFrontend shared] infoForOp:UDOpNegate] child:[self num:5]];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:NO];
    
    // Expected: PUSH 5, NEG
    XCTAssertEqual(prog.count, 2);
    [self assertPush:5 atIndex:0 inProgram:prog];
    [self assertOpcode:UDOpcodeNeg atIndex:1 inProgram:prog];
}

- (void)testBitwiseOperations {
    // AST: 5 & 3 (Bitwise AND)
    UDASTNode *root = [UDBinaryOpNode info:[[UDFrontend shared] infoForOp:UDOpBitwiseAnd] left:[self num:5] right:[self num:3]];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:YES];
    
    // Expected: PUSH 5, PUSH 3, AND
    XCTAssertEqual(prog.count, 3);
    [self assertOpcode:UDOpcodeBitAnd atIndex:2 inProgram:prog];
}

- (void)testBitwiseNot {
    // AST: ~7
    UDASTNode *root = [UDUnaryOpNode info:[[UDFrontend shared] infoForOp:UDOpComp1] child:[self num:7]];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:YES];
    
    // Expected: PUSH 7, NOT
    XCTAssertEqual(prog.count, 2);
    [self assertOpcode:UDOpcodeBitNot atIndex:1 inProgram:prog];
}

- (void)testFactorial {
    // AST: 5!
    UDASTNode *root = [UDPostfixOpNode info:[[UDFrontend shared] infoForOp:UDOpFactorial] child:[self num:5]];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:YES];
    
    // Expected: PUSH 5, FACT
    XCTAssertEqual(prog.count, 2);
    [self assertOpcode:UDOpcodeFact atIndex:1 inProgram:prog];
}

- (void)testFunctionCallSingleArg {
    // AST: sin(90)
    // Note: Assuming 'sin' takes 1 arg
    UDFunctionNode *root = [UDFunctionNode func:UDConstSin args:@[[self num:90]]];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:NO];
    
    // Expected: PUSH 90, SIN
    XCTAssertEqual(prog.count, 2);
    [self assertPush:90 atIndex:0 inProgram:prog];
    [self assertOpcode:UDOpcodeSin atIndex:1 inProgram:prog];
}

- (void)testFunctionCallMultiArg {
    // AST: pow(2, 3) -> 2^3
    UDFunctionNode *root = [UDFunctionNode func:UDConstPow args:@[[self num:2], [self num:3]]];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:NO];
    
    // Expected: PUSH 2, PUSH 3, POW
    XCTAssertEqual(prog.count, 3);
    [self assertPush:2 atIndex:0 inProgram:prog]; // Arg 1
    [self assertPush:3 atIndex:1 inProgram:prog]; // Arg 2
    [self assertOpcode:UDOpcodePow atIndex:2 inProgram:prog];
}

- (void)testProgrammerFunctions {
    // AST: flip_w(0x1234)
    UDFunctionNode *root = [UDFunctionNode func:UDConstFlipW args:@[[self num:0x1234]]];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:YES];
    
    // Expected: PUSH 0x1234, FLIP_W
    XCTAssertEqual(prog.count, 2);
    [self assertOpcode:UDOpcodeFlipW atIndex:1 inProgram:prog];
}

- (void)testNestedFunctions {
    // AST: sqrt(pow(3, 2) + pow(4, 2))  => Pythagorean 3-4-5
    
    UDFunctionNode *pow1 = [UDFunctionNode func:UDConstPow args:@[[self num:3], [self num:2]]];
    UDFunctionNode *pow2 = [UDFunctionNode func:UDConstPow args:@[[self num:4], [self num:2]]];
    UDBinaryOpNode *add  = [UDBinaryOpNode info:[[UDFrontend shared] infoForOp:UDOpAdd] left:pow1 right:pow2];
    UDFunctionNode *root = [UDFunctionNode func:UDConstSqrt args:@[add]];
    
    NSArray *prog = [UDCompiler compile:root withIntegerMode:NO];
    
    // Logic Flow:
    // 1. Visit Sqrt Args -> Visit Add
    // 2. Visit Add Left -> Visit Pow1 (Push 3, Push 2, Pow)
    // 3. Visit Add Right -> Visit Pow2 (Push 4, Push 2, Pow)
    // 4. Emit Add
    // 5. Emit Sqrt
    
    int i = 0;
    [self assertPush:3 atIndex:i++ inProgram:prog];
    [self assertPush:2 atIndex:i++ inProgram:prog];
    [self assertOpcode:UDOpcodePow atIndex:i++ inProgram:prog];
    
    [self assertPush:4 atIndex:i++ inProgram:prog];
    [self assertPush:2 atIndex:i++ inProgram:prog];
    [self assertOpcode:UDOpcodePow atIndex:i++ inProgram:prog];
    
    [self assertOpcode:UDOpcodeAdd atIndex:i++ inProgram:prog];
    [self assertOpcode:UDOpcodeSqrt atIndex:i++ inProgram:prog];
}

@end
