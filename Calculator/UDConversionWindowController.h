//
//  ConversionWindowController.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <Cocoa/Cocoa.h>
#import "UDCalc.h"
#import "UDUnitConverter.h"

@interface UDConversionWindowController : NSWindowController

// Reference to the main calculator engine
@property (strong) UDCalc *calc;
@property (strong) UDUnitConverter *converter;

// Block/Callback to tell the Main App to refresh its display
@property (copy) void (^didConvertBlock)(NSString *cat, NSString *from, NSString *to);

- (void)selectCategory:(NSString *)categoryName;

- (IBAction)cancelPressed:(id)sender;

@end
