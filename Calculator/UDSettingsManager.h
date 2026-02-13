//
//  UDSettingsManager.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 12.02.2026.
//

#import "UDCalc.h"

// UDSettingsManager.h
@interface UDSettingsManager : NSObject

+ (instancetype)sharedManager;

- (void)registerDefaults;
- (void)forceSync;

// Properties that automatically sync to NSUserDefaults
@property (nonatomic, assign) UDCalcMode calcMode;
@property (nonatomic, assign) BOOL isRPN;
@property (nonatomic, assign) UDCalcEncodingMode encodingMode;
@property (nonatomic, assign) BOOL isRadians;
@property (nonatomic, assign) UDBase inputBase;
@property (nonatomic, assign) BOOL showBinaryView;

@end
