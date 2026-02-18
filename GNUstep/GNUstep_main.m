/*
 * GNUstep_main.m
 *
 * GNUstep-specific AppDelegate that creates the calculator UI
 * programmatically (XIB files from Xcode are not compatible with GNUstep).
 *
 * This replaces AppDelegate.m + UDCalcViewController.m + main.m
 * for the GNUstep build.
 */

#import <AppKit/AppKit.h>
#import "UDCalc.h"
#import "UDCalcButton.h"
#import "UDValueFormatter.h"
#import "UDSettingsManager.h"
#import "UDUnitConverter.h"
#import "UDConversionHistoryManager.h"
#import "UDTape.h"

/* Notification names (matching the macOS UDCalcViewController.m) */
NSString * const UDCalcDidFinishCalculationNotification = @"org.underivable.calculator.DidFinishCalculation";
NSString * const UDCalcFormulaKey = @"UDCalcFormulaKey";
NSString * const UDCalcResultKey = @"UDCalcResultKey";

/* ============================================================
 * GNUstep Calculator Controller
 *
 * Builds a calculator layout programmatically with:
 *   - Basic keypad (digits, +, -, *, /, =, C, AC, %, +/-)
 *   - Scientific drawer (sin, cos, tan, sqrt, pow, ln, log, etc.)
 *   - Memory operations (MC, MR, M+, M-)
 *   - Parentheses
 * ============================================================ */

static const CGFloat kPad   = 4.0;
static const CGFloat kBtnW  = 54.0;
static const CGFloat kBtnH  = 32.0;

@interface GNUstepCalcController : NSObject <UDCalcDelegate>
{
    NSWindow    *_window;
    NSTextField *_displayField;
    NSTextField *_radLabel;
}

@property (strong) UDCalc *calc;
@property (strong) UDTape *tape;

- (void)buildUI;
- (NSMenu *)buildMainMenu;
@end

@implementation GNUstepCalcController

- (instancetype)init {
    self = [super init];
    if (self) {
        _calc = [[UDCalc alloc] init];
        _calc.delegate = self;
        _tape = [[UDTape alloc] init];
    }
    return self;
}

/* --------------------------------------------------------
 * Helper: create a button
 * -------------------------------------------------------- */
- (NSButton *)btnWithTitle:(NSString *)title
                      tag:(NSInteger)tag
                   action:(SEL)action
                    frame:(NSRect)frame
{
    NSButton *btn = [[NSButton alloc] initWithFrame:frame];
    [btn setTitle:title];
    [btn setTag:tag];
    [btn setTarget:self];
    [btn setAction:action];
    [btn setBezelStyle:NSRegularSquareBezelStyle];
    return btn;
}

/* --------------------------------------------------------
 * Build UI
 * -------------------------------------------------------- */
