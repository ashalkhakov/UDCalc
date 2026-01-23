//
//  ConversionWindowController.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import "UDConversionWindowController.h"

@interface UDConversionWindowController ()

@property (weak) IBOutlet NSComboBox *typeBox;
@property (weak) IBOutlet NSComboBox *fromBox;
@property (weak) IBOutlet NSComboBox *toBox;

// Data Source: Dictionary where Key = Category Name, Value = Array of NSUnit objects
@property (strong) NSDictionary<NSString *, NSArray<NSUnit *> *> *unitData;
@property (strong) NSArray<NSUnit *> *currentUnits;

@end

@implementation UDConversionWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // 1. Use the Converter to populate categories
    [self.typeBox removeAllItems];
    [self.typeBox addItemsWithObjectValues:[self.converter availableCategories]];
    [self.typeBox selectItemAtIndex:0];
    [self typeChanged:self.typeBox];
}

- (IBAction)typeChanged:(NSComboBox *)sender {
    NSString *category = sender.stringValue;

    // 2. Use the Converter to get units
    NSArray *names = [self.converter unitNamesForCategory:category];
    
    [self.fromBox removeAllItems];
    [self.toBox removeAllItems];
    [self.fromBox addItemsWithObjectValues:names];
    [self.toBox addItemsWithObjectValues:names];
    
    if (names.count > 0) {
        [self.fromBox selectItemAtIndex:0];
        if (names.count > 1) [self.toBox selectItemAtIndex:1];
    }
}

- (IBAction)convertPressed:(id)sender {
    NSString *cat = self.typeBox.stringValue;
    NSString *from = self.fromBox.stringValue;
    NSString *to = self.toBox.stringValue;
    
    // 3. Perform conversion via the Converter object
    double result = [self.converter convertValue:self.calc.currentInputValue
                                        category:cat
                                        fromUnit:from
                                          toUnit:to];
    
    [self.calc inputNumber:result];
    
    if (self.didConvertBlock) {
        self.didConvertBlock(cat, from, to);
    }
    
    [self.window close];
}

- (void)selectCategory:(NSString *)categoryName {
    // Ensure the window UI is loaded first
    if (!self.isWindowLoaded) {
        [self loadWindow];
    }
    
    // Select the item in the UI
    [self.typeBox selectItemWithObjectValue:categoryName];
    
    // Trigger the update logic manually so the Unit boxes refresh
    [self typeChanged:self.typeBox];
}

- (IBAction)cancelPressed:(id)sender {
    [self.window close];
}

@end
