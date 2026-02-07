//
//  UDBitDisplayView.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 02.02.2026.
//

#import "UDBitDisplayView.h"

@implementation UDBitDisplayView {
    NSMutableArray<NSValue *> *_bitRects;
}

- (void)setValue:(uint64_t)value {
    _value = value;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if (!_bitRects) _bitRects = [NSMutableArray array];
    [_bitRects removeAllObjects];

    // CONFIGURATION
    CGFloat rowHeight = self.bounds.size.height / 2.0;
    CGFloat nibbleGap = 8.0;
    // 7 gaps in a row of 8 nibbles (32 bits)
    CGFloat totalGapSpace = 7.0 * nibbleGap;
    CGFloat availableWidth = self.bounds.size.width - totalGapSpace;
    CGFloat bitWidth = availableWidth / 32.0;
    
    // --- STYLING UPDATES ---
    // Bits: Smaller font, Gray color
    NSDictionary *bitAttrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor grayColor]
    };
    
    // Markers (63, 47, etc): Larger font, White color
    NSDictionary *markerAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11 weight:NSFontWeightBold],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };

    // DRAWING LOOP (63 down to 0)
    for (int i = 63; i >= 0; i--) {
        BOOL isTopRow = (i >= 32);
        int colIndex = isTopRow ? (63 - i) : (31 - i); // 0 is Left-most column
        
        // Calculate Gaps
        int gapCount = colIndex / 4;
        
        // Calculate Position
        CGFloat x = (colIndex * bitWidth) + (gapCount * nibbleGap);
        CGFloat y = isTopRow ? rowHeight : 0;
        
        // 1. Draw the Bit (0 or 1)
        BOOL isSet = (_value >> i) & 1;
        NSString *bitStr = isSet ? @"1" : @"0";
        
        // Calculate text size for centering
        CGSize bitSize = [bitStr sizeWithAttributes:bitAttrs];
        
        // Center vertically in the top portion of the row (leaving space for marker below)
        CGFloat bitY = y + 12 + (rowHeight - 12 - bitSize.height) / 2;
        
        NSRect textRect = NSMakeRect(
            x + (bitWidth - bitSize.width)/2,
            bitY,
            bitSize.width,
            bitSize.height
        );
        [bitStr drawInRect:textRect withAttributes:bitAttrs];
        
        // Store Hit-Test Rect
        NSRect touchRect = NSMakeRect(x, y, bitWidth, rowHeight);
        [_bitRects addObject:[NSValue valueWithRect:touchRect]];
        
        // 2. Draw Markers (63, 47, 32...)
        BOOL shouldLabel = (i == 63 || i == 47 || i == 32 ||
                            i == 31 || i == 15 || i == 0);
        
        if (shouldLabel) {
            NSString *label = [NSString stringWithFormat:@"%d", i];
            CGSize labelSize = [label sizeWithAttributes:markerAttrs];
            
            // Draw below the bit, closer to the bottom edge
            NSRect labelRect = NSMakeRect(
                x + (bitWidth - labelSize.width)/2,
                y + 2,
                labelSize.width,
                labelSize.height
            );
            [label drawInRect:labelRect withAttributes:markerAttrs];
        }
    }
}

// HANDLE CLICKS
- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    
    // Since we introduced gaps, simple division (x / width) no longer works reliably.
    // Instead, we check the cached rects we generated during drawing.
    // The _bitRects array is filled in loop order: Index 0 = Bit 63, Index 63 = Bit 0.
    
    for (int i = 0; i < _bitRects.count; i++) {
        NSRect r = [_bitRects[i] rectValue];
        
        // Check if the click is inside this specific bit's box
        if (NSPointInRect(point, r)) {
            int bitIndex = 63 - i; // Map array index back to bit index
            
            BOOL currentBit = (_value >> bitIndex) & 1;
            [self.delegate bitDisplayDidToggleBit:bitIndex toValue:!currentBit];
            return; // Stop looking once found
        }
    }
}

@end
