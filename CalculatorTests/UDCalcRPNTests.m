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
    // Scenario: 5 Enter 10 Drop -> 5
    
    [self.calculator inputNumber:5];
    [self.calculator performOperation:UDOpEnter]; // Stack: [5]
    
    
    [self.calculator inputNumber:10];
    [self.calculator performOperation:UDOpEnter]; // Stack: [5, 10]
    
    // Action
    [self.calculator performOperation:UDOpDrop];  // Stack: [5]
    
    // Verify
    XCTAssertEqual(self.calculator.currentStackValues.count, 2);
    XCTAssertEqualWithAccuracy([self.calculator currentInputValue], 10.0, 0.0001);
    XCTAssertEqual(self.calculator.nodeStack.count, 1);
    XCTAssertEqualWithAccuracy([self.calculator evaluateNode:self.calculator.nodeStack[0]], 5.0, 0.0001);
}

- (void)testRPN_Swap {
    // Scenario: 1 Enter 2 Swap -> X=1, Y=2
    // Stack order: [1, 2] -> Swap -> [2, 1] (Top is X)
    
    [self.calculator inputNumber:1];
    [self.calculator performOperation:UDOpEnter];
    [self.calculator inputNumber:2];
    
    // Action
    [self.calculator performOperation:UDOpSwap];  // Stack: [2, 1]
    
    // Verify Top (X Register) is 1
    XCTAssertEqualWithAccuracy([self.calculator currentInputValue], 1.0, 0.0001);
    
    // Verify Depth 2 (Y Register) is 2
    XCTAssertEqual(self.calculator.nodeStack.count, 1);
    double yVal = [[self.calculator.currentStackValues objectAtIndex:0] doubleValue]; // 0 is bottom
    XCTAssertEqualWithAccuracy(yVal, 2.0, 0.0001);
}

- (void)testRPN_RollDown {
    // Scenario: 1 Enter 2 Enter 3 Enter
    // Stack: [1, 2, 3] (3 is Top/X)
    // Roll Down: X moves to bottom. Y becomes X.
    // Result: [3, 1, 2] (2 is now X)
    
    [self.calculator inputNumber:1];
    [self.calculator performOperation:UDOpEnter];
    [self.calculator inputNumber:2];
    [self.calculator performOperation:UDOpEnter];
    [self.calculator inputNumber:3];
    
    // Action
    [self.calculator performOperation:UDOpRollDown];
    
    // Verify Structure: [3, 1, 2]
    NSArray *stack = self.calculator.currentStackValues;
    XCTAssertEqual(stack.count, 3);
    
    XCTAssertEqualWithAccuracy([stack[0] doubleValue], 3.0, 0.0001); // Bottom
    XCTAssertEqualWithAccuracy([stack[1] doubleValue], 1.0, 0.0001); // Middle
    XCTAssertEqualWithAccuracy([stack[2] doubleValue], 2.0, 0.0001); // Top (X)
}

- (void)testRPN_RollUp {
    // Scenario: 1 Enter 2 Enter 3 Enter
    // Stack: [1, 2, 3] (3 is Top/X)
    // Roll Up: Bottom moves to Top.
    // Result: [2, 3, 1] (1 is now X)
    
    [self.calculator inputNumber:1];
    [self.calculator performOperation:UDOpEnter];
    [self.calculator inputNumber:2];
    [self.calculator performOperation:UDOpEnter];
    [self.calculator inputNumber:3];
    
    // Action
    [self.calculator performOperation:UDOpRollUp];
    
    // Verify Structure: [2, 3, 1]
    NSArray *stack = self.calculator.currentStackValues;
    XCTAssertEqual(stack.count, 3);
    
    XCTAssertEqualWithAccuracy([stack[0] doubleValue], 2.0, 0.0001); // Bottom
    XCTAssertEqualWithAccuracy([stack[1] doubleValue], 3.0, 0.0001); // Middle
    XCTAssertEqualWithAccuracy([stack[2] doubleValue], 1.0, 0.0001); // Top (X)
}

- (void)testRPN_ImplicitEnter {
    // Scenario: 3 Enter 4 +
    // The "4" is in the buffer. Hitting "+" should implicitly flush 4 to stack, then add.
    
    [self.calculator inputNumber:3];
    [self.calculator performOperation:UDOpEnter]; // Stack: [3]
    
    [self.calculator inputNumber:4];              // Buffer: 4, Stack: [3]
    
    // Action: Operator causes implicit push
    [self.calculator performOperation:UDOpAdd];
    
    // Verify Stack has 1 item: (3+4)
    XCTAssertEqual(self.calculator.currentStackValues.count, 1);
    XCTAssertEqualWithAccuracy([self.calculator currentInputValue], 7.0, 0.0001);
}

