//
//  AppDelegate.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import "AppDelegate.h"

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

    // Setup Tape Output
    __weak typeof(self) weakSelf = self;
    self.tape.didCommitEquation = ^(NSString *line) {
        // Auto-open window if it doesn't exist? Or just ensure it's alloc'd?
        if (!weakSelf.tapeWindowController) {
            weakSelf.tapeWindowController = [[UDTapeWindowController alloc] initWithWindowNibName:@"UDTapeWindow"];
        }
        
        // Show the window if you want it to pop up automatically,
        // OR just append in background if you prefer it passive.
        // [weakSelf.tapeWindowController showWindow:nil];
        
        [weakSelf.tapeWindowController appendLog:line];
    };

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

- (IBAction)showTape:(id)sender {
    if (!self.tapeWindowController) {
        self.tapeWindowController = [[UDTapeWindowController alloc] initWithWindowNibName:@"UDTapeWindow"];
    }
    [self.tapeWindowController showWindow:self];
}

- (IBAction)digitPressed:(NSButton *)sender {
    // We will use the Button's "Tag" (set in XIB) to identify the number (0-9)
    NSInteger digit = sender.tag;
    
    [self.calc digit:digit];
    
    // 2. Tape Input (Drafting Phase)
    // We update the draft every time a digit is pressed
    [self.tape updateDraftValue:self.calc.currentValue];

    [self updateUI];
}

- (IBAction)decimalPressed:(NSButton *)sender {
    // 1. Update Calc
    // This switches 'typing' to YES and sets the internal decimal multiplier
    [self.calc decimal];

    // 2. Update Tape Draft
    // We update the tape so it knows the current number being built is valid.
    // (Note: Since the tape stores a double, "5." and "5" look the same to it,
    // but that's okay because the tape typically only prints when you hit an operator.)
    [self.tape updateDraftValue:self.calc.currentValue];

    // 3. Refresh Display
    [self updateUI];
}

- (IBAction)operationPressed:(NSButton *)sender {
    NSString *opTitle = sender.identifier;
    UDOp op = UDOpNone;
    
    // Map button titles to Enum
    if ([opTitle isEqualToString:@"add"]) op = UDOpAdd;
    else if ([opTitle isEqualToString:@"sub"]) op = UDOpSub;
    else if ([opTitle isEqualToString:@"mul"]) op = UDOpMul; // or "x" or "X"
    else if ([opTitle isEqualToString:@"div"]) op = UDOpDiv; // or "÷"
    else if ([opTitle isEqualToString:@"equals"]) op = UDOpEq;
    else if ([opTitle isEqualToString:@"clear"]) op = UDOpClear;
    else if ([opTitle isEqualToString:@"negate"]) op = UDOpNegate;
    else if ([opTitle isEqualToString:@"percent"]) op = UDOpPercent;
        
    // 1. Handle CLEAR separately
    if (op == UDOpClear) {
        [self.calc reset]; // Or performOperation:UDOpClear
        [self.tape clear];

    } else if (op == UDOpEq) {
        // CASE 1: EQUALS (=)
        // 1. Calculate FIRST to get the final answer.
        [self.calc operation:UDOpEq];
        
        // 2. Commit the result to the tape.
        // We pass the Calculator's final value (e.g., 17) to the tape.
        [self.tape commitResult:self.calc.currentValue];
        
    } else {
        // CASE 2: BINARY OPERATORS (+, -, *, /)

        // CONTINUITY CHECK:
        // If the tape is empty (new line), but we are NOT typing a new number,
        // it means we are chaining operations on the previous result.
        // Action: Grab the calculator's current value and put it into the tape's draft.
        if ([self.tape isEmpty] && !self.calc.typing) {
            [self.tape updateDraftValue:self.calc.currentValue];
        }

        // 1. Update Tape FIRST.
        // We lock in the number the user just typed (the Draft) and add the operator symbol.
        [self.tape commitOperator:op];
        
        // 2. Update Calculator.
        // Perform the Shunting Yard logic (stacking the operator).
        [self.calc operation:op];
    }
    
    // 3. Update Display
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

- (IBAction)conversionMenuClicked:(NSMenuItem *)sender {
    // CASE A: History (Headless)
    if (sender.representedObject) {
        NSDictionary *data = sender.representedObject;
        
        // 1. Use the UnitConverter directly
        double result = [self.unitConverter convertValue:self.calc.currentValue
                                                category:data[@"cat"]
                                                fromUnit:data[@"from"]
                                                  toUnit:data[@"to"]];
        
        [self.calc setCurrentValue:result];
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
    if (self.calc.errorMessage) {
        [self.displayField setStringValue:self.calc.errorMessage];
    } else {
        // %g removes trailing zeros for us
        [self.displayField setStringValue:[NSString stringWithFormat:@"%g", self.calc.currentValue]];
    }
}

#pragma mark - Copy & Paste

- (void)copy:(id)sender {
    // 1. Get the current display value
    // We format it to ensure we don't copy "5.0000" but just "5"
    NSString *stringToCopy = [NSString stringWithFormat:@"%g", self.calc.currentValue];

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
        [self.calc setCurrentValue:value];
        [self updateUI];
    } else {
        NSBeep(); // Standard macOS "error" sound for invalid input
    }
}

@end
