//
//  UDTapeWindowController.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import "UDTapeWindowController.h"

@interface UDTapeWindowController ()

// Connect this outlet to the NSTextView in Interface Builder
@property (unsafe_unretained) IBOutlet NSTextView *textView;

@end

@implementation UDTapeWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Set a nice monospaced font so numbers align perfectly
    //[self.textView setFont:[NSFont monospacedDigitSystemFontOfSize:14.0 weight:NSFontWeightRegular]];
}

- (void)appendLog:(NSString *)logLine {
    // Ensure window is loaded before trying to write
    if (!self.isWindowLoaded) {
        [self loadWindow];
    }
    
    // Create attributes dictionary with Font and Color
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:14.0 weight:NSFontWeightRegular],
        NSForegroundColorAttributeName: [NSColor labelColor] // <--- Forces adaptive color
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
