//
//  UDTape.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import "UDTape.h"

@implementation UDTape

- (void)logTransaction:(UDASTNode *)rootNode result:(double)val {
    if (!self.windowController) return;
    
    // 1. Get the Math String (e.g., "(5 + 3) * 2")
    // We use the prettyPrint method we built in UDAST
    NSString *equation = [rootNode prettyPrint];

    // 2. Format the full line (Equation + Result)
    // Standard Format:
    // (5 + 3) * 2
    // = 16
    NSString *logEntry = [NSString stringWithFormat:@"%@\n= %.8g\n\n", equation, val];
    
    // 3. Send to UI
    [self.windowController appendLog:logEntry];
}

@end
