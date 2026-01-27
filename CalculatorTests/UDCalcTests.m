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

- (void)testSimpleAddAST {
    // 2 + 3
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpEq];

    // Construct Expected Tree Manually
    UDASTNode *expected = [UDBinaryOpNode op:@"+"
                                        left:[UDNumberNode value:2]
                                       right:[UDNumberNode value:3]
                                  precedence:UDASTPrecedenceAdd];

    // Check Structure
    // Note: The calculator holds an array of nodes (the stack).
    // After Eq, the stack should contain exactly one root node.
    XCTAssertEqual(self.calculator.nodeStack.count, 1);
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expected);
    
    // Check Value
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 5.0, 0.0001);
}

- (void)testSimpleAddition {
    // 2 + 3 = 5
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpEq];

    // --- Structural Verification ---
    // Expected: (+ 2 3)
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"+"
                                            left:[UDNumberNode value:2.0]
                                           right:[UDNumberNode value:3.0]
                                      precedence:UDASTPrecedenceAdd];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch");
    
    // --- Value Verification ---
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 5.0, 0.0001);
}

- (void)testOrderOfOperations {
    // 2 + 3 * 4 = 14 (Not 20)
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpMul];
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpEq];

    // --- Structural Verification ---
    // Expected: (+ 2 (* 3 4))
    
    // 1. Build the inner multiplication node: (3 * 4)
    UDASTNode *multNode = [UDBinaryOpNode op:@"*"
                                        left:[UDNumberNode value:3.0]
                                       right:[UDNumberNode value:4.0]
                                  precedence:UDASTPrecedenceMul];
    
    // 2. Build the root addition node: 2 + (multNode)
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"+"
                                            left:[UDNumberNode value:2.0]
                                           right:multNode
                                      precedence:UDASTPrecedenceAdd];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Did operator precedence fail?");
    
    // --- Value Verification ---
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

    // --- Structural Verification ---
    // Expected: (* (P (+ 2 3)) 4)
    
    // 1. Inner Addition: 2 + 3
    UDASTNode *addNode = [UDBinaryOpNode op:@"+"
                                       left:[UDNumberNode value:2.0]
                                      right:[UDNumberNode value:3.0]
                                 precedence:UDASTPrecedenceAdd];
    
    // 2. Parenthesis Wrapper: ( ... )
    UDASTNode *parenNode = [UDParenNode wrap:addNode];
    
    // 3. Root Multiplication: parenNode * 4
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"*"
                                            left:parenNode
                                           right:[UDNumberNode value:4.0]
                                      precedence:UDASTPrecedenceMul];

    XCTAssertEqual(self.calculator.nodeStack.count, 1);
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Parentheses logic failed.");

    // --- Value Verification ---
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
    
    // --- Structural Verification ---
    // Expected: (P (* (P (+ 1 2)) (P (+ 3 4))))
    
    // 1. Left Group: (1 + 2)
    UDASTNode *leftAdd = [UDBinaryOpNode op:@"+"
                                       left:[UDNumberNode value:1.0]
                                      right:[UDNumberNode value:2.0]
                                 precedence:UDASTPrecedenceAdd];
    UDASTNode *leftGroup = [UDParenNode wrap:leftAdd];
    
    // 2. Right Group: (3 + 4)
    UDASTNode *rightAdd = [UDBinaryOpNode op:@"+"
                                        left:[UDNumberNode value:3.0]
                                       right:[UDNumberNode value:4.0]
                                  precedence:UDASTPrecedenceAdd];
    UDASTNode *rightGroup = [UDParenNode wrap:rightAdd];
    
    // 3. Multiplication: (1+2) * (3+4)
    UDASTNode *multNode = [UDBinaryOpNode op:@"*"
                                        left:leftGroup
                                       right:rightGroup
                                  precedence:UDASTPrecedenceMul];
    
    // 4. Outer Wrapper: ( ... )
    UDASTNode *expectedTree = [UDParenNode wrap:multNode];

    XCTAssertEqual(self.calculator.nodeStack.count, 1);
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST nesting failed.");
    
    // --- Value Verification ---
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
    
    // 4. Clear current calc
    [self.calculator performOperation:UDOpClear];
    
    // 5. Recall Memory (7.0)
    [self.calculator performOperation:UDOpMR];
    [self.calculator performOperation:UDOpEq];

    // --- Structural Verification ---
    // Expected: The single number 7.0 (recalled from memory)
    UDASTNode *expectedTree = [UDNumberNode value:7.0];

    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should contain exactly one node (the recalled memory)");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch");

    // --- Value Verification ---
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 7.0, 0.0001);
}

