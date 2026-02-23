//
//  UDTapeWindowController.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import "UDTapeWindowController.h"
#import "UDCalcViewController.h"
#import "UDSettingsManager.h"

@interface UDTapeWindowController ()

// Connect this outlet to the NSTextView in Interface Builder
@property (unsafe_unretained) IBOutlet NSTextView *textView;

@property (nonatomic, assign) BOOL isAppTerminating;

@end

@implementation UDTapeWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.window.delegate = self;
#ifndef GNUSTEP
    self.window.styleMask |= NSWindowStyleMaskNonactivatingPanel;
#endif
    
    ((NSPanel *)self.window).becomesKeyOnlyIfNeeded = YES;

    // Set a nice monospaced font so numbers align perfectly
    //[self.textView setFont:[NSFont monospacedDigitSystemFontOfSize:14.0 weight:NSFontWeightRegular]];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillTerminate:)
                                                 name:NSApplicationWillTerminateNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appWillTerminate:(NSNotification *)notification {
    self.isAppTerminating = YES;
}

- (void)windowWillClose:(NSNotification *)notification {
    if (!self.isAppTerminating) {
        [UDSettingsManager sharedManager].showTapeWindow = NO;
    }
}

- (void)appendLog:(NSString *)logLine {
    // Ensure window is loaded before trying to write
    if (!self.isWindowLoaded) {
        [self loadWindow];
    }
    
    // Create attributes dictionary with Font and Color
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:14.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor controlTextColor]
    };
    
    NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:logLine attributes:attrs];

    // Append to the text storage
    [[self.textView textStorage] appendAttributedString:attrStr];
    
    // Scroll to the bottom so the newest entry is visible
    [self.textView scrollRangeToVisible:NSMakeRange([[self.textView string] length], 0)];
}

- (IBAction)clearLog:(id)sender {
    [self.textView setString:@""];
}

@end
