//
//  UDCalcViewController.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 29.01.2026.
//


#import "UDCalcViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "UDCalcButton.h"
#import "UDValueFormatter.h"

NSString * const UDCalcDidFinishCalculationNotification = @"org.underivable.calculator.DidFinishCalculation";

NSString * const UDCalcFormulaKey = @"UDCalcFormulaKey";
NSString * const UDCalcResultKey = @"UDCalcResultKey";


@implementation UDCalcViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.calc = [[UDCalc alloc] init];
    self.calc.delegate = self;
    self.bitDisplayView.delegate = self;

    // 1. Store the designed width of the scientific pane
    self.standardScientificWidth = self.scientificWidthConstraint.constant;
    self.standardProgrammerInputHeight = self.programmerInputHeightConstraint.constant;
    
    // 2. Default to Basic Mode on launch (Optional)
    [self setCalculatorMode:CalculatorModeBasic animate:NO];

    [self updateScientificButtons];
    [self updateUI];
}

#pragma mark - Button Actions

- (IBAction)changeMode:(NSMenuItem *)sender {
    // Tag 1 = Basic, Tag 2 = Scientific, Tag 3 = Programmer
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
    self.equalsButton.tag = isRPNMode ? UDOpEnter : UDOpEq;

    // 3. Disable Parens in RPN
    self.parenLeftButton.enabled = !isRPNMode;
    self.parenRightButton.enabled = !isRPNMode;

    // 4. Refresh Data
    [self updateUI];
}

- (void)setCalculatorMode:(CalculatorMode)mode animate:(BOOL)animate {
    NSWindow *window = self.view.window;
    if (!window) return;

    BOOL isProgrammer = (mode == CalculatorModeProgrammer);
    BOOL isScientific = (mode == CalculatorModeScientific);

    // --- 1. Determine Target Content & Sizes ---
    // Instead of asking the whole window, we ask the specific Grid View
    // "How big do you need to be to show all your rows?"
    NSView *targetGrid = isProgrammer ? self.programmerGridView : self.basicGridView;
    NSSize gridFitSize = [targetGrid fittingSize];
    
    // Add a small buffer for tab margins if necessary (usually 0-4 pts)
    CGFloat targetKeypadHeight = gridFitSize.height;
    CGFloat targetKeypadWidth = gridFitSize.width;
    
    CGFloat targetBitDisplayHeight = isProgrammer ? self.standardProgrammerInputHeight : 0.0;
    CGFloat targetDrawerWidth = isScientific ? self.standardScientificWidth : 0.0;

    // --- 2. Calculate Window Deltas ---
    // We calculate the difference between "What we want" and "What constraints are set to NOW"
    
    CGFloat currentKeypadHeight = self.keypadHeightConstraint.constant;
    CGFloat currentBitDisplayHeight = self.programmerInputHeightConstraint.constant;
    CGFloat currentDrawerWidth = self.scientificWidthConstraint.constant;
    
    // Height Delta = (Keypad Change) + (BitDisplay Change)
    CGFloat deltaH = (targetKeypadHeight - currentKeypadHeight) + (targetBitDisplayHeight - currentBitDisplayHeight);
    
    // Width Deltas
    // We separate these because they affect the window Origin differently
    // Assuming you have a keypadWidthConstraint connected. If not, use current frame width differences.
    // If you don't have a keypadWidthConstraint, you can rely on the natural stack resizing,
    // but calculating the delta manually is safer.
    // For now, let's assume the window width change is driven by the Drawer mainly.
    // If you want the keypad to widen the window to the RIGHT, we add that delta but don't move X.
    
    CGFloat currentWindowWidth = window.frame.size.width;
    // Calculate expected total width = Drawer + Keypad (plus margins/borders)
    // Note: This relies on your layout being tight.
    // A safer way for Width is utilizing the Drawer Delta only for Origin X shift.
    
    CGFloat deltaW_Drawer = targetDrawerWidth - currentDrawerWidth;
    
    // If Keypad gets wider, we want window to grow.
    // If we assume the current Keypad width matches the grid inside it (roughly):
    CGFloat deltaW_Keypad = isProgrammer ? (targetKeypadWidth - self.basicGridView.fittingSize.width) : (targetKeypadWidth - self.programmerGridView.fittingSize.width);
    
    // Simplify: Just use the fittingSize difference for width if you don't have a width constraint
    // But applying the Drawer Delta to Origin.x is CRITICAL.
    
    // --- 3. Calculate New Window Frame ---
    NSRect newFrame = window.frame;
    
    // Apply Height (Grow Down)
    newFrame.size.height += deltaH;
    newFrame.origin.y -= deltaH;
    
    // Apply Width (Drawer Grows Left, Keypad Grows Right)
    // We add the total width change...
    // Note: To do this perfectly without a Keypad Width Constraint is tricky,
    // so we calculate total expected width change implies:
    CGFloat totalNewWidth = newFrame.size.width + deltaW_Drawer; // Start with drawer change
    
    // If we are switching Keypads, check if we need to expand for the new keypad width
    // (This block effectively simulates a width constraint)
    if (isProgrammer) {
        totalNewWidth += (targetKeypadWidth - [self.basicGridView fittingSize].width);
    } else {
        totalNewWidth -= ([self.programmerGridView fittingSize].width - targetKeypadWidth);
    }
    
    newFrame.size.width = totalNewWidth;
    newFrame.origin.x -= deltaW_Drawer; // Only move Left for the Drawer
    
    
    // --- 4. Setup State ---
    [self.basicOrProgrammerTabView selectTabViewItemAtIndex:isProgrammer ? 1 : 0];
    self.programmerInputView.hidden = !isProgrammer;
    self.scientificView.hidden = !isScientific;

    // --- 5. Animate ---
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = animate ? 0.25 : 0.0;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        [[window animator] setFrame:newFrame display:YES];
        
        // Animate Constraints
        [[self.scientificWidthConstraint animator] setConstant:targetDrawerWidth];
        [[self.programmerInputHeightConstraint animator] setConstant:targetBitDisplayHeight];
        [[self.keypadHeightConstraint animator] setConstant:targetKeypadHeight]; // Fixes the missing row!
        
        [self.view.superview layoutSubtreeIfNeeded];
    } completionHandler:nil];

    self.calc.isIntegerMode = isProgrammer;
    self.calcMode = mode;
}

