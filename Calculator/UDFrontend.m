//
//  UDOpRegistry.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 18.01.2026.
//

#import "UDFrontend.h"
#import "UDCalc.h" // Needs your UDOp Enum definition
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
    self.table = [[NSMutableDictionary alloc] init];

    // ============================================================
    // PRECEDENCE TABLE (Scaled for Programmer Mode)
    // ============================================================
    // 60: Functions, Exponents, Standard Unary (-, !)
    // 50: Programmer Unary (Byte/Word Flip)
    // 40: Multiplicative (*, /)
    // 30: Additive (+, -)
    // 20: Shifts (<<, >>, ROL, ROR)
    // 15: Bitwise AND (&)
    // 10: Bitwise XOR (^)
    //  5: Bitwise OR (|), NOR
    // ============================================================

    // --- PARENTHESES & MEMORY (Precedence 0 / Special) ---
    self.table[@(UDOpParenLeft)] = [UDOpInfo infoWithSymbol:@"(" tag:UDOpParenLeft placement:UDOpPlacementPrefix assoc:UDOpAssocNone precedence:0 action:nil];
    self.table[@(UDOpParenRight)] = [UDOpInfo infoWithSymbol:@")" tag:UDOpParenRight placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:0 action:nil];
    
    self.table[@(UDOpMR)] = [UDOpInfo infoWithSymbol:@"MR" tag:UDOpMR action:^UDASTNode *(UDFrontendContext *ctx) {
        return [UDConstantNode value:UDValueMakeDouble(ctx.memoryValue) symbol:@"MR"];
    }];

    // ============================================================
    // TIER 1: LOGIC & BITWISE (Low Precedence)
    // ============================================================
    
    // OR (|) - Precedence 5
    self.table[@(UDOpBitwiseOr)] = [UDOpInfo infoWithSymbol:@"|" tag:UDOpBitwiseOr placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:5 action:[self binaryOp:UDConstBitOr prec:5]];

    // NOR - Precedence 5
    // Implemented as NOT( A OR B )
    self.table[@(UDOpBitwiseNor)] = [UDOpInfo infoWithSymbol:@"NOR" tag:UDOpBitwiseNor placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:5 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *right = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *left = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        
        UDASTNode *orNode = [UDBinaryOpNode op:UDConstBitOr left:left right:right precedence:5];
        return [UDUnaryOpNode op:UDConstBitNeg child:orNode];
    }];

    // XOR (^) - Precedence 10
    self.table[@(UDOpBitwiseXor)] = [UDOpInfo infoWithSymbol:@"XOR" tag:UDOpBitwiseXor placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:10 action:[self binaryOp:UDConstBitXor prec:10]];

    // AND (&) - Precedence 15
    self.table[@(UDOpBitwiseAnd)] = [UDOpInfo infoWithSymbol:@"AND" tag:UDOpBitwiseAnd placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:15 action:[self binaryOp:UDConstBitAnd prec:15]];

    // ============================================================
    // TIER 2: SHIFTS (Precedence 20)
    // ============================================================

    // << (Left Shift)
    self.table[@(UDOpShiftLeft)] = [UDOpInfo infoWithSymbol:@"<<" tag:UDOpShiftLeft placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:20 action:[self binaryOp:@"<<" prec:20]];

    // >> (Right Shift)
    self.table[@(UDOpShiftRight)] = [UDOpInfo infoWithSymbol:@">>" tag:UDOpShiftRight placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:20 action:[self binaryOp:@">>" prec:20]];

    // ============================================================
    // TIER 3: STANDARD ARITHMETIC (Precedence 30 - 40)
    // ============================================================

    // + (Add) - Precedence 30
    self.table[@(UDOpAdd)] = [UDOpInfo infoWithSymbol:@"+" tag:UDOpAdd placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:30 action:[self binaryOp:UDConstAdd prec:30]];

    // - (Sub) - Precedence 30
    self.table[@(UDOpSub)] = [UDOpInfo infoWithSymbol:@"-" tag:UDOpSub placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:30 action:[self binaryOp:UDConstSub prec:30]];

    // * (Multiply) - Precedence 40
    self.table[@(UDOpMul)] = [UDOpInfo infoWithSymbol:@"×" tag:UDOpMul placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:40 action:[self binaryOp:UDConstMul prec:40]];

    // / (Divide) - Precedence 40
    self.table[@(UDOpDiv)] = [UDOpInfo infoWithSymbol:@"÷" tag:UDOpDiv placement:UDOpPlacementInfix assoc:UDOpAssocLeft precedence:40 action:[self binaryOp:UDConstDiv prec:40]];

    // ============================================================
    // TIER 4: PROGRAMMER UNARY (Precedence 50)
    // ============================================================

    // Byte Flip - Unary Prefix (Right-to-Left)
    self.table[@(UDOpByteFlip)] = [UDOpInfo infoWithSymbol:@"ByteFlip" tag:UDOpByteFlip placement:UDOpPlacementPrefix assoc:UDOpAssocRight precedence:50 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *top = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstFlipB args:@[top]]; // "flip_b" handled in backend
    }];

    // Word Flip - Unary Prefix (Right-to-Left)
    self.table[@(UDOpWordFlip)] = [UDOpInfo infoWithSymbol:@"WordFlip" tag:UDOpWordFlip placement:UDOpPlacementPrefix assoc:UDOpAssocRight precedence:50 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *top = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstFlipW args:@[top]]; // "flip_w" handled in backend
    }];

    // 1's Complement (Bitwise NOT) -> ~x
    // Symbol: "~" or "NOT"
    self.table[@(UDOpComp1)] = [UDOpInfo infoWithSymbol:@"~"
                                                    tag:UDOpComp1
                                              placement:UDOpPlacementPostfix
                                                  assoc:UDOpAssocRight
                                             precedence:50
                                                 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *val = [ctx.nodeStack lastObject];
        [ctx.nodeStack removeLastObject];
        
        // Return Unary Op Node: (~ val)
        return [UDUnaryOpNode op:UDConstBitNeg child:val];
    }];

    // 2's Complement (Negation) -> -x
    // Symbol: "2's" or "NEG"
    // Note: We already have a generic negation operator ('-'), but programmer mode
    // often treats this distinctly as "2's Comp".
    // We can reuse the existing negation logic or make a specific node.
    self.table[@(UDOpComp2)] = [UDOpInfo infoWithSymbol:@"NEG"
                                                    tag:UDOpComp2
                                              placement:UDOpPlacementPostfix
                                                  assoc:UDOpAssocRight
                                             precedence:50
                                                 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *val = [ctx.nodeStack lastObject];
        [ctx.nodeStack removeLastObject];
        
        // 2's Complement is just Arithmetic Negation in binary representation
        return [UDUnaryOpNode op:UDConstNeg child:val];
    }];

    // ============================================================
    // ROTATE SHORTCUTS: Unary (ROL, ROR) -> Binary (x rot 1)
    // ============================================================

    // Rotate Left by 1 (ROL)
    // Usage: 5 ROL -> 10 (in 8-bit mode: 00000101 -> 00001010)
    self.table[@(UDOpRotateLeft)] = [UDOpInfo infoWithSymbol:@"ROL"
                                                         tag:UDOpRotateLeft
                                                   placement:UDOpPlacementPostfix
                                                       assoc:UDOpAssocNone
                                                  precedence:60 // High Precedence matches Factorial/Square
                                                      action:^UDASTNode *(UDFrontendContext *ctx) {
        // 1. Pop value
        UDASTNode *val = [ctx.nodeStack lastObject];
        [ctx.nodeStack removeLastObject];
        
        // 2. Create Constant "1"
        UDASTNode *one = [UDNumberNode value:UDValueMakeDouble(1)];
        
        // 3. Return Binary Node: (val rol 1)
        return [UDBinaryOpNode op:UDConstRotateLeft left:val right:one precedence:20];
    }];

    // Rotate Right by 1 (ROR)
    // Usage: 5 ROR -> (depends on word size, likely very large in 64-bit)
    self.table[@(UDOpRotateRight)] = [UDOpInfo infoWithSymbol:@"ROR"
                                                          tag:UDOpRotateRight
                                                    placement:UDOpPlacementPostfix
                                                        assoc:UDOpAssocNone
                                                   precedence:60
                                                       action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *val = [ctx.nodeStack lastObject];
        [ctx.nodeStack removeLastObject];
        
        UDASTNode *one = [UDNumberNode value:UDValueMakeDouble(1)];
        
        // Return Binary Node: (val ror 1)
        return [UDBinaryOpNode op:UDConstRotateRight left:val right:one precedence:20];
    }];

    // ============================================================
    // SHORTCUTS: Unary Shift (<< 1, >> 1)
    // Acts like x!, but generates AST for (x << 1)
    // ============================================================

    // << 1 (Shift Left by 1)
    self.table[@(UDOpShift1Left)] = [UDOpInfo infoWithSymbol:@"<<1"
                                                         tag:UDOpShift1Left
                                                   placement:UDOpPlacementPostfix
                                                       assoc:UDOpAssocNone
                                                  precedence:60 // High Precedence (binds tight)
                                                      action:^UDASTNode *(UDFrontendContext *ctx) {
        // 1. Pop the value to be shifted
        UDASTNode *val = [ctx.nodeStack lastObject];
        [ctx.nodeStack removeLastObject];
        
        // 2. Create a "1" node
        UDASTNode *one = [UDNumberNode value:UDValueMakeDouble(1)];
        
        // 3. Return a standard Binary Node: (val << 1)
        // We use the standard Shift Precedence (20) for the node itself,
        // but the Parser used Precedence 60 to grab 'val'.
        return [UDBinaryOpNode op:UDConstShiftLeft left:val right:one precedence:20];
    }];

    // >> 1 (Shift Right by 1)
    self.table[@(UDOpShift1Right)] = [UDOpInfo infoWithSymbol:@">>1"
                                                          tag:UDOpShift1Right
                                                    placement:UDOpPlacementPostfix
                                                        assoc:UDOpAssocNone
                                                   precedence:60
                                                       action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *val = [ctx.nodeStack lastObject];
        [ctx.nodeStack removeLastObject];
        
        UDASTNode *one = [UDNumberNode value:UDValueMakeDouble(1)];
        
        // Return standard Binary Node: (val >> 1)
        return [UDBinaryOpNode op:UDConstShiftRight left:val right:one precedence:20];
    }];

    // ============================================================
    // TIER 5: HIGH MATH / FUNCTIONS (Precedence 60)
    // ============================================================
    
    // Negate (Uniary -)
    self.table[@(UDOpNegate)] = [UDOpInfo infoWithSymbol:@"-" tag:UDOpNegate placement:UDOpPlacementPrefix assoc:UDOpAssocRight precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *top = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        if ([top isKindOfClass:[UDNumberNode class]]) {
            return [UDNumberNode value:UDValueMakeDouble(-1 * UDValueAsDouble([(UDNumberNode*)top value]))];
        }
        return [UDUnaryOpNode op:UDConstNeg child:top];
    }];

    // % (Percent) - Context sensitive, keeping logic similar but high precedence
    self.table[@(UDOpPercent)] = [UDOpInfo infoWithSymbol:@"%" tag:UDOpPercent placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *current = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        if (ctx.pendingOp == UDOpAdd || ctx.pendingOp == UDOpSub) {
            return [UDPostfixOpNode symbol:UDConstPercent child:current];
        }
        return [UDBinaryOpNode op:UDConstDiv left:current right:[UDNumberNode value:UDValueMakeDouble(100)] precedence:60];
    }];

    // Standard Math Functions (Precedence 60)
    self.table[@(UDOpSquare)] = [UDOpInfo infoWithSymbol:@"²" tag:UDOpSquare placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *base = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstPow args:@[base, [UDNumberNode value:UDValueMakeDouble(2)]]];
    }];

    self.table[@(UDOpCube)] = [UDOpInfo infoWithSymbol:@"³" tag:UDOpCube placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *base = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstPow args:@[base, [UDNumberNode value:UDValueMakeDouble(3)]]];
    }];

    // Power (x^y) - Right Associative
    self.table[@(UDOpPow)] = [UDOpInfo infoWithSymbol:@"^" tag:UDOpPow placement:UDOpPlacementInfix assoc:UDOpAssocRight precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *exp = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *base = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstPow args:@[base, exp]];
    }];

    // Roots
    self.table[@(UDOpSqrt)] = [UDOpInfo infoWithSymbol:@"√" tag:UDOpSqrt placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDFunctionNode func:UDConstSqrt args:@[arg]];
    }];

    self.table[@(UDOpCbrt)] = [UDOpInfo infoWithSymbol:@"∛" tag:UDOpCbrt placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *oneThird = [UDBinaryOpNode op:UDConstDiv left:[UDNumberNode value:UDValueMakeDouble(1)] right:[UDNumberNode value:UDValueMakeDouble(3)] precedence:60];
        return [UDFunctionNode func:UDConstPow args:@[arg, oneThird]];
    }];

    self.table[@(UDOpInvert)] = [UDOpInfo infoWithSymbol:@"1/x" tag:UDOpCbrt placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        UDASTNode *oneX = [UDBinaryOpNode op:UDConstDiv left:[UDNumberNode value:UDValueMakeDouble(1)] right:arg precedence:60];
        return oneX;
    }];

    // Factorial
    self.table[@(UDOpFactorial)] = [UDOpInfo infoWithSymbol:@"!" tag:UDOpFactorial placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:^UDASTNode *(UDFrontendContext *ctx) {
        UDASTNode *arg = [ctx.nodeStack lastObject]; [ctx.nodeStack removeLastObject];
        return [UDPostfixOpNode symbol:@"!" child:arg];
    }];

    // Trig & Logs (Keeping existing logic)
    self.table[@(UDOpSin)] = [UDOpInfo infoWithSymbol:@"sin" tag:UDOpSin placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:[self trigOp:UDConstSin]];
    self.table[@(UDOpCos)] = [UDOpInfo infoWithSymbol:@"cos" tag:UDOpCos placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:[self trigOp:UDConstCos]];
    self.table[@(UDOpTan)] = [UDOpInfo infoWithSymbol:@"tan" tag:UDOpTan placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:[self trigOp:UDConstTan]];
    self.table[@(UDOpLn)]  = [UDOpInfo infoWithSymbol:@"ln" tag:UDOpLn placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:[self funcOp:UDConstLn]];
    self.table[@(UDOpLog10)] = [UDOpInfo infoWithSymbol:@"log_10" tag:UDOpLog10 placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:[self funcOp:UDConstLog10]];
    self.table[@(UDOpLog2)] = [UDOpInfo infoWithSymbol:@"log_2" tag:UDOpLog10 placement:UDOpPlacementPostfix assoc:UDOpAssocNone precedence:60 action:[self funcOp:UDConstLog2]];

    // Rand
    self.table[@(UDOpRand)] = [UDOpInfo infoWithSymbol:@"rand" tag:UDOpRand action:^UDASTNode *(UDFrontendContext *ctx) {
        return [UDConstantNode value:UDValueMakeDouble(((double)arc4random()/UINT32_MAX)) symbol:@"rand"];
    }];
}

// Helpers
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
