//
//  UDCalculatorViewController.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 29.01.2026.
//

#import <Cocoa/Cocoa.h>
#import "UDCalc.h"
#import "UDUnitConverter.h"
#import "UDConversionHistoryManager.h"
#import "UDConversionWindowController.h"
#import "UDTape.h"
#import "UDTapeWindowController.h"
#import "UDBitDisplayView.h"

typedef NS_ENUM(NSInteger, CalculatorMode) {
    CalculatorModeBasic         = 1,
    CalculatorModeScientific    = 2,
    CalculatorModeProgrammer    = 3
};

extern NSString * const UDCalcDidFinishCalculationNotification;
// Keys for the userInfo dictionary
extern NSString * const UDCalcFormulaKey; // UDASTNode*
extern NSString * const UDCalcResultKey;  // double

@interface UDCalcViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate, UDCalcDelegate>

@property (nonatomic, weak) IBOutlet NSTextField *displayField;

@property (nonatomic, strong) UDCalc *calc;
@property (nonatomic, assign) CalculatorMode calcMode;
@property (nonatomic, assign) BOOL isSecondFunctionActive;

// Actions (Methods linked to buttons)
- (IBAction)digitPressed:(NSButton *)sender;
- (IBAction)operationPressed:(NSButton *)sender;
- (IBAction)decimalPressed:(NSButton *)sender;
- (IBAction)secondFunctionPressed:(NSButton *)sender;
- (IBAction)showBinaryPressed:(NSButton *)sender;
- (IBAction)baseSelected:(NSSegmentedControl *)sender;
- (IBAction)encodingSelected:(NSSegmentedControl *)sender;

@property (nonatomic, weak) IBOutlet NSTabView *displayTabView;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *scientificWidthConstraint;
@property (nonatomic, weak) IBOutlet NSView *scientificView;
@property (nonatomic, assign) CGFloat standardScientificWidth; // To remember the size

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *programmerInputHeightConstraint;
@property (nonatomic, assign) CGFloat standardProgrammerInputHeight; // To remember the size
@property (nonatomic, weak) IBOutlet NSStackView *programmerInputView;
@property (nonatomic, weak) IBOutlet NSSegmentedControl *baseSegmentedControl;
@property (nonatomic, weak) IBOutlet UDBitDisplayView *bitDisplayView;

@property (nonatomic, weak) IBOutlet NSTableView *stackTableView;

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

- (void)updateUI;
- (void)setCalculatorMode:(CalculatorMode)mode animate:(BOOL)animate;

@end
