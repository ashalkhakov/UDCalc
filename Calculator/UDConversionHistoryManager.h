//
//  UDConversionHistoryManager.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <Foundation/Foundation.h>

@interface UDConversionHistoryManager : NSObject

/**
 Returns the current list of conversion dictionaries.
 format: @{ @"cat":..., @"from":..., @"to":... }
 */
@property (nonatomic, readonly) NSArray<NSDictionary *> *history;

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
