//
//  UDAST.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDAST.h"
#import "UDFrontend.h" // Import your operator info definition here
#import "UDValueFormatter.h" // Assuming you have this for formatting values

// Define a precedence higher than any operator for atomic values (Numbers, Parens)
static const NSInteger kUDPrecedenceAtomic = 1000;

@implementation UDASTNode
- (NSInteger)precedence { return 0; }
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
- (NSInteger)precedence { return kUDPrecedenceAtomic; }
- (NSString *)prettyPrint {
    return [UDValueFormatter stringForValue:self.value base:UDBaseDec showThousandsSeparators:NO decimalPlaces:10];
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
    n->_value = v;
    n->_symbol = sym;
    return n;
}
- (NSInteger)precedence { return kUDPrecedenceAtomic; }
- (NSString *)prettyPrint { return self.symbol; }

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
#pragma mark - Unary Prefix Node
// ---------------------------------------------------------
@implementation UDUnaryOpNode
+ (instancetype)info:(UDOpInfo *)info child:(UDASTNode *)c {
    UDUnaryOpNode *n = [UDUnaryOpNode new];
    n->_info = info;
    n->_child = c;
    return n;
}

- (NSInteger)precedence { return self.info.precedence; }

- (NSString *)prettyPrint {
    NSString *cStr = [self.child prettyPrint];
    
    // If child is weaker than us, wrap it.
    // Example: - (5 + 3) vs -5
    if (self.child.precedence < self.precedence) {
        cStr = [NSString stringWithFormat:@"(%@)", cStr];
    }
    return [NSString stringWithFormat:@"%@%@", self.info.symbol, cStr];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[UDUnaryOpNode class]]) return NO;
    UDUnaryOpNode *other = (UDUnaryOpNode *)object;
    return (self.info.tag == other.info.tag) && [self.child isEqual:other.child];
}

- (NSUInteger)hash {
    return self.info.tag ^ [self.child hash];
}

- (id)copyWithZone:(NSZone *)zone {
    UDUnaryOpNode *copy = [UDUnaryOpNode info:self.info child:[self.child copy]];
    return copy;
}

@end

// ---------------------------------------------------------
#pragma mark - Postfix Node
// ---------------------------------------------------------
@implementation UDPostfixOpNode
+ (instancetype)info:(UDOpInfo *)info child:(UDASTNode *)c {
    UDPostfixOpNode *n = [UDPostfixOpNode new];
    n->_info = info;
    n->_child = c;
    return n;
}

- (NSInteger)precedence { return self.info.precedence; }

- (NSString *)prettyPrint {
    NSString *cStr = [self.child prettyPrint];
    
    // If child is weaker, wrap it.
    // Example: (5 + 3)! vs 5!
    if (self.child.precedence < self.precedence) {
        cStr = [NSString stringWithFormat:@"(%@)", cStr];
    }
    return [NSString stringWithFormat:@"%@%@", cStr, self.info.symbol];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[UDPostfixOpNode class]]) return NO;
    UDPostfixOpNode *other = (UDPostfixOpNode *)object;
    return (self.info.tag == other.info.tag) && [self.child isEqual:other.child];
}

- (NSUInteger)hash {
    return self.info.tag ^ [self.child hash];
}

- (id)copyWithZone:(NSZone *)zone {
    UDPostfixOpNode *copy = [UDPostfixOpNode info:self.info child:[self.child copy]];
    return copy;
}

@end

// ---------------------------------------------------------
#pragma mark - Binary Op Node (The Logic Core)
// ---------------------------------------------------------
@implementation UDBinaryOpNode
+ (instancetype)info:(UDOpInfo *)info left:(UDASTNode *)l right:(UDASTNode *)r {
    UDBinaryOpNode *n = [UDBinaryOpNode new];
    n->_info = info;
    n->_left = l;
    n->_right = r;
    return n;
}

- (NSInteger)precedence { return self.info.precedence; }

- (NSString *)prettyPrint {
    NSString *lhs = [self.left prettyPrint];
    NSString *rhs = [self.right prettyPrint];
    
    NSInteger myPrec = self.precedence;
    
    // --- LEFT CHILD CHECK ---
    BOOL wrapLeft = NO;
    if (self.left.precedence < myPrec) {
        // Normal precedence rule: (1+2) * 3
        wrapLeft = YES;
    } else if (self.left.precedence == myPrec && self.info.associativity == UDOpAssocRight) {
        // Right Associativity Exception: (2^3)^4
        // If we are Right Associative, the left child must be wrapped if it has the same precedence.
        wrapLeft = YES;
    }
    
    // --- RIGHT CHILD CHECK ---
    BOOL wrapRight = NO;
    if (self.right.precedence < myPrec) {
        // Normal precedence rule: 3 * (1+2)
        wrapRight = YES;
    } else if (self.right.precedence == myPrec && self.info.associativity == UDOpAssocLeft) {
        // Left Associativity Exception: 1 - (2 - 3)
        // If we are Left Associative, the right child must be wrapped if it has the same precedence.
        wrapRight = YES;
    }
    
    if (wrapLeft)  lhs = [NSString stringWithFormat:@"(%@)", lhs];
    if (wrapRight) rhs = [NSString stringWithFormat:@"(%@)", rhs];
    
    return [NSString stringWithFormat:@"%@ %@ %@", lhs, self.info.symbol, rhs];
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[UDBinaryOpNode class]]) return NO;
    UDBinaryOpNode *other = (UDBinaryOpNode *)object;
    return (self.info.tag == other.info.tag) &&
        [self.left isEqual:other.left] &&
        [self.right isEqual:other.right];
}

- (NSUInteger)hash {
    return self.info.tag ^ [self.left hash] ^ [self.right hash];
}

- (id)copyWithZone:(NSZone *)zone {
    UDBinaryOpNode *copy = [UDBinaryOpNode info:self.info
                                           left:[self.left copy]
                                          right:[self.right copy]];
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

// Functions bind extremely tight (like a value)
- (NSInteger)precedence { return kUDPrecedenceAtomic; }

- (NSString *)prettyPrint {
    NSMutableArray *parts = [NSMutableArray array];
    for (UDASTNode *arg in self.args) {
        [parts addObject:[arg prettyPrint]];
    }
    return [NSString stringWithFormat:@"%@(%@)", self.name, [parts componentsJoinedByString:@", "]];
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
#pragma mark - Explicit Parenthesis Node
// ---------------------------------------------------------
@implementation UDParenNode
+ (instancetype)wrap:(UDASTNode *)node {
    UDParenNode *n = [UDParenNode new];
    n->_child = node;
    return n;
}

// Parentheses are atomic; they protect their contents from being wrapped again.
- (NSInteger)precedence { return kUDPrecedenceAtomic; }

- (NSString *)prettyPrint {
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
