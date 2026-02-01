//
//  UDAST.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDAST.h"
#import "UDValueFormatter.h"

@implementation UDASTNode
- (UDASTPrecedence)precedence { return UDASTPrecedenceNone; }
- (NSString *)prettyPrint { return @"?"; }

// Base equality implementation (fails safe)
- (BOOL)isEqual:(id)object {
    return [object isKindOfClass:[self class]];
}

- (NSUInteger)hash {
    return [self.prettyPrint hash];
}

- (id)copyWithZone:(NSZone *)zone {
    // Base implementation or Abstract
    return self;
}

@end

// ---------------------------------------------------------
#pragma mark - Number Node
// ---------------------------------------------------------
@implementation UDNumberNode
+ (instancetype)value:(UDValue)v {
    UDNumberNode *n = [UDNumberNode new];
    n->_value = v;
    return n;
}

- (UDASTPrecedence)precedence {
    return UDASTPrecedenceValue;
}

- (NSString *)prettyPrint {
    // Format nicely: Remove trailing zeros (e.g. 5.0 -> 5)
    // %.8g uses significant digits, usually cleanest for calcs
    return [UDValueFormatter stringForValue:self.value base:UDBaseDec];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[UDNumberNode class]]) return NO;
    UDNumberNode *other = (UDNumberNode *)object;
    if (other.value.type != self.value.type) return NO;
    switch (self.value.type) {
        case UDValueTypeErr:
            return other.value.v.intValue == self.value.v.intValue;
        case UDValueTypeDouble:
            // Use a small epsilon for double comparison to avoid floating point issues
            return fabs(UDValueAsDouble(self.value) - UDValueAsDouble(other.value)) < 0.0000001;
        case UDValueTypeInteger:
            return UDValueAsInt(self.value) == UDValueAsInt(other.value);
        default:
            NSLog(@"isEqual: unhandled value type %ld", self.value.type);
            return NO;
    }
}

- (NSUInteger)hash {
    switch (self.value.type) {
        case UDValueTypeDouble:
            return [[NSNumber numberWithDouble:UDValueAsDouble(self.value)] hash];
        case UDValueTypeErr:
        case UDValueTypeInteger:
            return [[NSNumber numberWithLongLong:UDValueAsInt(self.value)] hash];
        default:
            NSLog(@"hash: unhandled value type %ld", self.value.type);
            return 0;
    }
}

- (id)copyWithZone:(NSZone *)zone {
    UDNumberNode *copy = [UDNumberNode value:self.value];
    return copy;
}

@end

// ---------------------------------------------------------
#pragma mark - Constant Node
// ---------------------------------------------------------
@implementation UDConstantNode
+ (instancetype)value:(UDValue)v symbol:(NSString *)sym {
    UDConstantNode *n = [UDConstantNode new];
    n->_symbol = sym;
    n->_value = v;
    return n;
}

- (UDASTPrecedence)precedence {
    return UDASTPrecedenceValue;
}

- (NSString *)prettyPrint {
    return self.symbol;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[UDConstantNode class]]) return NO;
    UDConstantNode *other = (UDConstantNode *)object;
    return [self.symbol isEqualToString:other.symbol]; // Value is implied by symbol
}

- (NSUInteger)hash {
    return [self.symbol hash];
}

-(id)copyWithZone:(NSZone *)zone {
    UDConstantNode *copy = [UDConstantNode value:self.value symbol:self.symbol];
    return copy;
}

@end

// ---------------------------------------------------------
#pragma mark - Unary Operation Node
// ---------------------------------------------------------

@implementation UDUnaryOpNode
+ (instancetype)op:(NSString *)op child:(UDASTNode *)c {
    UDUnaryOpNode *n = [UDUnaryOpNode new]; n->_op = op; n->_child = c; return n;
}
- (NSString *)prettyPrint {
    // Logic: If child is a complex operation (5+3), wrap in parens: -(5+3)
    NSString *cStr = [self.child prettyPrint];
    if (self.child.precedence < self.precedence) cStr = [NSString stringWithFormat:@"(%@)", cStr];
    return [NSString stringWithFormat:@"%@%@", self.op, cStr];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[UDUnaryOpNode class]]) return NO;
    UDUnaryOpNode *other = (UDUnaryOpNode *)object;
    return [self.op isEqualToString:other.op] && [self.child isEqual:other.child];
}

- (NSUInteger)hash {
    return [self.op hash] ^ [self.child hash];
}

- (id)copyWithZone:(NSZone *)zone {
    UDUnaryOpNode *copy = [UDUnaryOpNode op:self.op child:[self.child copy]];
    return copy;
}

@end

@implementation UDPostfixOpNode
+ (instancetype)symbol:(NSString *)sym child:(UDASTNode *)c {
    UDPostfixOpNode *n = [UDPostfixOpNode new]; n->_symbol = sym; n->_child = c; return n;
}
- (NSString *)prettyPrint {
    // Logic: (5+3)!
    NSString *cStr = [self.child prettyPrint];
    if (self.child.precedence < self.precedence) cStr = [NSString stringWithFormat:@"(%@)", cStr];
    return [NSString stringWithFormat:@"%@%@", cStr, self.symbol];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[UDPostfixOpNode class]]) return NO;
    UDPostfixOpNode *other = (UDPostfixOpNode *)object;
    return [self.symbol isEqualToString:other.symbol] && [self.child isEqual:other.child];
}

