//
//  UDInputBuffer.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 23.01.2026.
//

#import "UDInputBuffer.h"
#import "UDValueFormatter.h"

// Safety limit to prevent long long overflow (approx 17-18 digits)
static const long long MAX_DIGITS_LIMIT = 10000000000000000LL;

@interface UDInputBuffer ()
// Read-write versions of properties for internal use
@property (nonatomic, assign) unsigned long long mantissaBuffer;
@property (nonatomic, assign) unsigned long long exponentBuffer;
@property (nonatomic, assign) NSInteger decimalShift;
@property (nonatomic, assign) BOOL inExponentMode;
@property (nonatomic, assign) BOOL isMantissaNegative;
@property (nonatomic, assign) BOOL isExponentNegative;
@property (nonatomic, assign) BOOL hasHitDecimal;
@end

@implementation UDInputBuffer

- (instancetype)init {
    self = [super init];
    if (self) {
        self.inputBase = UDBaseDec;
        [self performClearEntry];
    }
    return self;
}

#pragma mark - Input Handling

- (void)loadConstant:(UDValue)value {
    // 1. Reset everything first
    [self performClearEntry];
    
    if (value.type == UDValueTypeInteger) {
        self.mantissaBuffer = UDValueAsInt(value);
        return;
    }
    
    double constant = UDValueAsDouble(value);

    // 2. Handle Edge Case: Zero
    if (constant == 0) return; // Buffer is already 0 from clearEntry
    
    // 3. Handle Negative Numbers
    // We strip the sign here and apply it manually to ensure state is correct
    if (constant < 0) {
        self.isMantissaNegative = YES;
        constant = -constant;
    }

    // 4. Convert to String
    // %.15g is the standard for "General" floating point printing.
    // It automatically switches to scientific notation (e.g., 1e+20) if the number is huge.
    // It limits precision to 15 digits, which fits safely in our long long buffer.
    NSString *valStr = [NSString stringWithFormat:@"%.15g", constant];
    
    // 5. Simulate Typing
    for (NSUInteger i = 0; i < valStr.length; i++) {
        unichar c = [valStr characterAtIndex:i];
        
        if (isdigit(c)) {
            // It's a number 0-9
            [self handleDigit:(c - '0')];
        }
        else if (c == '.') {
            [self handleDecimalPoint];
        }
        else if (c == 'e' || c == 'E') {
            [self handleEE];
        }
        else if (c == '-') {
            // If we see a minus sign, it must be for the exponent (e.g. 1.2e-5)
            // because we already stripped the main sign in step 3.
            if (self.inExponentMode) {
                self.isExponentNegative = YES;
            }
        }
        // Note: We ignore '+' chars (e.g. "1e+5") as positive is default
    }
}

- (void)handleDigit:(int)digit {
    if (_isIntegerMode) {
        // --- INTEGER MODE LOGIC ---
        // Simple accumulation: val = (val * base) + digit
        // e.g. Typing Hex "A" (10) then "5":
        // 1. Buffer = 10
        // 2. Buffer = (10 * 16) + 5 = 165 (which is 0xA5)
        if (digit < 0 || digit > _inputBase - 1) return;

        unsigned long long buf = self.mantissaBuffer;
        
        // Check for Overflow (Optional but recommended)
        if (buf > (ULLONG_MAX - digit) / _inputBase) {
            return;
        }

        // Re-use mantissaBuffer to store the raw integer
        _mantissaBuffer = (buf * _inputBase) + digit;
        return;
    }

    if (digit < 0 || digit > 9) return;

    if (self.inExponentMode) {
        // --- Exponent Mode ---
        // Exponents rarely need more than 3 digits, simple check
        if (self.exponentBuffer > 999) return;
        
        self.exponentBuffer = (self.exponentBuffer * 10) + digit;
    }
    else {
        // --- Mantissa Mode ---
        if (self.mantissaBuffer > MAX_DIGITS_LIMIT) return; // Overflow protection

        self.mantissaBuffer = (self.mantissaBuffer * 10) + digit;

        // If we are past the decimal point, we must count the shift
        if (self.hasHitDecimal) {
            self.decimalShift++;
        }
    }
}

