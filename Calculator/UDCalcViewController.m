//
//  UDCalcViewController.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 29.01.2026.
//


#import "UDCalcViewController.h"
#import "UDCalcButton.h"
#import "UDValueFormatter.h"
#import "UDSettingsManager.h"

NSString * const UDCalcDidFinishCalculationNotification = @"org.underivable.calculator.DidFinishCalculation";

NSString * const UDCalcFormulaKey = @"UDCalcFormulaKey";
NSString * const UDCalcResultKey = @"UDCalcResultKey";

@implementation UDCalcViewController

#pragma mark - Grid Rebuild Helpers

static const CGFloat kGridButtonWidth    = 60.0;
static const CGFloat kGridButtonHeight  = 50.0;
static const CGFloat kMinDisplayHeight  = 20.0;

/*
 * Frame-based layout state.  Since all constraints have been removed from
 * the XIB, these variables track the "logical" sizes of each panel.
 * They are initialised from hard-coded constants that match the XIB
 * frame design and updated when the calculator mode changes.
 */
static CGFloat _layoutKeypadH;
static CGFloat _layoutScientificW;
static CGFloat _layoutContainerH;
static CGFloat _layoutWrapperH;

/* Compute the fitting width for an NSSegmentedControl by measuring
 * each segment's label text. */
static CGFloat ud_segmentedControlFittingWidth(NSSegmentedControl *sc) {
    static const CGFloat kSegPad = 16.0;
    NSDictionary *attrs = @{NSFontAttributeName: [sc font] ?: [NSFont systemFontOfSize:0]};
    CGFloat total = 0;
    NSInteger count = [sc segmentCount];
    for (NSInteger i = 0; i < count; i++) {
        NSString *label = [sc labelForSegment:i] ?: @"";
        CGFloat textW = [label sizeWithAttributes:attrs].width;
        total += textW + kSegPad;
    }
    return total;
}

/*
 * Position the four main subviews of self.view based on the current
 * layout state.  Called after window frame changes.
 *
 * Layout (AppKit coords, origin bottom-left):
 *   Top:    displayTabView        (1px margins on top/left/right)
 *   Middle: programmerInputView   (visible in programmer mode only)
 *   Bottom: scientificView (left) + keypadTabView (right)
 */
