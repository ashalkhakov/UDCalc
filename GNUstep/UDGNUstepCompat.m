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
    /* For NSGridView, compute content size from numberOfRows/Columns
       and _prototypeFrame (which gives per-cell size).
       total = cellSize * count + spacing * (count-1) */
    SEL protoSel = @selector(_prototypeFrame);
    SEL rowsSel  = @selector(numberOfRows);
    SEL colsSel  = @selector(numberOfColumns);
    SEL rSpacSel = @selector(rowSpacing);
    SEL cSpacSel = @selector(columnSpacing);

    if ([self respondsToSelector:protoSel] &&
        [self respondsToSelector:rowsSel] &&
        [self respondsToSelector:colsSel]) {
        NSMethodSignature *sig = [self methodSignatureForSelector:protoSel];
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:self];
        [inv setSelector:protoSel];
        [inv invoke];
        NSRect cellRect;
        [inv getReturnValue:&cellRect];

        NSInteger nRows = ((NSInteger (*)(id, SEL))[self methodForSelector:rowsSel])(self, rowsSel);
        NSInteger nCols = ((NSInteger (*)(id, SEL))[self methodForSelector:colsSel])(self, colsSel);

        CGFloat rSpacing = 0, cSpacing = 0;
        if ([self respondsToSelector:rSpacSel])
            rSpacing = ((CGFloat (*)(id, SEL))[self methodForSelector:rSpacSel])(self, rSpacSel);
        if ([self respondsToSelector:cSpacSel])
            cSpacing = ((CGFloat (*)(id, SEL))[self methodForSelector:cSpacSel])(self, cSpacSel);

        CGFloat w = cellRect.size.width  * nCols + cSpacing * MAX(0, nCols - 1);
        CGFloat h = cellRect.size.height * nRows + rSpacing * MAX(0, nRows - 1);
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