- (void)handleDecimalPoint {
    if (self.isIntegerMode) return;
    
    // Cannot add decimal if already in exponent mode
    if (self.inExponentMode) return;
    
    // Cannot add decimal if already present
    if (self.hasHitDecimal) return;
    
    self.hasHitDecimal = YES;
    // Note: decimalShift remains 0 until the first digit is typed
}

- (void)handleEE {
    if (self.isIntegerMode) return;

    // Already in EE mode? Do nothing.
    if (self.inExponentMode) return;
    
    self.inExponentMode = YES;
}

- (void)toggleSign {
    if (self.isIntegerMode) return;

    if (self.inExponentMode) {
        self.isExponentNegative = !self.isExponentNegative;
    } else {
        self.isMantissaNegative = !self.isMantissaNegative;
    }
}

#pragma mark - Editing & Deletion

- (void)handleBackspace {
    // ZONE 1: Exponent
    if (self.inExponentMode) {
        if (self.exponentBuffer > 0) {
            self.exponentBuffer /= 10;
        }
        else if (self.isExponentNegative) {
            // "1.5E-" -> "1.5E"
            self.isExponentNegative = NO;
        }
        else {
            // "1.5E" -> "1.5"
            self.inExponentMode = NO;
        }
        return;
    }

    // ZONE 2: Mantissa
    
    // Check if we have digits to remove (integer or fraction)
    // Note: decimalShift > 0 implies we have fractional digits
    if (self.mantissaBuffer > 0 || self.decimalShift > 0) {
        self.mantissaBuffer /= 10;
        
        if (self.decimalShift > 0) {
            self.decimalShift--;
        }
    }
    // Case: "0." (Buffer 0, Shift 0, HasDecimal YES) -> "0"
    else if (self.hasHitDecimal) {
        self.hasHitDecimal = NO;
    }
}

- (void)performClearEntry {
    self.mantissaBuffer = 0;
    self.exponentBuffer = 0;
    self.decimalShift = 0;
    self.inExponentMode = NO;
    self.isMantissaNegative = NO;
    self.isExponentNegative = NO;
    self.hasHitDecimal = NO;
}

#pragma mark - Output

- (UDValue)finalizeValue {
    if (self.isIntegerMode) {
        return UDValueMakeInt(self.mantissaBuffer);
    }

    double value = [self mantissa];
    
    long long finalExp = self.exponentBuffer;
    if (self.isExponentNegative) {
        finalExp = -finalExp;
    }
    
    if (finalExp != 0) {
        value = value * pow(10, (double)finalExp);
    }
    
    return UDValueMakeDouble(value);
}

- (double)mantissa {
    // 1. Convert Mantissa Digits
    double value = (double)self.mantissaBuffer;
    
    // 2. Apply Mantissa Sign
    if (self.isMantissaNegative) {
        value = -value;
    }
    
    // 3. Apply Decimal Shift (e.g. 123 with shift 2 -> 1.23)
    if (self.decimalShift > 0) {
        value = value * pow(10, -((double)self.decimalShift));
    }

    return value;
}

- (NSString *)displayStringWithThousandsSeparators:(BOOL)showThousandsSeparators {
    if (_isIntegerMode) {
        return [UDValueFormatter stringForValue:[self finalizeValue]
                                           base:self.inputBase
                        showThousandsSeparators:showThousandsSeparators
                                  decimalPlaces:15
                                forceScientific:NO];
    }
   
    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
    fmt.usesGroupingSeparator = showThousandsSeparators;
    fmt.minimumFractionDigits = 0;
    fmt.numberStyle = NSNumberFormatterDecimalStyle;
    fmt.maximumFractionDigits = 15;

    if (_inExponentMode) {
        double value = [self mantissa];

        return [NSString stringWithFormat:@"%@ e %lld", [fmt stringFromNumber:@(value)], _isExponentNegative ? -_exponentBuffer : _exponentBuffer];
    } else {
        UDValue value = [self finalizeValue];
        
        return [fmt stringFromNumber:@(UDValueAsDouble(value))];
    }
}

@end