- (void)testMemoryClear {
    // 1. Add 5 to memory
    [self.calculator inputDigit:5];
    [self.calculator performOperation:UDOpMAdd];
    
    // 2. Clear memory (Memory becomes 0)
    [self.calculator performOperation:UDOpMC];
    
    // 3. Add 2 to memory (Memory becomes 0 + 2 = 2)
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpMAdd];
    
    // 4. Recall. Should be 2 (not 7)
    [self.calculator performOperation:UDOpClear]; // Clear buffer
    [self.calculator performOperation:UDOpMR];    // Recall 2
    
    [self.calculator performOperation:UDOpEq];    // Flush to stack
    
    // --- Structural Verification ---
    // Expected: The single number 2.0
    UDASTNode *expectedTree = [UDNumberNode value:2.0];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Memory Clear failed.");
    
    // --- Value Verification ---
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 2.0, 0.0001);
}

#pragma mark - Complex Logic & Edge Cases

- (void)testImplicitMultiplication {
    // 5(2) should equal 10
    // This tests if your logic inserts a multiply op before the paren
    [self.calculator inputDigit:5];
    [self.calculator performOperation:UDOpParenLeft]; // ( -> Implicitly triggers '*'
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpParenRight];  // )
    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Expected: 5 * (2)
    // Tree: (* 5 (P 2))
    
    // 1. Inner Group: (2)
    UDASTNode *innerNode = [UDNumberNode value:2.0];
    UDASTNode *parenNode = [UDParenNode wrap:innerNode];
    
    // 2. Root: 5 * parenNode
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"*"
                                            left:[UDNumberNode value:5.0]
                                           right:parenNode
                                      precedence:UDASTPrecedenceMul];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Implicit multiplication failed.");
    
    // --- Value Verification ---
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 10.0, 0.0001);
}

- (void)testImplicitMultiplication2 {
    // Input: 2 + 3 ( 4 )
    // Logic: 2 + 3 * ( 4 )
    // Result: 2 + 12 = 14
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpParenLeft]; // Implicit *
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Expected Tree: (+ 2 (* 3 (P 4)))
    
    // 1. Paren Group: (4)
    UDASTNode *parenNode = [UDParenNode wrap:[UDNumberNode value:4.0]];
    
    // 2. Implicit Multiply: 3 * (4)
    UDASTNode *multNode = [UDBinaryOpNode op:@"*"
                                        left:[UDNumberNode value:3.0]
                                       right:parenNode
                                  precedence:UDASTPrecedenceMul];
    
    // 3. Root Addition: 2 + (3 * 4)
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"+"
                                            left:[UDNumberNode value:2.0]
                                           right:multNode
                                      precedence:UDASTPrecedenceAdd];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Did precedence or implicit mul fail?");
    
    // --- Value Verification ---
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

    // --- Structural Verification ---
    // Expected Tree: (* 2 (P (+ 3 (P (* 4 5)))))
    
    // 1. Innermost: 4 * 5
    UDASTNode *innerMult = [UDBinaryOpNode op:@"*"
                                         left:[UDNumberNode value:4.0]
                                        right:[UDNumberNode value:5.0]
                                   precedence:UDASTPrecedenceMul];
    UDASTNode *innerGroup = [UDParenNode wrap:innerMult];
    
    // 2. Middle: 3 + (4 * 5)
    UDASTNode *addNode = [UDBinaryOpNode op:@"+"
                                       left:[UDNumberNode value:3.0]
                                      right:innerGroup
                                 precedence:UDASTPrecedenceAdd];
    UDASTNode *outerGroup = [UDParenNode wrap:addNode];
    
    // 3. Root: 2 * (...)
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"*"
                                            left:[UDNumberNode value:2.0]
                                           right:outerGroup
                                      precedence:UDASTPrecedenceMul];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Nested parentheses failed.");

    // --- Value Verification ---
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 46.0, 0.0001);
}

