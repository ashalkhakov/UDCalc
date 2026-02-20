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
    
#ifdef GNUSTEP
    // Use theme-aware colors on GNUstep
    self.textColor = [NSColor controlTextColor];
    self.buttonColor = [NSColor controlColor];
    self.highlightColor = [NSColor selectedControlColor];
#else
    // Default "Dark Mode" Calculator Colors
    self.textColor = [NSColor whiteColor];
    self.buttonColor = [NSColor colorWithCalibratedWhite:0.2 alpha:1.0];      // Dark Grey
    self.highlightColor = [NSColor colorWithCalibratedWhite:0.4 alpha:1.0];   // Lighter Grey
#endif
}

#pragma mark - Main Draw Loop

- (void)drawRect:(NSRect)dirtyRect {
    // 1. Determine Background Color based on State
    NSColor *bg;
    
    if (!self.isEnabled) {
#ifdef GNUSTEP
        bg = [NSColor controlColor];
#else
        // DISABLED: Use a flat, dark gray to indicate inactivity
        bg = [NSColor colorWithCalibratedWhite:0.15 alpha:1.0];
#endif
    }
    else if ([self.cell isHighlighted]) {
        // HIGHLIGHTED: Use the specified highlight color
        bg = self.highlightColor;
    }
    else {
        // NORMAL: Use the custom background (Yellow, Dark Gray, etc.)
        bg = self.buttonColor ? self.buttonColor : [NSColor controlColor];
    }
    
    [bg setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:0 yRadius:0] fill];

    // 2. Draw Symbol
    // Note: The drawing helpers below now check [self isEnabled] to dim the text automatically.
    switch ((CalcButtonType)self.symbolType) {
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
    // 1. Calculate effective text color
    // If disabled, use the text color with 40% opacity (dimmed)
    NSColor *effectiveColor = self.isEnabled ? self.textColor : [self.textColor colorWithAlphaComponent:0.4];
    
    return @{
        NSFontAttributeName: [NSFont systemFontOfSize:size weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: effectiveColor
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
    // 1. Detect Coordinate Direction
    // Standard (Bottom-Left): dir = 1.0  (Add Y to go Up)
    // Flipped  (Top-Left):    dir = -1.0 (Subtract Y to go Up)
    CGFloat dir = [self isFlipped] ? -1.0 : 1.0;

    // 2. Setup Fonts & Attributes
    BOOL isLongBase = (base.length > 2); // Shrink font for things like "sinh"
    CGFloat baseFontSize = isLongBase ? 16.0 : 22.0;
    CGFloat expFontSize  = isLongBase ? 10.0 : 14.0;
    
    NSDictionary *baseAttrs = [self attributesWithSize:baseFontSize];
    NSDictionary *expAttrs  = [self attributesWithSize:expFontSize];
    
    NSSize baseDim = [base sizeWithAttributes:baseAttrs];
    NSSize expDim  = [exp sizeWithAttributes:expAttrs];
    
    // 3. Layout (Centering)
    CGFloat totalWidth = baseDim.width + expDim.width;
    CGFloat startX = (self.bounds.size.width - totalWidth) / 2.0;
    CGFloat centerY = (self.bounds.size.height - baseDim.height) / 2.0;
    
    // 4. Draw Base Text
    [base drawAtPoint:NSMakePoint(startX, centerY) withAttributes:baseAttrs];
    
    // 5. Draw Exponent
    // We calculate the Y position relative to the base text's center.
    // "lift" determines how many pixels visually UP we move.
    CGFloat lift = isLongBase ? 5.0 : 6.0;
    
    // Apply direction:
    // If flipped, this becomes (centerY - 9.0), moving towards top (0.0). Correct.
    // If standard, this becomes (centerY + 9.0), moving away from bottom (0.0). Correct.
    CGFloat expY = centerY + (lift * dir);
    CGFloat expX = startX + baseDim.width + 1.0; // +1.0 for a tiny bit of breathing room
    
    [exp drawAtPoint:NSMakePoint(expX, expY) withAttributes:expAttrs];
}

- (void)drawLogWithBase:(NSString *)subscript {
    // 1. Detect Coordinate Direction (Standard vs Flipped)
    CGFloat dir = [self isFlipped] ? -1.0 : 1.0;

    NSString *mainText = @"log";
    
    // 2. Setup Fonts
    // Log is usually regular weight, not bold
    NSDictionary *mainAttrs = [self attributesWithSize:22.0];
    NSDictionary *subAttrs = [self attributesWithSize:13.0];
    
    NSSize mainDim = [mainText sizeWithAttributes:mainAttrs];
    NSSize subDim = [subscript sizeWithAttributes:subAttrs];
    
    // 3. Layout
    // Calculate total width
    CGFloat totalWidth = mainDim.width + subDim.width;
    CGFloat startX = (self.bounds.size.width - totalWidth) / 2.0;
    
    // Calculate vertical center based on the main "log" text
    CGFloat centerY = (self.bounds.size.height - mainDim.height) / 2.0;
    
    // 4. Draw "log"
    [mainText drawAtPoint:NSMakePoint(startX, centerY) withAttributes:mainAttrs];
    
    // 5. Draw Subscript (Base)
    // We want the subscript to sit lower than the main text.
    // In standard coordinates (Up is +), we subtract.
    // In flipped coordinates (Down is +), we add.
    // We use 'dir' to inverse the logic automatically.
    
    // 8.0 is the visual offset downwards
    CGFloat subY = centerY - (10.0 * dir);
    
    // Move slightly right to sit next to the 'g'
    CGFloat subX = startX + mainDim.width + 1.0;
    
    [subscript drawAtPoint:NSMakePoint(subX, subY) withAttributes:subAttrs];
}

- (void)drawRootWithIndex:(NSString *)indexText {
    // 1. Detect Coordinate System Direction
    CGFloat dir = [self isFlipped] ? -1.0 : 1.0;
    
    // 2. Setup Fonts & Colors
    // Calculate effective color for both text and stroke
    NSColor *effectiveColor = self.isEnabled ? self.textColor : [self.textColor colorWithAlphaComponent:0.4];
    
    NSFont *baseFont = [NSFont systemFontOfSize:24.0 weight:NSFontWeightBold];
    NSFont *indexFont = [NSFont systemFontOfSize:13.0 weight:NSFontWeightBold];
    
    NSDictionary *baseAttrs = @{NSFontAttributeName: baseFont, NSForegroundColorAttributeName: effectiveColor};
    NSDictionary *indexAttrs = @{NSFontAttributeName: indexFont, NSForegroundColorAttributeName: effectiveColor};
    
    NSString *baseText = @"x";
    NSSize baseSize = [baseText sizeWithAttributes:baseAttrs];
    NSSize indexSize = indexText ? [indexText sizeWithAttributes:indexAttrs] : NSZeroSize;
    
    // 3. Layout Geometry
    CGFloat radicalLeftPadding = 5.0;
    CGFloat strokeWidth = 2.5;
    
    CGFloat totalWidth = baseSize.width + radicalLeftPadding + 6.0;
    if (indexText) totalWidth += (indexSize.width * 0.6);
    
    CGFloat startX = (self.bounds.size.width - totalWidth) / 2.0;
    CGFloat centerY = (self.bounds.size.height - baseSize.height) / 2.0;
    
    // 4. Draw Text
    CGFloat xTextX = startX + totalWidth - baseSize.width;
    [baseText drawAtPoint:NSMakePoint(xTextX, centerY) withAttributes:baseAttrs];
    
    if (indexText) {
        CGFloat indexX = xTextX - radicalLeftPadding - indexSize.width + 3.0;
        CGFloat indexY = centerY + (4.0 * dir);
        [indexText drawAtPoint:NSMakePoint(indexX, indexY) withAttributes:indexAttrs];
    }
    
    // 5. Draw Radical Geometry (The Checkmark)
    [effectiveColor setStroke]; // <--- Use the dimmed color here
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path setLineWidth:strokeWidth];
    [path setLineCapStyle:NSLineCapStyleRound];
    [path setLineJoinStyle:NSLineJoinStyleRound];
    
    // Vertical Offsets
    CGFloat baseY = centerY + (baseSize.height / 2.0);
    CGFloat tickYOffset   = 0.0;
    CGFloat bottomYOffset = -6.0;
    CGFloat topYOffset    = 9.0;
    
    CGFloat tickY   = baseY + (tickYOffset * dir);
    CGFloat bottomY = baseY + (bottomYOffset * dir);
    CGFloat topY    = baseY + (topYOffset * dir);
    
    // Horizontal Coordinates
    CGFloat barStartX = xTextX - 0.5;
    CGFloat barEndX   = xTextX + baseSize.width;
    CGFloat bottomPointX = xTextX - 5.0;
    CGFloat tickStartX = xTextX - 8.0;

    if (indexText) tickStartX -= 2.0;

    // Draw Path
    [path moveToPoint:NSMakePoint(tickStartX, tickY)];
    [path lineToPoint:NSMakePoint(bottomPointX, bottomY)];
    [path lineToPoint:NSMakePoint(barStartX, topY)];
    [path lineToPoint:NSMakePoint(barEndX, topY)];
    
    [path stroke];
}

@end
