//
//  UDCalcViewController.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 29.01.2026.
//


#import "UDCalcViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "UDCalcButton.h"

NSString * const UDCalcDidFinishCalculationNotification = @"org.underivable.calculator.DidFinishCalculation";

NSString * const UDCalcFormulaKey = @"UDCalcFormulaKey";
NSString * const UDCalcResultKey = @"UDCalcResultKey";


@implementation UDCalcViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.calc = [[UDCalc alloc] init];
    self.calc.delegate = self;

    // 1. Store the designed width of the scientific pane
    self.standardScientificWidth = self.scientificWidthConstraint.constant;
    
    // 2. Default to Basic Mode on launch (Optional)
    //[self setCalculatorMode:CalculatorModeBasic animate:NO];

    [self updateScientificButtons];
    [self updateUI];
}

#pragma mark - Button Actions

- (IBAction)changeMode:(NSMenuItem *)sender {
    // Tag 1 = Basic, Tag 2 = Scientific
    [self setCalculatorMode:(CalculatorMode)sender.tag animate:YES];
}

- (IBAction)changeRPNMode:(NSMenuItem *)sender {
    self.calc.isRPNMode = !self.calc.isRPNMode;
    
    sender.state = self.calc.isRPNMode ? NSControlStateValueOn : NSControlStateValueOff;
    
    [self updateUIForRPNMode:self.calc.isRPNMode];
}

- (void)updateUIForRPNMode:(BOOL)isRPNMode {
    
    // 1. Switch the Display View (0 = Standard, 1 = RPN)
    NSInteger tabIndex = isRPNMode ? 1 : 0;
    [self.displayTabView selectTabViewItemAtIndex:tabIndex];

    // 2. Toggle "Enter" vs "=" Button Title
    self.equalsButton.title = isRPNMode ? @"enter" : @"=";

    // 3. Disable Parens in RPN
    self.parenLeftButton.enabled = !isRPNMode;
    self.parenRightButton.enabled = !isRPNMode;

    // 4. Refresh Data
    [self updateUI];
}

- (void) setCalculatorMode:(CalculatorMode)mode animate:(BOOL)animate {
    switch (mode) {
        case CalculatorModeBasic:
            [self setScientificModeVisible:NO animate:animate];
            break;
        case CalculatorModeScientific:
            [self setScientificModeVisible:YES animate:animate];
            break;
        default:
            break;
    }
    self.calcMode = mode;
}

- (void)setScientificModeVisible:(BOOL)showScientific animate:(BOOL)animate {
    // If state isn't changing, do nothing
    BOOL isCurrentlyVisible = !self.scientificView.hidden;
    if (showScientific == isCurrentlyVisible) return;

    NSWindow *window = self.scientificView.window;
    NSRect currentFrame = window.frame;
    CGFloat widthDelta = self.standardScientificWidth;
    
    // Calculate new Frame (Expand/Shrink to the LEFT)
    NSRect newFrame = currentFrame;
    
    if (showScientific) {
        // EXPAND: Width increases, Origin.x moves Left
        newFrame.size.width += widthDelta;
        newFrame.origin.x -= widthDelta;
        self.scientificView.hidden = NO; // Show before animating
    } else {
        // SHRINK: Width decreases, Origin.x moves Right
        newFrame.size.width -= widthDelta;
        newFrame.origin.x += widthDelta;
    }
    
    // The Animation Block
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = animate ? 0.25 : 0.0;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        // 1. Animate the Window Frame
        [[window animator] setFrame:newFrame display:YES];
        
        // 2. Animate the Constraint (The Drawer Effect)
        // If showing, restore width. If hiding, crush to 0.
        [[self.scientificWidthConstraint animator] setConstant:(showScientific ? self.standardScientificWidth : 0)];
        
        // 3. Force layout update within animation
        [self.scientificView layoutSubtreeIfNeeded];
        
    } completionHandler:^{
        if (!showScientific) {
            self.scientificView.hidden = YES; // Hide strictly after animation
        }
    }];
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
            else if ([opTitle isEqualToString:@"equals"]) op = self.calc.isRPNMode ? UDOpEnter : UDOpEq;
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
            else if ([opTitle isEqualToString:@"mc"]) op = UDOpMC;
            else if ([opTitle isEqualToString:@"mplus"]) op = UDOpMAdd;
            else if ([opTitle isEqualToString:@"mminus"]) op = UDOpMSub;
            else if ([opTitle isEqualToString:@"mr"]) op = UDOpMR;
            // stack ops
            else if ([opTitle isEqualToString:@"swap"]) op = UDOpSwap;
            else if ([opTitle isEqualToString:@"rolldown"]) op = UDOpRollDown;
            else if ([opTitle isEqualToString:@"rollup"]) op = UDOpRollUp;
            else if ([opTitle isEqualToString:@"drop"]) op = UDOpDrop;
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
    } else {
        // Update Calculator.
        [self.calc performOperation:op];
    }
    
    // 3. Update Display
    [self updateUI];
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