- (void)buildUI {
    /* Column counts: 4 basic + 5 scientific = 9 cols (sci hidden initially) */
    int basicCols = 4;
    int sciCols   = 5;
    int totalCols = basicCols + sciCols;

    CGFloat winW = kPad + totalCols * (kBtnW + kPad);
    CGFloat winH = kPad + 50 + kPad + 7 * (kBtnH + kPad) + kPad;

    NSRect winFrame = NSMakeRect(200, 200, winW, winH);
    _window = [[NSWindow alloc]
        initWithContentRect:winFrame
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskMiniaturizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    [_window setTitle:@"Calculator"];

    NSView *content = [_window contentView];
    CGFloat curY = winH;

    /* --------------------------------------------------------
     * Display
     * -------------------------------------------------------- */
    CGFloat dispH = 50.0;
    curY -= dispH + kPad;
    _displayField = [[NSTextField alloc]
        initWithFrame:NSMakeRect(kPad, curY, winW - 2*kPad, dispH)];
    [_displayField setStringValue:@"0"];
    [_displayField setEditable:NO];
    [_displayField setAlignment:NSTextAlignmentRight];
    [_displayField setFont:[NSFont userFixedPitchFontOfSize:26]];
    [_displayField setBezeled:YES];
    [_displayField setDrawsBackground:YES];
    [content addSubview:_displayField];

    /* Rad/Deg indicator */
    _radLabel = [[NSTextField alloc]
        initWithFrame:NSMakeRect(kPad + 4, curY + 2, 40, 16)];
    [_radLabel setStringValue:@"Rad"];
    [_radLabel setFont:[NSFont systemFontOfSize:10]];
    [_radLabel setBezeled:NO];
    [_radLabel setDrawsBackground:NO];
    [_radLabel setEditable:NO];
    [_radLabel setSelectable:NO];
    [content addSubview:_radLabel];

    /* --------------------------------------------------------
     * Row 0 (memory): MC  MR  M+  M-  |  (   )   x²  x³  xʸ
     * -------------------------------------------------------- */
    typedef struct { const char *label; NSInteger tag; SEL act; } BD;

    #define OP(l,t)  { l, t, @selector(operationPressed:) }
    #define DG(l,t)  { l, t, @selector(digitPressed:) }
    #define DC       { ".", UDOpDecimal, @selector(decimalPressed:) }
    #define RD       { "Rad", UDOpRad, @selector(operationPressed:) }

    /* 7 rows x 9 columns */
    BD layout[7][9] = {
        /* row 0 – memory + sci top */
        { OP("MC", UDOpMC), OP("MR", UDOpMR), OP("M+", UDOpMAdd), OP("M-", UDOpMSub),
          OP("(", UDOpParenLeft), OP(")", UDOpParenRight), OP("x²", UDOpSquare), OP("x³", UDOpCube), OP("xʸ", UDOpPow) },
        /* row 1 – clear row + sci */
        { OP("C", UDOpClear), OP("+/-", UDOpNegate), OP("%", UDOpPercent), OP("/", UDOpDiv),
          OP("1/x", UDOpInvert), OP("√x", UDOpSqrt), OP("∛x", UDOpCbrt), OP("ⁿ√x", UDOpYRoot), OP("x!", UDOpFactorial) },
        /* row 2 */
        { DG("7", 7), DG("8", 8), DG("9", 9), OP("×", UDOpMul),
          OP("sin", UDOpSin), OP("cos", UDOpCos), OP("tan", UDOpTan), OP("eˣ", UDOpExp), OP("10ˣ", UDOpPow10) },
        /* row 3 */
        { DG("4", 4), DG("5", 5), DG("6", 6), OP("-", UDOpSub),
          OP("sin⁻¹", UDOpSinInverse), OP("cos⁻¹", UDOpCosInverse), OP("tan⁻¹", UDOpTanInverse), OP("ln", UDOpLn), OP("log₁₀", UDOpLog10) },
        /* row 4 */
        { DG("1", 1), DG("2", 2), DG("3", 3), OP("+", UDOpAdd),
          OP("sinh", UDOpSinh), OP("cosh", UDOpCosh), OP("tanh", UDOpTanh), OP("log₂", UDOpLog2), OP("logᵧ", UDOpLogY) },
        /* row 5 */
        { DG("0", 0), DC, OP("=", UDOpEq), OP("AC", UDOpClearAll),
          OP("sinh⁻¹", UDOpSinhInverse), OP("cosh⁻¹", UDOpCoshInverse), OP("tanh⁻¹", UDOpTanhInverse), RD, OP("Rand", UDOpRand) },
        /* row 6 – constants */
        { {NULL,0,NULL}, {NULL,0,NULL}, {NULL,0,NULL}, {NULL,0,NULL},
          OP("π", UDOpConstPi), OP("e", UDOpConstE), OP("EE", UDOpEE), {NULL,0,NULL}, {NULL,0,NULL} },
    };

    #undef OP
    #undef DG
    #undef DC
    #undef RD

    for (int row = 0; row < 7; row++) {
        curY -= kBtnH + kPad;
        for (int col = 0; col < totalCols; col++) {
            BD def = layout[row][col];
            if (def.label == NULL) continue;

            CGFloat x = kPad + col * (kBtnW + kPad);
            NSButton *btn = [self btnWithTitle:[NSString stringWithUTF8String:def.label]
                                           tag:def.tag
                                        action:def.act
                                         frame:NSMakeRect(x, curY, kBtnW, kBtnH)];
            [content addSubview:btn];
        }
    }

    [_window makeKeyAndOrderFront:nil];
}

/* --------------------------------------------------------
 * Actions
 * -------------------------------------------------------- */

- (void)digitPressed:(id)sender {
    [self.calc inputDigit:[sender tag]];
    [self updateDisplay];
}

- (void)decimalPressed:(id)sender {
    [self.calc inputDecimal];
    [self updateDisplay];
}

- (void)operationPressed:(id)sender {
    UDOp op = (UDOp)[sender tag];

    /* Constants inject a number */
    if (op == UDOpConstPi) {
        [self.calc inputNumber:UDValueMakeDouble(M_PI)];
    } else if (op == UDOpConstE) {
        [self.calc inputNumber:UDValueMakeDouble(M_E)];
    } else if (op == UDOpExp) {
        /* e^x  =  e [pow] x */
        UDValue cur = [self.calc currentInputValue];
        [self.calc inputNumber:UDValueMakeDouble(M_E)];
        [self.calc performOperation:UDOpPow];
        [self.calc inputNumber:cur];
        [self.calc performOperation:UDOpEq];
    } else if (op == UDOpPow10) {
        /* 10^x */
        UDValue cur = [self.calc currentInputValue];
        [self.calc inputNumber:UDValueMakeDouble(10.0)];
        [self.calc performOperation:UDOpPow];
        [self.calc inputNumber:cur];
        [self.calc performOperation:UDOpEq];
    } else {
        [self.calc performOperation:op];
    }

    /* Update Rad/Deg indicator */
    [_radLabel setStringValue:self.calc.isRadians ? @"Rad" : @"Deg"];

    [self updateDisplay];
}

- (void)updateDisplay {
    [_displayField setStringValue:[self.calc currentDisplayValue]];
}

/* --------------------------------------------------------
 * UDCalcDelegate
 * -------------------------------------------------------- */

- (void)calculator:(UDCalc *)calc didCalculateResult:(UDValue)result forTree:(UDASTNode *)tree {
    if (!tree) return;
    [self.tape logTransaction:tree result:UDValueAsDouble(result)];
}

/* --------------------------------------------------------
 * Menu
 * -------------------------------------------------------- */

- (NSMenu *)buildMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"MainMenu"];

    /* App menu */
    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"Calculator" action:nil keyEquivalent:@""];
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:@"Calculator"];
    [appMenu addItemWithTitle:@"About Calculator" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    [appMenuItem setSubmenu:appMenu];
    [mainMenu addItem:appMenuItem];

    /* Edit menu */
    NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenuItem setSubmenu:editMenu];
    [mainMenu addItem:editMenuItem];

    return mainMenu;
}

@end

/* ============================================================
 * AppDelegate
 * ============================================================ */

@interface GNUstepAppDelegate : NSObject <NSApplicationDelegate>
{
    GNUstepCalcController *_controller;
}
@end

@implementation GNUstepAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [[UDSettingsManager sharedManager] registerDefaults];

    _controller = [[GNUstepCalcController alloc] init];
    [NSApp setMainMenu:[_controller buildMainMenu]];
    [_controller buildUI];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app {
    return YES;
}

@end

/* ============================================================
 * main
 * ============================================================ */

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        GNUstepAppDelegate *delegate = [[GNUstepAppDelegate alloc] init];
        [app setDelegate:delegate];
        [app run];
    }
    return 0;
}
