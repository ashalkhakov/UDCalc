//
//  UDSelfTest.m
//  Calculator
//
//  Use cases, written as Feature / Scenario / Given-When-Then and run inside
//  the app (see UDSelfTest.h). To add one: write a scenario block in
//  UDRunFeatures below. Keep steps in the user's words and act through the
//  UI (UDClick, UDShortcut, UDChoose), not by calling the model directly,
//  so a scenario fails when the user's path fails.
//

#import "UDSelfTest.h"
#import "AppDelegate.h"
#import "UDCalcViewController.h"
#import "UDCalcButton.h"
#import "UDSettingsManager.h"
#import "UDUpdater.h"

NSString *UDSelfTestFilter;

static int UDFailed, UDPassed, UDScenarios;
static NSString *UDCurrentFeature;
static BOOL UDFeatureSelected;
static AppDelegate *UDApp;

#pragma mark - Output

static void UDSay(BOOL ok, NSString *step) {
    fprintf(stderr, "    %s %s\n", ok ? "PASS" : "FAIL", step.UTF8String);
    if (ok) UDPassed++; else UDFailed++;
}

static BOOL UDSelected(NSString *name) {
    if (!UDSelfTestFilter.length) return YES;
    return [name rangeOfString:UDSelfTestFilter options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static void UDFeature(NSString *name) {
    UDCurrentFeature = name;
    UDFeatureSelected = UDSelected(name);
}

/* A scenario runs when its feature or its own name matches the filter. */
static void UDScenario(NSString *name, void (^body)(void)) {
    if (!UDFeatureSelected && !UDSelected(name)) return;
    static NSString *printedFeature;
    if (printedFeature != UDCurrentFeature) {
        fprintf(stderr, "\nFeature: %s\n", UDCurrentFeature.UTF8String);
        printedFeature = UDCurrentFeature;
    }
    fprintf(stderr, "  Scenario: %s\n", name.UTF8String);
    UDScenarios++;
    @try {
        body();
    } @catch (NSException *e) {
        UDSay(NO, [NSString stringWithFormat:@"raised %@: %@", e.name, e.reason]);
    }
}

#pragma mark - Running the app

/* The run loop turned until done says so, or seconds pass. */
static BOOL UDWait(NSTimeInterval seconds, BOOL (^done)(void)) {
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!done() && [until timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    return done();
}

static void UDSettle(void) {
    UDWait(0.2, ^BOOL { return NO; });
}

static UDCalcViewController *UDController(void) { return UDApp.calcViewController; }
static UDCalc *UDModel(void) { return UDController().calc; }
static NSWindow *UDWindow(void) { return UDController().view.window; }

static NSString *UDDisplay(void) {
    return UDController().displayField.stringValue ?: @"";
}

static double UDValueShown(void) {
    return UDValueAsDouble(UDModel().currentInputValue);
}

#pragma mark - Acting through the UI

/* The button with this title that the user can see: in the window, not
   inside a hidden view (the other mode's keypad stays loaded, hidden). */
static NSButton *UDFindButton(NSView *view, NSString *title) {
    if (view.isHidden) return nil;
    if ([view isKindOfClass:[NSButton class]] && [[(NSButton *)view title] isEqualToString:title])
        return (NSButton *)view;
    for (NSView *sub in view.subviews) {
        NSButton *b = UDFindButton(sub, title);
        if (b) return b;
    }
    return nil;
}

/* Clicks the buttons named, in order: "1 2 + 7 =". */
static BOOL UDClick(NSString *keys) {
    for (NSString *key in [keys componentsSeparatedByString:@" "]) {
        if (!key.length) continue;
        NSButton *button = UDFindButton(UDWindow().contentView, key);
        if (!button || !button.isEnabled) {
            fprintf(stderr, "      (no enabled button \"%s\" on screen)\n", key.UTF8String);
            return NO;
        }
        [button performClick:nil];
    }
    UDSettle();
    return YES;
}

/* Cmd+<key> as the user types it: a key event handed to NSApp, which tries
   the key window and then the main menu, as for a real key press. */
static BOOL UDShortcut(NSString *key) {
    [UDWindow() makeKeyAndOrderFront:nil];
    UDSettle();
    NSEvent *down = [NSEvent keyEventWithType:NSEventTypeKeyDown
                                     location:NSZeroPoint
                                modifierFlags:NSEventModifierFlagCommand
                                    timestamp:[[NSProcessInfo processInfo] systemUptime]
                                 windowNumber:UDWindow().windowNumber
                                      context:nil
                                   characters:key
                  charactersIgnoringModifiers:key
                                    isARepeat:NO
                                      keyCode:0];
    [NSApp sendEvent:down];
    UDSettle();
    return YES;
}

static NSMenuItem *UDMenuItem(NSString *path, NSInteger *index) {
    NSArray *parts = [path componentsSeparatedByString:@"/"];
    NSMenu *menu = [NSApp mainMenu];
    NSMenuItem *item = nil;
    for (NSUInteger i = 0; i < parts.count; i++) {
        if (!menu) return nil;
        [menu update];   /* titles can change on validation (Show/Hide) */
        NSInteger at = [menu indexOfItemWithTitle:parts[i]];
        if (at < 0) return nil;
        item = [menu itemAtIndex:at];
        if (index) *index = at;
        if (i + 1 < parts.count) menu = item.submenu;
    }
    return item;
}

/* What the user sees in a menu once it is validated (enabled, ticked). */
static NSMenuItem *UDValidatedItem(NSString *path) {
    return UDMenuItem(path, NULL);
}

/* Chooses "View/Scientific Mode" from the main menu. */
static BOOL UDChoose(NSString *path) {
    NSInteger index = -1;
    NSMenuItem *item = UDMenuItem(path, &index);
    if (!item) {
        fprintf(stderr, "      (no menu item \"%s\")\n", path.UTF8String);
        return NO;
    }
    if (!item.isEnabled) {
        fprintf(stderr, "      (menu item \"%s\" is disabled)\n", path.UTF8String);
        return NO;
    }
    [item.menu performActionForItemAtIndex:index];
    UDSettle();
    return YES;
}

static BOOL UDTicked(NSString *path) {
    return UDValidatedItem(path).state == NSControlStateValueOn;
}

static BOOL UDEnabled(NSString *path) {
    return UDValidatedItem(path).isEnabled;
}

/* How many dark pixels the display field draws inside rect (in the field's
   coordinates), rendered the way it draws on screen: with its subviews. */
static NSInteger UDInkInDisplay(NSRect rect) {
    NSView *field = UDController().displayField;
    [field.window displayIfNeeded];
    NSBitmapImageRep *rep = [field bitmapImageRepForCachingDisplayInRect:field.bounds];
    [field cacheDisplayInRect:field.bounds toBitmapImageRep:rep];
    NSInteger ink = 0;
    for (NSInteger y = 0; y < rep.pixelsHigh; y++) {
        for (NSInteger x = 0; x < rep.pixelsWide; x++) {
            /* bitmap rows run top-down; the field may not be flipped */
            NSPoint p = NSMakePoint(x, field.isFlipped ? y : rep.pixelsHigh - 1 - y);
            if (!NSPointInRect(p, rect)) continue;
            NSColor *c = [[rep colorAtX:x y:y] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
            if (c && c.redComponent + c.greenComponent + c.blueComponent < 1.5) ink++;
        }
    }
    return ink;
}

static NSString *UDModeName(UDCalcMode mode) {
    switch (mode) {
        case UDCalcModeBasic: return @"Basic";
        case UDCalcModeScientific: return @"Scientific";
        case UDCalcModeProgrammer: return @"Programmer";
    }
    return @"?";
}

static NSString *UDTickedModes(void) {
    NSMutableArray *on = [NSMutableArray array];
    for (NSString *m in @[ @"Basic", @"Scientific", @"Programmer" ])
        if (UDTicked([NSString stringWithFormat:@"View/%@ Mode", m])) [on addObject:m];
    return on.count ? [on componentsJoinedByString:@","] : @"none";
}

#pragma mark - Givens

static void UDGivenFreshCalculator(UDCalcMode mode) {
    if (UDModel().isRPNMode) UDChoose(@"View/RPN Mode");
    if (UDModel().mode != mode) [UDController() setCalculatorMode:mode animate:NO];
    [UDModel() reset];
    [UDController() updateUI];
    [UDWindow() makeKeyAndOrderFront:nil];
    UDSettle();
    UDSay(UDModel().mode == mode && [UDDisplay() isEqualToString:@"0"],
          [NSString stringWithFormat:@"Given a cleared calculator in %@ mode (display \"%@\")", UDModeName(mode), UDDisplay()]);
}

#pragma mark - The use cases

static void UDRunFeatures(void) {
    UDFeature(@"Arithmetic");

    UDScenario(@"Adding two numbers", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        UDSay(UDClick(@"1 2 + 7 ="), @"When I press 1 2 + 7 =");
        UDSay([UDDisplay() isEqualToString:@"19"], [NSString stringWithFormat:@"Then the display shows 19 (\"%@\")", UDDisplay()]);
    });

    UDScenario(@"Multiplication binds tighter than addition", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        UDSay(UDClick(@"2 + 3 × 4 ="), @"When I press 2 + 3 × 4 =");
        UDSay([UDDisplay() isEqualToString:@"14"], [NSString stringWithFormat:@"Then the display shows 14 (\"%@\")", UDDisplay()]);
    });

    UDScenario(@"Division with a fractional result", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        UDSay(UDClick(@"9 ÷ 4 ="), @"When I press 9 ÷ 4 =");
        UDSay(fabs(UDValueShown() - 2.25) < 1e-9, [NSString stringWithFormat:@"Then the result is 2.25 (\"%@\")", UDDisplay()]);
    });

    UDScenario(@"Adding a percentage", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        UDSay(UDClick(@"1 0 0 + 1 0 % ="), @"When I press 1 0 0 + 1 0 % =");
        UDSay([UDDisplay() isEqualToString:@"110"], [NSString stringWithFormat:@"Then the display shows 110 (\"%@\")", UDDisplay()]);
    });

    UDScenario(@"Clearing everything", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        UDClick(@"4 2");
        UDSay(UDFindButton(UDWindow().contentView, @"C") != nil, @"When I have typed 42, the clear key reads C");
        UDSay(UDClick(@"C"), @"And I press C");
        UDSay([UDDisplay() isEqualToString:@"0"], [NSString stringWithFormat:@"Then the display shows 0 (\"%@\")", UDDisplay()]);
        UDSay(UDFindButton(UDWindow().contentView, @"AC") != nil, @"And the clear key reads AC again");
    });

    UDScenario(@"A long number is shown smaller instead of clipped", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        NSTextField *field = UDController().displayField;
        CGFloat designed = field.font.pointSize;
        UDSay(UDClick(@"1 0 0 0 0 0 0 0 0 0 0 0 0"), @"When I type 1 and twelve zeros");
        CGFloat width = [field.stringValue sizeWithAttributes:@{ NSFontAttributeName : field.font }].width;
        UDSay(field.font.pointSize < designed,
              [NSString stringWithFormat:@"Then the display font is smaller (%g pt, designed %g pt)", field.font.pointSize, designed]);
        UDSay(width <= NSWidth(field.bounds),
              [NSString stringWithFormat:@"And the whole number fits (%.0f of %.0f points)", width, NSWidth(field.bounds)]);
        UDSay(UDClick(@"C") && field.font.pointSize == designed,
              [NSString stringWithFormat:@"When I press C the font is back to %g pt (%g pt)", designed, field.font.pointSize]);
    });

    UDFeature(@"Switching modes from the View menu");

    UDScenario(@"The current mode is ticked at start", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        UDSay([UDTickedModes() isEqualToString:@"Basic"], [NSString stringWithFormat:@"Then only Basic Mode is ticked (ticked: %@)", UDTickedModes()]);
        UDSay(UDEnabled(@"View/Scientific Mode") && UDEnabled(@"View/Programmer Mode"), @"And the other modes can be chosen");
    });

    UDScenario(@"Cmd-2 switches to Scientific and the tick follows", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        UDSay(UDShortcut(@"2"), @"When I press Cmd-2 without switching windows");
        UDSay(UDModel().mode == UDCalcModeScientific, [NSString stringWithFormat:@"Then the calculator is in Scientific mode (%@)", UDModeName(UDModel().mode)]);
        UDSay(UDFindButton(UDWindow().contentView, @"sin") != nil, @"And the scientific keys are on screen");
        UDSay([UDTickedModes() isEqualToString:@"Scientific"], [NSString stringWithFormat:@"And only Scientific Mode is ticked (ticked: %@)", UDTickedModes()]);
    });

    UDScenario(@"Choosing Basic from the menu switches back", ^{
        UDGivenFreshCalculator(UDCalcModeScientific);
        UDSay(UDChoose(@"View/Basic Mode"), @"When I choose View > Basic Mode");
        UDSay(UDModel().mode == UDCalcModeBasic, [NSString stringWithFormat:@"Then the calculator is in Basic mode (%@)", UDModeName(UDModel().mode)]);
        UDSay(UDFindButton(UDWindow().contentView, @"sin") == nil, @"And the scientific keys are gone");
        UDSay([UDTickedModes() isEqualToString:@"Basic"], [NSString stringWithFormat:@"And only Basic Mode is ticked (ticked: %@)", UDTickedModes()]);
    });

    UDScenario(@"Cmd-3 switches to Programmer and unit conversion is unavailable", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        UDSay(UDShortcut(@"3"), @"When I press Cmd-3");
        UDSay(UDModel().mode == UDCalcModeProgrammer, [NSString stringWithFormat:@"Then the calculator is in Programmer mode (%@)", UDModeName(UDModel().mode)]);
        UDSay([UDTickedModes() isEqualToString:@"Programmer"], [NSString stringWithFormat:@"And only Programmer Mode is ticked (ticked: %@)", UDTickedModes()]);
        NSMenu *convert = UDApp.convertMenu;
        NSMenuItem *first = nil;
        [convert update];
        for (NSMenuItem *i in convert.itemArray) if (i.action == @selector(conversionMenuClicked:)) { first = i; break; }
        UDSay(first && !first.isEnabled, [NSString stringWithFormat:@"And the Convert menu's categories are disabled (%@)", first.title ?: @"none listed"]);
        UDGivenFreshCalculator(UDCalcModeBasic);
    });

    UDFeature(@"Unit conversion");

    UDScenario(@"Choosing a category from the Convert menu opens it", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        UDClick(@"1");
        UDSay(UDChoose(@"Convert/Length..."), @"When I enter 1 and choose Convert > Length...");
        NSWindow *window = UDApp.converterWindow.window;
        UDSay(UDWait(3, ^BOOL { return window.isVisible; }), @"Then the conversion window opens");
        NSComboBox *type = [UDApp.converterWindow valueForKey:@"typeBox"];
        NSComboBox *from = [UDApp.converterWindow valueForKey:@"fromBox"];
        NSComboBox *to = [UDApp.converterWindow valueForKey:@"toBox"];
        UDSay([type.stringValue isEqualToString:@"Length"],
              [NSString stringWithFormat:@"And it shows the category Length (\"%@\")", type.stringValue]);
        UDSay(from.stringValue.length > 0 && to.stringValue.length > 0,
              [NSString stringWithFormat:@"And units to convert from and to (\"%@\" to \"%@\")", from.stringValue, to.stringValue]);
        NSButton *convert = UDFindButton(window.contentView, @"Convert");
        [convert performClick:nil];
        UDSettle();
        UDSay(!window.isVisible && fabs(UDValueShown() - 0.001) < 1e-12,
              [NSString stringWithFormat:@"When I press Convert, 1 meter is shown as 0.001 kilometers (%g)", UDValueShown()]);
        [window close];
        [UDWindow() makeKeyAndOrderFront:nil];
    });

    UDFeature(@"Reverse Polish Notation");

    UDScenario(@"Cmd-R turns RPN on and enter pushes onto the stack", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        UDSay(UDShortcut(@"r"), @"When I press Cmd-R");
        UDSay(UDModel().isRPNMode && UDTicked(@"View/RPN Mode"), @"Then RPN mode is on and ticked in the View menu");
        UDSay(UDClick(@"3 enter 4 +"), @"When I press 3 enter 4 +");
        UDSay(fabs(UDValueShown() - 7) < 1e-9, [NSString stringWithFormat:@"Then the result is 7 (%g)", UDValueShown()]);
        {
            NSTableView *stack = UDController().stackTableView;
            NSScrollView *scroll = stack.enclosingScrollView;
            NSInteger last = stack.numberOfRows - 1;
            NSTableCellView *cell = last >= 0 ? (NSTableCellView *)[stack viewAtColumn:0 row:last makeIfNecessary:YES] : nil;
            UDSay(cell.textField.superview == cell && [cell.textField.stringValue isEqualToString:@"7"],
                  [NSString stringWithFormat:@"And the bottom row of the stack shows 7 (\"%@\", %s)",
                   cell.textField.stringValue, cell.textField.superview == cell ? "in the row" : "not in the row"]);
            UDSay(stack.selectedRow == -1, [NSString stringWithFormat:@"And no row is highlighted (selected row %ld)", (long)stack.selectedRow]);
            NSTableColumn *column = stack.tableColumns.firstObject;
            UDSay(column.width <= NSWidth(scroll.contentView.bounds) && !scroll.horizontalScroller.superview,
                  [NSString stringWithFormat:@"And the stack fits across without a scroller (column %.0f in %.0f)",
                   column.width, NSWidth(scroll.contentView.bounds)]);
        }
        UDSay(UDChoose(@"View/RPN Mode") && !UDModel().isRPNMode, @"When I choose View > RPN Mode again, RPN is off");
        UDSay(UDFindButton(UDWindow().contentView, @"=") != nil, @"And the = key is back");
    });

    UDFeature(@"Copy and paste");

    UDScenario(@"Copying a result and pasting it back", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        UDClick(@"6 × 7 =");
        UDSay(UDShortcut(@"c"), @"When I compute 6 × 7 and press Cmd-C");
        NSString *copied = [[NSPasteboard generalPasteboard] stringForType:NSPasteboardTypeString];
        UDSay([copied isEqualToString:@"42"], [NSString stringWithFormat:@"Then the pasteboard holds 42 (\"%@\")", copied]);
        UDClick(@"AC");
        UDSay(UDEnabled(@"Edit/Paste"), @"And Edit > Paste is enabled");
        UDSay(UDShortcut(@"v"), @"When I clear and press Cmd-V");
        UDSay(fabs(UDValueShown() - 42) < 1e-9, [NSString stringWithFormat:@"Then the display shows 42 (\"%@\")", UDDisplay()]);
    });

    UDFeature(@"Programmer mode");

    UDScenario(@"The ASCII character follows the digits typed", ^{
        UDGivenFreshCalculator(UDCalcModeProgrammer);
        UDController().baseSegmentedControl.selectedSegment = 1;
        [UDController() baseSelected:UDController().baseSegmentedControl];
        UDSettle();
        UDSay(UDModel().inputBase == UDBaseDec, @"Given decimal input");
        NSSegmentedControl *encoding = UDController().encodingSegmentedControl;
        if (UDModel().encodingMode != UDCalcEncodingModeASCII) {
            encoding.selectedSegment = 0;
            [UDController() encodingSelected:encoding];
            UDSettle();
        }
        UDSay(UDModel().encodingMode == UDCalcEncodingModeASCII, @"And ASCII encoding is on");
        UDSay(UDClick(@"6 5"), @"When I press 6 5");
        NSTextField *label = UDController().charLabel;
        UDSay(!label.isHidden && [label.stringValue isEqualToString:@"A"],
              [NSString stringWithFormat:@"Then the character shown is A (\"%@\", %@)",
               label.stringValue, label.isHidden ? @"hidden" : @"visible"]);
        NSRect where = [UDController().displayField convertRect:label.bounds fromView:label];
        NSInteger ink = UDInkInDisplay(where);
        UDSay(ink > 0, [NSString stringWithFormat:@"And it is drawn on the display, not painted over (%ld dark pixels)", (long)ink]);
        encoding.selectedSegment = 0;
        [UDController() encodingSelected:encoding];   /* the same segment again: off */
        UDSettle();
        UDGivenFreshCalculator(UDCalcModeBasic);
    });

    UDFeature(@"Paper tape");

    UDScenario(@"Showing and hiding the paper tape", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        BOOL wasShown = UDApp.tapeWindowController.window.isVisible;
        if (wasShown) UDChoose(@"Window/Hide Paper Tape");
        UDSay(UDValidatedItem(@"Window/Show Paper Tape") != nil, @"Given the Window menu offers Show Paper Tape");
        UDSay(UDShortcut(@"t"), @"When I press Cmd-T");
        UDSay(UDWait(3, ^BOOL { return UDApp.tapeWindowController.window.isVisible; }), @"Then the paper tape window is shown");
        UDSay(UDValidatedItem(@"Window/Hide Paper Tape") != nil, @"And the menu item reads Hide Paper Tape");
        UDClick(@"5 + 5 =");
        UDSay(UDChoose(@"Window/Hide Paper Tape"), @"When I choose Window > Hide Paper Tape");
        UDSay(UDWait(3, ^BOOL { return !UDApp.tapeWindowController.window.isVisible; }), @"Then the paper tape window is gone");
        UDSay(![UDSettingsManager sharedManager].showTapeWindow, @"And it will not open at the next launch");
        [UDWindow() makeKeyAndOrderFront:nil];
    });

    UDScenario(@"An open paper tape is remembered when the app quits", ^{
        UDGivenFreshCalculator(UDCalcModeBasic);
        if (!UDApp.tapeWindowController.window.isVisible) UDShortcut(@"t");
        UDSay(UDWait(3, ^BOOL { return UDApp.tapeWindowController.window.isVisible; }), @"Given the paper tape is open");
        /* What -[NSApplication terminate:] does first, then what a desktop
           that closes the windows of a quitting app does, before the
           will-terminate notification. The app is not actually quit. */
        id<NSApplicationDelegate> delegate = NSApp.delegate;
        if ([(NSObject *)delegate respondsToSelector:@selector(applicationShouldTerminate:)]) {
            [delegate applicationShouldTerminate:NSApp];
        }
        [UDApp.tapeWindowController.window close];
        UDSettle();
        UDSay([UDSettingsManager sharedManager].showTapeWindow,
              @"When the app quits and its windows are closed, the tape will open at the next launch");
        UDApp.tapeWindowController.isAppTerminating = NO;
        [UDWindow() makeKeyAndOrderFront:nil];
    });

    UDFeature(@"Updates");

    // In the app menu where there is an updater (Sparkle, on macOS); not
    // where the image is updated from outside (GNUstep's AppImage).
    UDScenario(@"Check for Updates… where the app can update itself", ^{
        BOOL hasUpdater = [[UDUpdater alloc] initStarting:NO].available;
        NSMenuItem *check = [[[[NSApp mainMenu] itemAtIndex:0] submenu] itemWithTag:7100];
        UDSay((check != nil) == hasUpdater && (!check || check.action == @selector(checkForUpdates:)),
              [NSString stringWithFormat:@"Then Check for Updates… is %@", hasUpdater ? @"in the app menu" : @"not offered"]);
    });
}

