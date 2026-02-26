//
//  UDCalcFSMTests.m
//  CalculatorTests
//
//  Covers every well-defined FSM transition for the Shunting-Yard parser.
//  Tests are grouped by the grammar production they exercise.
//
//  State enum reminder:
//    Idle → TypingNumber → AfterValue → AfterOperator → AfterResult
//                                   ↑__________________________|
//                                   (next expression)
//    RPN adds: RPNResult
//

#import <XCTest/XCTest.h>
#import "UDCalc.h"
#import "UDAST.h"
#import "UDFrontend.h"

// ---------------------------------------------------------------------------
#pragma mark - Helpers
// ---------------------------------------------------------------------------

/// Evaluate whatever is currently on top of the stack.
static double calcResult(UDCalc *c) {
    return UDValueAsDouble([c evaluateCurrentExpression]);
}

// ---------------------------------------------------------------------------
#pragma mark - Base class (shared setUp)
// ---------------------------------------------------------------------------

@interface UDCalcFSMTests : XCTestCase
@property (nonatomic, strong) UDCalc *calc;
@end

@implementation UDCalcFSMTests

- (void)setUp {
    [super setUp];
    self.calc = [[UDCalc alloc] init];
    self.calc.isRPNMode = NO;
}

// ===========================================================================
#pragma mark - 1. ATOM: bare number
// ===========================================================================

// Idle --digit--> TypingNumber
- (void)test_Atom_SingleDigit {
    [self.calc inputDigit:7];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 7.0, 1e-9);
}

// TypingNumber --digit--> TypingNumber  (multi-digit number)
- (void)test_Atom_MultiDigit {
    [self.calc inputDigit:4];
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 42.0, 1e-9);
}

// TypingNumber --decimal--> TypingNumber
- (void)test_Atom_DecimalNumber {
    [self.calc inputDigit:3];
    [self.calc inputDecimal];
    [self.calc inputDigit:1];
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 3.14, 1e-9);
}

// Idle --decimal--> TypingNumber  (leading decimal point → "0.5")
- (void)test_Atom_LeadingDecimal {
    [self.calc inputDecimal];
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 0.5, 1e-9);
}

// Idle --constant--> AfterValue
- (void)test_Atom_Constant_Pi {
    [self.calc inputNumber:UDValueMakeDouble(M_PI)];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), M_PI, 1e-9);
}

// ===========================================================================
#pragma mark - 2. ATOM: parenthesised group
// ===========================================================================

// AfterOperator --(--> AfterOperator,  AfterValue --)--> AfterValue
- (void)test_Paren_SimpleGroup {
    // (3) = 3
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 3.0, 1e-9);
}

// Tree structure: (P 3)
- (void)test_Paren_SimpleGroup_Tree {
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpEq];

    UDASTNode *expected = [UDParenNode wrap:[UDNumberNode value:UDValueMakeDouble(3.0)]];
    XCTAssertEqualObjects(self.calc.nodeStack.lastObject, expected);
}

// Nested parens: ((5)) = 5
- (void)test_Paren_Nested {
    [self.calc performOperation:UDOpParenLeft];
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 5.0, 1e-9);
}

// Mismatched ')' is silently ignored (no crash, no state corruption)
- (void)test_Paren_MismatchedClose_Ignored {
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpParenRight]; // spurious ')'
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 3.0, 1e-9);
}

// ===========================================================================
#pragma mark - 3. POSTFIX  (value --postfix--> AfterValue)
// ===========================================================================

// TypingNumber --postfix--> AfterValue
- (void)test_Postfix_Factorial_AfterTyping {
    // 5! = 120
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpFactorial];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 120.0, 1e-9);
}

// Idle --postfix--> AfterValue  (implicit 0)
- (void)test_Postfix_Factorial_ImplicitZero {
    // 0! = 1
    [self.calc performOperation:UDOpFactorial];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 1.0, 1e-9);
    XCTAssertEqual(self.calc.nodeStack.count, 1);
}

// AfterOperator --postfix--> ignored  ("2 + !" should not crash or corrupt)
- (void)test_Postfix_AfterOperator_Ignored {
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpAdd];
    [self.calc performOperation:UDOpFactorial]; // invalid – should be ignored
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 5.0, 1e-9);
}

// Chain of postfixes: AfterValue --postfix--> AfterValue
- (void)test_Postfix_Chain_SquareThenSquare {
    // (3²)² = 81
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpSquare];
    [self.calc performOperation:UDOpSquare];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 81.0, 1e-9);
}

// AfterValue (result of ')') --postfix--> AfterValue
- (void)test_Postfix_AfterCloseParen {
    // (3)! = 6
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpFactorial];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 6.0, 1e-9);
}

