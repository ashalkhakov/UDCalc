//
//  UDCalcButton.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 21.01.2026.
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, CalcButtonType) {
    // We will use this to mean "Just draw the button title"
    CalcButtonTypeStandard = 0,

    CalcButtonTypePi = 1,           // Pi symbol
    CalcButtonTypeInverse = 2,      // 1/x

    // --- Standard Trig ---
    CalcButtonTypeSin = 3,          // sin
    CalcButtonTypeCos = 4,          // cos
    CalcButtonTypeTan = 5,          // tan
    CalcButtonTypeSinh = 6,         // sinh
    CalcButtonTypeCosh = 7,         // cosh
    CalcButtonTypeTanh = 8,         // tanh

    // Inverse Trig
    CalcButtonTypeSinInverse = 9,   // sin^-1 <-- NEW
    CalcButtonTypeCosInverse = 10,   // cos^-1 <-- NEW
    CalcButtonTypeTanInverse = 11,   // tan^-1 <-- NEW
    CalcButtonTypeSinhInverse = 12,  // sinh^-1 <-- NEW
    CalcButtonTypeCoshInverse = 13,  // cosh^-1 <-- NEW
    CalcButtonTypeTanhInverse = 14,  // tanh^-1 <-- NEW

    // Standard Exponents
    CalcButtonTypeSquare = 15,       // x^2
    CalcButtonTypeCube = 16,         // x^3
    CalcButtonTypePower = 17,        // x^y
    CalcButtonTypePowerYtoX = 18,    // y^x  <-- NEW
    CalcButtonTypePower2toX = 19,    // 2^x  <-- NEW
    CalcButtonTypeExp = 20,          // e^x
    CalcButtonTypeTenPower = 21,     // 10^x

    CalcButtonType2nd = 22,           // 2nd

    // Logarithms
    CalcButtonTypeLog10 = 23,        // log10
    CalcButtonTypeLog2 = 24,         // log2 <-- NEW
    CalcButtonTypeLogY = 25,         // logy <-- NEW

    // Roots & Others
    CalcButtonTypeSqrt = 26,         // sqrt(x)
    CalcButtonTypeCubeRoot = 27,     // 3rd root
    CalcButtonTypeYRoot = 28,        // y-th root
};

@interface UDCalcButton : NSButton

@property (nonatomic, assign) IBInspectable NSInteger symbolType;
@property (nonatomic, strong) IBInspectable NSColor *textColor;
@property (nonatomic, strong) IBInspectable NSColor *buttonColor;      // Normal background
@property (nonatomic, strong) IBInspectable NSColor *highlightColor;   // Color when pressed

@end