- (void)layoutMainSubviews {
    NSRect bounds = self.view.bounds;
    CGFloat W = bounds.size.width;
    CGFloat H = bounds.size.height;

    CGFloat keypadH    = _layoutKeypadH;
    CGFloat containerH = _layoutContainerH;
    CGFloat drawerW    = _layoutScientificW;

    CGFloat displayH = H - containerH - keypadH - 2.0;
    if (displayH < kMinDisplayHeight) displayH = kMinDisplayHeight;

    CGFloat displayW = MAX(0, W - 2);
    displayH = MAX(0, displayH);
    CGFloat keypadW = MAX(0, W - drawerW - 1);

    [self.displayTabView setFrame:NSMakeRect(1, containerH + keypadH + 1,
                                             displayW, displayH)];

    {
        NSRect dRect = [self.displayTabView contentRect];
        for (NSTabViewItem *item in [self.displayTabView tabViewItems])
            [[item view] setFrame:NSMakeRect(0, 0, dRect.size.width, dRect.size.height)];
        [self.displayField setFrame:NSMakeRect(0, 0, dRect.size.width, dRect.size.height)];
    }

    [self.programmerInputView setFrame:NSMakeRect(0, keypadH, MAX(0, W), containerH)];

    [self.scientificView setFrame:NSMakeRect(0, 0, drawerW, keypadH)];

    if (drawerW > 0) {
        for (NSView *sub in self.scientificView.subviews) {
            if ([sub isKindOfClass:[NSGridView class]]) {
                [sub setFrame:NSMakeRect(0, 0, drawerW, keypadH)];
                break;
            }
        }
    }

    [self.basicOrProgrammerTabView setFrame:NSMakeRect(drawerW, 0, keypadW, keypadH)];

    {
        NSRect contentRect = [self.basicOrProgrammerTabView contentRect];
        CGFloat cw = contentRect.size.width;
        CGFloat ch = contentRect.size.height;
        for (NSTabViewItem *item in [self.basicOrProgrammerTabView tabViewItems])
            [[item view] setFrame:NSMakeRect(0, 0, cw, ch)];
        [self.basicGridView setFrame:NSMakeRect(0, 0, cw, ch)];
        [self.programmerGridView setFrame:NSMakeRect(0, 0, cw, ch)];
    }

    if (containerH > 0) {
        static const CGFloat kProgButtonRowH = 30.0;
        CGFloat wrapperH = _layoutWrapperH;

        [self.bitDisplayWrapperView setFrame:NSMakeRect(0, 0, MAX(0, W), wrapperH)];
        [self.bitDisplayView setFrame:NSMakeRect(0, 0, MAX(0, W), wrapperH)];

        NSView *buttonRow = [self.baseSegmentedControl superview];
        if (buttonRow) {
            CGFloat rowY = containerH - kProgButtonRowH;
            [buttonRow setFrame:NSMakeRect(0, rowY, MAX(0, W), kProgButtonRowH)];

            static const CGFloat kPad = 8.0;
            CGFloat ctrlH = kProgButtonRowH - 4;
            CGFloat ctrlY = 2.0;
            CGFloat rowW = MAX(0, W) - 2 * kPad;

            CGFloat encW = ud_segmentedControlFittingWidth(self.encodingSegmentedControl);
            [self.encodingSegmentedControl setFrame:NSMakeRect(kPad, ctrlY, encW, ctrlH)];

            [self.showBinaryViewButton sizeToFit];
            NSSize btnSz = [self.showBinaryViewButton frame].size;
            CGFloat btnX = kPad + (rowW - btnSz.width) / 2.0;
            [self.showBinaryViewButton setFrame:NSMakeRect(btnX, ctrlY, btnSz.width, ctrlH)];

            CGFloat baseW = ud_segmentedControlFittingWidth(self.baseSegmentedControl);
            [self.baseSegmentedControl setFrame:NSMakeRect(kPad + rowW - baseW, ctrlY, baseW, ctrlH)];
        }
    }

    [self.view setNeedsDisplay:YES];
}

// XIB-designed standard sizes (matching the frame rects in UDCalcView.xib)
static const CGFloat kStandardScientificWidth       = 365.0;
static const CGFloat kStandardProgrammerInputHeight = 98.0;
static const CGFloat kStandardBitWrapperHeight      = 60.0;
static const CGFloat kStandardKeypadHeight          = 255.0;


- (void)viewDidLoad {
    [super viewDidLoad];

    self.calc = [[UDCalc alloc] init];
    self.calc.delegate = self;
    self.bitDisplayView.delegate = self;

    self.standardScientificWidth       = kStandardScientificWidth;
    self.standardProgrammerInputHeight = kStandardProgrammerInputHeight;
    self.standardBitWrapperHeight      = kStandardBitWrapperHeight;

    _layoutKeypadH     = kStandardKeypadHeight;
    _layoutScientificW = kStandardScientificWidth;
    _layoutContainerH  = kStandardProgrammerInputHeight;
    _layoutWrapperH    = kStandardBitWrapperHeight;

#ifdef GNUSTEP
    {
        NSColor *dark = [NSColor blackColor];
        [self.displayField setTextColor:dark];
        [self.radLabel setTextColor:dark];
        [self.charLabel setTextColor:dark];
        [self.radLabelRPN setTextColor:dark];
        [self.charLabelRPN setTextColor:dark];
    }
#endif

#ifndef GNUSTEP
    [self.basicGridView mergeCellsInHorizontalRange:NSMakeRange(0, 2)
                                      verticalRange:NSMakeRange(4, 1)];
    [self.programmerGridView mergeCellsInHorizontalRange:NSMakeRange(0, 2)
                                           verticalRange:NSMakeRange(4, 1)];
    [self.programmerGridView mergeCellsInHorizontalRange:NSMakeRange(0, 2)
                                           verticalRange:NSMakeRange(5, 1)];
    [self.programmerGridView mergeCellsInHorizontalRange:NSMakeRange(5, 2)
                                           verticalRange:NSMakeRange(5, 1)];
#endif

    // Listen for the app closing
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(saveApplicationState)
                                                 name:NSApplicationWillTerminateNotification
                                               object:nil];
}