- (void)test_Postfix_AdditivePercent {
    // 100 + 10 % = 110
    [self.calc inputDigit:1];
    [self.calc inputDigit:0];
    [self.calc inputDigit:0];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:1];
    [self.calc inputDigit:0];
    [self.calc performOperation:UDOpPercent];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 110.0, 1e-9);
}

- (void)test_Postfix_AdditivePercentRepeat {
    // 100 + 10 % = = 121
    [self.calc inputDigit:1];
    [self.calc inputDigit:0];
    [self.calc inputDigit:0];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:1];
    [self.calc inputDigit:0];
    [self.calc performOperation:UDOpPercent];
    [self.calc performOperation:UDOpEq];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 121.0, 1e-9);
}

// ===========================================================================
#pragma mark - 4. INFIX (binary) operators
// ===========================================================================

// TypingNumber --infix--> AfterOperator
- (void)test_Infix_Addition {
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 7.0, 1e-9);
}

- (void)test_Infix_Subtraction {
    [self.calc inputDigit:9];
    [self.calc performOperation:UDOpSub];
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 5.0, 1e-9);
}

- (void)test_Infix_Multiplication {
    [self.calc inputDigit:6];
    [self.calc performOperation:UDOpMul];
    [self.calc inputDigit:7];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 42.0, 1e-9);
}

- (void)test_Infix_Division {
    [self.calc inputDigit:8];
    [self.calc performOperation:UDOpDiv];
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 2.0, 1e-9);
}

// Precedence: 2 + 3 * 4 = 14  (not 20)
- (void)test_Infix_PrecedenceMulOverAdd {
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpMul];
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 14.0, 1e-9);
}

// Precedence: 2 * 3 + 4 = 10  (left-to-right reduction)
- (void)test_Infix_PrecedenceMulThenAdd {
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpMul];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 10.0, 1e-9);
}

// Left-associativity: 8 - 3 - 2 = 3  (not 7)
- (void)test_Infix_LeftAssociativity {
    [self.calc inputDigit:8];
    [self.calc performOperation:UDOpSub];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpSub];
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 3.0, 1e-9);
}

// Idle --infix--> ignored  (no left operand)
- (void)test_Infix_Idle_Ignored {
    [self.calc performOperation:UDOpAdd]; // ignored
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 5.0, 1e-9);
}

// Duplicates the left operand
- (void)test_Infix_ImplicitOperand {
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpAdd];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 10.0, 1e-9);
}

// ===========================================================================
#pragma mark - 5. OPERATOR REPLACEMENT
// ===========================================================================

// AfterOperator --infix(non-paren top)--> AfterOperator  (replace)
- (void)test_OpReplacement_Basic {
    // "2 + *" -> last op becomes *, so 2 * 3 = 6
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpAdd];
    [self.calc performOperation:UDOpMul]; // replace '+'
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 6.0, 1e-9);
}

// Multiple replacements: last one wins
- (void)test_OpReplacement_MultipleReplacements {
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpAdd];
    [self.calc performOperation:UDOpMul];
    [self.calc performOperation:UDOpSub]; // replace '*'
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), -1.0, 1e-9);
}

// AfterOperator with '(' on top --infix--> ignored  ("2 * ( *" stays intact)
- (void)test_OpReplacement_AfterOpenParen_Ignored {
    // "2 * ( * 4)" should produce 2 * (4) = 8
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpMul];
    [self.calc performOperation:UDOpParenLeft];
    [self.calc performOperation:UDOpMul]; // invalid – ignored
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 8.0, 1e-9);
    XCTAssertEqual(self.calc.nodeStack.count, 1);
}

// ===========================================================================
#pragma mark - 6. IMPLICIT MULTIPLICATION
// ===========================================================================

// TypingNumber --(--> implicit *
- (void)test_ImplicitMul_NumberBeforeParen {
    // 5(2) = 10
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 10.0, 1e-9);
}

// AfterValue --(--> implicit *  (postfix result before paren)
- (void)test_ImplicitMul_PostfixBeforeParen {
    // 3!(2) = 6 * 2 = 12
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpFactorial];
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 12.0, 1e-9);
}

// AfterValue --digit--> implicit *  ("3! 2" -> 3! * 2 = 12)
- (void)test_ImplicitMul_PostfixBeforeDigit {
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpFactorial];
    [self.calc inputDigit:2]; // implicit *
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 12.0, 1e-9);
}

// AfterValue --constant--> implicit *  ("2 π" -> 2 * π)
- (void)test_ImplicitMul_NumberBeforeConstant {
    [self.calc inputDigit:2];
    [self.calc inputNumber:UDValueMakeDouble(M_PI)]; // implicit *
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 2.0 * M_PI, 1e-9);
}

// AfterValue --(--> implicit *  (close-paren result before paren)
- (void)test_ImplicitMul_ParenBeforeParen {
    // (2)(3) = 6
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 6.0, 1e-9);
}

