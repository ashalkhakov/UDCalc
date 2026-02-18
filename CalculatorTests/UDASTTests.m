#import <XCTest/XCTest.h>
#import "UDAST.h"
#import "UDFrontend.h"

@interface UDASTTests : XCTestCase
// Helpers to define operators for testing
@property (nonatomic, strong) UDOpInfo *addOp;
@property (nonatomic, strong) UDOpInfo *subOp;
@property (nonatomic, strong) UDOpInfo *mulOp;
@property (nonatomic, strong) UDOpInfo *powOp; // Right Associative
@property (nonatomic, strong) UDOpInfo *factOp;
@end

@implementation UDASTTests

- (void)setUp {
    // Setup standard operator definitions
    // Precedence: Add(30) < Mul(40) < Pow(50)
    self.addOp = [[UDFrontend shared] infoForOp:UDOpAdd];
    self.subOp = [[UDFrontend shared] infoForOp:UDOpSub];
    self.mulOp = [[UDFrontend shared] infoForOp:UDOpMul];
    self.powOp = [[UDFrontend shared] infoForOp:UDOpPow];
    self.factOp = [[UDFrontend shared] infoForOp:UDOpFactorial];
}

#pragma mark - 1. Basic Literals (No Parens)

- (void)testLiterals {
    UDASTNode *num = [UDNumberNode value:UDValueMakeInt(42)];
    XCTAssertEqualObjects([num prettyPrint], @"42");

    UDASTNode *dbl = [UDNumberNode value:UDValueMakeDouble(3.14159)];
    XCTAssertEqualObjects([dbl prettyPrint], @"3,14159");
}

#pragma mark - 2. Simple Binary (No Parens)

- (void)testSimpleBinary {
    // 1 + 2
    UDASTNode *n1 = [UDNumberNode value:UDValueMakeInt(1)];
    UDASTNode *n2 = [UDNumberNode value:UDValueMakeInt(2)];
    UDASTNode *expr = [UDBinaryOpNode info:self.addOp left:n1 right:n2];
    
    XCTAssertEqualObjects([expr prettyPrint], @"1 + 2");
}

#pragma mark - 3. Precedence: Multiplication binds tighter

- (void)testPrecedence_MulbindsTighter {
    // 1 + 2 * 3 -> "1 + 2 * 3"
    // The multiplication (40) is higher than addition (30), so no parens needed.
    UDASTNode *n1 = [UDNumberNode value:UDValueMakeInt(1)];
    UDASTNode *n2 = [UDNumberNode value:UDValueMakeInt(2)];
    UDASTNode *n3 = [UDNumberNode value:UDValueMakeInt(3)];
    
    UDASTNode *mul = [UDBinaryOpNode info:self.mulOp left:n2 right:n3];
    UDASTNode *expr = [UDBinaryOpNode info:self.addOp left:n1 right:mul];
    
    XCTAssertEqualObjects([expr prettyPrint], @"1 + 2 * 3");
}

- (void)testPrecedence_AddNeedsParens {
    // (1 + 2) * 3 -> "(1 + 2) * 3"
    // The addition is the CHILD of the multiplication.
    // Child Prec (30) < Parent Prec (40) -> Wraps in Parens.
    UDASTNode *n1 = [UDNumberNode value:UDValueMakeInt(1)];
    UDASTNode *n2 = [UDNumberNode value:UDValueMakeInt(2)];
    UDASTNode *n3 = [UDNumberNode value:UDValueMakeInt(3)];
    
    UDASTNode *add = [UDBinaryOpNode info:self.addOp left:n1 right:n2];
    UDASTNode *expr = [UDBinaryOpNode info:self.mulOp left:add right:n3];
    
    XCTAssertEqualObjects([expr prettyPrint], @"(1 + 2) * 3");
}

#pragma mark - 4. Associativity: Left (Subtraction)

- (void)testLeftAssociativity_Natural {
    // 1 - 2 - 3 -> "1 - 2 - 3" (Implies (1-2)-3)
    // Structure: Sub( Sub(1,2), 3 )
    UDASTNode *n1 = [UDNumberNode value:UDValueMakeInt(1)];
    UDASTNode *n2 = [UDNumberNode value:UDValueMakeInt(2)];
    UDASTNode *n3 = [UDNumberNode value:UDValueMakeInt(3)];
    
    UDASTNode *leftSub = [UDBinaryOpNode info:self.subOp left:n1 right:n2];
    UDASTNode *expr = [UDBinaryOpNode info:self.subOp left:leftSub right:n3];
    
    XCTAssertEqualObjects([expr prettyPrint], @"1 - 2 - 3");
}

