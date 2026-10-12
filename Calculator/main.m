//
//  main.m
//  Calculator
//
//  Created by Artyom Shalkhakov on 17.01.2026.
//

#import <AppKit/AppKit.h>
#import "UDSelfTest.h"

// Calculator --self-test [filter]   the app driven from within, use case by
//                                    use case (UDSelfTest.h)

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            if (!strcmp(argv[i], "--self-test")) {
                UDSelfTestFilter = (i + 1 < argc && argv[i + 1][0] != '-') ? @(argv[i + 1]) : @"";
            }
        }
    }
    return NSApplicationMain(argc, argv);
}
