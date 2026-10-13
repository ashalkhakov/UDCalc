#
# UDCalc on GNUstep: the calculator and its tests.
#
#   make            Calculator.app and the test bundle
#   make check      the unit tests, and the self-test's scenarios that pass
#                   on both systems (Arithmetic, Updates), headless
#                   (Tests/run-self-test.sh)
#   make install    the calculator; not the test bundle
#
# macOS: Makefile.apple.
#
ifeq ($(GNUSTEP_MAKEFILES),)
  $(error Set GNUSTEP_MAKEFILES (source GNUstep.sh). macOS: make -f Makefile.apple)
endif

include $(GNUSTEP_MAKEFILES)/common.make

PACKAGE_NAME = UDCalc
SUBPROJECTS = Calculator CalculatorTests

include $(GNUSTEP_MAKEFILES)/aggregate.make

SELF_TESTS = Arithmetic Updates
check::
	$(MAKE) -C CalculatorTests run-tests
	@for scenario in $(SELF_TESTS); do Tests/run-self-test.sh $$scenario || exit 1; done
