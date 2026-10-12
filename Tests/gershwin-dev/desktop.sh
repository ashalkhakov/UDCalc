#!/bin/bash
# Runs inside the container: a Gershwin session on a virtual display, shown
# over VNC on port 5900. If UDCalc is mounted at /src/UDCalc it is built
# (out of tree, in /tmp/udcalc-build) and started in the session. Stays up
# until the container is stopped.
# GNUstep.sh reads $ZSH_VERSION unguarded, so source it before set -u.
. /System/Library/Makefiles/GNUstep.sh
set -u

export DISPLAY=:1
GEOMETRY="${GEOMETRY:-1440x900}"
VNC_PASSWORD="${VNC_PASSWORD:-gershwin}"
LOGS=/tmp/gershwin-logs
mkdir -p "$LOGS"

rm -f /tmp/.X1-lock
Xvfb :1 -screen 0 "${GEOMETRY}x24" -nolisten tcp >"$LOGS/xvfb.log" 2>&1 &
for _ in $(seq 50); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.1; done

eval "$(dbus-launch --sh-syntax)"
export DBUS_SESSION_BUS_ADDRESS
gpbs >"$LOGS/gpbs.log" 2>&1 &
/System/Library/CoreServices/Applications/Menu.app/Menu >"$LOGS/menu.log" 2>&1 &
sleep 2
/System/Library/CoreServices/Applications/WindowManager.app/WindowManager >"$LOGS/wm.log" 2>&1 &
sleep 2
/System/Applications/Workspace.app/Workspace >"$LOGS/workspace.log" 2>&1 &

mkdir -p ~/.vnc && x11vnc -storepasswd "$VNC_PASSWORD" ~/.vnc/passwd >/dev/null 2>&1
x11vnc -display :1 -rfbport 5900 -rfbauth ~/.vnc/passwd -forever -shared -quiet \
  >"$LOGS/x11vnc.log" 2>&1 &

if [ -f /src/UDCalc/Calculator/GNUmakefile ]; then
  echo "Building UDCalc..."
  if (cd /src/UDCalc/Calculator && make GNUSTEP_BUILD_DIR=/tmp/udcalc-build >"$LOGS/udcalc-build.log" 2>&1); then
    sleep 4
    /tmp/udcalc-build/Calculator.app/Calculator >"$LOGS/calculator.log" 2>&1 &
  else
    echo "UDCalc did not build; see $LOGS/udcalc-build.log"
  fi
fi

echo "Gershwin is up: connect to vnc://localhost:5900 (password: $VNC_PASSWORD)."
echo "Logs are in $LOGS inside the container."
wait
