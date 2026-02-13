//
//  UDSettingsManager.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 12.02.2026.
//

#import "UDSettingsManager.h"

// Constants for NSUserDefaults Keys
static NSString * const kUDKeyCalcMode                  = @"UDCalcMode";
static NSString * const kUDKeyRPNMode                   = @"UDRPNMode";
static NSString * const kUDKeyEncodingMode              = @"UDEncodingMode";
static NSString * const kUDKeyIsRadians                 = @"UDIsRadians";
static NSString * const kUDKeyInputBase                 = @"UDInputBase";
static NSString * const kUDKeyShowBinaryView            = @"UDShowBinaryView";
static NSString * const kUDKeyShowThousandsSeparators   = @"UDShowThousandsSeparators";
static NSString * const kUDKeyDecimalPlaces             = @"UDDecimalPlaces";

@implementation UDSettingsManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static UDSettingsManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Setup

- (void)registerDefaults {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        kUDKeyCalcMode: @(UDCalcModeBasic),
        kUDKeyRPNMode: @(NO),
        kUDKeyEncodingMode: @(UDCalcEncodingModeNone), // Default to None
        kUDKeyIsRadians: @(NO),     // Default to Degrees
        kUDKeyInputBase: @(UDBaseDec),
        kUDKeyShowBinaryView: @(YES),
        kUDKeyShowThousandsSeparators: @(NO),
        kUDKeyDecimalPlaces: @(15)
    }];
}

- (void)forceSync {
    // Force Sync (Optional, modern macOS does this automatically, but safe to add)
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Properties
// We implement custom Getters and Setters to talk directly to NSUserDefaults.

// --- Calc Mode ---
- (UDCalcMode)calcMode {
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:kUDKeyCalcMode];
    return (UDCalcMode)val;
}

- (void)setCalcMode:(UDCalcMode)calcMode {
    [[NSUserDefaults standardUserDefaults] setInteger:calcMode forKey:kUDKeyCalcMode];
}

// --- RPN Mode ---
- (BOOL)isRPN {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kUDKeyRPNMode];
}

- (void)setIsRPN:(BOOL)isRPN {
    [[NSUserDefaults standardUserDefaults] setBool:isRPN forKey:kUDKeyRPNMode];
}

// --- Encoding Mode ---
- (UDCalcEncodingMode)encodingMode {
    // If the key doesn't exist, integerForKey returns 0.
    // But we want our default to be -1 (None).
    // Luckily, registerDefaults handles this.
    // If for some reason defaults were wiped, we check explicitly:
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kUDKeyEncodingMode] == nil) {
        return UDCalcEncodingModeNone;
    }
    return [[NSUserDefaults standardUserDefaults] integerForKey:kUDKeyEncodingMode];
}

- (void)setEncodingMode:(UDCalcEncodingMode)encodingMode {
    [[NSUserDefaults standardUserDefaults] setInteger:encodingMode forKey:kUDKeyEncodingMode];
}

// --- Radians ---
- (BOOL)isRadians {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kUDKeyIsRadians];
}

- (void)setIsRadians:(BOOL)isRadians {
    [[NSUserDefaults standardUserDefaults] setBool:isRadians forKey:kUDKeyIsRadians];
}

// --- Input Base ---
- (UDBase)inputBase {
    NSInteger val = [[NSUserDefaults standardUserDefaults] integerForKey:kUDKeyInputBase];
    return (UDBase)val;
}

- (void)setInputBase:(UDBase)inputBase {
    [[NSUserDefaults standardUserDefaults] setInteger:inputBase forKey:kUDKeyInputBase];
}

// --- Show Binary View ---
- (BOOL)showBinaryView {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kUDKeyShowBinaryView];
}

- (void)setShowBinaryView:(BOOL)showBinaryView {
    [[NSUserDefaults standardUserDefaults] setBool:showBinaryView forKey:kUDKeyShowBinaryView];
}

// --- Show Thousands Separators ---
- (BOOL)showThousandsSeparators {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kUDKeyShowThousandsSeparators];
}

- (void)setShowThousandsSeparators:(BOOL)showThousandsSeparators {
    [[NSUserDefaults standardUserDefaults] setBool:showThousandsSeparators forKey:kUDKeyShowThousandsSeparators];
}

// --- Decimal Places ---
- (NSInteger)decimalPlaces {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kUDKeyDecimalPlaces] == nil) {
        return 15;
    }
    return [[NSUserDefaults standardUserDefaults] integerForKey:kUDKeyDecimalPlaces];
}

- (void)setDecimalPlaces:(NSInteger)places {
    [[NSUserDefaults standardUserDefaults] setInteger:places forKey:kUDKeyDecimalPlaces];
}

@end
