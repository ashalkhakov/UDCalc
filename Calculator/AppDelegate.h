//
//  AppDelegate.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <Cocoa/Cocoa.h>
#import "UDCalc.h"
#import "UDUnitConverter.h"
#import "UDConversionHistoryManager.h"
#import "UDConversionWindowController.h"
#import "UDTape.h"
#import "UDTapeWindowController.h"

typedef NS_ENUM(NSInteger, CalculatorMode) {
    CalculatorModeBasic         = 1,
    CalculatorModeScientific    = 2,
    CalculatorModeProgrammer    = 3
};

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet NSTextField *displayField;

@property (strong) UDCalc *calc;
@property (strong) UDUnitConverter *unitConverter;
@property (strong) UDConversionHistoryManager *historyManager;
@property (strong) UDTape *tape;

@property (weak) IBOutlet NSLayoutConstraint *scientificWidthConstraint;
@property (weak) IBOutlet NSView *scientificView;
@property (assign) CGFloat standardScientificWidth; // To remember the size

@property (strong) UDConversionWindowController *converterWindow;
@property (strong) UDTapeWindowController *tapeWindowController;

@property (assign) BOOL isSecondFunctionActive;

// Actions (Methods linked to buttons)
- (IBAction)changeMode:(NSMenuItem *)sender;
- (IBAction)digitPressed:(NSButton *)sender;
- (IBAction)operationPressed:(NSButton *)sender;
- (IBAction)decimalPressed:(NSButton *)sender;
- (IBAction)memoryClearPressed:(NSButton *)sender;
- (IBAction)memoryAddPressed:(NSButton *)sender;
- (IBAction)memorySubPressed:(NSButton *)sender;
- (IBAction)memoryRecallPressed:(NSButton *)sender;
- (IBAction)openConverter:(id)sender;
- (IBAction)secondFunctionPressed:(NSButton *)sender;

@property (weak) IBOutlet NSButton *acButton;
@property (weak) IBOutlet NSButton *expButton;
@property (weak) IBOutlet NSButton *xthPowerOf10Button;
@property (weak) IBOutlet NSButton *lnButton;
@property (weak) IBOutlet NSButton *log10Button;

@property (weak) IBOutlet NSButton *sinButton;
@property (weak) IBOutlet NSButton *cosButton;
@property (weak) IBOutlet NSButton *tanButton;
@property (weak) IBOutlet NSButton *sinhButton;
@property (weak) IBOutlet NSButton *coshButton;
@property (weak) IBOutlet NSButton *tanhButton;

@property (weak) IBOutlet NSMenu *recentMenu;

- (IBAction)conversionMenuClicked:(NSMenuItem *)sender;
- (void)setCalculatorMode:(CalculatorMode)mode animate:(BOOL)animate;

@end

