/*
 * UDGNUstepCompat.h - GNUstep compatibility definitions
 *
 * This header provides macOS API symbols that are missing in GNUstep.
 * It is force-included via ADDITIONAL_OBJCFLAGS in the GNUmakefile
 * so that existing source files compile without modification.
 *
 * Requires: GNUstep built with the modern Objective-C runtime (libobjc2)
 *           and recent gnustep-base/gnustep-gui from git master.
 */

#ifndef UD_GNUSTEP_COMPAT_H
#define UD_GNUSTEP_COMPAT_H

#ifdef GNUSTEP

#include <dispatch/dispatch.h>

/* ============================================================
 * IBInspectable (Interface Builder attribute, no-op on GNUstep)
 * ============================================================ */
#ifndef IBInspectable
#define IBInspectable
#endif

/* ============================================================
 * NSFont convenience methods missing in GNUstep
 * ============================================================ */
#import <AppKit/NSFont.h>

@interface NSFont (UDGNUstepCompat)
+ (NSFont *)monospacedDigitSystemFontOfSize:(CGFloat)fontSize weight:(CGFloat)weight;
+ (NSFont *)monospacedSystemFontOfSize:(CGFloat)fontSize weight:(CGFloat)weight;
+ (NSFont *)systemFontOfSize:(CGFloat)fontSize weight:(CGFloat)weight;
@end

/* ============================================================
 * NSTextField convenience methods missing in GNUstep
 * ============================================================ */
#import <AppKit/NSTextField.h>

@interface NSTextField (UDGNUstepCompat)
+ (NSTextField *)labelWithString:(NSString *)stringValue;
@end

/* ============================================================
 * NSPasteboard convenience methods missing in GNUstep
 * ============================================================ */
#import <AppKit/NSPasteboard.h>

@interface NSPasteboard (UDGNUstepCompat)
- (BOOL)canReadItemWithDataConformingToTypes:(NSArray<NSString *> *)types;
@end

/* ============================================================
 * NSView fittingSize (not available in GNUstep)
 * ============================================================ */
#import <AppKit/NSView.h>

@interface NSView (UDGNUstepCompat)
- (NSSize)fittingSize;
@end

/* ============================================================
 * NSLayoutConstraint setConstant (not available in GNUstep)
 * ============================================================ */
#import <AppKit/NSLayoutConstraint.h>

@interface NSLayoutConstraint (UDGNUstepCompat)
- (void)setConstant:(CGFloat)constant;
@end

/* ============================================================
 * NSPasteboard clearContents (not available in GNUstep)
 * ============================================================ */

@interface NSPasteboard (UDGNUstepClearCompat)
- (void)clearContents;
@end

#endif /* GNUSTEP */

#endif /* UD_GNUSTEP_COMPAT_H */
