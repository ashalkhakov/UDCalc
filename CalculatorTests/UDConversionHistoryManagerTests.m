//
//  UDConversionHistoryManagerTests.m
//  CalculatorTests
//
//  Created by Artyom Shalkhakov on 23.02.2026.
//

#import <XCTest/XCTest.h>
#import "UDConversionHistoryManager.h"
#import "UDConstants.h"

@interface UDConversionHistoryManagerTests : XCTestCase
@property (nonatomic, strong) UDUnitConverter *converter;
@property (nonatomic, strong) UDConversionHistoryManager *mgr;
@property (nonatomic, strong) NSUserDefaults *testDefaults;
@end

@implementation UDConversionHistoryManagerTests

- (void)setUp {
    [super setUp];
    // Use a unique suite name for testing
    NSString *suiteName = @"org.underivable.calculator.testHistory";
    self.testDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];

    self.converter = [[UDUnitConverter alloc] init];
    self.mgr = [[UDConversionHistoryManager alloc] initWithDefaults:self.testDefaults converter:self.converter];
}

- (void)tearDown {
    // Wipe the test suite from disk
    [self.testDefaults removePersistentDomainForName:@"org.underivable.calculator.testHistory"];
    self.mgr = nil;
    self.converter = nil;
    [super tearDown];
}

- (void)testAddConversionAddsToHistory {
    NSUnit *meters = [self.converter unitForSymbol:@"m" ofCategory:UDConstLength];
    NSDictionary *entry = @{
        @"cat": UDConstLength,
        @"from": meters,
        @"to": [self.converter unitForSymbol:@"km" ofCategory:UDConstLength]};
    [self.mgr addConversion:entry];
    
    XCTAssertEqual(self.mgr.history.count, 1);
    XCTAssertEqualObjects(self.mgr.history.firstObject[@"from"], meters);
}

- (void)testDeduplication {
    NSDictionary *entry = @{
        @"cat": UDConstMass,
        @"from": [self.converter unitForSymbol:@"kg" ofCategory:UDConstMass],
        @"to": [self.converter unitForSymbol:@"g" ofCategory:UDConstMass]};

    [self.mgr addConversion:entry];
    [self.mgr addConversion:entry]; // Add same entry twice
    
    XCTAssertEqual(self.mgr.history.count, 1, @"Duplicate entries should be moved to top, not duplicated");
}

- (void)testClearHistory {
    [self.mgr addConversion:@{
        @"cat": UDConstMass,
        @"from": [self.converter unitForSymbol:@"kg" ofCategory:UDConstMass],
        @"to": [self.converter unitForSymbol:@"g" ofCategory:UDConstMass]
    }];
    [self.mgr clearHistory];
    
    XCTAssertEqual(self.mgr.history.count, 0);
}

@end
