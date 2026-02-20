//
//  UDCalcViewController.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 29.01.2026.
//


#import "UDCalcViewController.h"
#if __has_include(<QuartzCore/QuartzCore.h>)
#import <QuartzCore/QuartzCore.h>
#endif
#import "UDCalcButton.h"
#import "UDValueFormatter.h"
#import "UDSettingsManager.h"

NSString * const UDCalcDidFinishCalculationNotification = @"org.underivable.calculator.DidFinishCalculation";

NSString * const UDCalcFormulaKey = @"UDCalcFormulaKey";
NSString * const UDCalcResultKey = @"UDCalcResultKey";

@implementation UDCalcViewController

#ifdef GNUSTEP
#pragma mark - GNUstep Grid Rebuild Helpers

// GNUstep's XIB parser may not properly connect gridCell contentViews
// from Xcode XIBs.  These helpers detect empty grids and rebuild them
// programmatically so the buttons actually appear.

static const CGFloat kGridButtonWidth    = 60.0;
static const CGFloat kGridButtonHeight  = 50.0;
static const CGFloat kMinDisplayHeight  = 20.0;

static UDCalcButton *makeButton(NSString *title, NSInteger tag, SEL action,
                                id target, CalcButtonType sym, NSColor *btnColor)
{
    UDCalcButton *b = [[UDCalcButton alloc] initWithFrame:
                        NSMakeRect(0, 0, kGridButtonWidth, kGridButtonHeight)];
    b.title = title;
    b.tag = tag;
    b.target = target;
    b.action = action;
    b.symbolType = sym;
    if (btnColor) b.buttonColor = btnColor;
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

// GNUstep's XIB parser can't decode color-type userDefinedRuntimeAttributes,
// so buttonColor is never set from the XIB.  Apply orange to operator buttons
// (tags 21–25: +, −, ×, ÷, =) programmatically after loading.
- (void)applyOperatorColorsInView:(NSView *)root {
    NSColor *orange = [NSColor orangeColor];
    NSColor *orangeHL = [NSColor colorWithCalibratedRed:1.0 green:0.72 blue:0.28 alpha:1.0];
    for (NSView *v in root.subviews) {
        if ([v isKindOfClass:[UDCalcButton class]]) {
            UDCalcButton *btn = (UDCalcButton *)v;
            if (btn.tag >= 21 && btn.tag <= 25) {
                btn.buttonColor = orange;
                btn.highlightColor = orangeHL;
            }
        }
        [self applyOperatorColorsInView:v];
    }
}

- (BOOL)gridNeedsRebuild:(NSGridView *)grid {
    if (!grid) return NO;
    if (grid.numberOfRows == 0 || grid.numberOfColumns == 0) return YES;
    NSGridCell *cell = [grid cellAtColumnIndex:0 rowIndex:0];
    return (cell.contentView == nil);
}

- (void)clearGrid:(NSGridView *)grid {
    while (grid.numberOfRows > 0)
        [grid removeRowAtIndex:0];
}

// ---------- Basic Grid (4 cols × 5 rows) ----------
- (void)rebuildBasicGrid {
    NSGridView *g = self.basicGridView;
    if (![self gridNeedsRebuild:g]) return;
    [self clearGrid:g];

    SEL opAct  = @selector(operationPressed:);
    SEL digAct = @selector(digitPressed:);
    SEL decAct = @selector(decimalPressed:);
    NSColor *orange = [NSColor orangeColor];

    UDCalcButton *ac  = makeButton(@"AC", UDOpClear,   opAct,  self, 0, nil);
    UDCalcButton *neg = makeButton(@"±",  UDOpNegate,  opAct,  self, 0, nil);
    UDCalcButton *pct = makeButton(@"%",  UDOpPercent, opAct,  self, 0, nil);
    UDCalcButton *div = makeButton(@"÷",  UDOpDiv,     opAct,  self, 0, orange);
    [g addRowWithViews:@[ac, neg, pct, div]];
    self.acButton = ac;

    UDCalcButton *b7  = makeButton(@"7", 7, digAct, self, 0, nil);
    UDCalcButton *b8  = makeButton(@"8", 8, digAct, self, 0, nil);
    UDCalcButton *b9  = makeButton(@"9", 9, digAct, self, 0, nil);
    UDCalcButton *mul = makeButton(@"×", UDOpMul, opAct, self, 0, orange);
    [g addRowWithViews:@[b7, b8, b9, mul]];

    UDCalcButton *b4  = makeButton(@"4", 4, digAct, self, 0, nil);
    UDCalcButton *b5  = makeButton(@"5", 5, digAct, self, 0, nil);
    UDCalcButton *b6  = makeButton(@"6", 6, digAct, self, 0, nil);
    UDCalcButton *sub = makeButton(@"−", UDOpSub, opAct, self, 0, orange);
    [g addRowWithViews:@[b4, b5, b6, sub]];

    UDCalcButton *b1  = makeButton(@"1", 1, digAct, self, 0, nil);
    UDCalcButton *b2  = makeButton(@"2", 2, digAct, self, 0, nil);
    UDCalcButton *b3  = makeButton(@"3", 3, digAct, self, 0, nil);
    UDCalcButton *add = makeButton(@"+", UDOpAdd, opAct, self, 0, orange);
    [g addRowWithViews:@[b1, b2, b3, add]];

    UDCalcButton *b0  = makeButton(@"0", 0,      digAct, self, 0, nil);
    UDCalcButton *dot = makeButton(@".", 0,      decAct, self, 0, nil);
    UDCalcButton *eq  = makeButton(@"=", UDOpEq, opAct,  self, 0, orange);
    // "0" normally spans 2 columns, but mergeCells not supported — use placeholder
    NSView *placeholder = [[NSView alloc] initWithFrame:NSZeroRect];
    [g addRowWithViews:@[b0, placeholder, dot, eq]];
    self.equalsButton = eq;

    // Set consistent row height / col width
    for (NSInteger r = 0; r < g.numberOfRows; r++)
        [g rowAtIndex:r].height = kGridButtonHeight;
    for (NSInteger c = 0; c < g.numberOfColumns; c++)
        [g columnAtIndex:c].width = kGridButtonWidth;
}

// ---------- Scientific Grid (6 cols × 5 rows) ----------
- (void)rebuildScientificGrid {
    // The scientific grid is a subview of self.scientificView
    NSGridView *g = nil;
    for (NSView *sub in self.scientificView.subviews) {
        if ([sub isKindOfClass:[NSGridView class]]) {
            g = (NSGridView *)sub;
            break;
        }
    }
    if (!g || ![self gridNeedsRebuild:g]) return;
    [self clearGrid:g];

    SEL opAct  = @selector(operationPressed:);
    SEL secAct = @selector(secondFunctionPressed:);

    // Row 0: ( ) mc m+ m- mr
    UDCalcButton *lp = makeButton(@"(",  UDOpParenLeft,  opAct, self, 0, nil);
    UDCalcButton *rp = makeButton(@")",  UDOpParenRight, opAct, self, 0, nil);
    UDCalcButton *mc = makeButton(@"mc", UDOpMC,   opAct, self, 0, nil);
    UDCalcButton *mp = makeButton(@"m+", UDOpMAdd, opAct, self, 0, nil);
    UDCalcButton *mm = makeButton(@"m-", UDOpMSub, opAct, self, 0, nil);
    UDCalcButton *mr = makeButton(@"mr", UDOpMR,   opAct, self, 0, nil);
    [g addRowWithViews:@[lp, rp, mc, mp, mm, mr]];
    self.parenLeftButton = lp;
    self.parenRightButton = rp;

    // Row 1: 2nd x² x³ x^y e^x 10^x
    UDCalcButton *sec  = makeButton(@"2nd", UDOpSecondFunc, secAct, self, CalcButtonType2nd, nil);
    UDCalcButton *sqr  = makeButton(@"x²",  UDOpSquare, opAct, self, CalcButtonTypeSquare, nil);
    UDCalcButton *cube = makeButton(@"x³",  UDOpCube,   opAct, self, CalcButtonTypeCube, nil);
    UDCalcButton *pw   = makeButton(@"x^y", UDOpPow,    opAct, self, CalcButtonTypePower, nil);
    UDCalcButton *ex   = makeButton(@"e^x", UDOpExp,    opAct, self, CalcButtonTypeExp, nil);
    UDCalcButton *t10  = makeButton(@"10^x",UDOpPow10,  opAct, self, CalcButtonTypeTenPower, nil);
    [g addRowWithViews:@[sec, sqr, cube, pw, ex, t10]];
    self.expButton = ex;
    self.xthPowerOf10Button = t10;

    // Row 2: 1/x √x ³√x ʸ√x ln log₁₀
    UDCalcButton *inv  = makeButton(@"1/x", UDOpInvert, opAct, self, CalcButtonTypeInverse, nil);
    UDCalcButton *sq   = makeButton(@"√x",  UDOpSqrt,   opAct, self, CalcButtonTypeSqrt, nil);
    UDCalcButton *cb   = makeButton(@"³√x", UDOpCbrt,   opAct, self, CalcButtonTypeCubeRoot, nil);
    UDCalcButton *yr   = makeButton(@"ʸ√x", UDOpYRoot,  opAct, self, CalcButtonTypeYRoot, nil);
    UDCalcButton *ln   = makeButton(@"ln",  UDOpLn,     opAct, self, 0, nil);
    UDCalcButton *lg10 = makeButton(@"log₁₀",UDOpLog10, opAct, self, CalcButtonTypeLog10, nil);
    [g addRowWithViews:@[inv, sq, cb, yr, ln, lg10]];
    self.lnButton = ln;
    self.log10Button = lg10;

    // Row 3: x! sin cos tan e EE
    UDCalcButton *fact = makeButton(@"x!",  UDOpFactorial, opAct, self, 0, nil);
    UDCalcButton *sin  = makeButton(@"sin", UDOpSin,  opAct, self, CalcButtonTypeSin, nil);
    UDCalcButton *cos  = makeButton(@"cos", UDOpCos,  opAct, self, CalcButtonTypeCos, nil);
    UDCalcButton *tan  = makeButton(@"tan", UDOpTan,  opAct, self, CalcButtonTypeTan, nil);
    UDCalcButton *ce   = makeButton(@"e",   UDOpConstE, opAct, self, 0, nil);
    UDCalcButton *ee   = makeButton(@"EE",  UDOpEE,  opAct, self, 0, nil);
    [g addRowWithViews:@[fact, sin, cos, tan, ce, ee]];
    self.sinButton = sin;
    self.cosButton = cos;
    self.tanButton = tan;

    // Row 4: Rad sinh cosh tanh π Rand
    UDCalcButton *rd   = makeButton(@"Rad", UDOpRad,     opAct, self, 0, nil);
    UDCalcButton *sinh = makeButton(@"sinh",UDOpSinh,    opAct, self, CalcButtonTypeSinh, nil);
    UDCalcButton *cosh = makeButton(@"cosh",UDOpCosh,    opAct, self, CalcButtonTypeCosh, nil);
    UDCalcButton *tanh = makeButton(@"tanh",UDOpTanh,    opAct, self, CalcButtonTypeTanh, nil);
    UDCalcButton *pi   = makeButton(@"π",   UDOpConstPi, opAct, self, CalcButtonTypePi, nil);
    UDCalcButton *rnd  = makeButton(@"Rand",UDOpRand,    opAct, self, 0, nil);
    [g addRowWithViews:@[rd, sinh, cosh, tanh, pi, rnd]];
    self.radDegButton = rd;
    self.sinhButton = sinh;
    self.coshButton = cosh;
    self.tanhButton = tanh;

    for (NSInteger r = 0; r < g.numberOfRows; r++)
        [g rowAtIndex:r].height = kGridButtonHeight;
    for (NSInteger c = 0; c < g.numberOfColumns; c++)
        [g columnAtIndex:c].width = kGridButtonWidth;
}

// ---------- Programmer Grid (7 cols × 6 rows) ----------
- (void)rebuildProgrammerGrid {
    NSGridView *g = self.programmerGridView;
    if (![self gridNeedsRebuild:g]) return;
    [self clearGrid:g];

    SEL opAct  = @selector(operationPressed:);
    SEL digAct = @selector(digitPressed:);
    NSColor *orange = [NSColor orangeColor];

    // Row 0: AND OR D E F AC C
    UDCalcButton *band = makeButton(@"AND",UDOpBitwiseAnd,opAct,self,0,nil);
    UDCalcButton *bor  = makeButton(@"OR", UDOpBitwiseOr, opAct,self,0,nil);
    // Hex digits D–F: UDOpDigitA (10) + offset
    UDCalcButton *bD   = makeButton(@"D",  UDOpDigitA+3,  digAct,self,0,nil);
    UDCalcButton *bE   = makeButton(@"E",  UDOpDigitA+4,  digAct,self,0,nil);
    UDCalcButton *bF   = makeButton(@"F",  UDOpDigitA+5,  digAct,self,0,nil);
    UDCalcButton *pac  = makeButton(@"AC", UDOpClearAll,   opAct,self,0,nil);
    UDCalcButton *pc   = makeButton(@"C",  UDOpClear,      opAct,self,0,nil);
    [g addRowWithViews:@[band, bor, bD, bE, bF, pac, pc]];
    self.pDButton = bD;
    self.pEButton = bE;
    self.pFButton = bF;

    // Row 1: NOR XOR A B C RoL RoR
    UDCalcButton *bnor = makeButton(@"NOR",UDOpBitwiseNor,opAct,self,0,nil);
    UDCalcButton *bxor = makeButton(@"XOR",UDOpBitwiseXor,opAct,self,0,nil);
    UDCalcButton *bA   = makeButton(@"A",  UDOpDigitA,    digAct,self,0,nil);
    UDCalcButton *bB   = makeButton(@"B",  UDOpDigitA+1,  digAct,self,0,nil);
    UDCalcButton *bC   = makeButton(@"C",  UDOpDigitA+2,  digAct,self,0,nil);
    UDCalcButton *rol  = makeButton(@"RoL",UDOpRotateLeft, opAct,self,0,nil);
    UDCalcButton *ror  = makeButton(@"RoR",UDOpRotateRight,opAct,self,0,nil);
    [g addRowWithViews:@[bnor, bxor, bA, bB, bC, rol, ror]];
    self.pAButton = bA;
    self.pBButton = bB;
    self.pCButton = bC;

    // Row 2: << >> 7 8 9 2's 1's
    UDCalcButton *sl1  = makeButton(@"<<", UDOpShift1Left,  opAct,self,0,nil);
    UDCalcButton *sr1  = makeButton(@">>", UDOpShift1Right, opAct,self,0,nil);
    UDCalcButton *p7   = makeButton(@"7",  7,  digAct,self,0,nil);
    UDCalcButton *p8   = makeButton(@"8",  8,  digAct,self,0,nil);
    UDCalcButton *p9   = makeButton(@"9",  9,  digAct,self,0,nil);
    UDCalcButton *c2s  = makeButton(@"2's",UDOpComp2, opAct,self,0,nil);
    UDCalcButton *c1s  = makeButton(@"1's",UDOpComp1, opAct,self,0,nil);
    [g addRowWithViews:@[sl1, sr1, p7, p8, p9, c2s, c1s]];
    self.p8Button = p8;
    self.p9Button = p9;

    // Row 3: X<<Y X>>Y 4 5 6 ÷ −
    UDCalcButton *sly  = makeButton(@"X<<Y",UDOpShiftLeft,  opAct,self,0,nil);
    UDCalcButton *sry  = makeButton(@"X>>Y",UDOpShiftRight, opAct,self,0,nil);
    UDCalcButton *p4   = makeButton(@"4",   4,  digAct,self,0,nil);
    UDCalcButton *p5   = makeButton(@"5",   5,  digAct,self,0,nil);
    UDCalcButton *p6   = makeButton(@"6",   6,  digAct,self,0,nil);
    UDCalcButton *pdiv = makeButton(@"÷",   UDOpDiv, opAct,self,0,orange);
    UDCalcButton *psub = makeButton(@"−",   UDOpSub, opAct,self,0,orange);
    [g addRowWithViews:@[sly, sry, p4, p5, p6, pdiv, psub]];

    // Row 4: byte-flip [placeholder] 1 2 3 × +
    UDCalcButton *bf   = makeButton(@"byte flip",UDOpByteFlip, opAct,self,0,nil);
    NSView *ph4        = [[NSView alloc] initWithFrame:NSZeroRect];
    UDCalcButton *p1   = makeButton(@"1",  1,  digAct,self,0,nil);
    UDCalcButton *p2   = makeButton(@"2",  2,  digAct,self,0,nil);
    UDCalcButton *p3   = makeButton(@"3",  3,  digAct,self,0,nil);
    UDCalcButton *pmul = makeButton(@"×",  UDOpMul, opAct,self,0,orange);
    UDCalcButton *padd = makeButton(@"+",  UDOpAdd, opAct,self,0,orange);
    [g addRowWithViews:@[bf, ph4, p1, p2, p3, pmul, padd]];

    // Row 5: word-flip [placeholder] FF 0 00 = [placeholder]
    UDCalcButton *wf   = makeButton(@"word flip",UDOpWordFlip, opAct,self,0,nil);
    NSView *ph5a       = [[NSView alloc] initWithFrame:NSZeroRect];
    UDCalcButton *ff   = makeButton(@"FF", UDOpDigitFF, digAct,self,0,nil);
    UDCalcButton *p0   = makeButton(@"0",  0,  digAct,self,0,nil);
    UDCalcButton *d00  = makeButton(@"00", UDOpDigit00, digAct,self,0,nil);
    UDCalcButton *peq  = makeButton(@"=",  UDOpEq, opAct,self,0,orange);
    NSView *ph5b       = [[NSView alloc] initWithFrame:NSZeroRect];
    [g addRowWithViews:@[wf, ph5a, ff, p0, d00, peq, ph5b]];
    self.pFFButton = ff;

    for (NSInteger r = 0; r < g.numberOfRows; r++)
        [g rowAtIndex:r].height = kGridButtonHeight;
    for (NSInteger c = 0; c < g.numberOfColumns; c++)
        [g columnAtIndex:c].width = kGridButtonWidth;
}

/*
 * GNUstep's Auto Layout solver loads constraints from XIBs but does NOT
 * re-solve when constraint constants change or the window resizes.  Views
 * stay at their XIB-designed positions regardless of window frame changes.
 *
 * We work around this by:
 * 1. Removing all inter-view constraints from self.view in viewDidLoad
 * 2. Tracking "logical" constraint constants in shadow variables
 * 3. Manually positioning the four main subviews (display, programmer
 *    input, scientific drawer, keypad) after each mode change
 *
 * Internal constraints on each subview (grid layouts, stack views) are
 * left intact — only the parent-to-child positioning is manual.
 */
static CGFloat _gs_keypadH;
static CGFloat _gs_scientificW;
static CGFloat _gs_containerH;
static CGFloat _gs_wrapperH;

/*
 * Enable frame-based positioning on a single view.
 * XIBs set translatesAutoresizingMaskIntoConstraints=NO, which
 * disables autoresizing; we reverse that here.
 * Only applied to top-level containers — NOT recursively, since
 * recursive autoresizing causes negative child widths when parents
 * shrink below XIB-designed sizes.
 */
/* Compute the fitting width for an NSSegmentedControl by measuring
 * each segment's label text.  GNUstep's sizeToFit is broken for
 * NSSegmentedControl (returns ~0 width).                            */
static CGFloat ud_segmentedControlFittingWidth(NSSegmentedControl *sc) {
    static const CGFloat kSegPad = 16.0; // per-segment padding
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

static void enableAutoresizing(NSView *view) {
    [view setTranslatesAutoresizingMaskIntoConstraints:YES];
    [view setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
}

/*
 * Position the four main subviews of self.view based on the current
 * shadow variable values.  Called after window frame changes.
 *
 * Layout (AppKit coords, origin bottom-left):
 *   Top:    displayTabView        (1px margins on top/left/right)
 *   Middle: programmerInputView   (1px gap below display)
 *   Bottom: scientificView (left) + keypadTabView (right)
 */
- (void)gnustepLayoutSubviews {
    NSRect bounds = self.view.bounds;
    CGFloat W = bounds.size.width;
    CGFloat H = bounds.size.height;

    CGFloat keypadH    = _gs_keypadH;
    CGFloat containerH = _gs_containerH;
    CGFloat drawerW    = _gs_scientificW;

    // Display height: fill remaining space above programmer + keypad
    // Constraint chain: 1(top) + displayH + 1(gap) + containerH + keypadH = H
    CGFloat displayH = H - containerH - keypadH - 2.0;
    if (displayH < kMinDisplayHeight) displayH = kMinDisplayHeight;

    // Guard all dimensions against negative values (can happen during
    // mode transitions before the window frame is updated).
    CGFloat displayW = MAX(0, W - 2);
    displayH = MAX(0, displayH);
    CGFloat keypadW = MAX(0, W - drawerW - 1);

    // Display at top with 1px margins
    [self.displayTabView setFrame:NSMakeRect(1, containerH + keypadH + 1,
                                             displayW, displayH)];

    // GNUstep's NSTabView doesn't propagate frame changes to tab item
    // content views.  Explicitly resize the display text field so
    // right-aligned text isn't clipped at its XIB-designed width (607px).
    [self.displayField setFrame:NSMakeRect(0, 0, displayW, displayH)];

    // Programmer input below display
    [self.programmerInputView setFrame:NSMakeRect(0, keypadH, MAX(0, W), containerH)];

    // Scientific view at bottom-left
    [self.scientificView setFrame:NSMakeRect(0, 0, drawerW, keypadH)];

    // Resize the scientific grid to fill its parent (GNUstep doesn't
    // propagate frame changes to children of plain NSView containers)
    if (drawerW > 0) {
        for (NSView *sub in self.scientificView.subviews) {
            if ([sub isKindOfClass:[NSGridView class]]) {
                [sub setFrame:NSMakeRect(0, 0, drawerW, keypadH)];
                break;
            }
        }
    }

    // Keypad at bottom-right (1px right margin matches XIB)
    [self.basicOrProgrammerTabView setFrame:NSMakeRect(drawerW, 0,
                                                       keypadW, keypadH)];

    // GNUstep's NSTabView doesn't propagate frame changes to content
    // views.  Resize BOTH grids so whichever is active fills the tab
    // area.  (We can't rely on self.calc.mode here because it hasn't
    // been updated yet when called from setCalculatorMode:.)
    [self.basicGridView setFrame:NSMakeRect(0, 0, keypadW, keypadH)];
    [self.programmerGridView setFrame:NSMakeRect(0, 0, keypadW, keypadH)];

    // Similarly, resize programmer input internals.  GNUstep's
    // NSStackView doesn't re-arrange children when frames change.
    // Layout (AppKit coords, origin bottom-left within containerH):
    //   Bottom: bitDisplayWrapperView  (height = wrapperH)
    //   Top:    button row             (height = kProgButtonRowH)
    if (containerH > 0) {
        static const CGFloat kProgButtonRowH = 30.0;
        CGFloat wrapperH = _gs_wrapperH;

        // Bit display wrapper at the bottom of the container
        [self.bitDisplayWrapperView setFrame:NSMakeRect(0, 0,
                                                        MAX(0, W), wrapperH)];
        [self.bitDisplayView setFrame:NSMakeRect(0, 0,
                                                 MAX(0, W), wrapperH)];

        // Button row (encoding, show-binary, base) at the top.
        // Found via baseSegmentedControl's superview (no IBOutlet).
        NSView *buttonRow = [self.baseSegmentedControl superview];
        if (buttonRow) {
            CGFloat rowY = containerH - kProgButtonRowH;
            [buttonRow setFrame:NSMakeRect(0, rowY, MAX(0, W), kProgButtonRowH)];

            // GNUstep's horizontal NSStackView doesn't re-arrange
            // children.  Position the three controls explicitly:
            //   [encoding] [show-binary] [base]
            static const CGFloat kPad = 8.0;
            static const CGFloat kGap = 4.0;
            CGFloat ctrlH = kProgButtonRowH - 4;
            CGFloat ctrlY = 2.0;
            CGFloat x = kPad;

            // GNUstep's sizeToFit is broken for NSSegmentedControl
            // (returns ~0 width).  Compute width from segment labels.
            CGFloat encW = ud_segmentedControlFittingWidth(
                               self.encodingSegmentedControl);
            [self.encodingSegmentedControl setFrame:
                NSMakeRect(x, ctrlY, encW, ctrlH)];
            x += encW + kGap;

            [self.showBinaryViewButton sizeToFit];
            NSSize btnSz = [self.showBinaryViewButton frame].size;
            [self.showBinaryViewButton setFrame:
                NSMakeRect(x, ctrlY, btnSz.width, ctrlH)];
            x += btnSz.width + kGap;

            CGFloat baseW = ud_segmentedControlFittingWidth(
                                self.baseSegmentedControl);
            [self.baseSegmentedControl setFrame:
                NSMakeRect(x, ctrlY, baseW, ctrlH)];
        }
    }

    [self.view setNeedsDisplay:YES];
}

#endif /* GNUSTEP */

- (void)viewDidLoad {
    [super viewDidLoad];

    self.calc = [[UDCalc alloc] init];
    self.calc.delegate = self;
    self.bitDisplayView.delegate = self;

    // Store the designed width of the scientific pane
    self.standardScientificWidth = self.scientificWidthConstraint.constant;
    self.standardProgrammerInputHeight = self.programmerInputHeightConstraint.constant;
    self.standardBitWrapperHeight = self.bitWrapperHeightConstraint.constant;

    // fix up button layout

#ifdef GNUSTEP
    // Initialize shadow variables from the XIB constraint constants.
    _gs_keypadH    = self.keypadHeightConstraint.constant;
    _gs_scientificW = self.scientificWidthConstraint.constant;
    _gs_containerH = self.programmerInputHeightConstraint.constant;
    _gs_wrapperH   = self.bitWrapperHeightConstraint.constant;

    // Remove inter-view constraints from self.view so we can position
    // subviews manually.  GNUstep's solver loads constraints from XIBs
    // but doesn't re-solve when the window resizes or constants change.
    // Internal constraints on each subview (grids, stacks) stay intact.
    // Note: performSelector: is used because GNUstep headers don't declare
    // -constraints or -removeConstraints: on NSView (they exist at runtime).
    {
        NSArray *constraints = [self.view performSelector:@selector(constraints)];
        if ([constraints count] > 0) {
            [self.view performSelector:@selector(removeConstraints:)
                            withObject:constraints];
        }
    }

    // Enable autoresizing on the four top-level containers only (not
    // recursively) so gnustepLayoutSubviews can position them.
    // XIBs set translatesAutoresizingMaskIntoConstraints=NO which
    // disables frame-based positioning; we reverse that here.
    // Children keep their XIB-internal constraints/autoresizing.
    enableAutoresizing(self.displayTabView);
    enableAutoresizing(self.programmerInputView);
    enableAutoresizing(self.scientificView);
    enableAutoresizing(self.basicOrProgrammerTabView);

    // GNUstep's XIB parser may not connect NSGridCell contentViews from
    // Xcode XIBs.  Detect empty grids and rebuild them programmatically.
    [self rebuildBasicGrid];
    [self rebuildScientificGrid];
    [self rebuildProgrammerGrid];
    // Apply orange operator colors (XIB color runtime attributes not decoded)
    [self applyOperatorColorsInView:self.view];
    // GNUstep may resolve catalog colors (controlTextColor, labelColor)
    // to white in some themes, making text invisible on light backgrounds.
    {
        NSColor *dark = [NSColor blackColor];
        [self.displayField setTextColor:dark];
        [self.radLabel setTextColor:dark];
        [self.charLabel setTextColor:dark];
        [self.radLabelRPN setTextColor:dark];
        [self.charLabelRPN setTextColor:dark];
    }
#else
    // mergeCellsInHorizontalRange:verticalRange: is not yet implemented
    // in GNUstep's NSGridView — skip on GNUstep (purely cosmetic).

    // button "0" (basic/scientific mode)
    // merge row 5 (index 4), columns 1-2 (start 0, len 2)
    [self.basicGridView mergeCellsInHorizontalRange:NSMakeRange(0, 2)
                                      verticalRange:NSMakeRange(4, 1)];

    // button "byte flip" (programmer mode)
    // merge row 5 (index 4), columns 1-2 (start 0, len 2)
    [self.programmerGridView mergeCellsInHorizontalRange:NSMakeRange(0, 2)
                                           verticalRange:NSMakeRange(4, 1)];

    // button "word flip" (programmer mode)
    // merge row 6 (index 5), columns 1-2 (start 0, len 2)
    [self.programmerGridView mergeCellsInHorizontalRange:NSMakeRange(0, 2)
                                           verticalRange:NSMakeRange(5, 1)];

    // button "enter" (programmer mode)
    // merge row 6 (index 5), columns 6-7 (start 5, len 2)
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
#ifdef GNUSTEP
    _gs_wrapperH = settings.showBinaryView ? self.standardBitWrapperHeight : 0;
#else
    self.bitWrapperHeightConstraint.constant = settings.showBinaryView ? self.standardBitWrapperHeight : 0;
#endif

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

#ifdef GNUSTEP
    // Read from shadow variables — GNUstep's solver doesn't track live changes
    CGFloat currentKeypadH = _gs_keypadH;
    CGFloat currentDrawerW = _gs_scientificW;
    CGFloat currentContainerH = _gs_containerH;
#else
    CGFloat currentKeypadH = self.keypadHeightConstraint.constant;
    CGFloat currentDrawerW = self.scientificWidthConstraint.constant;
    CGFloat currentContainerH = self.programmerInputHeightConstraint.constant;
#endif
    
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

#ifdef GNUSTEP
    // Update shadow variables and manually position subviews.
    _gs_keypadH    = targetKeypadH;
    _gs_scientificW = targetDrawerW;
    _gs_containerH = targetContainerH;
    _gs_wrapperH   = targetWrapperH;
    [self gnustepLayoutSubviews];
#else
    self.keypadHeightConstraint.constant = targetKeypadH;
    self.scientificWidthConstraint.constant = targetDrawerW;

    // 3. Animate Programmer Constraints (Both Inner and Outer)
    self.programmerInputHeightConstraint.constant = targetContainerH;
    self.bitWrapperHeightConstraint.constant = targetWrapperH;

    [self.view.superview layoutSubtreeIfNeeded];
#endif

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
#ifdef GNUSTEP
    CGFloat currentStackHeight = _gs_containerH;
#else
    CGFloat currentStackHeight = self.programmerInputHeightConstraint.constant;
#endif
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
#ifdef GNUSTEP
    _gs_wrapperH   = targetWrapperHeight;
    _gs_containerH = targetStackHeight;
    [self gnustepLayoutSubviews];
#else
    self.bitWrapperHeightConstraint.constant = targetWrapperHeight;
    self.programmerInputHeightConstraint.constant = targetStackHeight;
#endif
}

- (IBAction)baseSelected:(NSSegmentedControl *)sender {
    NSInteger selectedTag = [[sender cell] tagForSegment:[sender selectedSegment]];
    
    UDBase newBase = (UDBase)selectedTag;

    self.calc.inputBase = newBase;

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
            cell.textField.textColor = [NSColor secondaryLabelColor]; // Dim history
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