// ===========================================================================
#pragma mark - 7. TERMINATOR: =
// ===========================================================================

// AfterResult --digit--> soft reset, TypingNumber  (Ans discarded)
- (void)test_Eq_ThenDigit_StartsNewExpr {
    [self.calc inputDigit:9];
    [self.calc performOperation:UDOpEq]; // result = 9
    [self.calc inputDigit:3];            // soft reset
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 3.0, 1e-9);
}

// AfterResult --infix--> uses result as left operand  ("Ans + 2")
- (void)test_Eq_ThenOp_UsesAns {
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpEq]; // result = 4
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:6];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 10.0, 1e-9);
}

// AfterResult --constant--> soft reset, then constant  (not "Ans * π")
- (void)test_Eq_ThenConstant_StartsNewExpr {
    [self.calc inputDigit:9];
    [self.calc performOperation:UDOpEq];
    [self.calc inputNumber:UDValueMakeDouble(M_PI)];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), M_PI, 1e-9);
}

// ===========================================================================
#pragma mark - 8. REPETITION
// ===========================================================================

- (void)test_Eq_ThenEq_RepeatsLastInfixOperation {
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpMul];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpEq];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 24.0, 1e-9);
}

// ===========================================================================
#pragma mark - 9. CLEAR OPS
// ===========================================================================

// ClearEntry while typing clears buffer but keeps expression
- (void)test_Clear_WhileTyping_ClearsBuffer {
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:5];           // typing "5"
    [self.calc performOperation:UDOpClear]; // CE
    // "+" is still pending; type new right-hand side
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 5.0, 1e-9);
}

// ClearAll resets everything
- (void)test_ClearAll_ResetsState {
    [self.calc inputDigit:9];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:1];
    [self.calc performOperation:UDOpClearAll];
    [self.calc inputDigit:7];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 7.0, 1e-9);
    XCTAssertEqual(self.calc.nodeStack.count, 1);
}

// ===========================================================================
#pragma mark - 10. MEMORY
// ===========================================================================

- (void)test_Memory_MAddMSubMR {
    // 5 M+ -> memory = 5
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpMAdd];
    XCTAssertEqualWithAccuracy(self.calc.memoryRegister, 5.0, 1e-9);

    // 3 M- -> memory = 2
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpMSub];
    XCTAssertEqualWithAccuracy(self.calc.memoryRegister, 2.0, 1e-9);

    // MR -> inputs 2 as a constant
    [self.calc performOperation:UDOpMR];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 2.0, 1e-9);
}

- (void)test_Memory_MC {
    [self.calc inputDigit:7];
    [self.calc performOperation:UDOpMAdd];
    [self.calc performOperation:UDOpMC];
    XCTAssertEqualWithAccuracy(self.calc.memoryRegister, 0.0, 1e-9);
}

// ===========================================================================
#pragma mark - 11. COMPLEX EXPRESSIONS (grammar sentences)
// ===========================================================================

// 2 + 3 * (4 - 1) = 11
- (void)test_Complex_MixedPrecAndParens {
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpMul];
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpSub];
    [self.calc inputDigit:1];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 11.0, 1e-9);
}

// (1 + 2) * (3 + 4) = 21
- (void)test_Complex_TwoGroups {
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:1];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpMul];
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 21.0, 1e-9);
}

// 4! / (2! * 2!) = 6  (binomial C(4,2))
- (void)test_Complex_FactorialsInExpr {
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpFactorial];
    [self.calc performOperation:UDOpDiv];
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpFactorial];
    [self.calc performOperation:UDOpMul];
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpFactorial];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 6.0, 1e-9);
}

// 2π  (implicit mul, constant)  = 6.2831...
- (void)test_Complex_ImplicitMulPi {
    [self.calc inputDigit:2];
    [self.calc inputNumber:UDValueMakeDouble(M_PI)];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 2.0 * M_PI, 1e-6);
}

// 3² + 4² = 25  (Pythagorean triple verification)
- (void)test_Complex_SumOfSquares {
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpSquare];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpSquare];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 25.0, 1e-9);
}

// (2 + 3)² = 25
- (void)test_Complex_PostfixAfterGroup {
    [self.calc performOperation:UDOpParenLeft];
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpAdd];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpParenRight];
    [self.calc performOperation:UDOpSquare];
    [self.calc performOperation:UDOpEq];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 25.0, 1e-9);
}

// ===========================================================================
#pragma mark - 12. RPN MODE
// ===========================================================================

- (void)setUp_RPN {
    self.calc = [[UDCalc alloc] init];
    self.calc.isRPNMode = YES;
}

// Idle --Enter--> duplicates phantom zero
- (void)test_RPN_Enter_DuplicatesZero {
    [self setUp_RPN];
    [self.calc performOperation:UDOpEnter];
    XCTAssertEqual(self.calc.nodeStack.count, 2);
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 0.0, 1e-9);
}

