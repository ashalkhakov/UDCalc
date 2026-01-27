//
//  CalculatorTests.m
//  CalculatorTests
//
//  Created by Artyom Shalkhakov on 26.01.2026.
//

#import <XCTest/XCTest.h>
#import "UDCalc.h"

@interface UDCalcTests : XCTestCase
@property (nonatomic, strong) UDCalc *calculator;
@end

@implementation UDCalcTests

- (void)setUp {
    [super setUp];
    self.calculator = [[UDCalc alloc] init];
}

- (void)tearDown {
    self.calculator = nil;
    [super tearDown];
}

#pragma mark - Basic Arithmetic & Precedence

- (void)testSimpleAddition {
    // 2 + 3 = 5
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 5.0, 0.0001);
}

- (void)testOrderOfOperations {
    // 2 + 3 * 4 = 14 (Not 20)
    // This validates your Shunting-Yard algorithm implementation
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpMul];
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 14.0, 0.0001);
}

- (void)testParenthesesPriority {
    // (2 + 3) * 4 = 20
    [self.calculator performOperation:UDOpParenLeft]; // (
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpParenRight];  // )
    [self.calculator performOperation:UDOpMul];
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpEq];

    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 20.0, 0.0001);
}

- (void)testDeeplyNestedParentheses {
    // Expression: ((1 + 2) * (3 + 4))
    // Result: 3 * 7 = 21
    
    [self.calculator performOperation:UDOpParenLeft];
    [self.calculator performOperation:UDOpParenLeft];
    [self.calculator inputDigit:1];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpParenRight];
    
    [self.calculator performOperation:UDOpMul];
    
    [self.calculator performOperation:UDOpParenLeft];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpParenRight]; // Close outer
    
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 21.0, 0.0001);
}

#pragma mark - Memory Operations (MC, M+, M-, MR)

- (void)testMemoryAccumulation {
    // Sequence: 10, M+, 2, M+, 5, M- -> Expect Memory = 7
    
    // 1. Enter 10, Add to Memory
    [self.calculator inputNumber:10];
    [self.calculator performOperation:UDOpMAdd];
    
    // 2. Enter 2, Add to Memory
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpMAdd];
    
    // 3. Enter 5, Subtract from Memory
    [self.calculator inputDigit:5];
    [self.calculator performOperation:UDOpMSub];
    
    // 4. Clear current calc (standard workflow)
    [self.calculator performOperation:UDOpClear];
    
    // 5. Recall Memory
    [self.calculator performOperation:UDOpMR];
    
    [self.calculator performOperation:UDOpEq];

    // Check that the engine's current value is now 7
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 7.0, 0.0001);
}

- (void)testMemoryClear {
    // 1. Add 5 to memory
    [self.calculator inputDigit:5];
    [self.calculator performOperation:UDOpMAdd];
    
    // 2. Clear memory
    [self.calculator performOperation:UDOpMC];
    
    // 3. Add 2 to memory
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpMAdd];
    
    // 4. Recall. Should be 2 (not 7)
    [self.calculator performOperation:UDOpClear];
    [self.calculator performOperation:UDOpMR];
    
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 2.0, 0.0001);
}

#pragma mark - Complex Logic & Edge Cases

- (void)testImplicitMultiplication {
    // 5(2) should equal 10
    // This tests if your logic inserts a multiply op before the paren
    [self.calculator inputDigit:5];
    [self.calculator performOperation:UDOpParenLeft]; // (
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpParenRight];  // )
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 10.0, 0.0001);
}

- (void)testImplicitMultiplication2 {
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpParenLeft];
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 14.0, 0.0001);
}

- (void)testNestedParentheses {
    // 2 * (3 + (4 * 5)) = 46
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpMul];
    [self.calculator performOperation:UDOpParenLeft];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator performOperation:UDOpParenLeft];
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpMul];
    [self.calculator inputDigit:5];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpEq];

    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 46.0, 0.0001);
}

- (void)testFloatingPointPrecision {
    // 0.1 + 0.2 usually errors in strict equality, but your engine should handle it reasonably
    [self.calculator inputNumber:0.1];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputNumber:0.2];
    [self.calculator performOperation:UDOpEq];
    
    // Using 0.0001 epsilon to catch standard floating point drift
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 0.3, 0.0001);
}

- (void)testImplicitMul_NumberAndParen {
    // Grammar: N ( E ) -> N * ( E )
    // Case: 2 ( 3 ) -> 6
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpParenLeft];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 6.0, 0.0001);
}

- (void)testImplicitMul_ParenAndParen {
    // Grammar: ( E ) ( E ) -> ( E ) * ( E )
    // Case: ( 1 + 1 ) ( 2 + 2 ) -> 2 * 4 -> 8
    
    // First Group
    [self.calculator performOperation:UDOpParenLeft];
    [self.calculator inputDigit:1];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:1];
    [self.calculator performOperation:UDOpParenRight];
    
    // Second Group (Should trigger implicit *)
    [self.calculator performOperation:UDOpParenLeft];
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpParenRight];
    
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 8.0, 0.0001);
}

