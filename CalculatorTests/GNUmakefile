include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME = CalculatorTests

CalculatorTests_OBJC_FILES = $(wildcard *.m)
CalculatorTests_OBJC_FILES += \
    ../Calculator/UDAST.m \
    ../Calculator/UDCalc.m \
    ../Calculator/UDCompiler.m \
    ../Calculator/UDConstants.m \
    ../Calculator/UDFrontend.m \
    ../Calculator/UDFrontendContext.m \
    ../Calculator/UDInputBuffer.m \
    ../Calculator/UDInstruction.m \
    ../Calculator/UDSettingsManager.m \
    ../Calculator/UDTape.m \
    ../Calculator/UDUnitConverter.m \
    ../Calculator/UDVM.m \
    ../Calculator/UDValueFormatter.m

CalculatorTests_INCLUDE_DIRS = \
    -I../Calculator

CalculatorTests_LIBRARIES = objc gnustep-base XCTest

XCTEST ?= xctest

.PHONY: check run-tests
run-tests: all $(BUNDLE_NAME).bundle
	@echo "Running XCTest bundle: $(BUNDLE_NAME)"
	@echo "Using runner: $(XCTEST)"
	# Ensure GNUstep environment variables are set for the runner.
	# GNUSTEP_MAKEFILES sets GNUSTEP_SYSTEM_ROOT etc, but your shell may not.
	. $(GNUSTEP_MAKEFILES)/GNUstep.sh; \
	$(XCTEST) "$(BUNDLE_NAME).bundle"

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
