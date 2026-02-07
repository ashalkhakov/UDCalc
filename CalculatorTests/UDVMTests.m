//
//  UDVMTests.m
//  CalculatorTests
//
//  Created by Artyom Shalkhakov on 07.02.2026.
//

#import <XCTest/XCTest.h>
#import "UDVM.h"
#import "UDInstruction.h"
#import "UDConstants.h"

@interface UDVMTests : XCTestCase
@end

@implementation UDVMTests

// --- HELPERS ---

- (UDValue)run:(NSArray<UDInstruction *> *)prog {
    return [UDVM execute:prog];
}

- (UDInstruction *)push:(double)val {
    return [UDInstruction push:UDValueMakeDouble(val)];
}

- (UDInstruction *)pushInt:(unsigned long long)val {
    return [UDInstruction push:UDValueMakeInt(val)];
}

- (UDInstruction *)op:(UDOpcode)opcode {
    return [UDInstruction op:opcode];
}

// --- ARITHMETIC TESTS ---

- (void)testSimpleAddition {
    // 10 + 20 = 30
    NSArray *prog = @[ [self push:10], [self push:20], [self op:UDOpcodeAdd] ];
    UDValue res = [self run:prog];
    XCTAssertEqualWithAccuracy(UDValueAsDouble(res), 30.0, 0.0001);
}

- (void)testDivisionByZeroFloat {
    // 10 / 0 = Error
    NSArray *prog = @[ [self push:10], [self push:0], [self op:UDOpcodeDiv] ];
    UDValue res = [self run:prog];
    XCTAssertEqual(res.type, UDValueTypeErr);
    XCTAssertEqual(UDValueAsError(res), UDValueErrorTypeDivideByZero);
}

- (void)testIntegerArithmetic {
    // 5 + 3 (Integer Mode)
    NSArray *prog = @[ [self pushInt:5], [self pushInt:3], [self op:UDOpcodeAddI] ];
    UDValue res = [self run:prog];
    
    XCTAssertEqual(res.type, UDValueTypeInteger);
    XCTAssertEqual(UDValueAsInt(res), 8);
}

- (void)testNegativeResultInteger {
    // 5 - 10 = -5 (in 2's complement implementation this is huge unsigned,
    // but UDValueAsInt usually treats it as raw bits.
    // If your frontend displays it as signed, that's fine.
    // Here we check bit integrity).
    
    NSArray *prog = @[ [self pushInt:5], [self pushInt:10], [self op:UDOpcodeSubI] ];
    UDValue res = [self run:prog];
    
    // -5 in 64-bit 2's complement is 0xFFFFFFFFFFFFFFFB
    XCTAssertEqual(UDValueAsInt(res), 0xFFFFFFFFFFFFFFFBULL);
}

// --- STACK SAFETY TESTS ---

- (void)testStackUnderflow {
    // Pop empty stack
    NSArray *prog = @[ [self op:UDOpcodeAdd] ];
    UDValue res = [self run:prog];
    XCTAssertEqual(res.type, UDValueTypeErr);
    XCTAssertEqual(UDValueAsError(res), UDValueErrorTypeUnderflow);
}

- (void)testStackOverflow {
    // Push 1025 items
    NSMutableArray *prog = [NSMutableArray array];
    for (int i = 0; i < 1025; i++) {
        [prog addObject:[self push:1]];
    }
    
    UDValue res = [self run:prog];
    XCTAssertEqual(res.type, UDValueTypeErr);
    XCTAssertEqual(UDValueAsError(res), UDValueErrorTypeOverflow);
}

// --- BITWISE & LOGIC TESTS ---

- (void)testBitwiseAnd0 {
    // 0x0F & 0xF0 = 0x00
    NSArray *prog = @[ [self pushInt:0x0F], [self pushInt:0xF0], [self op:UDOpcodeBitAnd] ];
    UDValue res = [self run:prog];
    XCTAssertEqual(UDValueAsInt(res), 0x00);
}

