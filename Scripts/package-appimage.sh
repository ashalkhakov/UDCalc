#!/bin/bash
# Turn the AppDir into an AppImage. Ported from HomeRow's and TopoText's
# Scripts/package-appimage.sh (after XFormsKit's).
#
#   APP_VERSION=1.2.3 GNUSTEP_PREFIX=... ./Scripts/package-appimage.sh
#   LDAI_UPDATE_INFORMATION='gh-releases-zsync|...' ...   (and a .zsync beside it)
set -euo pipefail

WORKSPACE_DIR=$(pwd)
LOCAL_PREFIX="${GNUSTEP_PREFIX:-/opt/gnustep-prefix}"
# Where gnustep-release-actions/appimage-tools puts it (it sets LINUXDEPLOY).
LINUXDEPLOY="${LINUXDEPLOY:-${RUNNER_TEMP:-/tmp}/linuxdeploy/AppRun}"
arch=$(uname -m)

# What linuxdeploy insists on: a launcher, one desktop entry, its icon.
icon=Calculator/Assets.xcassets/AppIcon.appiconset/CalcIcon-256.png
install -m 0755 Scripts/appimage/AppRun AppDir/AppRun
install -m 0644 Scripts/appimage/udcalc.desktop AppDir/udcalc.desktop
mkdir -p AppDir/usr/share/applications AppDir/usr/share/icons/hicolor/256x256/apps
install -m 0644 Scripts/appimage/udcalc.desktop AppDir/usr/share/applications/udcalc.desktop
install -m 0644 "$icon" AppDir/udcalc.png
install -m 0644 "$icon" AppDir/usr/share/icons/hicolor/256x256/apps/udcalc.png
# What software centres and the AppImage catalog show of it.
mkdir -p AppDir/usr/share/metainfo
install -m 0644 Scripts/appimage/io.github.ashalkhakov.UDCalc.appdata.xml AppDir/usr/share/metainfo/

# The executable to trace for libraries, found rather than named:
# gnustep-make decides where it lands.
binary=$(find AppDir -type f -name Calculator -perm -111 -exec file {} \; 2>/dev/null | awk -F: '/ELF/{print $1; exit}')
if [ -z "$binary" ]; then
  echo "No Calculator executable in AppDir" >&2
  exit 1
fi

# What is loaded at run time rather than linked -- gnustep-gui's backend
# bundle, which needs cairo and the X libraries -- and the tools GNUstep
# starts (gpbs, gdnc): their libraries too, not the files themselves, which
# are already in place.
DEPS_ARGS=()
while IFS= read -r elf; do
  DEPS_ARGS+=(--deploy-deps-only "$elf")
done < <(find AppDir/usr/System/Library/Bundles AppDir/usr/Local/Library/Bundles AppDir/usr/System/Tools AppDir/usr/Local/Tools \
              -type f -perm -111 2>/dev/null | xargs -r file | awk -F: '/ELF/{print $1}')

export OUTPUT="UDCalc-Linux-${APP_VERSION:-dev}-${arch}.AppImage"
export APPIMAGE_EXTRACT_AND_RUN=1
export NO_VALIDATE=1
# Keep the symbol tables: Objective-C methods are named only in .symtab, and
# a backtrace from a user is worth more than the megabytes.
export NO_STRIP="${NO_STRIP:-1}"
export LDAI_RUNTIME_FILE="${LDAI_RUNTIME_FILE:-/tmp/appimage-runtime/runtime-${arch}}"
# LDAI_UPDATE_INFORMATION, when set (gnustep-release-actions'
# appimage-update-info, for a release), is embedded, and a .zsync written
# beside the image.

LD_LIBRARY_PATH="${LOCAL_PREFIX}/Local/Library/Libraries:${LOCAL_PREFIX}/System/Library/Libraries:${LOCAL_PREFIX}/lib:${WORKSPACE_DIR}/AppDir/usr/lib:${LD_LIBRARY_PATH:-}" \
  "$LINUXDEPLOY" --appdir AppDir --executable "$binary" "${DEPS_ARGS[@]}" --output appimage

echo "built $OUTPUT"