- (void)testFloatingPointPrecision {
    // 0.1 + 0.2 = 0.3
    [self.calculator inputNumber:0.1];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputNumber:0.2];
    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Expected Tree: (+ 0.1 0.2)
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"+"
                                            left:[UDNumberNode value:0.1]
                                           right:[UDNumberNode value:0.2]
                                      precedence:UDASTPrecedenceAdd];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch.");
    
    // --- Value Verification ---
    // Using 0.0001 epsilon to catch standard floating point drift
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 0.3, 0.0001);
}

- (void)testImplicitMul_NumberAndParen {
    // Grammar: N ( E ) -> N * ( E )
    // Case: 2 ( 3 ) -> 6
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpParenLeft]; // Implicit * inserted here
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Expected Tree: (* 2 (P 3))
    
    // 1. Parenthesis Content: (3)
    UDASTNode *parenContent = [UDParenNode wrap:[UDNumberNode value:3.0]];
    
    // 2. Root Multiplication: 2 * (3)
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"*"
                                            left:[UDNumberNode value:2.0]
                                           right:parenContent
                                      precedence:UDASTPrecedenceMul];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Implicit multiplication failed.");
    
    // --- Value Verification ---
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
    
    // --- Structural Verification ---
    // Expected Tree: (* (P (+ 1 1)) (P (+ 2 2)))
    
    // 1. Left Group: (1 + 1)
    UDASTNode *leftAdd = [UDBinaryOpNode op:@"+"
                                       left:[UDNumberNode value:1.0]
                                      right:[UDNumberNode value:1.0]
                                 precedence:UDASTPrecedenceAdd];
    UDASTNode *leftGroup = [UDParenNode wrap:leftAdd];
    
    // 2. Right Group: (2 + 2)
    UDASTNode *rightAdd = [UDBinaryOpNode op:@"+"
                                        left:[UDNumberNode value:2.0]
                                       right:[UDNumberNode value:2.0]
                                  precedence:UDASTPrecedenceAdd];
    UDASTNode *rightGroup = [UDParenNode wrap:rightAdd];
    
    // 3. Root Implicit Multiplication
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"*"
                                            left:leftGroup
                                           right:rightGroup
                                      precedence:UDASTPrecedenceMul];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Implicit mul between parens failed.");
    
    // --- Value Verification ---
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 8.0, 0.0001);
}

- (void)testImplicitMul_ComplexRightSide {
    // Case: 2 + 3 ( 4 )
    // Logic: 2 + (3 * 4) = 14
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpParenLeft]; // Should insert * here
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Expected Tree: (+ 2 (* 3 (P 4)))
    // If precedence failed, it would look like (* (+ 2 3) (P 4)) which is wrong.
    
    // 1. Paren Group: (4)
    UDASTNode *parenNode = [UDParenNode wrap:[UDNumberNode value:4.0]];
    
    // 2. Implicit Multiplication: 3 * (4)
    UDASTNode *multNode = [UDBinaryOpNode op:@"*"
                                        left:[UDNumberNode value:3.0]
                                       right:parenNode
                                  precedence:UDASTPrecedenceMul];
    
    // 3. Root Addition: 2 + (3 * 4)
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"+"
                                            left:[UDNumberNode value:2.0]
                                           right:multNode
                                      precedence:UDASTPrecedenceAdd];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Precedence of implicit mul failed.");
    
    // --- Value Verification ---
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 14.0, 0.0001);
}

- (void)testOperatorReplacement {
    // Scenario: User types "2 +", changes mind, types "* 3 ="
    // Expected: The '+' is discarded. Calculation is "2 * 3 = 6".
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    
    // MISTAKE: User meant multiply, not add.
    // The logic must REPLACE the '+' with '*' because no number was typed in between.
    [self.calculator performOperation:UDOpMul];
    
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Expected Tree: (* 2 3)
    // The '+' node should NOT exist in the tree.
    
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"*"
                                            left:[UDNumberNode value:2.0]
                                           right:[UDNumberNode value:3.0]
                                      precedence:UDASTPrecedenceMul];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Operator replacement failed (Did '+' remain?).");
    
    // --- Value Verification ---
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 6.0, 0.0001);
}

