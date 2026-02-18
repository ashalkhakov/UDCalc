//
//  UDAST.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDValue.h"

@class UDOpInfo;

// --- BASE NODE ---
@interface UDASTNode : NSObject
// Returns the precedence of this node.
// For operators, this delegates to the UDOpInfo.
// For values (numbers/parens), this returns a "Max" value.
- (NSInteger)precedence;
- (NSString *)prettyPrint;
@end

// --- NUMBER NODE (e.g., 5, 3.14) ---
@interface UDNumberNode : UDASTNode
@property (nonatomic, readonly) UDValue value;
+ (instancetype)value:(UDValue)v;
@end

// --- CONSTANT NODE (e.g. pi) ---
@interface UDConstantNode : UDASTNode
@property (nonatomic, copy, readonly) NSString *symbol;
@property (nonatomic, readonly) UDValue value;
+ (instancetype)value:(UDValue)v symbol:(NSString *)sym;
@end

// --- UNARY PREFIX NODE (e.g. -5) ---
@interface UDUnaryOpNode : UDASTNode
// REFACTORED: Reference the metadata directly
@property (nonatomic, strong, readonly) UDOpInfo *info;
@property (nonatomic, strong, readonly) UDASTNode *child;

+ (instancetype)info:(UDOpInfo *)info child:(UDASTNode *)c;
@end

// --- UNARY POSTFIX NODE (e.g. 5!) ---
@interface UDPostfixOpNode : UDASTNode
// REFACTORED: Reference the metadata directly
@property (nonatomic, strong, readonly) UDOpInfo *info;
@property (nonatomic, strong, readonly) UDASTNode *child;

+ (instancetype)info:(UDOpInfo *)info child:(UDASTNode *)c;
@end

// --- BINARY OPERATOR NODE (e.g., 5 + 3) ---
@interface UDBinaryOpNode : UDASTNode
// REFACTORED: Reference the metadata directly
@property (nonatomic, strong, readonly) UDOpInfo *info;
@property (nonatomic, strong, readonly) UDASTNode *left;
@property (nonatomic, strong, readonly) UDASTNode *right;

+ (instancetype)info:(UDOpInfo *)info left:(UDASTNode *)l right:(UDASTNode *)r;
@end

// --- FUNCTION CALL NODE (e.g., sin(30)) ---
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
