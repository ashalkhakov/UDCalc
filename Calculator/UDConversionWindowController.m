//
//  ConversionWindowController.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import "UDConversionWindowController.h"
#import "UDConstants.h"

NSString * const UDUnitConverterDidConvertNotification = @"org.underivable.calculator.UDUnitConverterDidConvertNotification";
NSString * const UDUnitConverterCategoryKey = @"UDUnitConverterCategoryKey";
NSString * const UDUnitConverterFromUnitKey = @"UDUnitConverterFromUnitKey";
NSString * const UDUnitConverterToUnitKey = @"UDUnitConverterToUnitKey";
NSString * const UDUnitConverterInputKey = @"UDUnitConverterInputKey";
NSString * const UDUnitConverterResultKey = @"UDUnitConverterResultKey";

@interface UDConversionWindowController ()

@property (weak) IBOutlet NSComboBox *typeBox;
@property (weak) IBOutlet NSComboBox *fromBox;
@property (weak) IBOutlet NSComboBox *toBox;

@end

// Selects an item and shows it in the box. AppKit shows a programmatically
// selected item; GNUstep only records the index, leaving the box empty
// (#3). Setting the text as well does the same on both.
static void UDComboSelect(NSComboBox *box, NSInteger index) {
    if (index < 0 || index >= box.numberOfItems) {
        return;
    }
    [box selectItemAtIndex:index];
    box.objectValue = [box itemObjectValueAtIndex:index];
}

@implementation UDConversionWindowController {
    NSArray<NSUnit *> *_currentUnits; // Shadow array to track objects by index
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Initial UI Population
    [self.typeBox removeAllItems];

    NSArray *internalKeys = [self.converter availableCategories];
    
    NSMutableArray *localizedCategories = [NSMutableArray array];
    for (NSString *key in internalKeys) {
        [localizedCategories addObject:[self.converter localizedNameForCategory:key]];
    }
    
    [self.typeBox addItemsWithObjectValues:localizedCategories];

    UDComboSelect(self.typeBox, 0);
    [self typeChanged:self.typeBox];
}

- (IBAction)typeChanged:(NSComboBox *)sender {
    NSInteger selectedIdx = [sender indexOfSelectedItem];
    if (selectedIdx == -1) return;
    
    NSString *internalKey = [self.converter availableCategories][selectedIdx];

    // 1. Fetch raw objects from the model
    _currentUnits = [self.converter unitsForCategory:internalKey];
    
    // 2. Generate display strings for the UI
    NSMutableArray *names = [NSMutableArray array];
    for (NSUnit *u in _currentUnits) {
        [names addObject:[self.converter localizedNameForUnit:u]];
    }
    
    [self.fromBox removeAllItems];
    [self.toBox removeAllItems];
    [self.fromBox addItemsWithObjectValues:names];
    [self.toBox addItemsWithObjectValues:names];
    
    if (names.count > 0) {
        UDComboSelect(self.fromBox, 0);
        if (names.count > 1) UDComboSelect(self.toBox, 1);
    }
}

- (void)selectCategory:(NSString *)categoryName {
    // Ensure the window UI is loaded first
    if (!self.isWindowLoaded) {
        [self loadWindow];
    }
    
    // Select the item in the UI
    UDComboSelect(self.typeBox, [self.typeBox indexOfItemWithObjectValue:
                                     [self.converter localizedNameForCategory:categoryName]]);
    
    // Trigger the update logic manually so the Unit boxes refresh
    [self typeChanged:self.typeBox];
}

- (IBAction)convertPressed:(id)sender {
    // Use Index-based lookup to remain language-agnostic
    NSInteger fromIdx = [self.fromBox indexOfSelectedItem];
    NSInteger toIdx = [self.toBox indexOfSelectedItem];
    
    if (fromIdx == -1 || toIdx == -1) return;

    // Retrieve objects from shadow array
    NSUnit *fromUnit = _currentUnits[fromIdx];
    NSUnit *toUnit = _currentUnits[toIdx];
    
    double input = UDValueAsDouble(self.calc.currentInputValue);

    // Convert using objects
    double result = [self.converter convertValue:input
                                        fromUnit:fromUnit
                                          toUnit:toUnit];

    NSDictionary *userInfo = @{
        UDUnitConverterCategoryKey: self.typeBox.objectValue,
        UDUnitConverterFromUnitKey: fromUnit,
        UDUnitConverterToUnitKey: toUnit,
        UDUnitConverterInputKey: @(input),
        UDUnitConverterResultKey: @(result)
    };

    [[NSNotificationCenter defaultCenter] postNotificationName:UDUnitConverterDidConvertNotification
                                                        object:self
                                                      userInfo:userInfo];
    [self.window close];
}

- (IBAction)cancelPressed:(id)sender {
    [self.window close];
}

@end
