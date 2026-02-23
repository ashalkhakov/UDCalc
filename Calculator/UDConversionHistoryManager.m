//
//  UDConversionHistoryManager.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import "UDConversionHistoryManager.h"
#import "UDGNUstepCompat.h"

// Constant for the UserDefaults key
static NSString * const kHistoryKey = @"ConversionHistory";
static const NSUInteger kMaxHistoryItems = 10;

@interface UDConversionHistoryManager ()
@property (nonatomic, strong) NSUserDefaults *defaults;
@end

@implementation UDConversionHistoryManager

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults converter:(UDUnitConverter *)converter {
    self = [super init];
    if (self) {
        self.defaults = defaults;
        self.unitConverter = converter;
    }
    return self;
}

- (NSArray<NSDictionary *> *)history {
    // Return immutable copy for safety
    NSArray *list = [self.defaults arrayForKey:kHistoryKey];

    // Filter out bad data (legacy strings) instantly to protect the rest of the app
    NSMutableArray *cleanList = [NSMutableArray array];
    for (id item in list) {
        if ([item isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)item;
            
            if ([[dict valueForKey:@"to"] isKindOfClass:[NSString class]] && [[dict valueForKey:@"from"] isKindOfClass:[NSString class]]) {
                [cleanList addObject:[self deserializeFromHistory:dict]];
            }
        }
    }
    
    return [cleanList copy];
}

- (NSDictionary *)deserializeFromHistory:(NSDictionary *)item {
    NSString *cat = [item valueForKey:@"cat"];
    NSDictionary *deserialized = @{
        @"cat": cat,
        @"from": [self.unitConverter unitForSymbol:[item valueForKey:@"from"] ofCategory:cat],
        @"to": [self.unitConverter unitForSymbol:[item valueForKey:@"to"] ofCategory:cat]
    };
    return deserialized;
}

- (NSDictionary *)serializeToHistory:(NSDictionary *)item {
    NSDictionary *serialized = @{
        @"cat": [item valueForKey:@"cat"],
        @"from": [(NSUnit *)[item valueForKey:@"from"] symbol],
        @"to": [(NSUnit *)[item valueForKey:@"to"] symbol]
    };
    return serialized;
}

- (void)addConversion:(NSDictionary *)conversion {
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
    NSMutableArray *serializedHistory = [NSMutableArray array];
    for (NSInteger i = 0; i < currentHistory.count; i++) {
        [serializedHistory addObject: [self serializeToHistory:currentHistory[i]]];
    }

    [self.defaults setObject:serializedHistory forKey:kHistoryKey];
    [self.defaults synchronize];
}

- (void)clearHistory {
    [self.defaults removeObjectForKey:kHistoryKey];
    [self.defaults synchronize];
}

@end
