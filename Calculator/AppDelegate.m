//
//  AppDelegate.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import "AppDelegate.h"
#import "UDCalcButton.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application

    self.calc = [[UDCalc alloc] init];
    self.unitConverter = [[UDUnitConverter alloc] init];
    self.historyManager = [[UDConversionHistoryManager alloc] init];
    self.tape = [[UDTape alloc] init];

    [self updateScientificButtons];
    [self updateUI];
    [self updateRecentMenu];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(paste:)) {
        // Only enable Paste if the clipboard has a string
        return [[NSPasteboard generalPasteboard] canReadItemWithDataConformingToTypes:@[NSPasteboardTypeString]];
    }
    return YES;
}

#pragma mark - Button Actions
#pragma mark - Button Actions

- (IBAction)showTape:(id)sender {
    if (!self.tapeWindowController) {
        self.tapeWindowController = [[UDTapeWindowController alloc] initWithWindowNibName:@"UDTapeWindow"];
        self.tape.windowController = self.tapeWindowController;
    }
    [self.tapeWindowController showWindow:self];
}

- (IBAction)digitPressed:(NSButton *)sender {
    NSString *buttonName = sender.identifier;
    NSInteger digit = 0;
    
    if ([buttonName length] == 2 && [buttonName characterAtIndex:0] == 'b' && isdigit([buttonName characterAtIndex:1])) {
        digit = [buttonName characterAtIndex:1] - '0';
    } else {
        NSLog(@"Unsupported button name %@", buttonName);
        return;
    }
    
    [self.calc inputDigit:digit];

    [self updateUI];
}

- (IBAction)decimalPressed:(NSButton *)sender {
    // 1. Update Calc
    // This switches 'typing' to YES and sets the internal decimal multiplier
    [self.calc inputDecimal];

    // 3. Refresh Display
    [self updateUI];
}