- (void)testLeftAssociativity_Forced {
    // 1 - (2 - 3) -> "1 - (2 - 3)"
    // Structure: Sub( 1, Sub(2,3) )
    // The Right Child (Sub) has SAME precedence as Parent (Sub).
    // Because it is LEFT associative, the right child MUST be wrapped.
    UDASTNode *n1 = [UDNumberNode value:UDValueMakeInt(1)];
    UDASTNode *n2 = [UDNumberNode value:UDValueMakeInt(2)];
    UDASTNode *n3 = [UDNumberNode value:UDValueMakeInt(3)];
    
    UDASTNode *rightSub = [UDBinaryOpNode info:self.subOp left:n2 right:n3];
    UDASTNode *expr = [UDBinaryOpNode info:self.subOp left:n1 right:rightSub];
    
    XCTAssertEqualObjects([expr prettyPrint], @"1 - (2 - 3)");
}

#pragma mark - 5. Associativity: Right (Power)

- (void)testRightAssociativity_Natural {
    // 2 ^ 3 ^ 4 -> "2 ^ 3 ^ 4" (Implies 2^(3^4))
    // Structure: Pow( 2, Pow(3,4) )
    UDASTNode *n2 = [UDNumberNode value:UDValueMakeInt(2)];
    UDASTNode *n3 = [UDNumberNode value:UDValueMakeInt(3)];
    UDASTNode *n4 = [UDNumberNode value:UDValueMakeInt(4)];
    
    UDASTNode *rightPow = [UDBinaryOpNode info:self.powOp left:n3 right:n4];
    UDASTNode *expr = [UDBinaryOpNode info:self.powOp left:n2 right:rightPow];
    
    XCTAssertEqualObjects([expr prettyPrint], @"2 ^ 3 ^ 4");
}

- (void)testRightAssociativity_Forced {
    // (2 ^ 3) ^ 4 -> "(2 ^ 3) ^ 4"
    // Structure: Pow( Pow(2,3), 4 )
    // The Left Child (Pow) has SAME precedence as Parent (Pow).
    // Because it is RIGHT associative, the left child MUST be wrapped.
    UDASTNode *n2 = [UDNumberNode value:UDValueMakeInt(2)];
    UDASTNode *n3 = [UDNumberNode value:UDValueMakeInt(3)];
    UDASTNode *n4 = [UDNumberNode value:UDValueMakeInt(4)];
    
    UDASTNode *leftPow = [UDBinaryOpNode info:self.powOp left:n2 right:n3];
    UDASTNode *expr = [UDBinaryOpNode info:self.powOp left:leftPow right:n4];
    
    XCTAssertEqualObjects([expr prettyPrint], @"(2 ^ 3) ^ 4");
}

#pragma mark - 6. Postfix / Unary Mixing

- (void)testPostfixFactorial {
    // 5! + 2 -> "5! + 2"
    // Factorial binds tighter than Add. No parens.
    UDASTNode *n5 = [UDNumberNode value:UDValueMakeInt(5)];
    UDASTNode *n2 = [UDNumberNode value:UDValueMakeInt(2)];
    
    // NOTE: You need to make sure UDPostfixOpNode returns High Precedence (e.g. 60 or 100)
    UDASTNode *fact = [UDPostfixOpNode info:self.factOp child:n5];
    UDASTNode *expr = [UDBinaryOpNode info:self.addOp left:fact right:n2];
    
    XCTAssertEqualObjects([expr prettyPrint], @"5! + 2");
}

- (void)testPostfixFactorial_Wrapped {
    // (5 + 2)! -> "(5 + 2)!"
    // Add (30) is lower than Factorial (assume 60). Wraps child.
    UDASTNode *n5 = [UDNumberNode value:UDValueMakeInt(5)];
    UDASTNode *n2 = [UDNumberNode value:UDValueMakeInt(2)];
    
    UDASTNode *add = [UDBinaryOpNode info:self.addOp left:n5 right:n2];
    UDASTNode *expr = [UDPostfixOpNode info:self.factOp child:add];
    
    XCTAssertEqualObjects([expr prettyPrint], @"(5 + 2)!");
}

#pragma mark - 7. Functions

- (void)testFunctionCalls {
    // sin(x) + 1 -> "sin(x) + 1"
    UDASTNode *x = [UDConstantNode value:UDValueMakeError(UDValueErrorTypeUnknown) symbol:@"x"];
    UDASTNode *one = [UDNumberNode value:UDValueMakeInt(1)];
    
    UDASTNode *func = [UDFunctionNode func:@"sin" args:@[x]];
    UDASTNode *expr = [UDBinaryOpNode info:self.addOp left:func right:one];
    
    XCTAssertEqualObjects([expr prettyPrint], @"sin(x) + 1");
}

- (void)testFunctionArguments_NoParensNeeded {
    // sin(x + 1) -> "sin(x + 1)"
    // The function node itself manages the parens around its arguments list.
    // It shouldn't double wrap like "sin((x + 1))"
    UDASTNode *x = [UDConstantNode value:UDValueMakeError(UDValueErrorTypeUnknown) symbol:@"x"];
    UDASTNode *one = [UDNumberNode value:UDValueMakeInt(1)];
    UDASTNode *add = [UDBinaryOpNode info:self.addOp left:x right:one];
    
    UDASTNode *func = [UDFunctionNode func:@"sin" args:@[add]];
    
    XCTAssertEqualObjects([func prettyPrint], @"sin(x + 1)");
}

@end
