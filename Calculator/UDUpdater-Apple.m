//
//  UDUpdater-Apple.m
//  Calculator
//
//  macOS: Sparkle (UDUpdater.h).
//

#import "UDUpdater.h"
#import <Sparkle/Sparkle.h>

@implementation UDUpdater {
    SPUStandardUpdaterController *_controller;
}

- (instancetype)initStarting:(BOOL)start {
    if (!(self = [super init])) return nil;
    _controller = [[SPUStandardUpdaterController alloc] initWithStartingUpdater:start updaterDelegate:nil userDriverDelegate:nil];
    return self;
}

- (BOOL)available {
    return YES;
}

- (BOOL)canCheckForUpdates {
    return _controller.updater.canCheckForUpdates;
}

- (IBAction)checkForUpdates:(id)sender {
    [_controller checkForUpdates:sender];
}

@end
