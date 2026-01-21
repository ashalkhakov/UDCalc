//
//  UDAST.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDAST.h"

@implementation UDASTNode
- (UDASTPrecedence)precedence { return UDASTPrecedenceNone; }
- (NSString *)prettyPrint { return @"?"; }
@end

// ---------------------------------------------------------
#pragma mark - Number Node
// ---------------------------------------------------------
@implementation UDNumberNode
+ (instancetype)value:(double)v {
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
    return [NSString stringWithFormat:@"%.8g", self.value];
}
@end

// ---------------------------------------------------------
#pragma mark - Constant Node
// ---------------------------------------------------------
@implementation UDConstantNode
+ (instancetype)value:(double)v symbol:(NSString *)sym {
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

@end

