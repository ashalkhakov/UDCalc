//
//  UDTape.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import "UDTape.h"
#import "UDCalc.h" // Needed for UDOpEq constant

@interface UDTape ()
// The list of immutable tokens (committed history)
@property (strong, nonatomic) NSMutableArray<UDTapeToken *> *history;

// The mutable "Draft" state (current user input)
@property (assign, nonatomic) double draftValue;
@property (assign, nonatomic) UDTapePostfix draftPostfix;
@property (assign, nonatomic) BOOL hasDraft; // Tracks if the draft is active/valid

// Tracks if we just finished an equation
@property (assign) BOOL calculationCompleted;
@end

@implementation UDTape

- (instancetype)init {
    self = [super init];
    if (self) {
        _history = [NSMutableArray array];
        [self resetDraft];
    }
    return self;
}

- (void)resetDraft {
    _draftValue = 0.0;
    _draftPostfix = UDTapePostfixNone;
    _hasDraft = NO;
}

#pragma mark - Draft Actions

- (void)updateDraftValue:(double)value {
    // STARTING NEW NUMBER
    // If we just finished a calculation (e.g., 5+3=8), typing a new number (e.g. 9)
    // should wipe the history (Start Fresh).
    if (self.calculationCompleted) {
        [self.history removeAllObjects];
        self.calculationCompleted = NO;
    }

    self.draftValue = value;
    self.hasDraft = YES;
    // Note: We keep the existing postfix (if any) intact unless explicitly cleared,
    // though usually typing a new digit implies a fresh start in the Controller.
}

- (void)setDraftPostfix:(UDTapePostfix)postfix {
    self.draftPostfix = postfix;
    self.hasDraft = YES;
}

#pragma mark - Commit Actions

- (void)commitOperator:(NSInteger)op {
    // CHAINING
    // If we just finished a calc (5+3=8) and user hits '+',
    // we set calculationCompleted = NO, keeping the old history (5+3).
    // This allows the tape to show "5 + 3 + ..."
    if (self.calculationCompleted) {
        self.calculationCompleted = NO;
    }

    // 1. Commit the Draft (if valid)
    if (self.hasDraft) {
        [self.history addObject:[UDTapeToken tokenWithValue:self.draftValue
                                                    postfix:self.draftPostfix]];
        [self resetDraft];
    }
    
    // 2. Add the Operator
    // Logic: If the last item in history is ALSO an operator, replace it.
    // (User typed 5 +, changed mind to 5 -)
    if (self.history.count > 0 &&
        [self.history.lastObject type] == UDTokenTypeOperator) {
        [self.history removeLastObject];
    }
    
    [self.history addObject:[UDTapeToken tokenWithOperator:op]];
}

- (void)commitResult:(double)result {
    // 1. Commit final draft to the persistent history
    if (self.hasDraft) {
        [self.history addObject:[UDTapeToken tokenWithValue:self.draftValue
                                                    postfix:self.draftPostfix]];
        [self resetDraft];
    }
    
    // 2. PREPARE PRINT TOKENS (Snapshot)
    // We want to print [History] + [=] + [Result]
    // But we do NOT want to add [=] and [Result] to the persistent history,
    // because if the user continues typing, we only want [History].
    
    NSMutableArray *printTokens = [self.history mutableCopy];
    [printTokens addObject:[UDTapeToken tokenWithOperator:UDOpEq]];
    [printTokens addObject:[UDTapeToken tokenWithValue:result postfix:UDTapePostfixNone]];
    
    // 3. GENERATE STRING
    NSMutableString *line = [NSMutableString string];
    
    for (UDTapeToken *t in printTokens) {
        
        // FORMATTING: Newline before '='
        if (t.type == UDTokenTypeOperator && t.opValue == UDOpEq) {
            [line appendString:@"\n"];
        }
        
        [line appendString:[t stringValue]];
        
        // Add space (unless it's the very end, though extra space is invisible)
        [line appendString:@" "];
    }
    
    [line appendString:@"\n"]; // Final break
    
    // 4. Notify UI
    if (self.didCommitEquation) {
        self.didCommitEquation(line);
    }
    
    // 5. DO NOT CLEAR HISTORY
    // We mark this flag so that if the user types a NUMBER next, we clear.
    // If they type an OPERATOR, we continue.
    self.calculationCompleted = YES;
}

- (void)clear {
    [self.history removeAllObjects];
    [self resetDraft];
    self.calculationCompleted = NO;
    if (self.didCommitEquation) {
        self.didCommitEquation(@"--- CLEAR ---\n");
    }
}

- (BOOL)isEmpty {
    return (self.history.count == 0 && !self.hasDraft);
}

@end