- (void)testBitwiseAnd1 {
    // 0x0F & 0x0F = 0x0F
    NSArray *prog = @[ [self pushInt:0x0F], [self pushInt:0x0F], [self op:UDOpcodeBitAnd] ];
    UDValue res = [self run:prog];
    XCTAssertEqual(UDValueAsInt(res), 0x0F);
}

- (void)testBitwiseOr {
    // 0x01 | 0x02 = 0x03
    NSArray *prog = @[ [self pushInt:0x01], [self pushInt:0x02], [self op:UDOpcodeBitOr] ];
    UDValue res = [self run:prog];
    XCTAssertEqual(UDValueAsInt(res), 0x03);
}

- (void)testBitwiseNot {
    // ~0 = All 1s
    NSArray *prog = @[ [self pushInt:0], [self op:UDOpcodeBitNot] ];
    UDValue res = [self run:prog];
    XCTAssertEqual(UDValueAsInt(res), 0xFFFFFFFFFFFFFFFFULL);
}

// --- ROTATE & SHIFT TESTS ---

- (void)testShiftLeft {
    // 1 << 4 = 16
    NSArray *prog = @[ [self pushInt:1], [self pushInt:4], [self op:UDOpcodeShiftLeft] ];
    UDValue res = [self run:prog];
    XCTAssertEqual(UDValueAsInt(res), 16);
}

- (void)testRotateLeft {
    // Rotate 0x8000...0000 left by 1 -> 0x0000...0001
    unsigned long long val = 1ULL << 63; // Highest bit set
    NSArray *prog = @[ [self pushInt:val], [self pushInt:1], [self op:UDOpcodeRotateLeft] ]; // Rotates by 1 hardcoded in VM
    UDValue res = [self run:prog];
    XCTAssertEqual(UDValueAsInt(res), 1);
}

- (void)testRotateRight {
    // Rotate 0x0000...0001 right by 1 -> 0x8000...0000
    NSArray *prog = @[ [self pushInt:1], [self pushInt:1], [self op:UDOpcodeRotateRight] ];
    UDValue res = [self run:prog];
    unsigned long long expected = 1ULL << 63;
    XCTAssertEqual(UDValueAsInt(res), expected);
}

// --- MATH & FUNCTION TESTS ---

- (void)testPowerBasic {
    // 2^3 = 8
    NSArray *prog = @[ [self push:2], [self push:3], [self op:UDOpcodePow] ];
    UDValue res = [self run:prog];
    XCTAssertEqualWithAccuracy(UDValueAsDouble(res), 8.0, 0.0001);
}

- (void)testOddRootOfNegative {
    // Cube root of -8 -> (-8)^(1/3) should be -2
    // Your VM has specific logic to handle this case
    double third = 1.0/3.0;
    NSArray *prog = @[ [self push:-8], [self push:third], [self op:UDOpcodePow] ];
    UDValue res = [self run:prog];
    XCTAssertEqualWithAccuracy(UDValueAsDouble(res), -2.0, 0.0001);
}

- (void)testEvenRootOfNegative {
    // Square root of -4 -> NaN
    NSArray *prog = @[ [self push:-4], [self push:0.5], [self op:UDOpcodePow] ];
    UDValue res = [self run:prog];
    XCTAssertTrue(isnan(UDValueAsDouble(res)), @"Even root of negative should be NaN");
}

- (void)testTrigDegrees {
    // sin(90 degrees) should be 1
    // Your VM has UDOpcodeSinD
    NSArray *prog = @[ [self push:90], [self op:UDOpcodeSinD] ];
    UDValue res = [self run:prog];
    XCTAssertEqualWithAccuracy(UDValueAsDouble(res), 1.0, 0.0001);
}

- (void)testTrigRadians {
    // sin(PI/2) should be 1
    NSArray *prog = @[ [self push:M_PI_2], [self op:UDOpcodeSin] ];
    UDValue res = [self run:prog];
    XCTAssertEqualWithAccuracy(UDValueAsDouble(res), 1.0, 0.0001);
}

