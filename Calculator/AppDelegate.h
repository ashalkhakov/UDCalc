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

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (nonatomic, weak) IBOutlet NSTextField *displayField;

@property (nonatomic, strong) UDCalc *calc;
@property (nonatomic, strong) UDUnitConverter *unitConverter;
@property (nonatomic, strong) UDConversionHistoryManager *historyManager;
@property (nonatomic, strong) UDTape *tape;
@property (nonatomic, assign) CalculatorMode calcMode;
@property (nonatomic, assign) BOOL isSecondFunctionActive;

// Actions (Methods linked to buttons)
- (IBAction)changeMode:(NSMenuItem *)sender;
- (IBAction)changeRPNMode:(NSMenuItem *)sender;
- (IBAction)digitPressed:(NSButton *)sender;
- (IBAction)operationPressed:(NSButton *)sender;
- (IBAction)decimalPressed:(NSButton *)sender;
- (IBAction)openConverter:(id)sender;
- (IBAction)secondFunctionPressed:(NSButton *)sender;

@property (nonatomic, weak) IBOutlet NSTabView *displayTabView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *scientificWidthConstraint;
@property (nonatomic, weak) IBOutlet NSView *scientificView;
@property (nonatomic, assign) CGFloat standardScientificWidth; // To remember the size

@property (nonatomic, weak) IBOutlet NSTableView *stackTableView;

@property (nonatomic, strong) UDConversionWindowController *converterWindow;
@property (nonatomic, strong) UDTapeWindowController *tapeWindowController;

@property (nonatomic, weak) IBOutlet NSButton *parenLeftButton;
@property (nonatomic, weak) IBOutlet NSButton *parenRightButton;
@property (nonatomic, weak) IBOutlet NSButton *acButton;
@property (nonatomic, weak) IBOutlet NSButton *expButton;
@property (nonatomic, weak) IBOutlet NSButton *xthPowerOf10Button;
@property (nonatomic, weak) IBOutlet NSButton *lnButton;
@property (nonatomic, weak) IBOutlet NSButton *log10Button;
@property (nonatomic, weak) IBOutlet NSButton *equalsButton;

@property (nonatomic, weak) IBOutlet NSButton *sinButton;
@property (nonatomic, weak) IBOutlet NSButton *cosButton;
@property (nonatomic, weak) IBOutlet NSButton *tanButton;
@property (nonatomic, weak) IBOutlet NSButton *sinhButton;
@property (nonatomic, weak) IBOutlet NSButton *coshButton;
@property (nonatomic, weak) IBOutlet NSButton *tanhButton;

@property (nonatomic, weak) IBOutlet NSMenu *recentMenu;

- (IBAction)conversionMenuClicked:(NSMenuItem *)sender;
- (void)setCalculatorMode:(CalculatorMode)mode animate:(BOOL)animate;

@end

