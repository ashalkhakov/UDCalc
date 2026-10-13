#!/bin/bash
# The version stamped; prepare-appdir.sh (linux-package.sh) builds the app.
set -euo pipefail
./Scripts/stamp-version.sh "$APP_VERSION"
