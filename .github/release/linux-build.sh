#!/bin/bash
# The version stamped; linux-install.sh builds and installs the app.
set -euo pipefail
./Scripts/stamp-version.sh "$APP_VERSION"