- (void)testParenthesisProtection {
    // Scenario: "2 * ( * 4 )"
    // The user mistakenly types '*' immediately after '('.
    // Standard behavior: The calculator ignores the invalid '*' keypress.
    // Result: 2 * ( 4 ) = 8
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpMul];
    [self.calculator performOperation:UDOpParenLeft];
    
    // BAD INPUT: '*' after '('.
    // Expectation: This operation should be ignored or discarded.
    [self.calculator performOperation:UDOpMul];
    
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Expected Tree: (* 2 (P 4))
    
    // 1. Paren Group: (4)
    UDASTNode *parenNode = [UDParenNode wrap:[UDNumberNode value:4.0]];
    
    // 2. Root: 2 * (...)
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"*"
                                            left:[UDNumberNode value:2.0]
                                           right:parenNode
                                      precedence:UDASTPrecedenceMul];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1);
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. The bad operator '*' should have been ignored.");
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 8.0, 0.0001);
}

- (void)testImplicitMul_WithParenthesisProtection {
    // Scenario: "2 ( * 4 )"
    // 1. "2 (" -> Implicitly becomes "2 * ("
    // 2. "*"   -> Bad input after '('. Ignored.
    // 3. "4 )" -> "4 )"
    // Result: 2 * 4 = 8
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpParenLeft]; // Implicit * added
    
    [self.calculator performOperation:UDOpMul];       // Ignored (Protection)
    
    [self.calculator inputDigit:4];
    [self.calculator performOperation:UDOpParenRight];
    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Expected Tree: (* 2 (P 4))
    
    UDASTNode *parenNode = [UDParenNode wrap:[UDNumberNode value:4.0]];
    
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"*"
                                            left:[UDNumberNode value:2.0]
                                           right:parenNode
                                      precedence:UDASTPrecedenceMul];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1);
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch.");
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 8.0, 0.0001);
}

#pragma mark - Postfix ops

- (void)testFactorial {
    // 3! = 6
    [self.calculator inputNumber:3];
    [self.calculator performOperation:UDOpFactorial];
    
    [self.calculator performOperation:UDOpEq];

    // --- Structural Verification ---
    // Expected Tree: (3!)
    
    // 1. Postfix Node: 3!
    UDASTNode *expectedTree = [UDPostfixOpNode symbol:@"!"
                                                child:[UDNumberNode value:3.0]];
    
    // Note: Even though the calculator "auto-calculates" postfix operators for the display,
    // the underlying AST node should remain on the stack until cleared.
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Factorial node failed.");

    // --- Value Verification ---
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 6.0, 0.0001);
}

