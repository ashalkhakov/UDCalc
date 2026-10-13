#!/bin/bash
# UDCalc-Linux-<version>-x86_64.AppImage: the calculator and the GNUstep
# runtime in one file.
set -euo pipefail
GNUSTEP_PREFIX="$PREFIX" ./Scripts/prepare-appdir.sh
GNUSTEP_PREFIX="$PREFIX" ./Scripts/package-appimage.sh
