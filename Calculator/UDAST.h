//
//  UDAST.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import <Foundation/Foundation.h>

// Precedence levels for Pretty Printing
// Higher number = Binds tighter
typedef NS_ENUM(NSInteger, UDASTPrecedence) {
    UDASTPrecedenceNone   = 0,
    UDASTPrecedenceAdd    = 1, // + -
    UDASTPrecedenceMul    = 2, // * /
    UDASTPrecedencePower  = 3, // ^
    UDASTPrecedenceFunc   = 4, // sin, cos
    UDASTPrecedenceValue  = 5  // Numbers, Constants
};

// --- BASE NODE ---
@interface UDASTNode : NSObject
@property (nonatomic, readonly) UDASTPrecedence precedence;
- (NSString *)prettyPrint;
@end

// --- NUMBER NODE (e.g., 5, 3.14) ---
@interface UDNumberNode : UDASTNode
@property (nonatomic, readonly) double value;
+ (instancetype)value:(double)v;
@end

// --- BINARY OPERATOR NODE (e.g., 5 + 3) ---
@interface UDBinaryOpNode : UDASTNode
@property (nonatomic, readonly) NSString *op;
@property (nonatomic, strong, readonly) UDASTNode *left;
@property (nonatomic, strong, readonly) UDASTNode *right;

+ (instancetype)op:(NSString *)op left:(UDASTNode *)l right:(UDASTNode *)r precedence:(UDASTPrecedence)p;
@end

// --- FUNCTION CALL NODE (e.g., sin(30), pow(2, 3)) ---
@interface UDFunctionNode : UDASTNode
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSArray<UDASTNode *> *args;

+ (instancetype)func:(NSString *)name args:(NSArray<UDASTNode *> *)args;
@end

// --- EXPLICIT PARENTHESIS NODE ---
@interface UDParenNode : UDASTNode
@property (nonatomic, strong, readonly) UDASTNode *child;
+ (instancetype)wrap:(UDASTNode *)node;
@end