#pragma mark - NSTableViewDataSource and NSTableViewDelegate Delegate

- (NSString *)formatDouble:(double)val {
    return [NSString stringWithFormat:@"%.10g", val];
}

// Calculate how many filler rows are needed
- (NSInteger)calculateFillerRows:(NSTableView *)tableView forActualRows:(NSInteger)actualRows {
    CGFloat tableHeight = NSHeight(tableView.enclosingScrollView.documentVisibleRect);
    CGFloat rowHeight = tableView.rowHeight; // Or use your custom row height
    
    NSInteger visibleRows = (NSInteger)floor(tableHeight / rowHeight);
    
    return MAX(0, visibleRows - actualRows);
}

// 1. Data Source: How many rows?
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    NSInteger count = self.calc.currentStackValues.count;
    return count + [self calculateFillerRows:tableView forActualRows:count];
}

// 2. View For Row: What to display?
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {

    NSArray *values = [self.calc currentStackValues];

    NSInteger fillerRowCount = [self calculateFillerRows:tableView forActualRows:values.count];
    
    // Check if this is a filler row
    if (row < fillerRowCount) {
        // Return an empty cell for filler rows
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"FillerCell" owner:self];
        if (!cellView) {
            cellView = [[NSTableCellView alloc] init];
            cellView.identifier = @"FillerCell";
        }
        return cellView;
    }
    
    row -= fillerRowCount;
    
    // Get a reusable cell view (Standard Cocoa pattern)
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"StackCell" owner:self];
    
    if (!cell) {
        // If IB didn't create one, make it manually (Safe for simple tables)
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 100, 20)];
        NSTextField *tf = [NSTextField labelWithString:@""];
        tf.alignment = NSTextAlignmentRight;
        tf.font = [NSFont systemFontOfSize:18]; // Nice readable font
        tf.translatesAutoresizingMaskIntoConstraints = NO;
        [cell addSubview:tf];
        cell.textField = tf;
        
        // Pin text field to cell edges
        [cell addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tf]|" options:0 metrics:nil views:@{@"tf":tf}]];
        [cell addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[tf]|" options:0 metrics:nil views:@{@"tf":tf}]];
    }
    
    // FETCH DATA
    // Note: currentStackValues[0] is usually bottom of stack (history).
    // Apple's UI usually puts X (Top of Stack) at the BOTTOM visually.
    // So Row 0 = Deep History. Row Last = X Register.

    if (row < values.count) {
        double val = [values[row] doubleValue];
        cell.textField.stringValue = [self formatDouble:val];
        
        // Styling: The last row is always the X Register (Active) -> Bold
        // If we are typing, the Buffer (handled above) is X.
        // If not typing, the last stack item is X.
        BOOL isXRegister = (row == values.count - 1);
        
        if (isXRegister) {
            cell.textField.font = [NSFont boldSystemFontOfSize:22];
            cell.textField.textColor = [NSColor labelColor];
        } else {
            cell.textField.font = [NSFont systemFontOfSize:18];
            cell.textField.textColor = [NSColor secondaryLabelColor]; // Dim history
        }
    }

    return cell;
}

#pragma mark - Helper

- (void)updateUI {
       
    if (self.calc.isTyping) {
        [self.acButton setTitle:@"C"];
    } else {
        [self.acButton setTitle:@"AC"];
    }
    
    if (self.calc.isRPNMode) {
        // --- RPN TABLE UPDATE ---
        [self.stackTableView reloadData];

        // Auto-scroll to the bottom (The X Register)
        NSInteger rowCount = [self.stackTableView numberOfRows];
        if (rowCount > 0) {
            [self.stackTableView scrollRowToVisible:rowCount - 1];
        }
    } else {
        // %g removes trailing zeros for us
        [self.displayField setStringValue:[self formatDouble:self.calc.currentInputValue]];
    }
}

#pragma mark - Copy & Paste

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(paste:)) {
        // Only enable Paste if the clipboard has a string
        return [[NSPasteboard generalPasteboard] canReadItemWithDataConformingToTypes:@[NSPasteboardTypeString]];
    }
    return YES;
}

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

#pragma mark - UDCalcDelegate

- (void)calculator:(UDCalc *)calc didCalculateResult:(double)result forTree:(UDASTNode *)tree {
    
    if (!tree) {
        return;
    }
    
    NSDictionary *userInfo = @{
        UDCalcFormulaKey : tree,
        UDCalcResultKey  : @(result)
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:UDCalcDidFinishCalculationNotification
                                                        object:self
                                                      userInfo:userInfo];
}

@end
