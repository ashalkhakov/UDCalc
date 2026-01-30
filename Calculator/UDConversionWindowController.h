//
//  ConversionWindowController.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <Cocoa/Cocoa.h>
#import "UDCalc.h"
#import "UDUnitConverter.h"

extern NSString * const UDUnitConverterDidConvertNotification;
// Keys for the userInfo dictionary
extern NSString * const UDUnitConverterCategoryKey;     // NSString*
extern NSString * const UDUnitConverterFromUnitKey;     // NSString*
extern NSString * const UDUnitConverterToUnitKey;       // NSString*
extern NSString * const UDUnitConverterInputKey;        // double
extern NSString * const UDUnitConverterResultKey;       // double

@interface UDConversionWindowController : NSWindowController

// Reference to the main calculator engine
@property (strong) UDCalc *calc;
@property (strong) UDUnitConverter *converter;

- (void)selectCategory:(NSString *)categoryName;

- (IBAction)cancelPressed:(id)sender;

@end
