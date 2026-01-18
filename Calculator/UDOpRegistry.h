//
//  UDOpRegistry.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import <Foundation/Foundation.h>

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

// Metadata container
@interface UDOpInfo : NSObject
@property (nonatomic, copy, readonly) NSString *symbol;
@property (nonatomic, assign, readonly) UDOpPlacement placement;
@property (nonatomic, assign, readonly) UDOpAssociativity associativity;
@property (nonatomic, assign, readonly) NSInteger precedence; // Ready for future use

+ (instancetype)infoWithSymbol:(NSString *)sym placement:(UDOpPlacement)place assoc:(UDOpAssociativity)assoc precedence:(NSInteger)precedence;
@end

@interface UDOpRegistry : NSObject

+ (instancetype)shared;

// The main lookup method
- (UDOpInfo *)infoForOp:(NSInteger)op;

@end