- (void)testRPN_EnterDup {
    // Scenario: 5 Enter Enter +
    // First Enter pushes 5.
    // Second Enter (while not typing) duplicates 5.
    // + adds them -> 10.
    
    [self.calculator inputNumber:5];
    [self.calculator performOperation:UDOpEnter]; // Stack: [5]. isTyping = NO.
    
    [self.calculator performOperation:UDOpEnter]; // Dup! Stack: [5, 5]
    
    [self.calculator performOperation:UDOpAdd];   // 5+5
    
    XCTAssertEqualWithAccuracy([self.calculator currentInputValue], 10.0, 0.0001);
}

- (void)testRPN_Integration_AreaOfCircle {
    // -------------------------------------------------------------------------
    // SETUP
    // -------------------------------------------------------------------------
    self.calculator.isRPNMode = YES;
    
    // Helper Block to simulate the TableView requesting row count
    NSInteger (^getRowCount)(void) = ^NSInteger{
        NSInteger count = self.calculator.currentStackValues.count;
        return count;
    };
    
    // Helper to get the String for the LAST row (The X Register)
    NSString* (^getXRegisterString)(void) = ^NSString*{
        NSArray *values = [self.calculator currentStackValues];
        
        double val = [[values lastObject] doubleValue];
        return [NSString stringWithFormat:@"%.4g", val]; // Simplified formatting
    };

    // -------------------------------------------------------------------------
    // STEP 0: INITIAL STATE
    // -------------------------------------------------------------------------
    XCTAssertEqual(getRowCount(), 1, @"UI should show 1 row (Phantom Zero)");
    XCTAssertEqualObjects(getXRegisterString(), @"0", @"X Register should be 0");

    // -------------------------------------------------------------------------
    // STEP 1: INPUT RADIUS ("5")
    // -------------------------------------------------------------------------
    [self.calculator inputDigit:5];
    
    // VERIFY:
    // Mode: Typing
    // Stack: [] (Empty)
    // UI: 1 Row (The "Ghost Buffer" Row)
    XCTAssertTrue(self.calculator.isTyping);
    XCTAssertEqual(self.calculator.nodeStack.count, 0);
    XCTAssertEqual(getRowCount(), 1);
    XCTAssertEqualObjects(getXRegisterString(), @"5", @"UI should show buffer '5'");

    // -------------------------------------------------------------------------
    // STEP 2: MULTIPLY (Calculate r^2 -> 25)
    // -------------------------------------------------------------------------
    [self.calculator performOperation:UDOpSquare];
    
    // VERIFY:
    // Mode: Idle
    // Stack: [25] (Consumes 2, Pushes 1)
    // UI: 1 Row
    XCTAssertEqual(self.calculator.nodeStack.count, 0);
    XCTAssertEqual(getRowCount(), 1);
    XCTAssertEqualObjects(getXRegisterString(), @"25");

    // -------------------------------------------------------------------------
    // STEP 3: COMMIT
    // -------------------------------------------------------------------------
    [self.calculator performOperation:UDOpEnter];

    XCTAssertEqual(self.calculator.nodeStack.count, 1);
    XCTAssertEqual(getRowCount(), 2);
    XCTAssertEqualObjects(getXRegisterString(), @"25");

    // -------------------------------------------------------------------------
    // STEP 4: INPUT PI ("3.14159")
    // -------------------------------------------------------------------------
    // Simulate typing: 3 . 1 4 ...
    [self.calculator inputDigit:3];
    [self.calculator inputDecimal]; // Assuming you have a helper/op for this
    [self.calculator inputDigit:1];
    [self.calculator inputDigit:4];
    
    // VERIFY:
    // Mode: Typing
    // Stack: [25] (Still there!)
    // UI: 2 Rows (Row 0: Stack "25", Row 1: Buffer "3.14")
    XCTAssertTrue(self.calculator.isTyping);
    XCTAssertEqual(self.calculator.nodeStack.count, 1);
    XCTAssertEqual(getRowCount(), 2, @"Should show Stack(25) AND Buffer(3.14)");
    XCTAssertEqualObjects(getXRegisterString(), @"3.14"); // The buffer

    // -------------------------------------------------------------------------
    // STEP 5: FINAL MULTIPLY (Area)
    // -------------------------------------------------------------------------
    // Implicit Enter! User hits '*' while typing.
    // 1. "3.14" flushes to stack -> [25, 3.14]
    // 2. '*' consumes both -> [78.5]
    [self.calculator performOperation:UDOpMul];
    
    // VERIFY:
    // Mode: Idle
    // Stack: [78.5]
    // UI: 1 Row
    XCTAssertTrue(self.calculator.isTyping);
    XCTAssertEqual(self.calculator.nodeStack.count, 0);
    XCTAssertEqual(getRowCount(), 1);
    
    double result = [[self.calculator currentStackValues][0] doubleValue];
    XCTAssertEqualWithAccuracy(result, 78.5, 0.1);
}

@end
