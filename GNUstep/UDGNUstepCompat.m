/*
 * UDGNUstepCompat.m - Implementation of GNUstep compatibility shims
 */

#import "UDGNUstepCompat.h"

#ifdef GNUSTEP

/* ============================================================
 * NSFont compatibility
 * ============================================================ */
@implementation NSFont (UDGNUstepCompat)

+ (NSFont *)monospacedDigitSystemFontOfSize:(CGFloat)fontSize weight:(CGFloat)weight {
    NSFont *f = [NSFont userFixedPitchFontOfSize:fontSize];
    return f ? f : [NSFont systemFontOfSize:fontSize];
}

+ (NSFont *)monospacedSystemFontOfSize:(CGFloat)fontSize weight:(CGFloat)weight {
    NSFont *f = [NSFont userFixedPitchFontOfSize:fontSize];
    return f ? f : [NSFont systemFontOfSize:fontSize];
}

+ (NSFont *)systemFontOfSize:(CGFloat)fontSize weight:(CGFloat)weight {
    if (weight > 0.3) {
        return [NSFont boldSystemFontOfSize:fontSize];
    }
    return [NSFont systemFontOfSize:fontSize];
}

@end

/* ============================================================
 * NSTextField compatibility
 * ============================================================ */
@implementation NSTextField (UDGNUstepCompat)

+ (NSTextField *)labelWithString:(NSString *)stringValue {
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 100, 20)];
    [tf setStringValue:stringValue];
    [tf setBezeled:NO];
    [tf setDrawsBackground:NO];
    [tf setEditable:NO];
    [tf setSelectable:NO];
    return tf;
}

@end

/* ============================================================
 * NSPasteboard compatibility
 * ============================================================ */
@implementation NSPasteboard (UDGNUstepCompat)

- (BOOL)canReadItemWithDataConformingToTypes:(NSArray<NSString *> *)types {
    NSArray *available = [self types];
    for (NSString *type in types) {
        if ([available containsObject:type]) {
            return YES;
        }
    }
    return NO;
}

@end

/* ============================================================
 * NSView fittingSize compatibility
 * ============================================================ */
@implementation NSView (UDGNUstepCompat)

- (NSSize)fittingSize {
    /* For NSGridView, compute content size by summing explicit row
       heights and column widths (set via row.height / column.width)
       plus inter-row/column spacing.  _prototypeFrame can't be used
       because it derives per-cell size from the current frame, which
       is circular and produces wrong results when the frame hasn't
       been set to the content size yet. */
    SEL rowsSel  = @selector(numberOfRows);
    SEL colsSel  = @selector(numberOfColumns);
    SEL rowAtSel = @selector(rowAtIndex:);
    SEL colAtSel = @selector(columnAtIndex:);
    SEL rSpacSel = @selector(rowSpacing);
    SEL cSpacSel = @selector(columnSpacing);

    if ([self respondsToSelector:rowsSel] &&
        [self respondsToSelector:colsSel] &&
        [self respondsToSelector:rowAtSel] &&
        [self respondsToSelector:colAtSel]) {
        NSInteger nRows = ((NSInteger (*)(id, SEL))[self methodForSelector:rowsSel])(self, rowsSel);
        NSInteger nCols = ((NSInteger (*)(id, SEL))[self methodForSelector:colsSel])(self, colsSel);

        CGFloat rSpacing = 0, cSpacing = 0;
        if ([self respondsToSelector:rSpacSel])
            rSpacing = ((CGFloat (*)(id, SEL))[self methodForSelector:rSpacSel])(self, rSpacSel);
        if ([self respondsToSelector:cSpacSel])
            cSpacing = ((CGFloat (*)(id, SEL))[self methodForSelector:cSpacSel])(self, cSpacSel);

        /* Sum explicit row heights */
        CGFloat h = 0;
        for (NSInteger r = 0; r < nRows; r++) {
            id row = ((id (*)(id, SEL, NSInteger))[self methodForSelector:rowAtSel])(self, rowAtSel, r);
            h += ((CGFloat (*)(id, SEL))[row methodForSelector:@selector(height)])(row, @selector(height));
        }
        h += rSpacing * MAX(0, nRows - 1);

        /* Sum explicit column widths */
        CGFloat w = 0;
        for (NSInteger c = 0; c < nCols; c++) {
            id col = ((id (*)(id, SEL, NSInteger))[self methodForSelector:colAtSel])(self, colAtSel, c);
            w += ((CGFloat (*)(id, SEL))[col methodForSelector:@selector(width)])(col, @selector(width));
        }
        w += cSpacing * MAX(0, nCols - 1);

        return NSMakeSize(w, h);
    }
    return [self frame].size;
}

@end

/* ============================================================
 * NSPasteboard clearContents compatibility
 * ============================================================ */
@implementation NSPasteboard (UDGNUstepClearCompat)

- (void)clearContents {
    [self declareTypes:@[] owner:nil];
}

@end

#endif /* GNUSTEP */
