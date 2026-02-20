/*
 * UDGNUstepCompat.m - Implementation of GNUstep compatibility shims
 *
 * This file provides runtime implementations of macOS AppKit and Foundation
 * methods that are not available in the GNUstep framework libraries.
 *
 * Each category method below corresponds to a declaration in the companion
 * header UDGNUstepCompat.h.  The implementations are intentionally simple
 * and aim to replicate the essential behavior of the macOS originals without
 * depending on any private GNUstep internals.
 *
 * The entire file is wrapped in an GNUSTEP preprocessor guard so that it
 * compiles to nothing when building on macOS with Xcode.
 */

#import "UDGNUstepCompat.h"

#ifdef GNUSTEP

/* Returns a fixed-pitch font suitable for displaying numbers in tabular
   columns.  Falls back to the regular system font if no monospaced font
   is available on the current GNUstep installation. */
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

/* Creates a read-only text field configured as a static label.
   The field has no border, no background, and is not editable or
   selectable, matching the behavior of the macOS convenience
   constructor used throughout the calculator user interface. */
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

/* Checks whether the pasteboard currently holds data conforming to
   at least one of the requested Uniform Type Identifiers.  This is
   used by the calculator paste logic to verify clipboard content
   before attempting to read numeric or text data from it. */
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

/* Computes the intrinsic content size of a view.  For an NSGridView
   the size is computed by iterating all rows and columns and summing
   the explicit height and width values that were assigned during the
   grid rebuild phase in UDCalcViewController.  Inter-row and
   inter-column spacing is added between adjacent items.

   For non-grid views the current frame size is returned as a
   reasonable fallback since those views do not expose intrinsic
   sizing information through a public interface on GNUstep. */
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

/* Removes all current items from the pasteboard.  This is called
   before writing new content to ensure that stale data from a
   previous copy operation does not remain on the pasteboard and
   confuse paste targets that check available types before reading. */
@implementation NSPasteboard (UDGNUstepClearCompat)

- (void)clearContents {
    [self declareTypes:@[] owner:nil];
}

@end

#endif /* GNUSTEP */
