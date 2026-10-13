#!/bin/bash
# The calculator (only the app: the test bundle has no business in the image) into the prefix's System domain, where gnustep-release-actions'
# appimage takes them from.
set -eo pipefail
# GNUstep.sh reads unset variables (ZSH_VERSION), so set -u comes after it.
. "$PREFIX/System/Library/Makefiles/GNUstep.sh"
set -u
make -C Calculator install GNUSTEP_INSTALLATION_DOMAIN=SYSTEM