- (void)testFactorial {
    // 5! = 120
    // Implemented via tgamma(n+1)
    NSArray *prog = @[ [self push:5], [self op:UDOpcodeFact] ];
    UDValue res = [self run:prog];
    XCTAssertEqualWithAccuracy(UDValueAsDouble(res), 120.0, 0.0001);
}

// --- PROGRAMMER MODE SPECIFICS ---

// --- FLIP OPERATIONS (Programmer Mode) ---

- (void)testByteFlip_16Bit {
    // Heuristic: Small number (<= 0xFFFF) treated as 16-bit
    // 0x1122 -> 0x2211
    NSArray *prog = @[ [self pushInt:0x1122], [self op:UDOpcodeFlipB] ];
    UDValue res = [self run:prog];
    XCTAssertEqual(UDValueAsInt(res), 0x2211, @"Should swap bytes in 16-bit mode");
}

- (void)testByteFlip_32Bit_AppleCase {
    // Heuristic: Value > 0xFFFF but <= 0xFFFFFFFF treated as 32-bit
    // 0x80000000 (2,147,483,648) -> Reverses to 0x00000080 (128)
    // This confirms full endian swap, not just neighbor swap.
    unsigned long long val = 0x80000000ULL;
    NSArray *prog = @[ [self pushInt:val], [self op:UDOpcodeFlipB] ];
    UDValue res = [self run:prog];
    
    // 80 00 00 00 -> 00 00 00 80
    XCTAssertEqual(UDValueAsInt(res), 0x80, @"Should reverse 4 bytes for 32-bit value");
}

- (void)testByteFlip_64Bit {
    // Heuristic: Value > 32-bit treated as 64-bit
    // 0x1122334455667788 -> 0x8877665544332211
    unsigned long long val = 0x1122334455667788ULL;
    NSArray *prog = @[ [self pushInt:val], [self op:UDOpcodeFlipB] ];
    UDValue res = [self run:prog];
    
    XCTAssertEqual(UDValueAsInt(res), 0x8877665544332211ULL, @"Should reverse 8 bytes for 64-bit value");
}

- (void)testWordFlip_16Bit_Identity {
    // Heuristic: 16-bit value only has 1 word.
    // 0xABCD -> 0xABCD (Nothing to swap with)
    NSArray *prog = @[ [self pushInt:0xABCD], [self op:UDOpcodeFlipW] ];
    UDValue res = [self run:prog];
    
    XCTAssertEqual(UDValueAsInt(res), 0xABCD, @"Word flip on 16-bit value should be identity");
}

- (void)testWordFlip_32Bit {
    // Heuristic: 32-bit value has 2 words.
    // 0x1234 5678 -> 0x5678 1234
    // [High 16] [Low 16] -> [Low 16] [High 16]
    NSArray *prog = @[ [self pushInt:0x12345678], [self op:UDOpcodeFlipW] ];
    UDValue res = [self run:prog];
    
    XCTAssertEqual(UDValueAsInt(res), 0x56781234, @"Should swap high/low 16-bit words");
}

- (void)testWordFlip_32Bit_AppleCase {
    // 65536 (0x0001 0000) -> 1 (0x0000 0001)
    // This confirms we are swapping words, not bytes.
    NSArray *prog = @[ [self pushInt:65536], [self op:UDOpcodeFlipW] ];
    UDValue res = [self run:prog];
    
    XCTAssertEqual(UDValueAsInt(res), 1, @"Should swap 0x0001 and 0x0000 to get 0x0001");
}

- (void)testWordFlip_64Bit {
    // 0x11112222 33334444 -> 0x33334444 11112222
    // Swaps the High 32 and Low 32
    unsigned long long val = 0x1111222233334444ULL;
    NSArray *prog = @[ [self pushInt:val], [self op:UDOpcodeFlipW] ];
    UDValue res = [self run:prog];
    
    XCTAssertEqual(UDValueAsInt(res), 0x3333444411112222ULL, @"Should swap high/low 32-bit halves");
}

@end