- (IBAction)digitPressed:(NSButton *)sender {
    UDOp op = sender.tag;
    
    if ((op >= UDOpDigit0 && op <= UDOpDigit9) || (op >= UDOpDigitA && op <= UDOpDigitF)) {
        
        NSInteger digit = op;
        
        [self.calc inputDigit:digit];
    } else if (op == UDOpDigit00) {
        [self.calc inputDigit:0];
        [self.calc inputDigit:0];
    } else if (op == UDOpDigitFF) {
        [self.calc inputDigit:UDOpDigitF];
        [self.calc inputDigit:UDOpDigitF];
    }

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
    
    if (![sender isKindOfClass:[UDCalcButton class]]) {
        NSLog(@"Incorrect button class");
        return;
    }
    
    UDOp op = sender.tag;

    if (op == UDOpSecondFunc) {
        self.isSecondFunctionActive = !self.isSecondFunctionActive;
        
        // Visual Feedback: Make the "2nd" button look pressed/highlighted
        sender.state = self.isSecondFunctionActive ? NSControlStateValueOn : NSControlStateValueOff;
        [sender setNeedsDisplay:YES];

        [self updateScientificButtons];
        return;
    } else if (op == UDOpConstPi) {
        [self.calc inputNumber:UDValueMakeDouble(M_PI)];
    } else if (op == UDOpConstE) {
        [self.calc inputNumber:UDValueMakeDouble(M_E)];
    } else if (op == UDOpRad) {
        [self.calc performOperation:op];
        
        // visual feedback
        sender.title = self.calc.isRadians ? @"Rad" : @"Deg";
        [sender setNeedsDisplay:YES];
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

- (IBAction)showBinaryPressed:(NSButton *)sender {
    self.bitDisplayView.hidden = !self.bitDisplayView.hidden;
    
    [self updateUI];
}

- (IBAction)baseSelected:(NSSegmentedControl *)sender {
    NSInteger selectedTag = [[sender cell] tagForSegment:[sender selectedSegment]];
    
    UDBase newBase = (UDBase)selectedTag;

    self.calc.inputBuffer.inputBase = newBase;
    
    BOOL hexInputEnabled = newBase == UDBaseHex;
    BOOL decOrHexInputEnabled = newBase == UDBaseHex || newBase == UDBaseDec;

    self.p8Button.enabled = decOrHexInputEnabled;
    self.p9Button.enabled = decOrHexInputEnabled;
    self.pAButton.enabled = hexInputEnabled;
    self.pBButton.enabled = hexInputEnabled;
    self.pCButton.enabled = hexInputEnabled;
    self.pDButton.enabled = hexInputEnabled;
    self.pEButton.enabled = hexInputEnabled;
    self.pFButton.enabled = hexInputEnabled;
    self.pFFButton.enabled = hexInputEnabled;

    [self updateUI];
}

- (IBAction)encodingSelected:(NSSegmentedControl *)sender {
    NSInteger index = [sender selectedSegment];
        
    if (index == 0) {
        NSLog(@"Switched to ASCII Mode");
        // self.calculator.inputBuffer.encodingMode = UDEncodingASCII;
    } else {
        NSLog(@"Switched to Unicode Mode");
        // self.calculator.inputBuffer.encodingMode = UDEncodingUnicode;
    }
    
    [self updateUI];
}

- (void)updateScientificButtons {
    BOOL second = self.isSecondFunctionActive;

    // Helper block to swap button state
    void (^setBtn)(NSButton*, CalcButtonType, UDOp, CalcButtonType, UDOp) =
    ^(NSButton *b, CalcButtonType norm, UDOp normOp, CalcButtonType sec, UDOp secOp) {
        if (![b isKindOfClass:[UDCalcButton class]]) {
            NSLog(@"wrong kind of button");
            return;
        }
        
        UDCalcButton *calcButton = (UDCalcButton *)b;
        
        if (second) {
            calcButton.symbolType = sec;
            calcButton.tag = secOp;
        } else {
            calcButton.symbolType = norm;
            calcButton.tag = normOp;
        }
        [calcButton setNeedsDisplay:YES];
    };
    
    setBtn(self.expButton, CalcButtonTypeExp, UDOpExp, CalcButtonTypePowerYtoX, UDOpPowRev);
    setBtn(self.xthPowerOf10Button, CalcButtonTypeTenPower, UDOpPow10, CalcButtonTypePower2toX, UDOpPow2);
    if ([self.lnButton isKindOfClass:[UDCalcButton class]]) {
        if (second) {
            self.lnButton.title = @"";
            ((UDCalcButton *)self.lnButton).symbolType = CalcButtonTypeLogY;
            self.lnButton.tag = UDOpLogY;
        } else {
            self.lnButton.title = @"ln";
            ((UDCalcButton *)self.lnButton).symbolType = CalcButtonTypeStandard;
            self.lnButton.tag = UDOpLn;
        }
    }
    setBtn(self.log10Button, CalcButtonTypeLog10, UDOpLog10, CalcButtonTypeLog2, UDOpLog2);
    setBtn(self.sinButton, CalcButtonTypeSin, UDOpSin, CalcButtonTypeSinInverse, UDOpSinInverse);
    setBtn(self.cosButton, CalcButtonTypeCos, UDOpCos, CalcButtonTypeCosInverse, UDOpCosInverse);
    setBtn(self.tanButton, CalcButtonTypeTan, UDOpTan, CalcButtonTypeTanInverse, UDOpTanInverse);
    setBtn(self.sinhButton, CalcButtonTypeSinh, UDOpSinh, CalcButtonTypeSinhInverse, UDOpSinhInverse);
    setBtn(self.coshButton, CalcButtonTypeCosh, UDOpCosh, CalcButtonTypeCoshInverse, UDOpCoshInverse);
    setBtn(self.tanhButton, CalcButtonTypeTanh, UDOpTanh, CalcButtonTypeTanhInverse, UDOpTanhInverse);
}

#pragma mark - NSTableViewDataSource and NSTableViewDelegate Delegate

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

    NSArray<UDNumberNode *> *values = [self.calc currentStackValues];

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
        UDValue val = values[row].value;
        cell.textField.stringValue = [UDValueFormatter stringForValue:val base:self.calc.inputBuffer.inputBase];
        
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
        [self.displayField setStringValue:self.calc.currentDisplayValue];
    }

    if (self.calcMode == CalculatorModeProgrammer) {
        self.bitDisplayView.value = UDValueAsInt(self.calc.currentInputValue);
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
    NSString *stringToCopy = self.calc.currentDisplayValue;

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
        [self.calc inputNumber:UDValueMakeDouble(value)];
        [self updateUI];
    } else {
        NSBeep(); // Standard macOS "error" sound for invalid input
    }
}

#pragma mark - UDCalcDelegate

- (void)calculator:(UDCalc *)calc didCalculateResult:(UDValue)result forTree:(UDASTNode *)tree {
    
    if (!tree) {
        return;
    }
       
    NSDictionary *userInfo = @{
        UDCalcFormulaKey : tree,
        UDCalcResultKey  : @(UDValueAsDouble(result))
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:UDCalcDidFinishCalculationNotification
                                                        object:self
                                                      userInfo:userInfo];
}

#pragma mark - UDBitDisplayDelegate

- (void)bitDisplayDidToggleBit:(NSInteger)bitIndex toValue:(BOOL)newValue {
    if (bitIndex < 0 || bitIndex > 63)
    {
        return;
    }

    UDValue currentValue = self.calc.currentInputValue;
    unsigned long long bits = UDValueAsInt(currentValue);

    if (newValue)
        bits |= (1ULL << bitIndex);
    else
        bits &= ~(1ULL << bitIndex);

    [self.calc inputNumber:UDValueMakeInt(bits)];
    [self updateUI];
}

@end
