//
//  UDSelfTest.h
//  Calculator
//
//  Calculator --self-test [filter]: the app as it runs, driven from within,
//  one use case (scenario) at a time. Buttons are clicked, keyboard
//  shortcuts are sent as key events through NSApp, and menu items are chosen
//  from the main menu, so actions travel the same path a user's do,
//  including the responder chain for items wired to the First Responder.
//
//  Each step prints PASS or FAIL; the app exits with the number that failed.
//  With a filter, only the features or scenarios whose name contains it run
//  (case-insensitive), e.g. --self-test "menu".
//
//  In CI or a container: Tests/run-self-test.sh (xvfb-run, throwaway HOME).
//

#import <AppKit/AppKit.h>

@class AppDelegate;

NS_ASSUME_NONNULL_BEGIN

// Set by main from --self-test, before the app starts. A non-nil value turns
// the self-test on; an empty string runs every scenario.
FOUNDATION_EXPORT NSString *_Nullable UDSelfTestFilter;

// Called once the app has finished launching.
FOUNDATION_EXPORT void UDStartSelfTest(AppDelegate *app);

NS_ASSUME_NONNULL_END
