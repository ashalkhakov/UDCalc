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
    return [self frame].size;
}

@end

/* ============================================================
 * NSLayoutConstraint setConstant compatibility
 *
 * GNUstep's NSLayoutConstraint lacks a public setter for constant.
 * Simply writing to the ivar is not enough: the Cassowary solver
 * still holds the old value.  Remove and re-add the constraint so
 * the solver picks up the new constant.
 * ============================================================ */
@implementation NSLayoutConstraint (UDGNUstepCompat)

- (void)setConstant:(CGFloat)constant {
    _constant = constant;

    /* Find the view that owns this constraint and bounce it through
       the solver by removing + re-adding.
       Use performSelector: because GNUstep headers don't declare
       removeConstraint:/addConstraint: on NSView. */
    id first = [self firstItem];
    if ([first isKindOfClass:[NSView class]]) {
        NSView *owner = [(NSView *)first superview];
        id target = owner ? (id)owner : first;
        [target performSelector:@selector(removeConstraint:) withObject:self];
        [target performSelector:@selector(addConstraint:) withObject:self];
    }
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
