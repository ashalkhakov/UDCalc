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
    self.standardBitWrapperHeight = self.bitWrapperHeightConstraint.constant;
    
    self.calc.isRadians = NO;
    
    // 2. Default to Basic Mode on launch (Optional)
    [self setCalculatorMode:UDCalcModeBasic animate:NO];

    [self updateUI];
}

#pragma mark - Button Actions

- (IBAction)changeMode:(NSMenuItem *)sender {
    // Tag 1 = Basic, Tag 2 = Scientific, Tag 3 = Programmer
    [self setCalculatorMode:(UDCalcMode)sender.tag animate:YES];
    [self updateUI];
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

- (void)setCalculatorMode:(UDCalcMode)mode animate:(BOOL)animate {
    NSWindow *window = self.view.window;
    if (!window) return;

    BOOL isProgrammer = (mode == UDCalcModeProgrammer);
    BOOL isScientific = (mode == UDCalcModeScientific);

    // ============================================================
    // 1. DETERMINE TARGET SIZES
    // ============================================================
    
    // A. Keypad (Grid) Size
    NSView *targetGrid = isProgrammer ? self.programmerGridView : self.basicGridView;
    NSSize targetGridFit = [targetGrid fittingSize];
    CGFloat targetKeypadH = targetGridFit.height;
    CGFloat targetKeypadW = targetGridFit.width;

    // B. Scientific Drawer Width
    CGFloat targetDrawerW = isScientific ? self.standardScientificWidth : 0.0;

    // C. Programmer Container & Wrapper Heights
    //    We need two targets now:
    //    1. The Wrapper (Inner): Force it to 60.0 (Visible) if Programmer, else 0.
    //    2. The Container (Outer): The total standard height (Buttons + Wrapper + Spacing).
    
    CGFloat targetWrapperH = 0.0;
    CGFloat targetContainerH = 0.0;

    if (isProgrammer) {
        // RESET to Full Open when entering Programmer Mode
        targetWrapperH = self.standardBitWrapperHeight;
        targetContainerH = self.standardProgrammerInputHeight;
    } else {
        // Collapse completely (Buttons + Bits) for Sci/Basic Mode
        targetWrapperH = 0.0;
        targetContainerH = 0.0;
    }

    // ============================================================
    // 2. DETERMINE CURRENT STATE
    // ============================================================

    CGFloat currentKeypadH = self.keypadHeightConstraint.constant;
    CGFloat currentDrawerW = self.scientificWidthConstraint.constant;
    CGFloat currentContainerH = self.programmerInputHeightConstraint.constant;
    
    // For width delta, use current grid fitting size
    NSView *currentGrid = (self.calc.mode == UDCalcModeProgrammer) ? self.programmerGridView : self.basicGridView;
    CGFloat currentKeypadW = [currentGrid fittingSize].width;

    // ============================================================
    // 3. CALCULATE DELTAS
    // ============================================================

    // Height Delta: Difference in Keypad + Difference in Container
    CGFloat deltaH = (targetKeypadH - currentKeypadH) + (targetContainerH - currentContainerH);

    // Width Deltas
    CGFloat deltaW_Drawer = targetDrawerW - currentDrawerW;
    CGFloat deltaW_Keypad = targetKeypadW - currentKeypadW;

    // ============================================================
    // 4. APPLY TO WINDOW FRAME
    // ============================================================
    
    NSRect newFrame = window.frame;

    // Height: Grow Down (Lower Y)
    newFrame.size.height += deltaH;
    newFrame.origin.y    -= deltaH;

    // Width: Apply both
    newFrame.size.width += (deltaW_Drawer + deltaW_Keypad);
    newFrame.origin.x   -= deltaW_Drawer; // Shift Left for Drawer

    // ============================================================
    // 5. ANIMATION & STATE UPDATES
    // ============================================================

    // Visibility Pre-set
    if (isProgrammer) {
        self.programmerInputView.hidden = NO;
        self.bitDisplayWrapperView.hidden = NO; // Ensure wrapper is visible
        self.bitDisplayView.hidden = NO;    // Ensure inner view is visible
    }
    if (isScientific) {
        self.scientificView.hidden = NO;
    }
    
    [self.basicOrProgrammerTabView selectTabViewItemAtIndex:isProgrammer ? 1 : 0];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = animate ? 0.25 : 0.0;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        // 1. Animate Window
        [[window animator] setFrame:newFrame display:YES];
        
        // 2. Animate Constraints
        [[self.keypadHeightConstraint animator] setConstant:targetKeypadH];
        [[self.scientificWidthConstraint animator] setConstant:targetDrawerW];
        
        // 3. Animate Programmer Constraints (Both Inner and Outer)
        [[self.programmerInputHeightConstraint animator] setConstant:targetContainerH];
        [[self.bitWrapperHeightConstraint animator] setConstant:targetWrapperH];
        
        [self.view.superview layoutSubtreeIfNeeded];
        
    } completionHandler:^{
        if (!isProgrammer) {
            self.programmerInputView.hidden = YES;
        }
        if (!isScientific) {
            self.scientificView.hidden = YES;
        }
    }];

    self.calc.mode = mode;
    [self updateScientificButtons];
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
    // 1. Determine State
    // We check the wrapper's constraint (0 = hidden, >0 = visible)
    BOOL isBitsVisible = (self.bitWrapperHeightConstraint.constant > 0);
    
    // 2. Define Dimensions
    CGFloat bitViewHeight = self.standardBitWrapperHeight; // Your fixed wrapper height
    CGFloat spacing = self.programmerInputView.spacing; // Spacing between Buttons and Bits
    CGFloat fullHeight = self.standardProgrammerInputHeight; // The Total Height (Buttons + Spacing + Bits)
    
    // Calculate the height of JUST the buttons
    // Logic: Full Stack - (BitView + Spacing) = Buttons Only
    CGFloat buttonsOnlyHeight = fullHeight - (bitViewHeight + spacing);
    
    // 3. Determine Targets
    // If visible -> Go to Buttons Only.
    // If hidden -> Go to Full Height.
    CGFloat targetStackHeight = isBitsVisible ? buttonsOnlyHeight : fullHeight;
    CGFloat targetWrapperHeight = isBitsVisible ? 0.0 : bitViewHeight;
    
    // 4. Calculate Window Delta (Target - Current)
    CGFloat currentStackHeight = self.programmerInputHeightConstraint.constant;
    CGFloat deltaH = targetStackHeight - currentStackHeight;

    // 5. Animate
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = 0.25;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        // A. Resize Window
        NSRect winFrame = self.view.window.frame;
        winFrame.size.height += deltaH;
        winFrame.origin.y -= deltaH;
        [[self.view.window animator] setFrame:winFrame display:YES];
        
        // B. Resize Wrapper (Inner Constraint)
        [[self.bitWrapperHeightConstraint animator] setConstant:targetWrapperHeight];
        
        // C. Resize Main Container (Outer Constraint)
        // This stops exactly at 'buttonsOnlyHeight', keeping buttons visible.
        [[self.programmerInputHeightConstraint animator] setConstant:targetStackHeight];
        
        // D. Toggle Visibility (Pre-animation show)
        if (!isBitsVisible) {
            self.bitDisplayWrapperView.hidden = NO;
        }
        
    } completionHandler:^{
        // E. Cleanup (Post-animation hide)
        if (isBitsVisible) {
            self.bitDisplayWrapperView.hidden = YES;
        }
        [self updateUI];
    }];
}

