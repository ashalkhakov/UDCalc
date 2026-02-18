//
//  UDFrontend.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import "UDFrontend.h"
#import "UDCalc.h"
#import "UDAST.h"
#import "UDConstants.h"

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

+ (instancetype)infoWithSymbol:(NSString *)sym tag:(NSInteger)tag action:(UDFrontendAction)action {
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
    self.table = [[NSMutableDictionary alloc] init];
    
    // We need a weak reference to self to use inside the blocks
    // because self -> table -> block -> self would cause a memory leak.
    __weak typeof(self) weakSelf = self;

    // ============================================================
    // PRECEDENCE TABLE
    // ============================================================

    // --- PARENTHESES & MEMORY ---
    self.table[@(UDOpParenLeft)] = [UDOpInfo infoWithSymbol:@"(" tag:UDOpParenLeft placement:UDOpPlacementPrefix assoc:UDOpAssocNone precedence:0 action:nil];
    self.table[@(UDOpParenRight)] = [UDOpInfo infoWithSymbol:@")" tag:UDOpParenRight placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:0 action:nil];
    
    self.table[@(UDOpMR)] = [UDOpInfo infoWithSymbol:@"MR" tag:UDOpMR action:^UDASTNode *(UDFrontendContext *ctx) {
        return [UDConstantNode value:UDValueMakeDouble(ctx.memoryValue) symbol:@"MR"];
    }];

    // ============================================================
    // TIER 1: LOGIC & BITWISE (Low Precedence)
    // ============================================================
    
    // OR (|)
    self.table[@(UDOpBitwiseOr)] = [UDOpInfo infoWithSymbol:UDConstBitOr tag:UDOpBitwiseOr placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:5 action:[self binaryOp:UDOpBitwiseOr]];

    // NOR (Implemented as ~ (A | B))
    self.table[@(UDOpBitwiseNor)] = [UDOpInfo infoWithSymbol:@"NOR" tag:UDOpBitwiseNor placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:5 action:^UDASTNode *(UDFrontendContext *ctx) {
        // Pop args
        UDASTNode *right = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *left = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        
        // Lookup Info
        UDOpInfo *orInfo = [weakSelf infoForOp:UDOpBitwiseOr];
        UDOpInfo *notInfo = [weakSelf infoForOp:UDOpComp1]; // Using 1's comp (~) as NOT
        
        // Build AST: NOT( OR(a, b) )
        UDASTNode *orNode = [UDBinaryOpNode info:orInfo left:left right:right];
        return [UDUnaryOpNode info:notInfo child:orNode];
    }];

    // XOR (^)
    self.table[@(UDOpBitwiseXor)] = [UDOpInfo infoWithSymbol:UDConstBitXor tag:UDOpBitwiseXor placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:10 action:[self binaryOp:UDOpBitwiseXor]];

    // AND (&)
    self.table[@(UDOpBitwiseAnd)] = [UDOpInfo infoWithSymbol:UDConstBitAnd tag:UDOpBitwiseAnd placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:15 action:[self binaryOp:UDOpBitwiseAnd]];

    // ============================================================
    // TIER 2: SHIFTS (Precedence 20)
    // ============================================================

    // << (Left Shift)
    self.table[@(UDOpShiftLeft)] = [UDOpInfo infoWithSymbol:@"<<" tag:UDOpShiftLeft placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:20 action:[self binaryOp:UDOpShiftLeft]];

    // >> (Right Shift)
    self.table[@(UDOpShiftRight)] = [UDOpInfo infoWithSymbol:@">>" tag:UDOpShiftRight placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:20 action:[self binaryOp:UDOpShiftRight]];

    // ============================================================
    // TIER 3: STANDARD ARITHMETIC (Precedence 30 - 40)
    // ============================================================

    // + (Add)
    self.table[@(UDOpAdd)] = [UDOpInfo infoWithSymbol:UDConstAdd tag:UDOpAdd placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:30 action:[self binaryOp:UDOpAdd]];

    // - (Sub)
    self.table[@(UDOpSub)] = [UDOpInfo infoWithSymbol:UDConstSub tag:UDOpSub placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:30 action:[self binaryOp:UDOpSub]];

    // * (Multiply)
    self.table[@(UDOpMul)] = [UDOpInfo infoWithSymbol:UDConstMul tag:UDOpMul placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:40 action:[self binaryOp:UDOpMul]];

    // / (Divide)
    self.table[@(UDOpDiv)] = [UDOpInfo infoWithSymbol:UDConstDiv tag:UDOpDiv placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:40 action:[self binaryOp:UDOpDiv]];

    // ============================================================
    // TIER 4: PROGRAMMER UNARY (Precedence 50)
    // ============================================================

    // Byte Flip
    self.table[@(UDOpByteFlip)] = [UDOpInfo infoWithSymbol:UDConstFlipB tag:UDOpByteFlip placement:UDOpPlacementPostfix assoc:UDOpAssocRight precedence:50 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *top = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstFlipB args:@[top]];
    }];

    // Word Flip
    self.table[@(UDOpWordFlip)] = [UDOpInfo infoWithSymbol:UDConstFlipW tag:UDOpWordFlip placement:UDOpPlacementPostfix assoc:UDOpAssocRight precedence:50 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *top = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstFlipW args:@[top]];
    }];

    // 1's Complement (~)
    self.table[@(UDOpComp1)] = [UDOpInfo infoWithSymbol:UDConstBitNeg tag:UDOpComp1 placement:UDOpPlacementPostfix assoc:UDOpAssocRight precedence:50 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *val = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDOpInfo *info = [weakSelf infoForOp:UDOpComp1];

        return [UDUnaryOpNode info:info child:val];
    }];

    // 2's Complement (NEG)
    self.table[@(UDOpComp2)] = [UDOpInfo infoWithSymbol:UDConstNeg tag:UDOpComp2 placement:UDOpPlacementPostfix assoc:UDOpAssocRight precedence:50 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *val = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        // This is semantically equivalent to standard Negation
        UDOpInfo *negInfo = [weakSelf infoForOp:UDOpNegate];

        return [UDUnaryOpNode info:negInfo child:val];
    }];

    // ============================================================
    // ROTATE SHORTCUTS
    // ============================================================

    // Rotate Left (ROL) -> Binary (x ROL 1)
    self.table[@(UDOpRotateLeft)] = [UDOpInfo infoWithSymbol:UDConstRotateLeft tag:UDOpRotateLeft placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *val = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *one = [UDNumberNode value:UDValueMakeDouble(1)];
        
        UDOpInfo *rolInfo = [weakSelf infoForOp:UDOpRotateLeft];
        return [UDBinaryOpNode info:rolInfo left:val right:one];
    }];

    // Rotate Right (ROR) -> Binary (x ROR 1)
    self.table[@(UDOpRotateRight)] = [UDOpInfo infoWithSymbol:UDConstRotateRight tag:UDOpRotateRight placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *val = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *one = [UDNumberNode value:UDValueMakeDouble(1)];
        
        UDOpInfo *rorInfo = [weakSelf infoForOp:UDOpRotateRight];
        return [UDBinaryOpNode info:rorInfo left:val right:one];
    }];

    // ============================================================
    // SHORTCUTS: Unary Shift (<< 1, >> 1)
    // ============================================================

    // << 1
    self.table[@(UDOpShift1Left)] = [UDOpInfo infoWithSymbol:UDConstShiftLeft tag:UDOpShift1Left placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *val = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *one = [UDNumberNode value:UDValueMakeDouble(1)];
        
        UDOpInfo *shiftInfo = [weakSelf infoForOp:UDOpShiftLeft];
        return [UDBinaryOpNode info:shiftInfo left:val right:one];
    }];

    // >> 1
    self.table[@(UDOpShift1Right)] = [UDOpInfo infoWithSymbol:UDConstShiftRight tag:UDOpShift1Right placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *val = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *one = [UDNumberNode value:UDValueMakeDouble(1)];
        
        UDOpInfo *shiftInfo = [weakSelf infoForOp:UDOpShiftRight];
        return [UDBinaryOpNode info:shiftInfo left:val right:one];
    }];

    // ============================================================
    // TIER 5: HIGH MATH / FUNCTIONS (Precedence 60)
    // ============================================================
    
    // Negate (Unary -)
    self.table[@(UDOpNegate)] = [UDOpInfo infoWithSymbol:UDConstNeg tag:UDOpNegate placement:UDOpPlacementPrefix assoc:UDOpAssocRight precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *top = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        
        // Fold Constants if possible
        if ([top isKindOfClass:[UDNumberNode class]]) {
            return [UDNumberNode value:UDValueMakeDouble(-1 * UDValueAsDouble([(UDNumberNode*)top value]))];
        }
        
        UDOpInfo *info = [weakSelf infoForOp:UDOpNegate];
        return [UDUnaryOpNode info:info child:top];
    }];

    // % (Percent)
    self.table[@(UDOpPercent)] = [UDOpInfo infoWithSymbol:UDConstPercent tag:UDOpPercent placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *current = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        
        UDOpInfo *info = [weakSelf infoForOp:UDOpPercent];
        return [UDPostfixOpNode info:info child:current];
    }];

    // Standard Math Functions
    self.table[@(UDOpSquare)] = [UDOpInfo infoWithSymbol:UDConstPow tag:UDOpSquare placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *base = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstPow args:@[base, [UDNumberNode value:UDValueMakeDouble(2)]]];
    }];
    
    self.table[@(UDOpCube)] = [UDOpInfo infoWithSymbol:UDConstPow tag:UDOpCube placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *base = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstPow args:@[base, [UDNumberNode value:UDValueMakeDouble(3)]]];
    }];

    // Power (^)
    self.table[@(UDOpPow)] = [UDOpInfo infoWithSymbol:UDConstPow tag:UDOpPow placement:UDOpPlacementInfix assoc:UDOpAssocRight precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *exp = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *base = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstPow args:@[base, exp]];
    }];

    // Roots
    self.table[@(UDOpSqrt)] = [UDOpInfo infoWithSymbol:UDConstSqrt tag:UDOpSqrt placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstSqrt args:@[arg]];
    }];

    self.table[@(UDOpCbrt)] = [UDOpInfo infoWithSymbol:UDConstPow tag:UDOpCbrt placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *oneThird = [UDBinaryOpNode info:[weakSelf infoForOp:UDOpDiv] left:[UDNumberNode value:UDValueMakeDouble(1)] right:[UDNumberNode value:UDValueMakeDouble(3)]];
        return [UDFunctionNode func:UDConstPow args:@[arg, oneThird]];
    }];

    // n√x (N-th Root)
    // Input Sequence: Base [Op] Root
    // AST Transformation: pow(Base, 1/Root)
    self.table[@(UDOpYRoot)] = [UDOpInfo infoWithSymbol:@"ⁿ√x"
                                                      tag:UDOpYRoot
                                                placement:UDOpPlacementInfix
                                                    assoc:UDOpAssocRight
                                               precedence:60 // Same as Power (^)
                                                   action:^UDASTNode *(UDFrontendContext *ctx) {
        // 1. Pop n (Root) - Top of stack
        UDASTNode *n = [ctx.nodeStack lastObject];
        [ctx.nodeStack removeLastObject];

        // 2. Pop x (Base) - Below n
        UDASTNode *x = [ctx.nodeStack lastObject];
        [ctx.nodeStack removeLastObject];
        
        // 3. Create (1 / n)
        // We hardcode precedence 60 here to ensure tight binding in the AST
        UDASTNode *one = [UDNumberNode value:UDValueMakeDouble(1)];
        UDASTNode *exponent = [UDBinaryOpNode info:[weakSelf infoForOp:UDOpDiv] left:one right:n];
        
        // 4. Return pow(x, 1/n)
        return [UDFunctionNode func:UDConstPow args:@[x, exponent]];
    }];

    // 1/x (Invert)
    self.table[@(UDOpInvert)] = [UDOpInfo infoWithSymbol:UDConstDiv tag:UDOpInvert placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];

        UDOpInfo *divInfo = [weakSelf infoForOp:UDOpDiv];
        return [UDBinaryOpNode info:divInfo left:[UDNumberNode value:UDValueMakeDouble(1)] right:arg];
    }];

    // Factorial (!)
    self.table[@(UDOpFactorial)] = [UDOpInfo infoWithSymbol:@"!" tag:UDOpFactorial placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];

        UDOpInfo *info = [weakSelf infoForOp:UDOpFactorial];
        return [UDPostfixOpNode info:info child:arg];
    }];

    // Trig & Logs
    self.table[@(UDOpSin)] = [UDOpInfo infoWithSymbol:@"sin" tag:UDOpSin placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:[self trigOp:UDConstSin]];
    self.table[@(UDOpCos)] = [UDOpInfo infoWithSymbol:@"cos" tag:UDOpCos placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:[self trigOp:UDConstCos]];
    self.table[@(UDOpTan)] = [UDOpInfo infoWithSymbol:@"tan" tag:UDOpTan placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:[self trigOp:UDConstTan]];
    self.table[@(UDOpSinInverse)] = [UDOpInfo infoWithSymbol:@"sin⁻¹"
                                                         tag:UDOpSinInverse
                                                   placement:UDOpPlacementPostfix
                                                       assoc:UDOpAssocNone
                                                  precedence:60
                                                      action:[self trigOp:UDConstASin]];

    self.table[@(UDOpCosInverse)] = [UDOpInfo infoWithSymbol:@"cos⁻¹"
                                                         tag:UDOpCosInverse
                                                   placement:UDOpPlacementPostfix
                                                       assoc:UDOpAssocNone
                                                  precedence:60
                                                      action:[self trigOp:UDConstACos]];

    self.table[@(UDOpTanInverse)] = [UDOpInfo infoWithSymbol:@"tan⁻¹"
                                                         tag:UDOpTanInverse
                                                   placement:UDOpPlacementPostfix
                                                       assoc:UDOpAssocNone
                                                  precedence:60
                                                      action:[self trigOp:UDConstATan]];
    self.table[@(UDOpSinh)] = [UDOpInfo infoWithSymbol:@"sinh"
                                                   tag:UDOpSinh
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:60
                                                action:[self funcOp:UDConstSinH]];
    self.table[@(UDOpCosh)] = [UDOpInfo infoWithSymbol:@"cosh"
                                                   tag:UDOpCosh
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:60
                                                action:[self funcOp:UDConstCosH]];
    self.table[@(UDOpTanh)] = [UDOpInfo infoWithSymbol:@"tanh"
                                                   tag:UDOpTanh
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:60
                                                action:[self funcOp:UDConstTanH]];
    self.table[@(UDOpSinhInverse)] = [UDOpInfo infoWithSymbol:@"sinh⁻¹"
                                                          tag:UDOpSinhInverse
                                                    placement:UDOpPlacementPostfix
                                                        assoc:UDOpAssocNone
                                                   precedence:60
                                                       action:[self funcOp:UDConstASinH]];

    self.table[@(UDOpCoshInverse)] = [UDOpInfo infoWithSymbol:@"cosh⁻¹"
                                                          tag:UDOpCoshInverse
                                                    placement:UDOpPlacementPostfix
                                                        assoc:UDOpAssocNone
                                                   precedence:60
                                                       action:[self funcOp:UDConstACosH]];

    self.table[@(UDOpTanhInverse)] = [UDOpInfo infoWithSymbol:@"tanh⁻¹"
                                                          tag:UDOpTanhInverse
                                                    placement:UDOpPlacementPostfix
                                                        assoc:UDOpAssocNone
                                                   precedence:60
                                                       action:[self funcOp:UDConstATanH]];

    // ============================================================
    // LOGARITHMS
    // ============================================================

    self.table[@(UDOpLn)] = [UDOpInfo infoWithSymbol:@"ln"
                                                 tag:UDOpLn
                                           placement:UDOpPlacementPostfix
                                               assoc:UDOpAssocNone
                                          precedence:60
                                              action:[self funcOp:UDConstLn]];

    self.table[@(UDOpLog10)] = [UDOpInfo infoWithSymbol:@"log₁₀"
                                                    tag:UDOpLog10
                                              placement:UDOpPlacementPostfix
                                                  assoc:UDOpAssocNone
                                             precedence:60
                                                 action:[self funcOp:UDConstLog10]];

    self.table[@(UDOpLog2)] = [UDOpInfo infoWithSymbol:@"log₂"
                                                   tag:UDOpLog2
                                             placement:UDOpPlacementPostfix
                                                 assoc:UDOpAssocNone
                                            precedence:60
                                                action:[self funcOp:UDConstLog2]];

    // log_y(x) (Log Base Y)
    // Input Sequence: Value [Op] Base
    // AST Transformation: ln(Value) / ln(Base)
    self.table[@(UDOpLogY)] = [UDOpInfo infoWithSymbol:@"log_y"
                                                       tag:UDOpLogY
                                                 placement:UDOpPlacementInfix
                                                     assoc:UDOpAssocRight
                                                precedence:60 // Same as Power (^)
                                                    action:^UDASTNode *(UDFrontendContext *ctx) {
        // 1. Pop y (Base) - Top of stack
        UDASTNode *y = [ctx.nodeStack lastObject];
        [ctx.nodeStack removeLastObject];

        // 2. Pop x (Value) - Below y
        UDASTNode *x = [ctx.nodeStack lastObject];
        [ctx.nodeStack removeLastObject];
        
        // 3. Construct Change of Base Formula: ln(x) / ln(y)
        UDASTNode *lnX = [UDFunctionNode func:UDConstLn args:@[x]];
        UDASTNode *lnY = [UDFunctionNode func:UDConstLn args:@[y]];
        
        // 4. Return Division Node
        // Use Precedence 60 to ensure this entire block is treated as a single unit
        return [UDBinaryOpNode info:[weakSelf infoForOp:UDOpDiv] left:lnX right:lnY];
    }];

    // Rand
    self.table[@(UDOpRand)] = [UDOpInfo infoWithSymbol:@"rand" tag:UDOpRand action:^UDASTNode *(UDFrontendContext *ctx) {
        return [UDConstantNode value:UDValueMakeDouble(((double)arc4random()/UINT32_MAX)) symbol:@"rand"];
    }];
}

#pragma mark - Helpers

- (UDFrontendAction)binaryOp:(NSInteger)opTag {
    __weak typeof(self) weakSelf = self;
    return ^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *r = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *l = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];

        UDOpInfo *info = [weakSelf infoForOp:opTag];
        return [UDBinaryOpNode info:info left:l right:r];
    };
}

- (UDFrontendAction)funcOp:(NSString *)name {
    return ^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:name args:@[arg]];
    };
}

- (UDFrontendAction)trigOp:(NSString *)name {
    return ^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        NSString *sym = name;
        if (!ctx.isRadians) sym = [sym stringByAppendingString:@"D"];
        return [UDFunctionNode func:sym args:@[arg]];
    };
}

- (UDOpInfo *)infoForOp:(NSInteger)op {
    return self.table[@(op)];
}

@end
