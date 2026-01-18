//
//  UDOpRegistry.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import "UDOpRegistry.h"
#import "UDCalc.h" // Needs your UDOp Enum definition

@implementation UDOpInfo
+ (instancetype)infoWithSymbol:(NSString *)sym placement:(UDOpPlacement)place assoc:(UDOpAssociativity)assoc precedence:(NSInteger)precedence {
    UDOpInfo *i = [[UDOpInfo alloc] init];
    i->_symbol = sym;
    i->_placement = place;
    i->_associativity = assoc;
    i->_precedence = precedence;
    return i;
}
@end

@interface UDOpRegistry ()
@property (strong) NSDictionary<NSNumber *, UDOpInfo *> *table;
@end

@implementation UDOpRegistry

+ (instancetype)shared {
    static UDOpRegistry *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[UDOpRegistry alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) [self buildTable];
    return self;
}

- (void)buildTable {
    // PRECEDENCE LEVELS:
    // 1: + -
    // 2: * /
    // 3: Exponents (Future)
    // 4: Unary (Negate, %)
    
    self.table = @{
        @(UDOpAdd) : [UDOpInfo infoWithSymbol:@"+" placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:1],
        @(UDOpSub) : [UDOpInfo infoWithSymbol:@"-" placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:1],
        
        @(UDOpMul) : [UDOpInfo infoWithSymbol:@"×" placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:2],
        @(UDOpDiv) : [UDOpInfo infoWithSymbol:@"÷" placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:2],
        
        // Unary/Postfix usually bind tightest
        @(UDOpPercent) : [UDOpInfo infoWithSymbol:@"%" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpNegate) : [UDOpInfo infoWithSymbol:@"-" placement:UDOpPlacementPrefix assoc:UDOpAssocRight precedence:4],
        
        @(UDOpEq) : [UDOpInfo infoWithSymbol:@"=" placement:UDOpPlacementInfix assoc:UDOpAssocNone precedence:0],
        
        // --- BINARY SCIENTIFIC (Infix) ---
        // Powers bind tighter than multiply (Precedence 3)
        @(UDOpPow) : [UDOpInfo infoWithSymbol:@"^" placement:UDOpPlacementInfix assoc:UDOpAssocRight precedence:3],

        // --- UNARY SCIENTIFIC (Postfix) ---
        // These execute immediately on the current number.
        // Precedence 4 (Highest)
            
        // Trigonometry
        @(UDOpSin) : [UDOpInfo infoWithSymbol:@"sin" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpCos) : [UDOpInfo infoWithSymbol:@"cos" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpTan) : [UDOpInfo infoWithSymbol:@"tan" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
            
        @(UDOpASin) : [UDOpInfo infoWithSymbol:@"asin" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpACos) : [UDOpInfo infoWithSymbol:@"acos" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpATan) : [UDOpInfo infoWithSymbol:@"atan" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],

        // Roots & Logs
        @(UDOpSqrt) : [UDOpInfo infoWithSymbol:@"√" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpCbrt) : [UDOpInfo infoWithSymbol:@"∛" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpLog10) : [UDOpInfo infoWithSymbol:@"log" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpLn) : [UDOpInfo infoWithSymbol:@"ln" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
            
        // Powers (Unary Shortcuts)
        @(UDOpSquare) : [UDOpInfo infoWithSymbol:@"²" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpCube) : [UDOpInfo infoWithSymbol:@"³" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        
        // Misc
        @(UDOpInvert) : [UDOpInfo infoWithSymbol:@"⁻¹" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpFactorial) : [UDOpInfo infoWithSymbol:@"!" placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
    };
}

- (UDOpInfo *)infoForOp:(NSInteger)op {
    return self.table[@(op)];
}

@end
