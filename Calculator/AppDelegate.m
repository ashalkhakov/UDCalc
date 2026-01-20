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

- (IBAction)showTape:(id)sender {
    if (!self.tapeWindowController) {
        self.tapeWindowController = [[UDTapeWindowController alloc] initWithWindowNibName:@"UDTapeWindow"];
        self.tape.windowController = self.tapeWindowController;
    }
    [self.tapeWindowController showWindow:self];
}

- (IBAction)digitPressed:(NSButton *)sender {
    // We will use the Button's "Tag" (set in XIB) to identify the number (0-9)
    NSInteger digit = sender.tag;
    
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
    else if ([opTitle isEqualToString:@"lparen"]) op = UDOpParenLeft;
    else if ([opTitle isEqualToString:@"rparen"]) op = UDOpParenRight;
    else if ([opTitle isEqualToString:@"pi"]) op = UDOpPi;
    else if ([opTitle isEqualToString:@"e"]) op = UDOpE;
    else if ([opTitle isEqualToString:@"rand"]) op = UDOpRand;
    // row:
    else if ([opTitle isEqualToString:@"sqr"]) op = UDOpSquare;
    else if ([opTitle isEqualToString:@"pow"]) op = UDOpPow;
    else if ([opTitle isEqualToString:@"e_pow_x"]) op = UDOpExp;
    else if ([opTitle isEqualToString:@"_10_pow_x"]) op = UDOpPow10;
    else if ([opTitle isEqualToString:@"_2_pow_x"]) op = UDOpPow2;


    
    // CONSTANTS: Treat them as number inputs!
    if (op == UDOpPi) {
        [self.calc inputNumber:M_PI]; // You'll need to add this method
    } else if (op == UDOpE) {
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

        double resultVal = self.calc.currentValue;
                
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

    // Optional: Flash the display or show "M" indicator on Tape?
    [self updateUI];
}

// Connect 'm+' button here
- (IBAction)memoryAddPressed:(id)sender {
   // [self.calc memAdd];

    // Standard behavior: Add current display value to memory
    // If user is typing "5", add 5. If result is "10", add 10.
    //self.calc.memoryValue += self.calc.currentValue;
    [self updateUI];
}

// Connect 'm-' button here
- (IBAction)memorySubPressed:(id)sender {
//    self.calc.memoryValue -= self.calc.currentValue;
    //[self.calc memSub];
    [self updateUI];
}

// Connect 'mr' button here
- (IBAction)memoryRecallPressed:(id)sender {
    // Treat this exactly like typing a number
    //[self.calc memRecall];
    
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
    
    // Helper block to swap button state
    void (^setBtn)(NSButton*, NSString*, NSString*, NSString*, NSString*) =
    ^(NSButton *b, NSString *normTitle, NSString *normIdentifier, NSString *secTitle, NSString *secIdentifier) {
        if (second) {
            b.title = secTitle;
            b.identifier = secIdentifier;
        } else {
            b.title = normTitle;
            b.identifier = normIdentifier;
        }
    };
    
    // Apply changes
    
    setBtn(self.exButton, @"eˣ", @"e_pow_x", @"yˣ", @"y_pow_x");
    setBtn(self._10xButton, @"10ˣ", @"_10_pow_x", @"2ˣ", @"2_pow_x");
    setBtn(self.lnButton, @"ln", @"ln", @"logᵧ", @"log_y");
    setBtn(self._log10Button, @"log10", @"log₁₀", @"log2", @"log₂");
    /*
    else if ([opTitle isEqualToString:@"sqr"]) op = UDOpSquare;
    else if ([opTitle isEqualToString:@"pow"]) op = UDOpPow;
    else if ([opTitle isEqualToString:@"e_pow_x"]) op = UDOpExp;
    else if ([opTitle isEqualToString:@"_10_pow_x"]) op = UDOpPow10;
    else if ([opTitle isEqualToString:@"_2_pow_x"]) op = UDOpPow2;*/

    // e^x / y^x
    // 10^x / 2^x
    // ln / log y
    // log 10 / log 2
    // sin / sin -1
    // cos / cos -1
    // tan / tan -1
    // sinh / sinh -1
    // cosh / cosh -1
    // tanh / tanh -1
    
    /*setBtn(self._log10Button, @"log", @"log10", @"10ˣ", @"pow10");
    setBtn(self.lnButton,  @"ln",  @"ln",    @"log y",  UDOpExp);

    setBtn(self.sinButton, @"sin", @"sin", @"sin⁻¹", @"sinh");
    setBtn(self.cosButton, @"cos", @"cos", @"cos⁻¹", @"cosh");
    setBtn(self.tanButton, @"tan", @"tan", @"tan⁻¹", @"tanh");*/
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
        [self.calc inputNumber:value];
        [self updateUI];
    } else {
        NSBeep(); // Standard macOS "error" sound for invalid input
    }
}

@end
