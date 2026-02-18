# GNUmakefile - Build UDCalc with GNUstep
#
# Usage:
#   . /usr/local/share/GNUstep/Makefiles/GNUstep.sh
#   make
#
# Requirements:
#   - GNUstep with the modern Objective-C runtime (libobjc2)
#   - Clang compiler with ARC and blocks support
#   - Recent gnustep-base and gnustep-gui (from git master)
#

include $(GNUSTEP_MAKEFILES)/common.make

APP_NAME = Calculator

SRC_DIR = Calculator

# Core logic (unchanged from macOS build)
Calculator_OBJC_FILES = \
  $(SRC_DIR)/UDConstants.m \
  $(SRC_DIR)/UDInstruction.m \
  $(SRC_DIR)/UDAST.m \
  $(SRC_DIR)/UDFrontendContext.m \
  $(SRC_DIR)/UDFrontend.m \
  $(SRC_DIR)/UDCompiler.m \
  $(SRC_DIR)/UDVM.m \
  $(SRC_DIR)/UDInputBuffer.m \
  $(SRC_DIR)/UDValueFormatter.m \
  $(SRC_DIR)/UDCalc.m \
  $(SRC_DIR)/UDConversionHistoryManager.m \
  $(SRC_DIR)/UDSettingsManager.m \
  $(SRC_DIR)/UDTape.m \
  GNUstep/UDUnitConverter_GNUstep.m \
  $(SRC_DIR)/UDCalcButton.m \
  $(SRC_DIR)/UDBitDisplayView.m \
  GNUstep/UDGNUstepCompat.m \
  GNUstep/GNUstep_main.m

# Enable ARC
Calculator_OBJCFLAGS = -fobjc-arc

# Include paths:
#   - Calculator/ for project headers
#   - GNUstep/include/ for UDGNUstepCompat.h
#   - /usr/local/include/GNUstep for libobjc2 headers
ADDITIONAL_OBJCFLAGS = \
  -I$(SRC_DIR) \
  -IGNUstep/include \
  -I/usr/local/include/GNUstep \
  -include UDGNUstepCompat.h

ADDITIONAL_LDFLAGS = \
  -L/usr/local/lib \
  -ldispatch \
  -Wl,-rpath,/usr/local/lib

include $(GNUSTEP_MAKEFILES)/application.make
