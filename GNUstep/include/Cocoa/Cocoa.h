/*
 * Cocoa/Cocoa.h - GNUstep compatibility shim
 *
 * On macOS, Cocoa.h includes AppKit and Foundation.
 * On GNUstep, we include AppKit/AppKit.h which provides
 * the same functionality.
 */
#import <AppKit/AppKit.h>
