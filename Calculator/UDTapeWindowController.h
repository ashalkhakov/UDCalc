//
//  UDTapeWindowController.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import <AppKit/AppKit.h>

@interface UDTapeWindowController : NSWindowController <NSWindowDelegate>

// Public method to append a line to the text view
- (void)appendLog:(NSString *)logLine;

// Method to clear the view (optional but good for UX)
- (IBAction)clearLog:(id)sender;

@end
