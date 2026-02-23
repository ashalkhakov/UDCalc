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
    self.testDefaults = [NSUserDefaults standardUserDefaults];

    self.converter = [[UDUnitConverter alloc] init];
    self.mgr = [[UDConversionHistoryManager alloc] initWithDefaults:self.testDefaults converter:self.converter];
    [self.mgr clearHistory];
}

- (void)tearDown {
    self.mgr = nil;
    self.converter = nil;
    self.testDefaults = nil;
    [super tearDown];
}

- (void)testAddConversionAddsToHistory {
    NSUnit *meters = [NSUnitLength meters];
    XCTAssertTrue(meters != nil);
    NSDictionary *entry = @{
        @"cat": UDConstLength,
        @"from": meters,
        @"to": [NSUnitLength kilometers]
    };
    [self.mgr addConversion:entry];

    XCTAssertEqual(self.mgr.history.count, 1);
    XCTAssertEqualObjects(self.mgr.history.firstObject[@"from"], meters);
}

- (void)testDeduplicationWithUnits {
    NSUnit *u1 = [NSUnitLength meters];
    NSUnit *u2 = [NSUnitLength meters];

    NSDictionary *dict1 = @{@"from": u1};
    NSDictionary *dict2 = @{@"from": u2};

    XCTAssertEqualObjects(dict1, dict2);
}

- (void)testDeduplication {
    NSDictionary *entry = @{
        @"cat": UDConstMass,
        @"from": [NSUnitMass kilograms],
        @"to": [NSUnitMass grams]
    };

    [self.mgr addConversion:entry];
    [self.mgr addConversion:entry]; // Add same entry twice
    
    XCTAssertEqual(self.mgr.history.count, 1, @"Duplicate entries should be moved to top, not duplicated");
}

- (void)testClearHistory {
    [self.mgr addConversion:@{
        @"cat": UDConstMass,
        @"from": [NSUnitMass kilograms],
        @"to": [NSUnitMass grams]
    }];
    [self.mgr clearHistory];
    
    XCTAssertEqual(self.mgr.history.count, 0);
}

@end