// TypingNumber --Enter--> commits buffer, RPNResult
- (void)test_RPN_Enter_CommitsBuffer {
    [self setUp_RPN];
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpEnter];
    XCTAssertEqual(self.calc.nodeStack.count, 1);
    XCTAssertFalse(self.calc.isTyping);
}

// RPNResult --Enter--> duplicates X
- (void)test_RPN_Enter_DuplicatesX {
    [self setUp_RPN];
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpEnter];
    [self.calc performOperation:UDOpEnter]; // duplicate 5
    XCTAssertEqual(self.calc.nodeStack.count, 2);
}

// RPNResult --digit--> replaces buffer (push-on-digit)
- (void)test_RPN_RPNResult_DigitReplacesBuffer {
    [self setUp_RPN];
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpEnter]; // [5], RPNResult
    [self.calc inputDigit:3];               // pushes 5, starts new "3"
    XCTAssertEqual(self.calc.nodeStack.count, 1); // old 5 committed
    XCTAssertTrue(self.calc.isTyping);
}

// Basic binary: 3 Enter 4 + = 7
- (void)test_RPN_BinaryAdd {
    [self setUp_RPN];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpEnter];
    [self.calc inputDigit:4];
    [self.calc performOperation:UDOpAdd];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 7.0, 1e-9);
}

// Stack underflow: '+' with empty stack is a no-op
- (void)test_RPN_BinaryAdd_StackUnderflow_NoOp {
    [self setUp_RPN];
    [self.calc performOperation:UDOpAdd]; // empty – should not crash
    XCTAssertEqual(self.calc.nodeStack.count, 0);
}

// Unary: 9 √ = 3
- (void)test_RPN_Unary_Sqrt {
    [self setUp_RPN];
    [self.calc inputDigit:9];
    [self.calc performOperation:UDOpSqrt];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 3.0, 1e-9);
}

// DROP removes X
- (void)test_RPN_Drop {
    [self setUp_RPN];
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpEnter];
    [self.calc inputDigit:3];
    [self.calc performOperation:UDOpEnter];
    [self.calc performOperation:UDOpDrop]; // removes 3
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 5.0, 1e-9);
}

// SWAP swaps X and Y: [3, 5] -> [5, 3]  (X becomes 3 → wait: X is last)
- (void)test_RPN_Swap {
    [self setUp_RPN];
    [self.calc inputDigit:2];
    [self.calc performOperation:UDOpEnter];
    [self.calc inputDigit:8];
    [self.calc performOperation:UDOpEnter];
    // Stack: Y=2, X=8. Without swap: 2 - 8 = -6. With swap: 8 - 2 = 6.
    [self.calc performOperation:UDOpSwap];
    // After swap: Y=8, X=2. Sub: Y - X = 8 - 2 = 6.
    [self.calc performOperation:UDOpSub];
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 6.0, 1e-9);
}

// ROLL DOWN: [A, B, C] -> [C, A, B]  (X goes to bottom)
- (void)test_RPN_RollDown {
    [self setUp_RPN];
    // Build stack [1, 2, 3]
    [self.calc inputDigit:1]; [self.calc performOperation:UDOpEnter];
    [self.calc inputDigit:2]; [self.calc performOperation:UDOpEnter];
    [self.calc inputDigit:3]; [self.calc performOperation:UDOpEnter];
    [self.calc performOperation:UDOpRollDown]; // [3, 1, 2], X=2
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 2.0, 1e-9);
}

// ROLL UP: [A, B, C] -> [B, C, A]  (bottom comes to X)
- (void)test_RPN_RollUp {
    [self setUp_RPN];
    [self.calc inputDigit:1]; [self.calc performOperation:UDOpEnter];
    [self.calc inputDigit:2]; [self.calc performOperation:UDOpEnter];
    [self.calc inputDigit:3]; [self.calc performOperation:UDOpEnter];
    [self.calc performOperation:UDOpRollUp]; // [2, 3, 1], X=1
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 1.0, 1e-9);
}

// Area of circle: r=5, π r² = 25π ≈ 78.54
- (void)test_RPN_Integration_AreaOfCircle {
    [self setUp_RPN];
    [self.calc inputDigit:5];
    [self.calc performOperation:UDOpSquare]; // 25, RPNResult
    [self.calc performOperation:UDOpEnter];  // [25], commit
    [self.calc inputDigit:3]; [self.calc inputDecimal];
    [self.calc inputDigit:1]; [self.calc inputDigit:4];
    [self.calc performOperation:UDOpMul];    // 25 * 3.14 = 78.5
    XCTAssertEqualWithAccuracy(calcResult(self.calc), 78.5, 0.1);
}

@end
