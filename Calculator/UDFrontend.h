//
//  UDOpRegistry.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import <Foundation/Foundation.h>
#import "UDFrontendContext.h"

@class UDASTNode, UDFrontendContext;

// Types of operators
typedef NS_ENUM(NSInteger, UDOpPlacement) {
    UDOpPlacementInfix,   // a + b
    UDOpPlacementPrefix,  // -a
    UDOpPlacementPostfix  // a%
};

typedef NS_ENUM(NSInteger, UDOpAssociativity) {
    UDOpAssocLeft,
    UDOpAssocRight,
    UDOpAssocNone
};

// Definition of a block that knows how to build an AST Node
// It takes the stack of existing nodes and returns the new composite node.
typedef UDASTNode* (^UDFrontendAction)(UDFrontendContext *ctx);

// Metadata container
@interface UDOpInfo : NSObject
@property (nonatomic, copy, readonly) NSString *symbol;
@property (nonatomic, assign, readonly) NSInteger tag;
@property (nonatomic, assign, readonly) UDOpPlacement placement;
@property (nonatomic, assign, readonly) UDOpAssociativity associativity;
@property (nonatomic, assign, readonly) NSInteger precedence;
@property (nonatomic, copy, readonly) UDFrontendAction action;

+ (instancetype)infoWithSymbol:(NSString *)sym
                           tag:(NSInteger)tag
                     placement:(UDOpPlacement)place
                         assoc:(UDOpAssociativity)assoc
                    precedence:(NSInteger)precedence
                        action:(UDFrontendAction)action;
+ (instancetype) infoWithSymbol:(NSString *)sym
                            tag:(NSInteger)ag
                         action:(UDFrontendAction)action;
@end

@interface UDFrontend : NSObject

+ (instancetype)shared;

// The main lookup method
- (UDOpInfo *)infoForOp:(NSInteger)op;

@end
