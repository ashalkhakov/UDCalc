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
 * The entire file is wrapped in a GNUSTEP preprocessor guard so that it
 * compiles to nothing when building on macOS with Xcode.
 */

#import <AppKit/AppKit.h>
#import "UDGNUstepCompat.h"

#ifdef GNUSTEP

@implementation NSUnitConverter (UDGNUstepCompat)

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[NSUnitConverter class]]) return NO;

    if ([self isMemberOfClass:[NSUnitConverter class]]) {
        return [object isMemberOfClass:[NSUnitConverter class]];
    }

    // handle the most common case of linear converters (y = ax + b)
    if ([self isKindOfClass:[NSUnitConverterLinear class]] && [object isKindOfClass:[NSUnitConverterLinear class]]) {
        NSUnitConverterLinear *thisLinear = (NSUnitConverterLinear *)self;
        NSUnitConverterLinear *otherLinear = (NSUnitConverterLinear *)object;

        return (thisLinear.coefficient == otherLinear.coefficient && thisLinear.constant == otherLinear.constant);
    }

    return NO;
}

- (NSUInteger)hash {
    if ([self isKindOfClass:[NSUnitConverterLinear class]]) {
        NSUnitConverterLinear *linear = (NSUnitConverterLinear *)self;
        return (NSUInteger)(linear.coefficient * 1000) ^ (NSUInteger)linear.constant;
    }
    return [self.class hash];
}

@end

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
@implementation NSGridView (UDGNUstepCompat)

- (NSSize)fittingSize {
    /* For NSGridView, compute content size by summing explicit row
       heights and column widths (set via row.height / column.width)
       plus inter-row/column spacing.  _prototypeFrame can't be used
       because it derives per-cell size from the current frame, which
       is circular and produces wrong results when the frame hasn't
       been set to the content size yet. */

    NSInteger nRows = [self numberOfRows];
    NSInteger nCols = [self numberOfColumns];

    CGFloat rSpacing = [self rowSpacing];
    CGFloat cSpacing = [self columnSpacing];

    /* Sum explicit row heights */
    CGFloat h = 0;
    for (NSInteger r = 0; r < nRows; r++) {
        NSGridRow *row = [self rowAtIndex:r];
        h += [row height];
    }
    h += rSpacing * MAX(0, nRows - 1);

    /* Sum explicit column widths */
    CGFloat w = 0;
    for (NSInteger c = 0; c < nCols; c++) {
        NSGridColumn *col = [self columnAtIndex:c];
        w += [col width];
    }
    w += cSpacing * MAX(0, nCols - 1);

    return NSMakeSize(w, h);
}

@end

@implementation NSSegmentedControl (UDGNUstepCompat)
/* Compute the fitting width for an NSSegmentedControl by measuring
 * each segment's label text. */
- (NSSize)fittingSize {
    static const CGFloat kSegPad = 16.0;
    static const CGFloat kSegPadH = 8.0;

    NSInteger nSegments = [self segmentCount];
    NSDictionary *attrs = @{NSFontAttributeName: [self font] ?: [NSFont systemFontOfSize:0]};
    CGFloat totalWidth = 0;
    CGFloat maxHeight = 0;
    
    for (NSInteger c = 0; c < nSegments; c++) {
        NSString *label = [self labelForSegment:c] ?: @""; // TODO: image segments?
        NSSize textSize = [label sizeWithAttributes:attrs];
        totalWidth += textSize.width + kSegPad;
        maxHeight = MAX(maxHeight, textSize.height + kSegPadH);
    }

    return NSMakeSize(totalWidth, maxHeight);
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