- (void)restoreApplicationState {
    UDSettingsManager *settings = [UDSettingsManager sharedManager];
    
    self.calc.isRadians = settings.isRadians;
    self.calc.encodingMode = settings.encodingMode;
    self.calc.isRPNMode = settings.isRPN;
    self.calc.inputBase = settings.inputBase;
    self.calc.isBinaryViewShown = settings.showBinaryView;
    self.calc.showThousandsSeparators = settings.showThousandsSeparators;
    self.calc.decimalPlaces = settings.decimalPlaces;

    // Update Segment Control UI to match loaded state
    if (settings.encodingMode == UDCalcEncodingModeNone) {
#ifdef GNUSTEP
        // GNUstep doesn't support selectedSegment = -1 (deselect all)
        for (NSInteger i = 0; i < self.encodingSegmentedControl.segmentCount; i++) {
            [self.encodingSegmentedControl setSelected:NO forSegment:i];
        }
#else
        self.encodingSegmentedControl.selectedSegment = -1;
#endif
    } else {
        self.encodingSegmentedControl.selectedSegment = settings.encodingMode == UDCalcEncodingModeASCII ? 0 : 1;
    }

    // Update Input Base Control UI to match loaded state
    self.baseSegmentedControl.selectedSegment = settings.inputBase == UDBaseOct ? 0 : settings.inputBase == UDBaseDec ? 1 : 2;
    
    // Update Show Binary Button
    self.showBinaryViewButton.state = settings.showBinaryView ? NSControlStateValueOn : NSControlStateValueOff;
    _layoutWrapperH = settings.showBinaryView ? self.standardBitWrapperHeight : 0;

    [self setCalculatorMode:settings.calcMode animate:NO];
    if (self.calc.mode == UDCalcModeProgrammer) {
        [self setIsBinaryViewShown:settings.showBinaryView];
    }

    [self updateUIForRPNMode:self.calc.isRPNMode];
}

- (void)saveApplicationState {
    NSLog(@"App is terminating. Saving state...");
    
    // Save Calculator State (e.g., the number on screen)
    UDSettingsManager *settings = [UDSettingsManager sharedManager];
    
    settings.isRadians = self.calc.isRadians;
    settings.calcMode = self.calc.mode;
    settings.encodingMode = self.calc.encodingMode;
    settings.isRPN = self.calc.isRPNMode;
    settings.inputBase = self.calc.inputBase;
    settings.showBinaryView = self.calc.isBinaryViewShown;
    settings.showThousandsSeparators = self.calc.showThousandsSeparators;
    settings.decimalPlaces = self.calc.decimalPlaces;
    
    [settings forceSync];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    NSGridView *targetGrid = isProgrammer ? self.programmerGridView : self.basicGridView;
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

    CGFloat currentKeypadH = _layoutKeypadH;
    CGFloat currentDrawerW = _layoutScientificW;
    CGFloat currentContainerH = _layoutContainerH;
    
    // For width delta, use current grid fitting size
    NSGridView *currentGrid = (self.calc.mode == UDCalcModeProgrammer) ? self.programmerGridView : self.basicGridView;
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
    } else {
        self.programmerInputView.hidden = YES;
        self.bitDisplayWrapperView.hidden = YES;
        self.bitDisplayView.hidden = YES;
    }
    if (isScientific) {
        self.scientificView.hidden = NO;
    } else {
        self.scientificView.hidden = YES;
    }

    [self.basicOrProgrammerTabView selectTabViewItemAtIndex:isProgrammer ? 1 : 0];

    [window setFrame:newFrame display:YES];

    _layoutKeypadH     = targetKeypadH;
    _layoutScientificW = targetDrawerW;
    _layoutContainerH  = targetContainerH;
    _layoutWrapperH    = targetWrapperH;
    [self layoutMainSubviews];

    self.calc.mode = mode;
    [self updateScientificButtons];
}

