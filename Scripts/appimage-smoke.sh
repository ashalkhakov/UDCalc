#!/bin/bash
# The AppImage on a clean Ubuntu, as gnustep-release-actions' appimage-test
# runs it (.github/release/appimage.conf, SMOKE_SCRIPT): the self-test's
# scenarios that pass on both systems.
#   Scripts/appimage-smoke.sh <UDCalc AppImage>
set -euo pipefail
for scenario in Arithmetic Updates; do
  timeout 300 xvfb-run -a -s "-screen 0 1280x1024x24" "$1" --self-test "$scenario"
done
