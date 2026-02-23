//
//  UDConversionHistoryManager.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDUnitConverter.h"

@interface UDConversionHistoryManager : NSObject

@property (nonatomic, strong) UDUnitConverter *unitConverter;

/**
 Returns the current list of conversion dictionaries.
 format: @{ @"cat":..., @"from":..., @"to":... }
 */
@property (nonatomic, readonly) NSArray<NSDictionary *> *history;

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults converter:(UDUnitConverter *)converter;

/**
 Adds a conversion to the top of the history.
 Handles deduplication and limits list size to 10.
 */
- (void)addConversion:(NSDictionary *)conversion;

/**
 Wipes all history from disk.
 */
- (void)clearHistory;

@end
