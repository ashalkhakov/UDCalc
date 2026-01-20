//
//  UDOpRegistry.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import "UDOpRegistry.h"
#import "UDCalc.h" // Needs your UDOp Enum definition

@implementation UDOpInfo
+ (instancetype)infoWithSymbol:(NSString *)sym tag:(NSInteger)tag placement:(UDOpPlacement)place assoc:(UDOpAssociativity)assoc precedence:(NSInteger)precedence {
    UDOpInfo *i = [[UDOpInfo alloc] init];
    i->_symbol = sym;
    i->_tag = tag;
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
        @(UDOpAdd) : [UDOpInfo infoWithSymbol:@"+" tag:UDOpAdd placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:1],
        @(UDOpSub) : [UDOpInfo infoWithSymbol:@"-" tag:UDOpSub placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:1],
        
        @(UDOpMul) : [UDOpInfo infoWithSymbol:@"×" tag:UDOpMul placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:2],
        @(UDOpDiv) : [UDOpInfo infoWithSymbol:@"÷" tag:UDOpDiv placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:2],
        
        // Unary/Postfix usually bind tightest
        @(UDOpPercent) : [UDOpInfo infoWithSymbol:@"%" tag:UDOpPercent placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpNegate) : [UDOpInfo infoWithSymbol:@"-" tag:UDOpNegate placement:UDOpPlacementPrefix assoc:UDOpAssocRight precedence:4],
        
        @(UDOpEq) : [UDOpInfo infoWithSymbol:@"=" tag:UDOpEq placement:UDOpPlacementInfix assoc:UDOpAssocNone precedence:0],
        
        // --- BINARY SCIENTIFIC (Infix) ---
        // Powers bind tighter than multiply (Precedence 3)
        @(UDOpPow) : [UDOpInfo infoWithSymbol:@"^" tag:UDOpPow placement:UDOpPlacementInfix assoc:UDOpAssocRight precedence:3],

        // --- UNARY SCIENTIFIC (Postfix) ---
        // These execute immediately on the current number.
        // Precedence 4 (Highest)

        // Trigonometry
        @(UDOpSin) : [UDOpInfo infoWithSymbol:@"sin" tag:UDOpSin placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpCos) : [UDOpInfo infoWithSymbol:@"cos" tag:UDOpCos placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpTan) : [UDOpInfo infoWithSymbol:@"tan" tag:UDOpTan placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpSinh) : [UDOpInfo infoWithSymbol:@"sinh" tag:UDOpSinh placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpCosh) : [UDOpInfo infoWithSymbol:@"cosh" tag:UDOpCosh placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpTanh) : [UDOpInfo infoWithSymbol:@"tanh" tag:UDOpTanh placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],

        // Roots & Logs
        @(UDOpSqrt) : [UDOpInfo infoWithSymbol:@"√" tag:UDOpSqrt placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpCbrt) : [UDOpInfo infoWithSymbol:@"∛" tag:UDOpCbrt placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpLog10) : [UDOpInfo infoWithSymbol:@"log" tag:UDOpLog10 placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpLn) : [UDOpInfo infoWithSymbol:@"ln" tag:UDOpLn placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
            
        // Powers (Unary Shortcuts)
        @(UDOpSquare) : [UDOpInfo infoWithSymbol:@"²" tag:UDOpSquare placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpCube) : [UDOpInfo infoWithSymbol:@"³" tag:UDOpCube placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpPow2) : [UDOpInfo infoWithSymbol:@"2ˣ"
                                           tag:UDOpPow2
                                     placement:UDOpPlacementPostfix
                                         assoc:UDOpAssocNone
                                    precedence:4],
        @(UDOpPow10) : [UDOpInfo infoWithSymbol:@"10ˣ"
                                            tag:UDOpPow10
                                      placement:UDOpPlacementPostfix
                                          assoc:UDOpAssocNone
                                     precedence:4],

        // Misc
        @(UDOpInvert) : [UDOpInfo infoWithSymbol:@"⁻¹" tag:UDOpInvert placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        @(UDOpFactorial) : [UDOpInfo infoWithSymbol:@"!" tag:UDOpFactorial placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4],
        
        // --- BINARY SCIENTIFIC (Infix) ---
        // Precedence 3 (Higher than * /)
        @(UDOpYRoot) : [UDOpInfo infoWithSymbol:@"yroot" tag:UDOpYRoot placement:UDOpPlacementInfix assoc:UDOpAssocRight precedence:3],

        // --- PARENTHESES ---
        // Special handling required in logic, but we register them here.
        @(UDOpParenLeft) : [UDOpInfo infoWithSymbol:@"(" tag:UDOpParenLeft placement:UDOpPlacementPrefix assoc:UDOpAssocNone precedence:0],
        @(UDOpParenRight) : [UDOpInfo infoWithSymbol:@")" tag:UDOpParenRight placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:0]
    };
}

- (UDOpInfo *)infoForOp:(NSInteger)op {
    return self.table[@(op)];
}

@end
