#!/bin/bash
# The calculator for gnustep-release-actions' macos-release.yml: stamped,
# universal, into $RELEASE_DIR. Built ad hoc signed; macos-sign signs it
# for real when the certificate is there.
set -euo pipefail
xcodebuild -project Calculator.xcodeproj -scheme Calculator \
  -destination 'generic/platform=macOS' -configuration Release \
  -derivedDataPath "$RUNNER_TEMP/DerivedData" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= ENABLE_HARDENED_RUNTIME=NO build
ditto "$RUNNER_TEMP/DerivedData/Build/Products/Release/Calculator.app" "$RELEASE_DIR/Calculator.app"
