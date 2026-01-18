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

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (weak) IBOutlet NSTextField *displayField;

@property (strong) UDCalc *calc;
@property (strong) UDUnitConverter *unitConverter;
@property (strong) UDConversionHistoryManager *historyManager;
@property (strong) UDTape *tape;

@property (strong) UDConversionWindowController *converterWindow;
@property (strong) UDTapeWindowController *tapeWindowController;

// Actions (Methods linked to buttons)
- (IBAction)digitPressed:(NSButton *)sender;
- (IBAction)operationPressed:(NSButton *)sender;
- (IBAction)decimalPressed:(NSButton *)sender;
- (IBAction)openConverter:(id)sender;

@property (weak) IBOutlet NSMenu *recentMenu;

- (IBAction)conversionMenuClicked:(NSMenuItem *)sender;

@end

