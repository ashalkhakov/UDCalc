#!/bin/bash
# Assemble the AppDir: the calculator and the GNUstep runtime it runs on.
# Ported from HomeRow's Scripts/prepare-appdir.sh (after XFormsKit's,
# RDLKit's and UDQuakeTools'), and TopoText's.
#
#   GNUSTEP_PREFIX=/path/to/gnustep ./Scripts/prepare-appdir.sh
set -euo pipefail

LOCAL_PREFIX="${GNUSTEP_PREFIX:-/opt/gnustep-prefix}"

rm -rf AppDir
mkdir -p AppDir/usr/bin AppDir/usr/lib AppDir/usr/etc

set +u  # GNUstep.sh reads variables it has not set
. "${LOCAL_PREFIX}/System/Library/Makefiles/GNUstep.sh"
set -u

# The app, installed into the prefix, so it sits in the GNUstep layout
# AppRun points GNUstep at. Only the app: the test bundle has no business in
# the image.
make -C Calculator
make -C Calculator install GNUSTEP_INSTALLATION_DOMAIN=SYSTEM

# The prefix's GNUstep hierarchies: the app, the libraries, the backend
# bundle, the theme, the tools GNUstep starts (gdnc, gpbs, make_services).
for domain in System Local; do
  if [ -d "${LOCAL_PREFIX}/$domain" ]; then
    mkdir -p "AppDir/usr/$domain"
    cp -Rp "${LOCAL_PREFIX}/$domain/"* "AppDir/usr/$domain/"
  fi
done
# What a GNUstep image does not need at run time.
rm -rf AppDir/usr/System/Library/Headers AppDir/usr/Local/Library/Headers \
       AppDir/usr/System/Library/Makefiles AppDir/usr/System/Library/Documentation

# libobjc2 and libdispatch live in the prefix's plain lib/, outside the
# GNUstep layout.
for lib in "${LOCAL_PREFIX}"/lib/libobjc.so.*.* ; do
  [ -f "$lib" ] || continue
  soname=$(basename "$lib")
  cp -p "$lib" AppDir/usr/lib/
  ln -sf "$soname" "AppDir/usr/lib/${soname%.*}"
  ln -sf "$soname" AppDir/usr/lib/libobjc.so
done
for dir in lib lib64; do
  if ls "${LOCAL_PREFIX}/$dir"/libdispatch.so* >/dev/null 2>&1; then
    cp -p "${LOCAL_PREFIX}/$dir"/libdispatch.so* AppDir/usr/lib/
    cp -p "${LOCAL_PREFIX}/$dir"/libBlocksRuntime.so* AppDir/usr/lib/ 2>/dev/null || true
    break
  fi
done

# The backend bundle under the names gnustep-gui looks for.
backend=$(find AppDir/usr -name "libgnustep-back-*.bundle" 2>/dev/null | head -n 1 || true)
if [ -n "$backend" ]; then
  ln -sfn "$(basename "$backend")" "$(dirname "$backend")/libgnustep-back.bundle"
  ln -sfn "$(basename "$backend")" "$(dirname "$backend")/back.bundle"
fi

# The opener, under both names GNUstep asks for: "open" is what the
# GSUnknownFileTool default names, "xdg-open" is NSWorkspace's built-in
# fallback. In the bundle's GNUstep Tools, which [NSTask launchPathForTool:]
# searches before $PATH, and in usr/bin. Without it the link in the Info
# panel does nothing inside the image.
mkdir -p AppDir/usr/System/Tools AppDir/usr/bin
for name in open xdg-open; do
  install -m 0755 Scripts/appimage/open "AppDir/usr/System/Tools/$name"
  install -m 0755 Scripts/appimage/open "AppDir/usr/bin/$name"
done

# Fonts, so the window lays out the same on a machine that has none (AppRun
# writes the fontconfig that finds them).
for dir in /usr/share/fonts/truetype/dejavu /usr/share/fonts/truetype/liberation; do
  if [ -d "$dir" ]; then
    mkdir -p "AppDir/usr/share/fonts/truetype/$(basename "$dir")"
    cp -Rp "$dir"/* "AppDir/usr/share/fonts/truetype/$(basename "$dir")/"
  fi
done

du -sh AppDir
app=$(find AppDir/usr -maxdepth 5 -name "Calculator.app" -type d | head -n 1)
[ -n "$app" ] || { echo "MISSING: Calculator.app" >&2; exit 1; }
echo "  $app"
for f in MainMenu.xib UDCalcView.xib ConversionWindow.xib UDTapeWindow.xib; do
  [ -f "$app/Resources/$f" ] || { echo "MISSING: $f" >&2; exit 1; }
done
# The theme AppRun selects: without it GNUstep falls back to its own look.
theme=$(find AppDir/usr -maxdepth 5 -name "Eau.theme" -type d | head -n 1)
if [ -z "$theme" ]; then
  echo "MISSING: Eau.theme (is eau in the GNUstep stack's COMPONENTS?)" >&2
  exit 1
fi
echo "  $theme"
