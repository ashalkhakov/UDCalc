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
    /* NSGridView exposes -_prototypeFrame which computes the intrinsic
       content size from row/column dimensions.  Use it when available. */
    if ([self respondsToSelector:@selector(_prototypeFrame)]) {
        NSRect proto = [(id)self _prototypeFrame];
        return proto.size;
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