#pragma mark - Start

@interface UDSelfTestRunner : NSObject
@end

@implementation UDSelfTestRunner
/* From a timer, once the app is up; an exception outside a scenario is a
   failure, not a hang. */
- (void)fire:(NSTimer *)timer {
    @try {
        UDWait(1, ^BOOL { return UDWindow().isVisible; });
        fprintf(stderr, "UDCalc self-test%s%s\n", UDSelfTestFilter.length ? ": " : "", UDSelfTestFilter.UTF8String ?: "");
        NSMenuItem *mode = UDMenuItem(@"View/Basic Mode", NULL);
        fprintf(stderr, "(View > Basic Mode target: %s; first responder: %s; changeMode: goes to %s)\n",
                mode.target ? [NSStringFromClass([mode.target class]) UTF8String] : "First Responder",
                [NSStringFromClass([UDWindow().firstResponder class]) UTF8String],
                [NSStringFromClass([[NSApp targetForAction:@selector(changeMode:)] class]) UTF8String] ?: "nobody");
        UDRunFeatures();
    } @catch (NSException *e) {
        fprintf(stderr, "FAIL %s: %s\n", e.name.UTF8String, e.reason.UTF8String);
        UDFailed++;
    }
    fprintf(stderr, "\n%d scenarios, %d steps passed, %d failed\nself-test: %s\n",
            UDScenarios, UDPassed, UDFailed, UDFailed ? "FAILED" : (UDScenarios ? "passed" : "NO SCENARIOS MATCHED"));
    exit(UDScenarios ? UDFailed : 1);
}
@end

void UDStartSelfTest(AppDelegate *app) {
    UDApp = app;
    static UDSelfTestRunner *runner;
    runner = [UDSelfTestRunner new];
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:runner selector:@selector(fire:) userInfo:nil repeats:NO];
}
