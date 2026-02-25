//
//  UDCalcRPNTests.m
//  CalculatorTests
//
//  Created by Artyom Shalkhakov on 27.01.2026.
//


#import <XCTest/XCTest.h>
#import "UDCalc.h"

@interface UDCalcRPNTests : XCTestCase
@property (nonatomic, strong) UDCalc *calculator;
@end

@implementation UDCalcRPNTests

- (void)setUp {
    [super setUp];
    self.calculator = [[UDCalc alloc] init];
    self.calculator.isRPNMode = YES; // Enable RPN for these tests
}

- (void)testRPN_Drop {
    [self.calculator inputNumber:UDValueMakeDouble(5)];
    [self.calculator performOperation:UDOpEnter];  // Stack: [5]

    [self.calculator inputNumber:UDValueMakeDouble(10)];
    [self.calculator performOperation:UDOpEnter];  // Stack: [5, 10]

    [self.calculator performOperation:UDOpDrop];   // Removes X=10 -> Stack: [5]

    // X is now 5
    XCTAssertEqual(self.calculator.nodeStack.count, 1);
    XCTAssertEqualWithAccuracy(
        UDValueAsDouble([self.calculator evaluateNode:self.calculator.nodeStack[0]]), 5.0, 1e-9);
    XCTAssertEqualWithAccuracy(
        UDValueAsDouble([self.calculator currentInputValue]), 5.0, 1e-9);
}

- (void)testRPN_Swap {
    [self.calculator inputNumber:UDValueMakeDouble(1)];
    [self.calculator performOperation:UDOpEnter];   // nodeStack=[1]
    [self.calculator inputNumber:UDValueMakeDouble(2)]; // buffer=2, isTyping=YES

    [self.calculator performOperation:UDOpSwap];    // nodeStack=[2,1], isTyping=NO

    // X=1 is nodeStack.lastObject
    XCTAssertEqual(self.calculator.nodeStack.count, 2);
    XCTAssertEqualWithAccuracy(
        UDValueAsDouble([self.calculator currentInputValue]), 1.0, 1e-9,
        @"X register should be 1 after swap");

    // Y=2 is nodeStack[0]
    XCTAssertEqualWithAccuracy(
        UDValueAsDouble([self.calculator evaluateNode:self.calculator.nodeStack[0]]), 2.0, 1e-9,
        @"Y register should be 2 after swap");
}

- (void)testRPN_RollDown {
    // Build stack [1, 2, 3] — 3 typed but not Enter'd
    [self.calculator inputNumber:UDValueMakeDouble(1)]; [self.calculator performOperation:UDOpEnter];
    [self.calculator inputNumber:UDValueMakeDouble(2)]; [self.calculator performOperation:UDOpEnter];
    [self.calculator inputNumber:UDValueMakeDouble(3)]; // isTyping=YES, not committed

    [self.calculator performOperation:UDOpRollDown];
    // flushBufferToStack: [1,2,3]; X=3 moves to bottom → [3,1,2]; X=2

    XCTAssertEqual(self.calculator.nodeStack.count, 3);
    XCTAssertEqualWithAccuracy(
        UDValueAsDouble([self.calculator evaluateNode:self.calculator.nodeStack[0]]), 3.0, 1e-9,
        @"Bottom should be 3");
    XCTAssertEqualWithAccuracy(
        UDValueAsDouble([self.calculator evaluateNode:self.calculator.nodeStack[1]]), 1.0, 1e-9,
        @"Middle should be 1");
    XCTAssertEqualWithAccuracy(
        UDValueAsDouble([self.calculator currentInputValue]), 2.0, 1e-9,
        @"X (top) should be 2");
}

- (void)testRPN_RollUp {
    // Build stack [1, 2, 3] — 3 typed but not Enter'd
    [self.calculator inputNumber:UDValueMakeDouble(1)]; [self.calculator performOperation:UDOpEnter];
    [self.calculator inputNumber:UDValueMakeDouble(2)]; [self.calculator performOperation:UDOpEnter];
    [self.calculator inputNumber:UDValueMakeDouble(3)]; // isTyping=YES, not committed

    [self.calculator performOperation:UDOpRollUp];
    // flushBufferToStack: [1,2,3]; bottom=1 moves to top → [2,3,1]; X=1

    XCTAssertEqual(self.calculator.nodeStack.count, 3);
    XCTAssertEqualWithAccuracy(
        UDValueAsDouble([self.calculator evaluateNode:self.calculator.nodeStack[0]]), 2.0, 1e-9,
        @"Bottom should be 2");
    XCTAssertEqualWithAccuracy(
        UDValueAsDouble([self.calculator evaluateNode:self.calculator.nodeStack[1]]), 3.0, 1e-9,
        @"Middle should be 3");
    XCTAssertEqualWithAccuracy(
        UDValueAsDouble([self.calculator currentInputValue]), 1.0, 1e-9,
        @"X (top) should be 1");
}

- (void)testRPN_ImplicitEnter {
    // Scenario: 3 Enter 4 +
    // The "4" is in the buffer. Hitting "+" should implicitly flush 4 to stack, then add.
    
    [self.calculator inputNumber:UDValueMakeDouble(3)];
    [self.calculator performOperation:UDOpEnter]; // Stack: [3]
    
    [self.calculator inputNumber:UDValueMakeDouble(4)];              // Buffer: 4, Stack: [3]
    
    // Action: Operator causes implicit push
    [self.calculator performOperation:UDOpAdd];
    
    // Verify Stack has 1 item: (3+4)
    XCTAssertEqual(self.calculator.currentStackValues.count, 1);
    XCTAssertEqualWithAccuracy(UDValueAsDouble([self.calculator currentInputValue]), 7.0, 0.0001);
}

- (void)testRPN_ImplicitEnterFactorialOf0 {
    // 0! = 1
    [self.calculator performOperation:UDOpFactorial];
    
    // Verify Stack has 1 item: 1
    XCTAssertEqual(self.calculator.currentStackValues.count, 1);
    XCTAssertEqualWithAccuracy(UDValueAsDouble([self.calculator currentInputValue]), 1.0, 0.0001);
}


- (void)testRPN_EnterDup {
    // Scenario: 5 Enter Enter +
    // First Enter pushes 5.
    // Second Enter (while not typing) duplicates 5.
    // + adds them -> 10.
    
    [self.calculator inputNumber:UDValueMakeDouble(5)];
    [self.calculator performOperation:UDOpEnter]; // Stack: [5]. isTyping = NO.
    
    [self.calculator performOperation:UDOpEnter]; // Dup! Stack: [5, 5]
    
    [self.calculator performOperation:UDOpAdd];   // 5+5
    
    XCTAssertEqualWithAccuracy(UDValueAsDouble([self.calculator currentInputValue]), 10.0, 0.0001);
}

@end
