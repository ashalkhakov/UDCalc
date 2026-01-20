//
//  UDVM.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 19.01.2026.
//

#import "UDInstruction.h"

@interface UDVM : NSObject
+ (double)execute:(NSArray<UDInstruction *> *)program;
@end