- (IBAction)showThousandsSeparators:(NSMenuItem *)sender {
    self.calc.showThousandsSeparators = !self.calc.showThousandsSeparators;
    [self updateUI];
}

- (IBAction)changeDecimalPlaces:(NSMenuItem *)sender {
    self.calc.decimalPlaces = sender.tag;
        
    [self updateUI];
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
   NSLog(@"decimal pressed");

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
    self.calc.isBinaryViewShown = !self.calc.isBinaryViewShown;

    // 1. Determine State
    // We check the wrapper's constraint (0 = hidden, >0 = visible)
    BOOL isBitsVisible = self.calc.isBinaryViewShown;

    sender.state = isBitsVisible ? NSControlStateValueOn : NSControlStateValueOff;

    [self setIsBinaryViewShown:isBitsVisible];

    [self updateUI];
}

- (void)setIsBinaryViewShown:(BOOL)isBitsVisible {
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
    CGFloat currentStackHeight = _layoutContainerH;
    CGFloat deltaH = targetStackHeight - currentStackHeight;

    // 5. Animate

    // A. Resize Window
    NSRect winFrame = self.view.window.frame;
    winFrame.size.height += deltaH;
    winFrame.origin.y -= deltaH;
    [self.view.window setFrame:winFrame display:YES];
    
    // B. Resize Wrapper (Inner Constraint)
    // C. Resize Main Container (Outer Constraint)
    // This stops exactly at 'buttonsOnlyHeight', keeping buttons visible.
    _layoutWrapperH   = targetWrapperHeight;
    _layoutContainerH = targetStackHeight;
    [self layoutMainSubviews];
}

- (IBAction)baseSelected:(NSSegmentedControl *)sender {
    /* Map selected segment index to base value directly.
     * Segments are always: 0=Octal(8), 1=Decimal(10), 2=Hex(16).
     * Using the index avoids [[sender cell] tagForSegment:] which
     * returns 0 on GNUstep (cell tags not decoded from XIB). */
    static const UDBase baseMap[] = { UDBaseOct, UDBaseDec, UDBaseHex };
    NSInteger idx = [sender selectedSegment];
    if (idx < 0 || idx > 2) return;

    self.calc.inputBase = baseMap[idx];

    [self updateUI];
}

- (IBAction)encodingSelected:(NSSegmentedControl *)sender {
    NSInteger index = [sender selectedSegment];

    // Check visual state
    BOOL isAsciiOn = [sender isSelectedForSegment:0];
    BOOL isUnicodeOn = [sender isSelectedForSegment:1];
    
    // LOGIC: Enforce Mutually Exclusive "Select Zero or One"
    if (isAsciiOn && isUnicodeOn) {
        // User tried to select the second one while first was on.
        // We must turn off the OLD one.
        if (self.calc.encodingMode == UDCalcEncodingModeASCII) {
            // Was ASCII, user clicked Unicode -> Turn off ASCII
            [sender setSelected:NO forSegment:0];
            self.calc.encodingMode = UDCalcEncodingModeUnicode;
        } else {
            // Was Unicode, user clicked ASCII -> Turn off Unicode
            [sender setSelected:NO forSegment:1];
            self.calc.encodingMode = UDCalcEncodingModeASCII;
        }
    }
    else if (isAsciiOn) {
        self.calc.encodingMode = UDCalcEncodingModeASCII;
    }
    else if (isUnicodeOn) {
        self.calc.encodingMode = UDCalcEncodingModeUnicode;
    }
    else {
        // Both are off (User clicked the active one to deselect it)
        self.calc.encodingMode = UDCalcEncodingModeNone;
    }
    
    // Now update the UI (show/hide the char label)
    [self updateDisplayIndicators];
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
#ifdef GNUSTEP
            cell.textField.textColor = [NSColor blackColor];
#else
            cell.textField.textColor = [NSColor labelColor];
#endif
        } else {
            cell.textField.font = [NSFont systemFontOfSize:18];
#ifdef GNUSTEP
            cell.textField.textColor = [NSColor darkGrayColor];
#else
            cell.textField.textColor = [NSColor secondaryLabelColor];
#endif
        }
    }

    return cell;
}

