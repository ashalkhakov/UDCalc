//
//  UDBitDisplayView.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 02.02.2026.
//

#import "UDBitDisplayView.h"

@implementation UDBitDisplayView {
    NSMutableArray<NSValue *> *_bitRects; // Stores hit-test rects for clicks
}

- (void)setValue:(uint64_t)value {
    _value = value;
    [self setNeedsDisplay:YES]; // Redraw whenever value changes
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if (!_bitRects) _bitRects = [NSMutableArray array];
    [_bitRects removeAllObjects];

    // CONFIGURATION
    CGFloat rowHeight = self.bounds.size.height / 2.0;
    CGFloat bitWidth = self.bounds.size.width / 32.0; // 32 bits per row
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    NSDictionary *labelAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:9],
        NSForegroundColorAttributeName: [NSColor labelColor]
    };

    // DRAWING LOOP (63 down to 0)
    for (int i = 63; i >= 0; i--) {
        BOOL isTopRow = (i >= 32);
        int colIndex = isTopRow ? (63 - i) : (31 - i); // 0 is Left-most column
        
        // Calculate Position
        CGFloat x = colIndex * bitWidth;
        CGFloat y = isTopRow ? rowHeight : 0; // Top row draws in upper half
        
        // 1. Draw the Bit (0 or 1)
        BOOL isSet = (_value >> i) & 1;
        NSString *bitStr = isSet ? @"1" : @"0";
        NSRect bitRect = NSMakeRect(x, y + 15, bitWidth, rowHeight - 15); // Shift up for labels
        
        // Center text in rect
        CGSize textSize = [bitStr sizeWithAttributes:attrs];
        NSRect textRect = NSMakeRect(
            x + (bitWidth - textSize.width)/2,
            y + 15 + (bitRect.size.height - textSize.height)/2,
            textSize.width,
            textSize.height
        );
        [bitStr drawInRect:textRect withAttributes:attrs];
        
        // Store Hit-Test Rect (Full cell)
        NSRect touchRect = NSMakeRect(x, y, bitWidth, rowHeight);
        [_bitRects addObject:[NSValue valueWithRect:touchRect]]; // Index matches loop order? No.
        // We need to map Rect -> Bit Index later.
        
        // 2. Draw Labels (63, 47, 32...) underneath specific bits
        // Logic: Apple usually labels the MSB of groups (or every 16th/8th)
        // Your request: 63, 47, 32 on Top | 31, 15, 0 on Bottom
        BOOL shouldLabel = (i == 63 || i == 47 || i == 32 ||
                            i == 31 || i == 15 || i == 0);
        
        if (shouldLabel) {
            NSString *label = [NSString stringWithFormat:@"%d", i];
            CGSize labelSize = [label sizeWithAttributes:labelAttrs];
            // Draw slightly below the bit
            NSRect labelRect = NSMakeRect(
                x + (bitWidth - labelSize.width)/2,
                y + 2, // Close to bottom of row
                labelSize.width,
                labelSize.height
            );
            [label drawInRect:labelRect withAttributes:labelAttrs];
        }
    }
}

// HANDLE CLICKS
- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    CGFloat rowHeight = self.bounds.size.height / 2.0;
    CGFloat bitWidth = self.bounds.size.width / 32.0;
    
    // Determine Row
    BOOL isTopRow = (point.y >= rowHeight);
    
    // Determine Column (0..31)
    int col = (int)(point.x / bitWidth);
    if (col < 0 || col > 31) return;
    
    // Map back to Bit Index (0..63)
    // Top Row: Col 0 -> Bit 63
    // Bottom Row: Col 0 -> Bit 31
    int bitIndex = isTopRow ? (63 - col) : (31 - col);
    
    // Inform Delegate
    if (bitIndex >= 0 && bitIndex <= 63) {
        // Calculate new state locally for snappy feel, or let delegate handle it
        BOOL currentBit = (_value >> bitIndex) & 1;
        [self.delegate bitDisplayDidToggleBit:bitIndex toValue:!currentBit];
    }
}

@end
