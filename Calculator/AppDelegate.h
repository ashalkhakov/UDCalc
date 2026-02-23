//
//  AppDelegate.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <AppKit/AppKit.h>
#import "UDCalcViewController.h"
#import "UDUnitConverter.h"
#import "UDConversionHistoryManager.h"
#import "UDConversionWindowController.h"
#import "UDTape.h"
#import "UDTapeWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserInterfaceValidations>

@property (nonatomic, strong) UDUnitConverter *unitConverter;
@property (nonatomic, strong) UDConversionHistoryManager *historyManager;
@property (nonatomic, strong) UDTape *tape;

@property (nonatomic, strong) UDConversionWindowController *converterWindow;
@property (nonatomic, strong) UDTapeWindowController *tapeWindowController;
@property (nonatomic, strong) UDCalcViewController *calcViewController;

@property (nonatomic, weak) IBOutlet NSMenu *convertMenu;
@property (nonatomic, weak) IBOutlet NSMenu *recentMenu;

- (IBAction)conversionMenuClicked:(NSMenuItem *)sender;

@end