#pragma mark - Helper

- (void)updateDisplayIndicators {
    UDCalcMode mode = self.calc.mode;
    NSTextField *radLabel = self.calc.isRPNMode ? self.radLabelRPN : self.radLabel;
    NSTextField *charLabel = self.calc.isRPNMode ? self.charLabelRPN : self.charLabel;
    
    // ============================================================
    // 1. RADIAN INDICATOR (Scientific Mode)
    // ============================================================
    // Only show if we are in Scientific Mode AND Radians are active.
    if (mode == UDCalcModeScientific && self.calc.isRadians) {
        radLabel.hidden = NO;
        radLabel.stringValue = @"Rad";
    } else {
        radLabel.hidden = YES;
    }
    
    // ============================================================
    // 2. CHARACTER INDICATOR (Programmer Mode)
    // ============================================================
    
    if (mode == UDCalcModeProgrammer) {
        NSString *glyph = [self.calc currentValueEncoded];

        if (glyph.length > 0) {
            charLabel.hidden = NO;
            charLabel.stringValue = glyph;
        } else {
            charLabel.hidden = YES;
        }
    } else {
        charLabel.hidden = YES;
    }
}

- (void)updateUI {

    if (self.calc.mode != UDCalcModeProgrammer) {
        if (self.calc.isTyping) {
            [self.acButton setTitle:@"C"];
            [self.acButton setTag:UDOpClear];
        } else {
            [self.acButton setTitle:@"AC"];
            [self.acButton setTag:UDOpClearAll];
        }
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
    
    [self updateDisplayIndicators];
}

#pragma mark - Copy & Paste

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item {
    if ([(NSObject *)item isKindOfClass:[NSMenuItem class]]) {
        NSMenuItem *menuItem = (NSMenuItem *)item;
        SEL action = item.action;
        
        if (action == @selector(paste:)) {
            // Only enable Paste if the clipboard has a string
            return [[NSPasteboard generalPasteboard] canReadItemWithDataConformingToTypes:@[NSPasteboardTypeString]];
        }
        
        if (action == @selector(changeMode:)) {
            
            UDCalcMode targetMode = (UDCalcMode)menuItem.tag;
            
            menuItem.state = self.calc.mode == targetMode ? NSControlStateValueOn : NSControlStateValueOff;
            
            return YES; // The item is enabled
        }
        
        if (action == @selector(changeRPNMode:)) {
            menuItem.state = self.calc.isRPNMode ? NSControlStateValueOn : NSControlStateValueOff;
            
            return YES;
        }
        
        if (action == @selector(showThousandsSeparators:)) {
            menuItem.state = self.calc.showThousandsSeparators ? NSControlStateValueOn : NSControlStateValueOff;
            
            return YES;
        }

        if ([item action] == @selector(changeDecimalPlaces:)) {
            NSInteger current = self.calc.decimalPlaces;
            [(NSMenuItem *)item setState:(item.tag == current ? NSControlStateValueOn : NSControlStateValueOff)];
            return YES;
        }
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