- (IBAction)operationPressed:(NSButton *)sender {
    NSString *opTitle = sender.identifier;
    NSInteger tag = sender.tag;
    UDOp op = UDOpNone;
    
    switch (tag) {
        case CalcButtonTypeStandard:
            // Map button titles to Enum
            if ([opTitle isEqualToString:@"add"]) op = UDOpAdd;
            else if ([opTitle isEqualToString:@"sub"]) op = UDOpSub;
            else if ([opTitle isEqualToString:@"mul"]) op = UDOpMul; // or "x" or "X"
            else if ([opTitle isEqualToString:@"div"]) op = UDOpDiv; // or "÷"
            else if ([opTitle isEqualToString:@"equals"]) op = UDOpEq;
            else if ([opTitle isEqualToString:@"clear"]) op = UDOpClear;
            else if ([opTitle isEqualToString:@"negate"]) op = UDOpNegate;
            else if ([opTitle isEqualToString:@"percent"]) op = UDOpPercent;
            else if ([opTitle isEqualToString:@"lparen"]) op = UDOpParenLeft;
            else if ([opTitle isEqualToString:@"rparen"]) op = UDOpParenRight;
            else if ([opTitle isEqualToString:@"pi"]) op = UDOpConstPi;
            else if ([opTitle isEqualToString:@"e"]) op = UDOpConstE;
            else if ([opTitle isEqualToString:@"rand"]) op = UDOpRand;
            // row:
            else if ([opTitle isEqualToString:@"sqr"]) op = UDOpSquare;
            else if ([opTitle isEqualToString:@"pow"]) op = UDOpPow;
            else if ([opTitle isEqualToString:@"e_pow_x"]) op = UDOpExp;
            else if ([opTitle isEqualToString:@"_10_pow_x"]) op = UDOpPow10;
            else if ([opTitle isEqualToString:@"_2_pow_x"]) op = UDOpPow2;
            else if ([opTitle isEqualToString:@"rad"]) op = UDOpRad;
            else if ([opTitle isEqualToString:@"fact"]) op = UDOpFactorial;
            else if ([opTitle isEqualToString:@"ln"]) op = UDOpLn;
            break;
            
        case CalcButtonTypePi:           // Pi symbol
            op = UDOpConstPi;
            break;
        case CalcButtonTypeInverse:      // 1/x
            op = UDOpInvert;
            break;

        // --- Standard Trig ---
        case CalcButtonTypeSin:          // sin
            op = UDOpSin;
            break;
        case CalcButtonTypeCos:          // cos
            op = UDOpCos;
            break;
        case CalcButtonTypeTan:          // tan
            op = UDOpTan;
            break;
        case CalcButtonTypeSinh:         // sinh
            op = UDOpSinh;
            break;
        case CalcButtonTypeCosh:         // cosh
            op = UDOpCosh;
            break;
        case CalcButtonTypeTanh:         // tanh
            op = UDOpTanh;
            break;
            
        // Inverse Trig
        case CalcButtonTypeSinInverse:   // sin^-1
            op = UDOpSinInverse;
            break;
        case CalcButtonTypeCosInverse:   // cos^-1
            op = UDOpCosInverse;
            break;
        case CalcButtonTypeTanInverse:   // tan^-1
            op = UDOpTanInverse;
            break;
        case CalcButtonTypeSinhInverse:  // sinh^-1
            op = UDOpSinhInverse;
            break;
        case CalcButtonTypeCoshInverse:  // cosh^-1
            op = UDOpCoshInverse;
            break;
        case CalcButtonTypeTanhInverse:  // tanh^-1
            op = UDOpTanhInverse;
            break;

        // Standard Exponents
        case CalcButtonTypeSquare:      // x^2
            op = UDOpSquare;
            break;
        case CalcButtonTypeCube:        // x^3
            op = UDOpCube;
            break;
        case CalcButtonTypePower:       // x^y
            op = UDOpPow;
            break;
        case CalcButtonTypePowerYtoX:   // y^x
            op = UDOpPowRev;
            break;
        case CalcButtonTypePower2toX:   // 2^x
            op = UDOpPow2;
            break;
        case CalcButtonTypeExp:         // e^x
            op = UDOpExp;
            break;
        case CalcButtonTypeTenPower:    // 10^x
            op = UDOpPow10;
            break;
        case CalcButtonType2nd:         // 2nd
            self.isSecondFunctionActive = !self.isSecondFunctionActive;

            // Visual Feedback: Make the "2nd" button look pressed/highlighted
            sender.state = self.isSecondFunctionActive ? NSControlStateValueOn : NSControlStateValueOff;
            
            [self updateScientificButtons];
            return;

        // Logarithms
        case CalcButtonTypeLog10:        // log10
            op = UDOpLog10;
            break;
        case CalcButtonTypeLog2:         // log2 <-- NEW
            op = UDOpLog2;
            break;
        case CalcButtonTypeLogY:         // logy <-- NEW
            op = UDOpLogY;
            break;

        // Roots & Others
        case CalcButtonTypeSqrt:         // sqrt(x)
            op = UDOpSqrt;
            break;
        case CalcButtonTypeCubeRoot:     // 3rd root
            op = UDOpCbrt;
            break;
        case CalcButtonTypeYRoot:       // y-th root
            op = UDOpYRoot;
            break;
    }
    
    // CONSTANTS: Treat them as number inputs!
    if (op == UDOpConstPi) {
        [self.calc inputNumber:M_PI]; // You'll need to add this method
    } else if (op == UDOpConstE) {
        [self.calc inputNumber:M_E];
    } else if (op == UDOpClear) {
        // 1. Handle CLEAR separately
        [self.calc reset]; // Or performOperation:UDOpClear
    } else if (op == UDOpEq) {

        // CASE 1: EQUALS (=)
        // 1. Force the calculator to finish pending ops (like "5 + 3")
        // This collapses the NodeStack into a single Result Node.
        [self.calc performOperation:UDOpEq];

        // 2. Capture the Result
        // The Shunting Yard leaves exactly one node (the root) on the stack after Eq.
        UDASTNode *resultTree = [self.calc.nodeStack lastObject];

        double resultVal = self.calc.currentInputValue;
                
        // 3. Log to Tape (History Update)
        if (resultTree) {
            [self.tape logTransaction:resultTree result:resultVal];
        }
                
    } else {
        // CASE 2: BINARY OPERATORS (+, -, *, /)

        // Update Calculator.
        // Perform the Shunting Yard logic (stacking the operator).
        [self.calc performOperation:op];
    }
    
    // 3. Update Display
    [self updateUI];
}

// Connect 'mc' button here
- (IBAction)memoryClearPressed:(id)sender {
    //[self.calc memClear];
    [self.calc performOperation:UDOpMC];

    // Optional: Flash the display or show "M" indicator on Tape?
    [self updateUI];
}

// Connect 'm+' button here
- (IBAction)memoryAddPressed:(id)sender {
   // [self.calc memAdd];
    [self.calc performOperation:UDOpMAdd];

    // Standard behavior: Add current display value to memory
    // If user is typing "5", add 5. If result is "10", add 10.
    //self.calc.memoryValue += self.calc.currentValue;
    [self updateUI];
}

