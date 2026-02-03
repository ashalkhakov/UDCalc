//
//  UDBitDisplayView.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 02.02.2026.
//

#import <Cocoa/Cocoa.h>

@protocol UDBitDisplayDelegate <NSObject>
- (void)bitDisplayDidToggleBit:(NSInteger)bitIndex toValue:(BOOL)newValue;
@end

@interface UDBitDisplayView : NSView

@property (nonatomic, assign) uint64_t value;
@property (nonatomic, weak) id<UDBitDisplayDelegate> delegate;

@end
