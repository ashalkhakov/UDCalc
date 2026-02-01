//
//  UDOpRegistry.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import "UDFrontend.h"
#import "UDCalc.h" // Needs your UDOp Enum definition
#import "UDAST.h"

@implementation UDOpInfo

+ (instancetype)infoWithSymbol:(NSString *)sym tag:(NSInteger)tag placement:(UDOpPlacement)place assoc:(UDOpAssociativity)assoc precedence:(NSInteger)precedence action:(UDFrontendAction)action {
    UDOpInfo *i = [[UDOpInfo alloc] init];
    i->_symbol = sym;
    i->_tag = tag;
    i->_placement = place;
    i->_associativity = assoc;
    i->_precedence = precedence;
    i->_action = action;
    return i;
}

+ (instancetype) infoWithSymbol:(NSString *)sym
                            tag:(NSInteger)tag
                         action:(UDFrontendAction)action {
    return [UDOpInfo infoWithSymbol:sym tag:tag placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:0 action:action];
}

@end

@interface UDFrontend ()
@property (strong) NSMutableDictionary<NSNumber *, UDOpInfo *> *table;
@end

@implementation UDFrontend

+ (instancetype)shared {
    static UDFrontend *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[UDFrontend alloc] init];
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
    // 3: Exponents
    // 4: Unary (Negate, %)
    
    self.table = [[NSMutableDictionary alloc] init];
    // ==========================================
    // ROW 1: ( ) mc m+ m- mr C +/- % ÷
    // ==========================================
    
    // ( ) : Handled by Parser directly (Precedence 0)
    // mc, m+, m-, C : Handled by Controller (Commands)

    // --- PARENTHESES ---
    // Special handling required in logic, but we register them here.
    self.table[@(UDOpParenLeft)] = [UDOpInfo infoWithSymbol:@"(" tag:UDOpParenLeft placement:UDOpPlacementPrefix assoc:UDOpAssocNone precedence:0 action:nil];
    self.table[@(UDOpParenRight)] = [UDOpInfo infoWithSymbol:@")" tag:UDOpParenRight placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:0 action:nil];

    // mr (Memory Recall) -> Constant Snapshot
    self.table[@(UDOpMR)] = [UDOpInfo infoWithSymbol:@"MR" tag:UDOpMR action:^UDASTNode *(UDFrontendContext *ctx) {
        return [UDConstantNode value:UDValueMakeDouble(ctx.memoryValue) symbol:@"MR"];
    }];

    // +/- (Negate) -> Unary Op
    self.table[@(UDOpNegate)] = [UDOpInfo infoWithSymbol:@"-" tag:UDOpNegate placement:UDOpPlacementPrefix assoc:UDOpAssocRight precedence:4 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *top = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        // Optimization: If top is number, just flip sign
        if ([top isKindOfClass:[UDNumberNode class]]) {
             return [UDNumberNode value:UDValueMakeDouble(-1 * UDValueAsDouble([(UDNumberNode*)top value]))];
        }
        return [UDUnaryOpNode op:@"-" child:top];
    }];

    // % (Percent) -> The Smart Context Logic
    self.table[@(UDOpPercent)] = [UDOpInfo infoWithSymbol:@"%" tag:UDOpPercent placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:5 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *current = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        
        // Context: "50 + 10%" vs "10%"
        if (ctx.pendingOp == UDOpAdd || ctx.pendingOp == UDOpSub) {
            // Percent Of: Base * (Current / 100)
            // Note: We need a way to peek the base (the number before the +).
            // In a pure stack, it's hidden.
            // Workaround: We define % in this context to return (Current/100) * BasePlaceholder
            // Ideally, your parser supports peeking. Assuming we construct: 50 * (10/100)
            UDASTNode *fraction = [UDBinaryOpNode op:@"/" left:current right:[UDNumberNode value:UDValueMakeDouble(100)] precedence:5];
            // For the sake of this AST, we treat it as a Scalar multiplication for now to keep it simple,
            // or implement a specific UDPercentOfNode if you want perfect history.
            return [UDPostfixOpNode symbol:@"%" child:current];
        }
        
        // Standard: Current / 100
        return [UDBinaryOpNode op:@"/" left:current right:[UDNumberNode value:UDValueMakeDouble(100)] precedence:5];
    }];

    // ÷ (Divide)
    self.table[@(UDOpDiv)] = [UDOpInfo infoWithSymbol:@"÷"
                                                  tag:UDOpDiv
                                            placement:UDOpPlacementInfix
                                                assoc:UDOpAssocLeft
                                           precedence:2
                                               action:[self binaryOp:@"/" prec:2]];


    // ==========================================
    // ROW 2: 2nd x² x³ x^y e^x 10^x 7 8 9 ×
    // ==========================================
    
    // 2nd: Controller Toggle (No AST)
    
    // x² -> pow(x, 2)
    self.table[@(UDOpSquare)] = [UDOpInfo infoWithSymbol:@"²"
                                                     tag:UDOpSquare
                                               placement:UDOpPlacementPostfix
                                                   assoc:UDOpAssocNone
                                              precedence:5
                                                  action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *base = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:@"pow" args:@[base, [UDNumberNode value:UDValueMakeDouble(2)]]];
    }];
    
    // x³ -> pow(x, 3)
    self.table[@(UDOpCube)] = [UDOpInfo infoWithSymbol:@"³"
                                                   tag:UDOpCube
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:5
                                                action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *base = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:@"pow" args:@[base, [UDNumberNode value:UDValueMakeDouble(3)]]];
    }];
        
    // x^y (Power)
    self.table[@(UDOpPow)] = [UDOpInfo infoWithSymbol:@"^"
                                                  tag:UDOpPow
                                            placement:UDOpPlacementInfix
                                                assoc:UDOpAssocRight
                                           precedence:3
                                               action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *exp = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *base = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:@"pow" args:@[base, exp]];
    }];
    
    self.table[@(UDOpPowRev)] = [UDOpInfo infoWithSymbol:@"y^x"
                                                     tag:UDOpPowRev
                                               placement:UDOpPlacementInfix
                                                   assoc:UDOpAssocRight
                                              precedence:3
                                                  action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *base = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *exp = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:@"pow" args:@[base, exp]];
    }];

    // e^x -> pow(e, x)
    self.table[@(UDOpExp)] = [UDOpInfo infoWithSymbol:@"eˣ"
                                                  tag:UDOpExp
                                            placement:UDOpPlacementPostfix
                                                assoc:UDOpAssocNone
                                           precedence:5
                                               action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *exp = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:@"pow" args:@[[UDConstantNode value:UDValueMakeDouble(M_E) symbol:@"e"], exp]];
    }];
        
    // 10^x -> pow(10, x)
    self.table[@(UDOpPow10)] = [UDOpInfo infoWithSymbol:@"10ˣ"
                                                    tag:UDOpPow10
                                              placement:UDOpPlacementPostfix
                                                  assoc:UDOpAssocNone
                                             precedence:5
                                                 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *exp = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:@"pow" args:@[[UDNumberNode value:UDValueMakeDouble(10)], exp]];
    }];
        
    // × (Multiply)
    self.table[@(UDOpMul)] = [UDOpInfo infoWithSymbol:@"×"
                                                  tag:UDOpMul
                                            placement:UDOpPlacementInfix
                                                assoc:UDOpAssocLeft
                                           precedence:2
                                               action:[self binaryOp:@"*" prec:2]];


    // ==========================================
    // ROW 3: 1/x ²√x ³√x y√x ln log10 4 5 6 -
    // ==========================================
    
    // 1/x -> 1 / x
    self.table[@(UDOpInvert)] = [UDOpInfo infoWithSymbol:@"⁻¹"
                                                     tag:UDOpInvert
                                               placement:UDOpPlacementPostfix
                                                   assoc:UDOpAssocNone
                                              precedence:5
                                                  action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *denom = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDBinaryOpNode op:@"/" left:[UDNumberNode value:UDValueMakeDouble(1)] right:denom precedence:5];
    }];
        
    // ²√x (Sqrt)
    self.table[@(UDOpSqrt)] = [UDOpInfo infoWithSymbol:@"√"
                                                   tag:UDOpSqrt
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:5
                                                action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:@"sqrt" args:@[arg]];
    }];
        
    // ³√x (Cbrt) -> pow(x, 1/3) OR cbrt(x)
    self.table[@(UDOpCbrt)] = [UDOpInfo infoWithSymbol:@"∛"
                                                   tag:UDOpCbrt
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:5
                                                action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        // Using pow(x, 1/3) is safer for the VM
        UDASTNode *oneThird = [UDBinaryOpNode op:@"/"
                                            left:[UDNumberNode value:UDValueMakeDouble(1)]
                                           right:[UDNumberNode value:UDValueMakeDouble(3)]
                                      precedence:5];
        return [UDFunctionNode func:@"pow" args:@[arg, oneThird]];
    }];
        
    // y√x (Y Root X) -> pow(x, 1/y)
    self.table[@(UDOpYRoot)] = [UDOpInfo infoWithSymbol:@"root"
                                                    tag:UDOpYRoot
                                              placement:UDOpPlacementInfix
                                                  assoc:UDOpAssocRight
                                             precedence:3
                                                 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *root = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject]; // y
        UDASTNode *base = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject]; // x
        
        UDASTNode *invRoot = [UDBinaryOpNode op:@"/" left:[UDNumberNode value:UDValueMakeDouble(1)] right:root precedence:5];
        return [UDFunctionNode func:@"pow" args:@[base, invRoot]];
    }];
        
    // ln
    self.table[@(UDOpLn)] = [UDOpInfo infoWithSymbol:@"ln"
                                                 tag:UDOpLn
                                           placement:UDOpPlacementPostfix
                                               assoc:UDOpAssocNone
                                          precedence:5
                                              action:[self funcOp:@"ln"]];
    
    // log10
    self.table[@(UDOpLog10)] = [UDOpInfo infoWithSymbol:@"log"
                                                    tag:UDOpLog10
                                              placement:UDOpPlacementPostfix
                                                  assoc:UDOpAssocNone
                                             precedence:5
                                                 action:[self funcOp:@"log_10"]];
    
    // log2
    self.table[@(UDOpLog2)] = [UDOpInfo infoWithSymbol:@"log"
                                                   tag:UDOpLog2
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:5
                                                action:[self funcOp:@"log_2"]];
    
    // log y(x)
    self.table[@(UDOpLogY)] = [UDOpInfo infoWithSymbol:@"log"
                                                   tag:UDOpLogY
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:5
                                                action:^UDASTNode *(UDFrontendContext *ctx) {
        // 7, logY, 5, =: log_5(7)=1.20...
        
        
        UDASTNode *y = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject]; // y
        UDASTNode *x = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject]; // x
        NSString *name = [@"log_" stringByAppendingString:[y prettyPrint]]; // TODO: evaluate?

        return [UDFunctionNode func:name args:@[x]];
    }];

    // - (Subtract)
    self.table[@(UDOpSub)] = [UDOpInfo infoWithSymbol:@"-"
                                                  tag:UDOpSub
                                            placement:UDOpPlacementInfix
                                                assoc:UDOpAssocLeft
                                           precedence:1
                                               action:[self binaryOp:@"-" prec:1]];


    // ==========================================
    // ROW 4: x! sin cos tan e EE 1 2 3 +
    // ==========================================

    // x! (Factorial) -> Postfix Node
    self.table[@(UDOpFactorial)] = [UDOpInfo infoWithSymbol:@"!"
                                                        tag:UDOpFactorial
                                                  placement:UDOpPlacementPostfix
                                                      assoc:UDOpAssocNone
                                                 precedence:5
                                                     action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        // We use PostfixOpNode because we want it to print "5!", not "fact(5)"
        return [UDPostfixOpNode symbol:@"!" child:arg];
    }];
        
    self.table[@(UDOpSin)] = [UDOpInfo infoWithSymbol:@"sin"
                                                  tag:UDOpSin
                                            placement:UDOpPlacementPostfix
                                                assoc:UDOpAssocNone
                                           precedence:4
                                               action:[self trigOp:@"sin"]];
    self.table[@(UDOpSinInverse)] = [UDOpInfo infoWithSymbol:@"asin"
                                                         tag:UDOpSinInverse
                                                   placement:UDOpPlacementPostfix
                                                       assoc:UDOpAssocNone
                                                  precedence:4
                                                      action:[self trigOp:@"asin"]];
    self.table[@(UDOpCos)] = [UDOpInfo infoWithSymbol:@"cos"
                                                  tag:UDOpCos
                                            placement:UDOpPlacementPostfix
                                                assoc:UDOpAssocNone
                                           precedence:4
                                               action:[self trigOp:@"cos"]];
    self.table[@(UDOpCosInverse)] = [UDOpInfo infoWithSymbol:@"acos"
                                                         tag:UDOpCosInverse
                                                   placement:UDOpPlacementPostfix
                                                       assoc:UDOpAssocNone
                                                  precedence:4
                                                      action:[self trigOp:@"acos"]];
    self.table[@(UDOpTan)] = [UDOpInfo infoWithSymbol:@"tan"
                                                  tag:UDOpTan
                                            placement:UDOpPlacementPostfix
                                                assoc:UDOpAssocNone
                                           precedence:4
                                               action:[self trigOp:@"tan"]];
    self.table[@(UDOpTanInverse)] = [UDOpInfo infoWithSymbol:@"atan"
                                                         tag:UDOpTanInverse
                                                   placement:UDOpPlacementPostfix
                                                       assoc:UDOpAssocNone
                                                  precedence:4
                                                      action:[self trigOp:@"atan"]];

    // e (Constant)
        
    // EE -> Controller (Input) - No AST Node needed here
    
    // + (Add)
    self.table[@(UDOpAdd)] = [UDOpInfo infoWithSymbol:@"+"
                                                  tag:UDOpAdd
                                            placement:UDOpPlacementInfix
                                                assoc:UDOpAssocLeft
                                           precedence:1
                                               action:[self binaryOp:@"+" prec:1]];


    // ==========================================
    // ROW 5: Rad sinh cosh tanh pi Rand 0 , =
    // ==========================================
    
    // Rad -> Controller Toggle

    // Hyperbolic (sinh, cosh, tanh) - Always Radians/None, ignore switch
    self.table[@(UDOpSinh)] = [UDOpInfo infoWithSymbol:@"sinh"
                                                   tag:UDOpSinh
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:4
                                                action:[self funcOp:@"sinh"]];
    self.table[@(UDOpSinhInverse)] = [UDOpInfo infoWithSymbol:@"asinh"
                                                          tag:UDOpSinh
                                                    placement:UDOpPlacementPostfix
                                                        assoc:UDOpAssocNone
                                                   precedence:4
                                                       action:[self funcOp:@"asinh"]];
    self.table[@(UDOpCosh)] = [UDOpInfo infoWithSymbol:@"cosh"
                                                   tag:UDOpCosh
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:4
                                                action:[self funcOp:@"cosh"]];
    self.table[@(UDOpCoshInverse)] = [UDOpInfo infoWithSymbol:@"acosh"
                                                          tag:UDOpCoshInverse
                                                    placement:UDOpPlacementPostfix
                                                        assoc:UDOpAssocNone
                                                   precedence:4
                                                       action:[self funcOp:@"acosh"]];
    self.table[@(UDOpTanh)] = [UDOpInfo infoWithSymbol:@"tanh"
                                                   tag:UDOpTanh
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:4
                                                action:[self funcOp:@"tanh"]];
    self.table[@(UDOpTanhInverse)] = [UDOpInfo infoWithSymbol:@"atanh"
                                                          tag:UDOpTanhInverse
                                                    placement:UDOpPlacementPostfix
                                                        assoc:UDOpAssocNone
                                                   precedence:4
                                                       action:[self funcOp:@"atanh"]];

    // pi
    
    // Rand
    self.table[@(UDOpRand)] = [UDOpInfo infoWithSymbol:@"rand"
                                                   tag:UDOpRand
                                                action:^UDASTNode *(UDFrontendContext *ctx) {
        return [UDConstantNode value:UDValueMakeDouble(((double)arc4random()/UINT32_MAX)) symbol:@"rand"];
    }];

    /*
    self.table = @{
        @(UDOpAdd) : [UDOpInfo infoWithSymbol:@"+" tag:UDOpAdd placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:1 action:^UDASTNode *(UDFrontendContext *context) {
            UDASTNode *right = [context.nodeStack lastObject]; [context.nodeStack removeLastObject];
            UDASTNode *left  = [context.nodeStack lastObject]; [context.nodeStack removeLastObject];
            return [UDBinaryOpNode op:@"+" left:left right:right precedence:1];
        }],
        @(UDOpSub) : [UDOpInfo infoWithSymbol:@"-" tag:UDOpSub placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:1 builder:^UDASTNode *(NSMutableArray *stack) {
            UDASTNode *right = [stack lastObject]; [stack removeLastObject];
            UDASTNode *left = [stack lastObject]; [stack removeLastObject];
            return [UDBinaryOpNode op:@"-" left:left right:right precedence:1];
        }],
        
        @(UDOpMul) : [UDOpInfo infoWithSymbol:@"×" tag:UDOpMul placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:2 builder:^UDASTNode *(NSMutableArray *stack) {
            UDASTNode *right = [stack lastObject]; [stack removeLastObject];
            UDASTNode *left = [stack lastObject]; [stack removeLastObject];
            return [UDBinaryOpNode op:@"*" left:left right:right precedence:2];
        }],
        @(UDOpDiv) : [UDOpInfo infoWithSymbol:@"÷" tag:UDOpDiv placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:2 builder:^UDASTNode *(NSMutableArray *stack) {
            UDASTNode *right = [stack lastObject]; [stack removeLastObject];
            UDASTNode *left = [stack lastObject]; [stack removeLastObject];
            return [UDBinaryOpNode op:@"/" left:left right:right precedence:2];
        }],
        
        // Unary/Postfix usually bind tightest
        @(UDOpPercent) : [UDOpInfo infoWithSymbol:@"%" tag:UDOpPercent placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:4 builder:^UDASTNode *(NSMutableArray *stack) {
            UDASTNode *right = [stack lastObject]; [stack removeLastObject];
            UDASTNode *left = [stack lastObject]; [stack removeLastObject];
            return [UDBinaryOpNode op:@"%" left:left right:right precedence:2];

        }],
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
    };*/
}

// Helpers to reduce boilerplate
- (UDFrontendAction)binaryOp:(NSString *)sym prec:(NSInteger)prec {
    return ^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *r = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *l = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDBinaryOpNode op:sym left:l right:r precedence:prec];
    };
}

- (UDFrontendAction)funcOp:(NSString *)name {
    return ^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:name args:@[arg]];
    };
}

// Trig (sin, cos, tan) - NEEDS RAD/DEG STATE
// We assume UDFunctionNode has a generic 'meta' dictionary or we make a specific node.
// For simplicity, we stick to the plan: Bake unit into the function name or arg wrapper.
// Let's wrap the argument in a "ToRad" conversion if needed.
    
- (UDFrontendAction)trigOp:(NSString *)name {
    return ^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        NSString *sym = name;

        // If in Degrees, wrap arg in (arg * PI / 180)
        // OR better: Just name the function 'sinD' vs 'sin'
        if (!ctx.isRadians) sym = [sym stringByAppendingString:@"D"]; // "sinD"
        return [UDFunctionNode func:sym args:@[arg]];
    };
}

- (UDOpInfo *)infoForOp:(NSInteger)op {
    return self.table[@(op)];
}

@end
