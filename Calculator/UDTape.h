//
//  UDTape.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDTapeWindowController.h"
#import "UDAST.h" // Needs to know about Nodes to print them

@interface UDTape : NSObject

@property (nonatomic, strong) UDTapeWindowController *windowController;

// The main action: Takes a completed tree and the result value
- (void)logTransaction:(UDASTNode *)rootNode result:(double)val;

@end