- (IBAction)baseSelected:(NSSegmentedControl *)sender {
    NSInteger selectedTag = [[sender cell] tagForSegment:[sender selectedSegment]];
    
    UDBase newBase = (UDBase)selectedTag;

    self.calc.inputBase = newBase;

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
    if (self.calc.mode != UDCalcModeScientific) {
        return;
    }
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
    
    self.radDegButton.title = self.calc.isRadians ? @"Deg" : @"Rad";
    [self.radDegButton setNeedsDisplay:YES];
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
        cell.textField.stringValue = [self.calc stringForValue:val];
        
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

    if (self.calc.mode == UDCalcModeProgrammer) {
        self.bitDisplayView.value = UDValueAsInt(self.calc.currentInputValue);
        
        UDBase base = self.calc.inputBase;

        BOOL hexInputEnabled = base == UDBaseHex;
        BOOL decOrHexInputEnabled = base == UDBaseHex || base == UDBaseDec;

        self.p8Button.enabled = decOrHexInputEnabled;
        self.p9Button.enabled = decOrHexInputEnabled;
        self.pAButton.enabled = hexInputEnabled;
        self.pBButton.enabled = hexInputEnabled;
        self.pCButton.enabled = hexInputEnabled;
        self.pDButton.enabled = hexInputEnabled;
        self.pEButton.enabled = hexInputEnabled;
        self.pFButton.enabled = hexInputEnabled;
        self.pFFButton.enabled = hexInputEnabled;
    } else if (self.calc.mode == UDCalcModeScientific) {
        [self updateScientificButtons];
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
