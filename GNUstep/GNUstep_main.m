/*
 * GNUstep_AppDelegate.m
 *
 * GNUstep-specific AppDelegate that creates the calculator UI
 * programmatically (XIB files from Xcode are not compatible with GNUstep).
 *
 * This replaces AppDelegate.m for the GNUstep build.
 */

#import <AppKit/AppKit.h>
#import "UDCalc.h"
#import "UDCalcButton.h"
#import "UDValueFormatter.h"
#import "UDSettingsManager.h"
#import "UDUnitConverter.h"
#import "UDConversionHistoryManager.h"
#import "UDTape.h"

/* Notification names (defined in the macOS UDCalcViewController.m) */
NSString * const UDCalcDidFinishCalculationNotification = @"org.underivable.calculator.DidFinishCalculation";
NSString * const UDCalcFormulaKey = @"UDCalcFormulaKey";
NSString * const UDCalcResultKey = @"UDCalcResultKey";

/* ============================================================
 * Minimal Calculator View Controller (GNUstep)
 *
 * Builds a basic calculator layout programmatically.
 * Supports Basic mode with the standard keypad.
 * ============================================================ */

@interface GNUstepCalcController : NSObject <UDCalcDelegate>
{
    NSWindow *_window;
    NSTextField *_displayField;
    UDCalc *_calc;
    UDTape *_tape;
}

@property (strong) UDCalc *calc;
@property (strong) UDTape *tape;

- (void)buildUI;
- (void)updateDisplay;
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

- (void)buildUI {
    /* --------------------------------------------------------
     * Window
     * -------------------------------------------------------- */
    NSRect winFrame = NSMakeRect(200, 200, 260, 400);
    _window = [[NSWindow alloc]
        initWithContentRect:winFrame
                  styleMask:(NSWindowStyleMaskTitled |
                             NSWindowStyleMaskClosable |
                             NSWindowStyleMaskMiniaturizable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    [_window setTitle:@"Calculator"];

    NSView *content = [_window contentView];
    CGFloat pad = 4.0;
    CGFloat btnW = 60.0;
    CGFloat btnH = 40.0;
    CGFloat x, y;

    /* --------------------------------------------------------
     * Display Field (top)
     * -------------------------------------------------------- */
    CGFloat dispH = 50.0;
    CGFloat dispY = winFrame.size.height - dispH - pad;
    _displayField = [[NSTextField alloc]
        initWithFrame:NSMakeRect(pad, dispY, winFrame.size.width - 2*pad, dispH)];
    [_displayField setStringValue:@"0"];
    [_displayField setEditable:NO];
    [_displayField setAlignment:NSTextAlignmentRight];
    [_displayField setFont:[NSFont systemFontOfSize:28]];
    [_displayField setBezeled:YES];
    [_displayField setDrawsBackground:YES];
    [content addSubview:_displayField];

    /* --------------------------------------------------------
     * Button Layout (5 rows x 4 columns, bottom-up)
     *
     * Row 0 (bottom): 0  .  =
     * Row 1:  1  2  3  +
     * Row 2:  4  5  6  -
     * Row 3:  7  8  9  *
     * Row 4 (top):  C  AC  %  /
     * -------------------------------------------------------- */

    typedef struct { const char *label; NSInteger tag; } BtnDef;

    BtnDef rows[5][4] = {
        { {"C",  UDOpClear},   {"+/-", UDOpNegate}, {"%",  UDOpPercent}, {"/",  UDOpDiv} },
        { {"7",  7},           {"8",   8},          {"9",  9},           {"*",  UDOpMul} },
        { {"4",  4},           {"5",   5},          {"6",  6},           {"-",  UDOpSub} },
        { {"1",  1},           {"2",   2},          {"3",  3},           {"+",  UDOpAdd} },
        { {"0",  0},           {".",   UDOpDecimal},{"=",  UDOpEq},      {"AC", UDOpClearAll} },
    };

    CGFloat startY = dispY - pad - btnH;

    for (int row = 0; row < 5; row++) {
        y = startY - row * (btnH + pad);
        for (int col = 0; col < 4; col++) {
            x = pad + col * (btnW + pad);
            BtnDef def = rows[row][col];

            NSButton *btn = [[NSButton alloc]
                initWithFrame:NSMakeRect(x, y, btnW, btnH)];
            [btn setTitle:[NSString stringWithUTF8String:def.label]];
            [btn setTag:def.tag];

            /* Route digits vs operations */
            NSInteger t = def.tag;
            if (t >= 0 && t <= 9) {
                [btn setTarget:self];
                [btn setAction:@selector(digitPressed:)];
            } else if (t == UDOpDecimal) {
                [btn setTarget:self];
                [btn setAction:@selector(decimalPressed:)];
            } else {
                [btn setTarget:self];
                [btn setAction:@selector(operationPressed:)];
            }

            [content addSubview:btn];
        }
    }

    [_window makeKeyAndOrderFront:nil];
}

/* --------------------------------------------------------
 * Actions
 * -------------------------------------------------------- */

- (void)digitPressed:(id)sender {
    NSInteger digit = [sender tag];
    [self.calc inputDigit:digit];
    [self updateDisplay];
}

- (void)decimalPressed:(id)sender {
    [self.calc inputDecimal];
    [self updateDisplay];
}

- (void)operationPressed:(id)sender {
    UDOp op = (UDOp)[sender tag];

    if (op == UDOpNegate) {
        [self.calc performOperation:UDOpNegate];
    } else {
        [self.calc performOperation:op];
    }
    [self updateDisplay];
}

- (void)updateDisplay {
    NSString *val = [self.calc currentDisplayValue];
    [_displayField setStringValue:val];

    /* Update C/AC label */
    /* (simplified - we don't track the button reference here) */
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