- (NSUInteger)hash {
    return [self.symbol hash] ^ [self.child hash];
}

- (id)copyWithZone:(NSZone *)zone {
    UDPostfixOpNode *copy = [UDPostfixOpNode symbol:self.symbol child:[self.child copy]];
    return copy;
}

@end

// ---------------------------------------------------------
#pragma mark - Binary Operation Node
// ---------------------------------------------------------
@implementation UDBinaryOpNode {
    UDASTPrecedence _prec;
}

+ (instancetype)op:(NSString *)op left:(UDASTNode *)l right:(UDASTNode *)r precedence:(UDASTPrecedence)p {
    UDBinaryOpNode *n = [UDBinaryOpNode new];
    n->_op = op;
    n->_left = l;
    n->_right = r;
    n->_prec = p;
    return n;
}

- (UDASTPrecedence)precedence {
    return _prec;
}

- (NSString *)prettyPrint {
    NSString *lhs = [self.left prettyPrint];
    NSString *rhs = [self.right prettyPrint];
    
    // AUTOMATIC PARENTHESES LOGIC:
    // If the child's precedence is LOWER than ours, it needs wrapping.
    // Example: (5 + 3) * 2
    // Parent (*) has prec 2. Child (+) has prec 1.
    // 1 < 2, so we add parens around "5 + 3".
    
    if (self.left.precedence < self.precedence) {
        lhs = [NSString stringWithFormat:@"(%@)", lhs];
    }
    
    // Special handling for Right Associativity (like ^) or subtraction
    // usually requires stricter checks, but < works for standard PEMDAS.
    if (self.right.precedence < self.precedence) {
        rhs = [NSString stringWithFormat:@"(%@)", rhs];
    }
    
    return [NSString stringWithFormat:@"%@ %@ %@", lhs, self.op, rhs];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[UDBinaryOpNode class]]) return NO;
    UDBinaryOpNode *other = (UDBinaryOpNode *)object;
    return [self.op isEqualToString:other.op] &&
        [self.left isEqual:other.left] &&
        [self.right isEqual:other.right];
}

- (NSUInteger)hash {
    return [self.op hash] ^ [self.left hash] ^ [self.right hash];
}

- (id)copyWithZone:(NSZone *)zone {
    UDBinaryOpNode *copy = [UDBinaryOpNode op:self.op
                                         left:[self.left copy]
                                        right:[self.right copy]
                                   precedence:self.precedence];
    return copy;
}

@end

// ---------------------------------------------------------
#pragma mark - Function Node
// ---------------------------------------------------------
@implementation UDFunctionNode

+ (instancetype)func:(NSString *)name args:(NSArray<UDASTNode *> *)args {
    UDFunctionNode *n = [UDFunctionNode new];
    n->_name = name;
    n->_args = args;
    return n;
}

- (UDASTPrecedence)precedence {
    // Functions act like values/parentheses (they bind extremely tight)
    return UDASTPrecedenceFunc;
}

- (NSString *)prettyPrint {
    NSMutableArray *argStrings = [NSMutableArray array];
    for (UDASTNode *arg in self.args) {
        [argStrings addObject:[arg prettyPrint]];
    }
    
    // Format: name(arg1, arg2)
    return [NSString stringWithFormat:@"%@(%@)", self.name, [argStrings componentsJoinedByString:@", "]];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[UDFunctionNode class]]) return NO;
    UDFunctionNode *other = (UDFunctionNode *)object;
    return [self.name isEqualToString:other.name] && [self.args isEqualToArray:other.args];
}

- (NSUInteger)hash {
    return [self.name hash] ^ [self.args hash];
}

- (id)copyWithZone:(NSZone *)zone {
    NSArray *deepCopiedArgs = [[NSArray alloc] initWithArray:self.args copyItems:YES];
    UDFunctionNode *copy = [UDFunctionNode func:self.name
                                           args:deepCopiedArgs];
    return copy;
}

@end

// ---------------------------------------------------------
#pragma mark - Parenthesis Node
// ---------------------------------------------------------
@implementation UDParenNode

+ (instancetype)wrap:(UDASTNode *)node {
    UDParenNode *n = [UDParenNode new];
    n->_child = node;
    return n;
}

- (UDASTPrecedence)precedence {
    // Acts like a solid value (highest precedence)
    // This prevents outer operators from adding *extra* auto-parentheses.
    return UDASTPrecedenceValue;
}

- (NSString *)prettyPrint {
    // Force the brackets!
    return [NSString stringWithFormat:@"(%@)", [self.child prettyPrint]];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[UDParenNode class]]) return NO;
    UDParenNode *other = (UDParenNode *)object;
    return [self.child isEqual:other.child];
}

- (NSUInteger)hash {
    return [self.child hash];
}

@end