// Connect 'm-' button here
- (IBAction)memorySubPressed:(id)sender {
    [self.calc performOperation:UDOpMSub];
//    self.calc.memoryValue -= self.calc.currentValue;
    //[self.calc memSub];
    [self updateUI];
}

// Connect 'mr' button here
- (IBAction)memoryRecallPressed:(id)sender {
    // Treat this exactly like typing a number
    //[self.calc memRecall];
    [self.calc performOperation:UDOpMR];
    
    //[self.tape updateDraftValue:self.calc.memoryValue];
    [self updateUI];
}

-(void)createConverterWindow {
    if (!self.converterWindow) {
        self.converterWindow = [[UDConversionWindowController alloc] initWithWindowNibName:@"ConversionWindow"];
        
        // Inject dependencies
        self.converterWindow.calc = self.calc;
        self.converterWindow.converter = self.unitConverter;
        
        // Define what happens after conversion
        __weak typeof(self) weakSelf = self;
        self.converterWindow.didConvertBlock = ^(NSString *c, NSString *f, NSString *t) {
            [weakSelf updateUI];
            [weakSelf addToHistory:@{ @"cat":c, @"from":f, @"to":t }];
        };
    }
}

- (IBAction)openConverter:(id)sender {
    // Lazy initialization check
    [self createConverterWindow];
    
    // Show the window
    [self.converterWindow showWindow:self];
}

- (void)openConversionWithType:(NSString *)type {
    // Ensure window exists
    [self createConverterWindow];
    
    // Show it
    [self.converterWindow showWindow:self];
    
    // Set the specific type
    [self.converterWindow selectCategory:type];
}

- (IBAction)secondFunctionPressed:(NSButton *)sender {
    self.isSecondFunctionActive = !self.isSecondFunctionActive;

    // Visual Feedback: Make the "2nd" button look pressed/highlighted
    sender.state = self.isSecondFunctionActive ? NSControlStateValueOn : NSControlStateValueOff;
    
    [self updateScientificButtons];
}

- (void)updateScientificButtons {
    BOOL second = self.isSecondFunctionActive;
    
    /*
     // TODO:
     // Example in ViewDidLoad
     self.squareRootBtn.symbolType = MathButtonTypeSqrt;
     self.cubeRootBtn.symbolType = MathButtonTypeCubeRoot;
     self.piBtn.symbolType = MathButtonTypePi;
     // Force redraw
     [self.squareRootBtn setNeedsDisplay:YES];
     
     // Example: Configuring the "Square Root" button
     MathButton *sqrtBtn = [[MathButton alloc] initWithFrame:NSMakeRect(0, 0, 60, 50)];
     sqrtBtn.symbolType = MathButtonTypeSqrt;

     // Set it to "Function" style (Dark Grey)
     sqrtBtn.buttonColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];
     sqrtBtn.highlightColor = [NSColor colorWithCalibratedWhite:0.5 alpha:1.0]; // Flash lighter

     // Example: Configuring the "2nd" button (often lighter grey)
     MathButton *secondBtn = [[MathButton alloc] initWithFrame:NSMakeRect(60, 0, 60, 50)];
     secondBtn.symbolType = MathButtonType2nd;
     secondBtn.buttonColor = [NSColor colorWithCalibratedWhite:0.35 alpha:1.0]; // Light Grey
     secondBtn.highlightColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
     secondBtn.textColor = [NSColor blackColor]; // Text might need to be black on light buttons
     */

    // Helper block to swap button state
    void (^setBtn)(NSButton*, CalcButtonType, CalcButtonType) =
    ^(NSButton *b, CalcButtonType norm, CalcButtonType sec) {
        if (![b isKindOfClass:[UDCalcButton class]]) {
            NSLog(@"wrong kind of button");
            return;
        }
        
        UDCalcButton *calcButton = (UDCalcButton *)b;
        
        if (second) {
            calcButton.symbolType = sec;
        } else {
            calcButton.symbolType = norm;
        }
    };
    
    setBtn(self.expButton, CalcButtonTypeExp, CalcButtonTypePowerYtoX);
    setBtn(self.xthPowerOf10Button, CalcButtonTypeTenPower, CalcButtonTypePower2toX);
    if ([self.lnButton isKindOfClass:[UDCalcButton class]]) {
        if (second) {
            self.lnButton.title = @"";
            ((UDCalcButton *)self.lnButton).symbolType = CalcButtonTypeLogY;
        } else {
            self.lnButton.title = @"ln";
            ((UDCalcButton *)self.lnButton).symbolType = CalcButtonTypeStandard;
        }
    }
    setBtn(self.log10Button, CalcButtonTypeLog10, CalcButtonTypeLog2);
    setBtn(self.sinButton, CalcButtonTypeSin, CalcButtonTypeSinInverse);
    setBtn(self.cosButton, CalcButtonTypeCos, CalcButtonTypeCosInverse);
    setBtn(self.tanButton, CalcButtonTypeTan, CalcButtonTypeTanInverse);
    setBtn(self.sinhButton, CalcButtonTypeSinh, CalcButtonTypeSinhInverse);
    setBtn(self.coshButton, CalcButtonTypeCosh, CalcButtonTypeCoshInverse);
    setBtn(self.tanhButton, CalcButtonTypeTanh, CalcButtonTypeTanhInverse);
}

