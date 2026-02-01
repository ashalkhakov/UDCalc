//
//  UDValue.h
//  Calculator
//
//  Created by Artyom Shalkhakov on 31.01.2026.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UDValueErrorType) {
    UDValueErrorTypeUnknown,
    UDValueErrorTypeDivideByZero,
    UDValueErrorTypeOverflow,
    UDValueErrorTypeUnderflow
};

typedef NS_ENUM(NSInteger, UDValueType) {
    UDValueTypeErr,     // Error Value
    UDValueTypeDouble,  // Standard / Scientific
    UDValueTypeInteger  // Programmer (64-bit)
};

// We name the union 'v' to ensure strict C99/GNUstep compatibility
typedef struct {
    UDValueType type;
    union {
        double doubleValue;
        long long intValue; // Explicit 64-bit integer
    } v;
} UDValue;

static inline UDValue UDValueMakeError(UDValueErrorType errorCode) {
    UDValue val;
    val.type = UDValueTypeErr;
    val.v.intValue = errorCode;
    return val;
}

static inline UDValue UDValueMakeDouble(double d) {
    UDValue val;
    val.type = UDValueTypeDouble;
    val.v.doubleValue = d;
    return val;
}

static inline UDValue UDValueMakeInt(long long i) {
    UDValue val;
    val.type = UDValueTypeInteger;
    val.v.intValue = i;
    return val;
}

static inline UDValueErrorType UDValueAsError(UDValue val) {
    if (val.type == UDValueTypeErr) return (UDValueErrorType)val.v.intValue;
    return UDValueErrorTypeUnknown;
}

static inline double UDValueAsDouble(UDValue val) {
    if (val.type == UDValueTypeDouble) return val.v.doubleValue;
    return (double)val.v.intValue;
}

static inline long long UDValueAsInt(UDValue val) {
    if (val.type == UDValueTypeInteger) return val.v.intValue;
    return (long long)val.v.doubleValue; // Truncate
}

static inline BOOL UDValueIsZero(UDValue val) {
    if (val.type == UDValueTypeDouble) return val.v.doubleValue == 0.0 ? YES : NO;
    else if (val.type == UDValueTypeInteger) return val.v.intValue == 0 ? YES : NO;
    return NO;
}
