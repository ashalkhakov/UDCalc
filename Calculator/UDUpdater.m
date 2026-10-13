//
//  UDUpdater.m
//  Calculator
//
//  GNUstep: the AppImage is updated from outside it (UDUpdater.h).
//

#import "UDUpdater.h"

@implementation UDUpdater

- (instancetype)initStarting:(BOOL)start {
    return [super init];
}

- (BOOL)available {
    return NO;
}

- (BOOL)canCheckForUpdates {
    return NO;
}

- (IBAction)checkForUpdates:(id)sender {
}

@end
