//
//  AppDelegate.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import "AppDelegate.h"
#if __has_include(<QuartzCore/QuartzCore.h>)
#import <QuartzCore/QuartzCore.h>
#endif
#import "UDCalcButton.h"
#import "UDSettingsManager.h"

@interface AppDelegate ()

@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    [[UDSettingsManager sharedManager] registerDefaults];

    self.unitConverter = [[UDUnitConverter alloc] init];
    self.historyManager = [[UDConversionHistoryManager alloc] init];
    self.tape = [[UDTape alloc] init];

    // 1. Instantiate the Controller
    // This automatically loads "UDCalculatorViewController.xib"
    self.calcViewController = [[UDCalcViewController alloc] initWithNibName:@"UDCalcView" bundle:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(calculationDidFinish:)
                                                     name:UDCalcDidFinishCalculationNotification
                                                   object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(unitConversionDidFinish:)
                                                 name:UDUnitConverterDidConvertNotification
                                               object:nil];

    // 2. Add it to the Window
    // Modern macOS (10.10+):
    // self.window.contentViewController = self.calcViewController;
    
    // GNUstep / Universal Way:
    // We manually set the content view and resize the window to fit.
    NSView *calcView = self.calcViewController.view;
    
    // Resize window to match the XIB design size
    NSRect frame = [self.window frame];
    frame.size = calcView.frame.size;
    
    // Account for Title Bar height in frame calculation if needed,
    // but usually setting content size is cleaner:
    [self.window setContentSize:calcView.frame.size];
    [self.window setContentView:calcView];

    [self.calcViewController restoreApplicationState];

    // 3. Make the Next Responder chain work (Keyboard shortcuts)
#ifdef GNUSTEP
    // GNUstep doesn't automatically insert NSViewController into the
    // responder chain (macOS 10.10+ does this).  Wire it manually:
    //   view → viewController → window
    [calcView setNextResponder:self.calcViewController];
    [self.calcViewController setNextResponder:self.window];
#endif
    [self.window makeFirstResponder:self.calcViewController];

    [self updateRecentMenu];

    // open the tape window
    if ([UDSettingsManager sharedManager].showTapeWindow) {
        [self showTape:nil];
    }
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


#ifndef GNUSTEP
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}
#endif

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)unitConversionDidFinish:(NSNotification *)note {
    // Define what happens after conversion
    NSString *cat = note.userInfo[UDUnitConverterCategoryKey];
    NSString *from = note.userInfo[UDUnitConverterFromUnitKey];
    NSString *to = note.userInfo[UDUnitConverterToUnitKey];
    double input = [(NSNumber *)note.userInfo[UDUnitConverterInputKey] doubleValue];
    double result = [(NSNumber *)note.userInfo[UDUnitConverterResultKey] doubleValue];

    [self.calcViewController.calc inputNumber:UDValueMakeDouble(result)];
    [self.calcViewController updateUI];
    [self addToHistory:@{ @"cat": cat, @"from": from, @"to":to }];
}

- (void)calculationDidFinish:(NSNotification *)note {
    UDASTNode *formula = note.userInfo[UDCalcFormulaKey];
    NSNumber *result = note.userInfo[UDCalcResultKey];
    
    if (!formula) {
        return;
    }
    
    [self.tape logTransaction:formula result:[result doubleValue]];
}


#pragma mark - Button Actions

- (IBAction)showTape:(id)sender {
    if (!self.tapeWindowController) {
        self.tapeWindowController = [[UDTapeWindowController alloc] initWithWindowNibName:@"UDTapeWindow"];
        self.tape.windowController = self.tapeWindowController;
    }
    
    BOOL isVisible = self.tapeWindowController.window.isVisible;
    
    if (isVisible) {
        [self.tapeWindowController close];
    } else {
        [self.tapeWindowController showWindow:self];
        
        [UDSettingsManager sharedManager].showTapeWindow = YES;
    }
}

-(void)createConverterWindow {
    if (!self.converterWindow) {
        self.converterWindow = [[UDConversionWindowController alloc] initWithWindowNibName:@"ConversionWindow"];
        
        // Inject dependencies
        self.converterWindow.calc = self.calcViewController.calc;
        self.converterWindow.converter = self.unitConverter;
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
        double result = [self.unitConverter convertValue:UDValueAsDouble(self.calcViewController.calc.currentInputValue)
                                                category:data[@"cat"]
                                                fromUnit:data[@"from"]
                                                  toUnit:data[@"to"]];
        
        [self.calcViewController.calc inputNumber:UDValueMakeDouble(result)];
        [self.calcViewController updateUI];
        [self addToHistory:data];
        return;
    }
        
    // CASE B: Open Window
#ifdef GNUSTEP
    NSString *title = [sender title];
    if (title && [title length] > 0) {
        [self openConversionWithType:title];
    }
#else
    if (sender.identifier && [sender.identifier length] > 4) {
        NSString *type = [sender.identifier substringFromIndex:4];
        [self openConversionWithType:type];
    }
#endif
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

- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item {
    if ([item action] == @selector(showTape:) && [(NSObject *)item isKindOfClass:[NSMenuItem class]]) {
        BOOL isVisible = self.tapeWindowController.window.isVisible;
        [(NSMenuItem *)item setTitle: isVisible? @"Hide Paper Tape" : @"Show Paper Tape"];
        return YES;
    }

    return YES;
}

@end