- (void)testFactorialPrecedence {
    // 2 + 3! = 8 (Not 5!)
    [self.calculator inputNumber:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputNumber:3];
    [self.calculator performOperation:UDOpFactorial];
    
    [self.calculator performOperation:UDOpEq];

    // --- Structural Verification ---
    // Expected Tree: (+ 2 (3!))
    
    // 1. Postfix Node: 3!
    UDASTNode *factorialNode = [UDPostfixOpNode symbol:@"!"
                                                 child:[UDNumberNode value:3.0]];
    
    // 2. Root Addition: 2 + (3!)
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"+"
                                            left:[UDNumberNode value:2.0]
                                           right:factorialNode
                                      precedence:UDASTPrecedenceAdd];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Postfix precedence failed.");

    // --- Value Verification ---
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

    // --- Structural Verification ---
    // Expected Tree: (* (3!) 2)
    
    // 1. Postfix Node: 3!
    UDASTNode *factorialNode = [UDPostfixOpNode symbol:@"!"
                                                 child:[UDNumberNode value:3.0]];
    
    // 2. Root Multiplication: (3!) * 2
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"*"
                                            left:factorialNode
                                           right:[UDNumberNode value:2.0]
                                      precedence:UDASTPrecedenceMul];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Implicit mul after postfix failed.");

    // --- Value Verification ---
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
    // Assuming UDOpSquare creates a Postfix node with symbol "²"
    [self.calculator performOperation:UDOpSquare];

    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Expected Tree: pow((2 + 3), 2)
    
    // 1. Inner Addition: 2 + 3
    UDASTNode *addNode = [UDBinaryOpNode op:@"+"
                                       left:[UDNumberNode value:2.0]
                                      right:[UDNumberNode value:3.0]
                                 precedence:UDASTPrecedenceAdd];
    UDASTNode *parenNode = [UDParenNode wrap:addNode];
    
    // 2. Number: 2
    UDASTNode *constNode = [UDNumberNode value:2.0];
    
    // 3. Postfix Square: (...)²
    UDASTNode *expectedTree = [UDFunctionNode func:@"pow"
                                              args:@[parenNode, constNode]];

    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Square of parens failed.");

    // --- Value Verification ---
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
    
    // --- Structural Verification ---
    // Expected Tree: (* 2 3)
    // The '+' node must be completely discarded/replaced.
    
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"*"
                                            left:[UDNumberNode value:2.0]
                                           right:[UDNumberNode value:3.0]
                                      precedence:UDASTPrecedenceMul];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Operator replacement failed.");
    
    // --- Value Verification ---
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
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:5];
    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Previous Expectation: (+ 5 5) -> INCORRECT (Assumes collapsing)
    // New Expectation: (+ (+ 2 3) 5) -> CORRECT (Preserves history)
    
    // 1. Reconstruct the previous tree (2 + 3)
    UDASTNode *prevTree = [UDBinaryOpNode op:@"+"
                                        left:[UDNumberNode value:2.0]
                                       right:[UDNumberNode value:3.0]
                                  precedence:UDASTPrecedenceAdd];
    
    // 2. Build the new root: (prevTree + 5)
    UDASTNode *expectedTree = [UDBinaryOpNode op:@"+"
                                            left:prevTree
                                           right:[UDNumberNode value:5.0]
                                      precedence:UDASTPrecedenceAdd];

    XCTAssertEqual(self.calculator.nodeStack.count, 1);
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Result chaining should nest the previous tree.");
    
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 10.0, 0.0001);
}

- (void)testResultOverwriting {
    // Scenario: Calculate result, then discard it by typing number.
    // 2 + 3 = (5) ... 10 = 10
    
    [self.calculator inputDigit:2];
    [self.calculator performOperation:UDOpAdd];
    [self.calculator inputDigit:3];
    [self.calculator performOperation:UDOpEq]; // Result 5 (State is Result)
    
    // Restart with Digit
    // Logic: Inputting a digit in Result state implies a NEW calculation.
    // The previous stack (5) is cleared.
    [self.calculator inputDigit:1]; // Should CLEAR 5, Start 1..
    [self.calculator inputDigit:0]; // ..0
    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Expected Tree: 10
    // The previous tree (2+3) is gone.
    
    UDASTNode *expectedTree = [UDNumberNode value:10.0];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Did the calculator fail to clear the previous result?");
    
    // --- Value Verification ---
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 10.0, 0.0001);
}

- (void)testMemorySoftReset {
    // Scenario: Memory Add terminates a sentence.
    // 5 M+ (Buffer still shows 5) ... 6 M+ (Should be just 6, not 56 or 5*6)
    
    [self.calculator inputDigit:5];
    [self.calculator performOperation:UDOpMAdd]; // Mem=5. State should act like "Result Displayed".
    
    [self.calculator inputDigit:6]; // Should RESET buffer to 6
    [self.calculator performOperation:UDOpMAdd]; // Mem=5+6=11.
    
    [self.calculator performOperation:UDOpClear];
    [self.calculator performOperation:UDOpMR];   // Recall 11
    
    [self.calculator performOperation:UDOpEq];
    
    // --- Structural Verification ---
    // Expected Tree: 11.0
    // If soft reset failed, we might see 61 (5 + 56) or 56.
    
    UDASTNode *expectedTree = [UDNumberNode value:11.0];
    
    XCTAssertEqual(self.calculator.nodeStack.count, 1, @"Stack should have 1 root node");
    XCTAssertEqualObjects(self.calculator.nodeStack.lastObject, expectedTree, @"AST structure mismatch. Memory soft reset failed.");
    
    // --- Value Verification ---
    XCTAssertEqualWithAccuracy([self.calculator evaluateCurrentExpression], 11.0, 0.0001);
}

@end