- (void)testImplicitMul_ComplexRightSide {
    // Case: 2 + 3 ( 4 )
    // Logic: 2 + (3 * 4) = 14
    // If broken, might parse as (2+3)*4 = 20, or just 3*4=12
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpParenLeft]; // Should insert * here
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 14.0, 0.0001);
}

- (void)testOperatorReplacement {
    // Scenario: User types "2 +", changes mind, types "* 3 ="
    // Expected: The '+' is discarded. Calculation is "2 * 3 = 6".
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    
    // MISTAKE: User meant multiply, not add.
    // Since they haven't typed a number yet, this should REPLACE the '+'.
    [self.calculator performOperation:UDOpMul];
    
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 6.0, 0.0001);
}

- (void)testParenthesisProtection {
    // Scenario: "2 * ( * 4 )"
    //
    // IF BUGGY (Replaces '('):
    // Becomes "2 * * 4" -> "2 * 4" = 8.
    //
    // IF CORRECT (Protects '('):
    // Becomes "2 * ( 0 * 4 )" -> "2 * 0" = 0.
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpMul];
    [self.calculator performOperation:UDOpParenLeft];
    
    // MISTAKE: User types * immediately after (.
    // The logic must NOT replace the ( with *.
    [self.calculator performOperation:UDOpMul];
    
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpEq];
    
    // We expect 0, because ( * 4 ) evaluates to ( 0 * 4 )
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 0.0, 0.0001);
}

- (void)testImplicitMul_WithParenthesisProtection {
    // Scenario: "2 ( * 4 )"
    // 1. "2 (" -> Implicitly becomes "2 * ("
    // 2. "*"   -> Check runs. Top is '('. Must NOT replace.
    // 3. Result -> "2 * ( * 4 )" -> 0.
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpParenLeft]; // Stack: 2, *, (
    
    [self.calculator performOperation:UDOpMul];       // Stack: 2, *, (, *
    
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 0.0, 0.0001);
}

#pragma mark - Postfix ops

- (void)testFactorial {
    // 3! = 6
    [self.calculator inputNumber:3];
    [self.calculator performOperation:UDOpFactorial];
    
    [self.calculator performOperation:UDOpEq];

    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 6.0, 0.0001);
}

- (void)testFactorialPrecedence {
    // 2 + 3! = 8 (Not 5!)
    [self.calculator inputNumber:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputNumber:3];
    [self.calculator performOperation:UDOpFactorial];
    
    [self.calculator performOperation:UDOpEq];

    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 8.0, 0.0001);
}

- (void)testPostfixImplicitMultiplication {
    // 3! 2 = 12
    // This tests that your lastInputState logic works for postfix
    [self.calculator inputNumber:3];
    [self.calculator performOperation:UDOpFactorial];
    
    // User types '2' immediately after '!'. Should insert '*'
    [self.calculator inputNumber:2];

    [self.calculator performOperation:UDOpEq];

    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 12.0, 0.0001);
}

- (void)testSquareOfParenthesis {
    // (2 + 3)² = 25
    [self.calculator performOperation:UDOpParenLeft];
    [self.calculator inputNumber:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputNumber:3];
    [self.calculator performOperation:UDOpParenRight];
    
    // Apply Square to the entire group
    [self.calculator performOperation:UDOpSquare];

    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 25.0, 0.0001);
}

- (void)testDanglingOperators {
    // Scenario: User changes mind.
    // 2 + * 3 = 6 (Last operator wins)
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd]; // Stack: 2, +
    [self.calculator performOperation:UDOpMul]; // Should replace + with *
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 6.0, 0.0001);
}

#pragma mark - Test Reset vs Continue

- (void)testResultChaining {
    // Scenario: Calculate result, then use it immediately.
    // 2 + 3 = (5) + 5 = 10
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpEq]; // Result 5
    
    // Continue with Operator
    [self.calculator performOperation:UDOpAdd]; // Should use 5
    [self.calculator inputDigit:5];
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 10.0, 0.0001);
}

- (void)testResultOverwriting {
    // Scenario: Calculate result, then discard it by typing number.
    // 2 + 3 = (5) ... 10 = 10
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpEq]; // Result 5
    
    // Restart with Digit
    [self.calculator inputDigit:1]; // Should CLEAR 5, Start 1..
    [self.calculator inputDigit:0]; // ..0
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 10.0, 0.0001);
}

- (void)testMemorySoftReset {
    // Scenario: Memory Add terminates a sentence.
    // 5 M+ (Buffer still shows 5) ... 6 M+ (Should be just 6, not 56 or 5*6)
    
    [self.calculator inputDigit:5];
    [self.calculator performOperation:UDOpMAdd]; // Mem=5, Buffer=5
    
    [self.calculator inputDigit:6]; // Should RESET buffer to 6
    [self.calculator performOperation:UDOpMAdd]; // Mem=5+6=11
    
    [self.calculator performOperation:UDOpClear];
    [self.calculator performOperation:UDOpMR];
    
    [self.calculator performOperation:UDOpEq];
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 11.0, 0.0001);
}

@end
