//
//  UDCalcButton.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 21.01.2026.
//

#import "UDCalcButton.h"

@implementation UDCalcButton

#pragma mark - Initialization

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) [self setupDefaults];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) [self setupDefaults];
    return self;
}

- (void)setupDefaults {
    self.bordered = NO; // Handle our own drawing
    
    // Default "Dark Mode" Calculator Colors
    self.textColor = [NSColor whiteColor];
    self.buttonColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];      // Dark Grey
    self.highlightColor = [NSColor colorWithCalibratedWhite:0.4 alpha:1.0];   // Lighter Grey
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    // Map the Interface Builder 'Tag' integer to our Enum
    // This allows you to set the type directly in the IB side panel
    self.symbolType = (CalcButtonType)self.tag;
}

#pragma mark - Main Draw Loop

- (void)drawRect:(NSRect)dirtyRect {
    // 1. Draw Background (Highlight logic)
    NSColor *bg = [self.cell isHighlighted] ? self.highlightColor : self.buttonColor;
    [bg setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:0 yRadius:0] fill];

    // 2. Draw Symbol
    switch (self.symbolType) {
        // If Tag is 0, just draw the text from Interface Builder (e.g., "7", "AC", "+")
        case CalcButtonTypeStandard:  [self drawScaledText:self.title]; break;
            
        // --- Standard Trig ---
        case CalcButtonTypeSin:       [self drawScaledText:@"sin"]; break;
        case CalcButtonTypeCos:       [self drawScaledText:@"cos"]; break;
        case CalcButtonTypeTan:       [self drawScaledText:@"tan"]; break;
        case CalcButtonTypeSinh:      [self drawScaledText:@"sinh"]; break;
        case CalcButtonTypeCosh:      [self drawScaledText:@"cosh"]; break;
        case CalcButtonTypeTanh:      [self drawScaledText:@"tanh"]; break;
        
        // --- Inverse Trig ---
        case CalcButtonTypeSinInverse:  [self drawSuperscriptBase:@"sin" exponent:@"-1"]; break;
        case CalcButtonTypeCosInverse:  [self drawSuperscriptBase:@"cos" exponent:@"-1"]; break;
        case CalcButtonTypeTanInverse:  [self drawSuperscriptBase:@"tan" exponent:@"-1"]; break;
        case CalcButtonTypeSinhInverse: [self drawSuperscriptBase:@"sinh" exponent:@"-1"]; break;
        case CalcButtonTypeCoshInverse: [self drawSuperscriptBase:@"cosh" exponent:@"-1"]; break;
        case CalcButtonTypeTanhInverse: [self drawSuperscriptBase:@"tanh" exponent:@"-1"]; break;

        // --- Powers ---
        case CalcButtonTypeSquare:    [self drawSuperscriptBase:@"x" exponent:@"2"]; break;
        case CalcButtonTypeCube:      [self drawSuperscriptBase:@"x" exponent:@"3"]; break;
        case CalcButtonTypePower:     [self drawSuperscriptBase:@"x" exponent:@"y"]; break;
        case CalcButtonTypePowerYtoX: [self drawSuperscriptBase:@"y" exponent:@"x"]; break;
        case CalcButtonTypePower2toX: [self drawSuperscriptBase:@"2" exponent:@"x"]; break;
        case CalcButtonTypeExp:       [self drawSuperscriptBase:@"e" exponent:@"x"]; break;
        case CalcButtonTypeTenPower:  [self drawSuperscriptBase:@"10" exponent:@"x"]; break;
        case CalcButtonType2nd:       [self drawSuperscriptBase:@"2" exponent:@"nd"]; break;

        // --- Logs ---
        case CalcButtonTypeLog10:     [self drawLogWithBase:@"10"]; break;
        case CalcButtonTypeLog2:      [self drawLogWithBase:@"2"]; break;
        case CalcButtonTypeLogY:      [self drawLogWithBase:@"y"]; break;

        // --- Roots ---
        case CalcButtonTypeSqrt:      [self drawRootWithIndex:nil]; break;
        case CalcButtonTypeCubeRoot:  [self drawRootWithIndex:@"3"]; break;
        case CalcButtonTypeYRoot:     [self drawRootWithIndex:@"y"]; break;

        // --- Misc ---
        case CalcButtonTypeInverse:   [self drawScaledText:@"1/x"]; break;
        case CalcButtonTypePi:        [self drawScaledText:@"π"]; break;
    }
}

#pragma mark - Drawing Helpers

