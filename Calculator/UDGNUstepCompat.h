/*
 * UDGNUstepCompat.h - GNUstep compatibility definitions
 *
 * This header provides macOS API symbols that are missing or have
 * different signatures in GNUstep compared to Apple's AppKit and
 * Foundation frameworks.
 *
 * It is force-included via ADDITIONAL_OBJCFLAGS in the GNUmakefile
 * so that existing source files compile without modification on both
 * macOS and GNUstep platforms.
 *
 * Requires: GNUstep built with the modern Objective-C runtime (libobjc2)
 *           and recent gnustep-base and gnustep-gui from git master.
 *
 * Compatibility shims provided:
 *
 *   NSDimension and NSUnitConverter:
 *     isEqual: Cocoa-compatible equality for dimensions
 *
 *   NSFont:
 *     monospacedDigitSystemFontOfSize - returns a fixed-pitch font that is
 *       suitable for displaying numeric values in a tabular layout where
 *       all digits occupy the same horizontal space.
 *     monospacedSystemFontOfSize - returns a monospaced system font.
 *     systemFontOfSize with weight parameter - returns a bold variant
 *       of the system font when the weight parameter exceeds a threshold.
 *
 *   NSTextField:
 *     labelWithString - creates a non-editable, non-bordered text field
 *       that is suitable for use as a static label in a user interface.
 *
 *   NSPasteboard:
 *     canReadItemWithDataConformingToTypes - checks whether the pasteboard
 *       contains data matching any of the requested type identifiers.
 *     clearContents - removes all items from the pasteboard so that new
 *       content can be written without stale data remaining.
 *
 *   NSView:
 *     fittingSize - computes the intrinsic content size of a view. For
 *       NSGridView instances this sums explicit row heights and column
 *       widths to determine the natural dimensions of the grid content.
 *
 *   IBInspectable:
 *     Defined as a no-op macro since GNUstep does not use Interface
 *     Builder inspectable annotations.
 */

#ifndef UD_GNUSTEP_COMPAT_H
#define UD_GNUSTEP_COMPAT_H

#ifdef GNUSTEP

#if __has_include(<dispatch/dispatch.h>)
#include <dispatch/dispatch.h>
#endif

/* ------------------------------------------------------------
 * IBInspectable (Interface Builder attribute, no-op on GNUstep)
 * ------------------------------------------------------------ */
#ifndef IBInspectable
#define IBInspectable
#endif

/* ------------------------------------------------------------
 * NSDimension
 * ------------------------------------------------------------ */
#import <Foundation/NSUnit.h>

@interface NSDimension (UDGNUstepCompat)
- (BOOL) isEqual:(id)object;
@end
@interface NSUnitConverter (UDGNUstepCompat)
- (BOOL) isEqual:(id)object;
@end

/* GUI shims below require AppKit; skip when building non-GUI targets
 * (e.g. command-line test runners linked with gnustep-base only). */
#if __has_include(<AppKit/AppKit.h>)

/* ------------------------------------------------------------
 * NSFont convenience methods missing in GNUstep
 * ------------------------------------------------------------ */
#import <AppKit/NSFont.h>

@interface NSFont (UDGNUstepCompat)
+ (NSFont *)monospacedDigitSystemFontOfSize:(CGFloat)fontSize weight:(CGFloat)weight;
+ (NSFont *)monospacedSystemFontOfSize:(CGFloat)fontSize weight:(CGFloat)weight;
+ (NSFont *)systemFontOfSize:(CGFloat)fontSize weight:(CGFloat)weight;
@end

/* ------------------------------------------------------------
 * NSTextField convenience methods missing in GNUstep
 * ------------------------------------------------------------ */
#import <AppKit/NSTextField.h>

@interface NSTextField (UDGNUstepCompat)
+ (NSTextField *)labelWithString:(NSString *)stringValue;
@end

/* ------------------------------------------------------------
 * NSPasteboard convenience methods missing in GNUstep
 * ------------------------------------------------------------ */
#import <AppKit/NSPasteboard.h>

@interface NSPasteboard (UDGNUstepCompat)
- (BOOL)canReadItemWithDataConformingToTypes:(NSArray<NSString *> *)types;
@end

/* ------------------------------------------------------------
 * NSView fittingSize (not available in GNUstep)
 * ------------------------------------------------------------ */
#import <AppKit/NSGridView.h>
#import <AppKit/NSSegmentedControl.h>

@interface NSGridView (UDGNUstepCompat)
- (NSSize)fittingSize;
@end

@interface NSSegmentedControl (UDGNUstepCompat)
- (NSSize)fittingSize;
@end

/* ------------------------------------------------------------
 * NSPasteboard clearContents (not available in GNUstep)
 * ------------------------------------------------------------ */

@interface NSPasteboard (UDGNUstepClearCompat)
- (void)clearContents;
@end

#endif /* __has_include AppKit */

#endif /* GNUSTEP */

#endif /* UD_GNUSTEP_COMPAT_H */
