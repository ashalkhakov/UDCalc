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
    SEL selector = @selector(_prototypeFrame);
    if ([self respondsToSelector:selector]) {;
        // Get the method signature for the selector
        NSMethodSignature *signature = [self methodSignatureForSelector:selector];
        if (!signature) {
           [NSException raise:NSInvalidArgumentException format:@"Method signature not found for selector %@", NSStringFromSelector(selector)];
        }

        // Create an NSInvocation object
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:self];
        [invocation setSelector:selector];

        // Invoke the method
        [invocation invoke];

        // Get the return value
        NSRect rect;
        // The `getReturnValue:` method expects a pointer to the memory location where the return value should be stored.
        [invocation getReturnValue:&rect];

        return rect.size;
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
