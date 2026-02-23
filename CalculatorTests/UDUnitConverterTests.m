//
//  UDUnitConverterTests.m
//  CalculatorTests
//
//  Created by Artyom Shalkhakov on 23.02.2026.
//

#import <XCTest/XCTest.h>
#import "UDUnitConverter.h"

@interface UDUnitConverterTests : XCTestCase
@property (strong) UDUnitConverter *converter;
@end

@implementation UDUnitConverterTests

- (void)setUp {
    self.converter = [[UDUnitConverter alloc] init];
}

- (void)testLengthConversion {
    // Meters to Kilometers: 1000m = 1km
    double result = [self.converter convertValue:1000 fromUnit:[NSUnitLength meters] toUnit:[NSUnitLength kilometers]];
    XCTAssertEqualWithAccuracy(result, 1.0, 0.0001);
}

- (void)testTemperatureConversion {
    // Celsius to Fahrenheit: 0C = 32F
    double result = [self.converter convertValue:0 fromUnit:[NSUnitTemperature celsius] toUnit:[NSUnitTemperature fahrenheit]];
    XCTAssertEqualWithAccuracy(result, 32.0, 0.0001);
}

@end
