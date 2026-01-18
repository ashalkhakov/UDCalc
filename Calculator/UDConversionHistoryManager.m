//
//  UDConversionHistoryManager.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import "UDConversionHistoryManager.h"

// Constant for the UserDefaults key
static NSString * const kHistoryKey = @"ConversionHistory";
static const NSUInteger kMaxHistoryItems = 10;

@implementation UDConversionHistoryManager

- (NSArray<NSDictionary *> *)history {
    // Return immutable copy for safety
    NSArray *list = [[NSUserDefaults standardUserDefaults] arrayForKey:kHistoryKey];
    
    // Filter out bad data (legacy strings) instantly to protect the rest of the app
    NSMutableArray *cleanList = [NSMutableArray array];
    for (id item in list) {
        if ([item isKindOfClass:[NSDictionary class]]) {
            [cleanList addObject:item];
        }
    }
    return [cleanList copy];
}

- (void)addConversion:(NSDictionary *)conversion {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *currentHistory = [self.history mutableCopy]; // Use self.history to get clean data
    if (!currentHistory) currentHistory = [NSMutableArray array];
    
    // 1. Deduplicate: Remove if already exists
    [currentHistory removeObject:conversion];
    
    // 2. Insert at top
    [currentHistory insertObject:conversion atIndex:0];
    
    // 3. Limit size
    if (currentHistory.count > kMaxHistoryItems) {
        [currentHistory removeLastObject];
    }
    
    // 4. Save
    [defaults setObject:currentHistory forKey:kHistoryKey];
    [defaults synchronize];
}

- (void)clearHistory {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kHistoryKey];
}

@end
