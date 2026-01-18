//
//  UDTape.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDCalc.h"
#import "UDTapeToken.h"

@interface UDTape : NSObject

/**
 Callback fired when a full equation is committed (e.g., after '=' is pressed).
 Returns a formatted string ending in a newline.
 */
@property (copy) void (^didCommitEquation)(NSString *equationString);

// --- DRAFTING (Mutable State) ---
// Call these methods while the user is typing a number or modifying it.

/**
 Updates the current number being typed.
 */
- (void)updateDraftValue:(double)value;

/**
 Marks the current number with a postfix symbol (e.g., user pressed '%').
 This does not commit the value yet, just changes its display format.
 */
- (void)setDraftPostfix:(UDTapePostfix)postfix;

// --- COMMIT (Finalize State) ---
// Call these methods when the user presses an operator or equals.

/**
 Commits the current draft (if any) to history, then adds the operator.
 Handles replacing the last operator if the user changes their mind.
 */
- (void)commitOperator:(NSInteger)op;

/**
 Commits the current draft, adds '=', adds the result, generates the string,
 fires the callback, and clears the tape for the next calculation.
 */
- (void)commitResult:(double)result;

/**
 Clears all history and draft state. Fires a "--- CLEAR ---" log.
 */
- (void)clear;

- (BOOL)isEmpty;

@end