- (IBAction)conversionMenuClicked:(NSMenuItem *)sender {
    // CASE A: History (Headless)
    if (sender.representedObject) {
        NSDictionary *data = sender.representedObject;
        
        // 1. Use the UnitConverter directly
        double result = [self.unitConverter convertValue:self.calc.currentInputValue
                                                category:data[@"cat"]
                                                fromUnit:data[@"from"]
                                                  toUnit:data[@"to"]];
        
        [self.calc inputNumber:result];
        [self updateUI];
        [self addToHistory:data];
        return;
    }
        
    // CASE B: Open Window
    if (sender.identifier && [sender.identifier length] > 4) {
        NSString *type = [sender.identifier substringFromIndex:4];
        [self openConversionWithType:type];
    }
}

- (void)addToHistory:(NSDictionary *)conversionDict {
    [self.historyManager addConversion:conversionDict];
    
    [self updateRecentMenu];
}

- (void)updateRecentMenu {
    if (!self.recentMenu) return;
    [self.recentMenu removeAllItems];
    
    // Ask the manager for the data
    NSArray *history = self.historyManager.history;
    
    if (history.count == 0) {
        [self.recentMenu addItemWithTitle:@"No Recent Items" action:nil keyEquivalent:@""];
    } else {
        for (NSDictionary *dict in history) {
            NSString *title = [NSString stringWithFormat:@"%@: %@ → %@",
                               dict[@"cat"], dict[@"from"], dict[@"to"]];
            
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                          action:@selector(conversionMenuClicked:)
                                                   keyEquivalent:@""];
            [item setTarget:self];
            item.representedObject = dict;
            [self.recentMenu addItem:item];
        }
    }
    
    [self.recentMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *clear = [[NSMenuItem alloc] initWithTitle:@"Clear History" action:@selector(clearHistory) keyEquivalent:@""];
    [clear setTarget:self];
    [self.recentMenu addItem:clear];
}

- (void)clearHistory {
    [self.historyManager clearHistory];
    [self updateRecentMenu];
}

#pragma mark - Helper

- (void)updateUI {
    /*if (self.calc.errorMessage) {
        [self.displayField setStringValue:self.calc.errorMessage];
    } else*/ {
        // %g removes trailing zeros for us
        [self.displayField setStringValue:[NSString stringWithFormat:@"%g", self.calc.currentInputValue]];
    }
}

#pragma mark - Copy & Paste

- (void)copy:(id)sender {
    // 1. Get the current display value
    // We format it to ensure we don't copy "5.0000" but just "5"
    NSString *stringToCopy = [NSString stringWithFormat:@"%g", self.calc.currentInputValue];

    // 2. Clear and write to Pasteboard
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:stringToCopy forType:NSPasteboardTypeString];
}

- (void)paste:(id)sender {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    
    // 1. Check if there is a string
    NSString *pastedString = [pb stringForType:NSPasteboardTypeString];
    if (!pastedString) return;
    
    // 2. Validate: Is it a valid number?
    // We use NSScanner or doubleValue, but we want to be safe about garbage text
    NSScanner *scanner = [NSScanner scannerWithString:pastedString];
    double value = 0.0;
    
    // scanDouble returns YES if it found a valid double at the start
    if ([scanner scanDouble:&value] && [scanner isAtEnd]) {
        // 3. Update the Calculator
        [self.calc inputNumber:value];
        [self updateUI];
    } else {
        NSBeep(); // Standard macOS "error" sound for invalid input
    }
}

@end
