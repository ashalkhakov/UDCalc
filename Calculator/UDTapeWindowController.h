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

// Set once the app has decided to quit: a window closed after that is being
// closed by the quit, not by the user, and the tape's setting is kept.
@property (nonatomic, assign) BOOL isAppTerminating;

@end
