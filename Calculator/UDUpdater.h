//
//  UDUpdater.h
//  Calculator
//
//  The app's updates. On macOS, Sparkle: the newest release's appcast
//  (SUFeedURL in Info.plist, signed with the key SUPublicEDKey names) is
//  checked once a day if the user allows it, and Check for Updates… checks
//  now. On GNUstep, nothing: the AppImage carries its update information,
//  for AppImageUpdate, Gear Lever and the like (gnustep-release-actions' appimage).
//
//  UDUpdater-Apple.m is the macOS one (Xcode), UDUpdater.m the GNUstep one
//  (GNUmakefile).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UDUpdater : NSObject

// Started at once unless told not to (a self-test reaches no network).
- (instancetype)initStarting:(BOOL)start;

// Whether this system has an updater at all (Check for Updates… shown).
@property (nonatomic, readonly) BOOL available;
@property (nonatomic, readonly) BOOL canCheckForUpdates;

- (IBAction)checkForUpdates:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
