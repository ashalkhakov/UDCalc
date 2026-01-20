//
//  UDCompiler.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDAST.h"
#import "UDInstruction.h"

@interface UDCompiler : NSObject
// The main entry point
+ (NSArray<UDInstruction *> *)compile:(UDASTNode *)root;
@end