- (NSDictionary *)attributesWithSize:(CGFloat)size {
    return @{
        NSFontAttributeName: [NSFont systemFontOfSize:size weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: self.textColor
    };
}

// Draws simple text but scales it down if it's too long (e.g. "tanh")
- (void)drawScaledText:(NSString *)text {
    CGFloat fontSize = 22.0;
    
    // Scale down for 3 letters (sin, cos) and 4 letters (sinh, cosh)
    if (text.length == 3) fontSize = 18.0;
    if (text.length >= 4) fontSize = 16.0;
    
    NSDictionary *attrs = [self attributesWithSize:fontSize];
    NSSize textSize = [text sizeWithAttributes:attrs];
    
    // Center in button
    CGFloat x = (self.bounds.size.width - textSize.width) / 2.0;
    CGFloat y = (self.bounds.size.height - textSize.height) / 2.0;
    
    [text drawAtPoint:NSMakePoint(x, y) withAttributes:attrs];
}

- (void)drawSuperscriptBase:(NSString *)base exponent:(NSString *)exp {
    // If base is long (sinh), shrink font
    BOOL isLong = (base.length > 2);
    CGFloat baseFontSize = isLong ? 16.0 : 22.0;
    CGFloat expFontSize = isLong ? 10.0 : 14.0;
    
    NSDictionary *baseAttrs = [self attributesWithSize:baseFontSize];
    NSDictionary *expAttrs = [self attributesWithSize:expFontSize];
    
    NSSize baseDim = [base sizeWithAttributes:baseAttrs];
    NSSize expDim = [exp sizeWithAttributes:expAttrs];
    
    CGFloat totalWidth = baseDim.width + expDim.width;
    CGFloat startX = (self.bounds.size.width - totalWidth) / 2.0;
    CGFloat centerY = (self.bounds.size.height - baseDim.height) / 2.0;
    
    [base drawAtPoint:NSMakePoint(startX, centerY) withAttributes:baseAttrs];
    
    // Lift the exponent. If font is smaller, lift less.
    CGFloat lift = isLong ? 6.0 : 8.0;
    [exp drawAtPoint:NSMakePoint(startX + baseDim.width, centerY + lift) withAttributes:expAttrs];
}

- (void)drawLogWithBase:(NSString *)subscript {
    NSString *mainText = @"log";
    
    NSDictionary *mainAttrs = [self attributesWithSize:16.0];
    NSDictionary *subAttrs = [self attributesWithSize:10.0];
    
    NSSize mainDim = [mainText sizeWithAttributes:mainAttrs];
    NSSize subDim = [subscript sizeWithAttributes:subAttrs];
    
    CGFloat totalWidth = mainDim.width + subDim.width;
    CGFloat startX = (self.bounds.size.width - totalWidth) / 2.0;
    CGFloat centerY = (self.bounds.size.height - mainDim.height) / 2.0;
    
    // Draw 'log' slightly higher
    [mainText drawAtPoint:NSMakePoint(startX, centerY + 2) withAttributes:mainAttrs];
    
    // Draw subscript slightly lower
    [subscript drawAtPoint:NSMakePoint(startX + mainDim.width, centerY - 4) withAttributes:subAttrs];
}

- (void)drawRootWithIndex:(NSString *)indexText {
    NSString *content = @"x";
    NSDictionary *contentAttrs = [self attributesWithSize:20.0];
    NSSize contentSize = [content sizeWithAttributes:contentAttrs];
    
    CGFloat padding = 4.0;
    CGFloat radicalWidth = 14.0;
    
    // Calculate total width including index if present
    CGFloat totalWidth = radicalWidth + contentSize.width + padding;
    if (indexText) totalWidth += 6.0;
    
    CGFloat startX = (self.bounds.size.width - totalWidth) / 2.0;
    if (indexText) startX += 6.0;
    
    CGFloat centerY = (self.bounds.size.height - contentSize.height) / 2.0;
    
    // Draw Index (3 or y)
    if (indexText) {
        NSDictionary *indexAttrs = [self attributesWithSize:10.0];
        [indexText drawAtPoint:NSMakePoint(startX - 8, centerY + 10) withAttributes:indexAttrs];
    }
    
    // Draw 'x' content
    NSRect textRect = NSMakeRect(startX + radicalWidth, centerY - 2, contentSize.width, contentSize.height);
    [content drawInRect:textRect withAttributes:contentAttrs];
    
    // Draw Vector Radical Path
    [self.textColor setStroke];
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineWidth:1.5];
    [path setLineCapStyle:NSLineCapStyleRound];
    [path setLineJoinStyle:NSLineJoinStyleRound];
    
    CGFloat baseline = centerY;
    CGFloat height = contentSize.height;
    
    [path moveToPoint:NSMakePoint(startX, baseline + 8)];
    [path lineToPoint:NSMakePoint(startX + 4, baseline + 2)];
    [path lineToPoint:NSMakePoint(startX + 10, baseline + height + 2)];
    [path lineToPoint:NSMakePoint(startX + radicalWidth + contentSize.width + 2, baseline + height + 2)];
    [path stroke];
}

@end
