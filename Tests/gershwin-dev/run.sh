#!/bin/sh
# Gershwin (dev) in Docker, for trying UDCalc on the real desktop.
#
#   Tests/gershwin-dev/run.sh build      build the image (once; ~30-40 min)
#   Tests/gershwin-dev/run.sh desktop    start the desktop with UDCalc in it;
#                                        connect to vnc://localhost:5900
#   Tests/gershwin-dev/run.sh selftest [filter]
#                                        run Calculator --self-test headless
#   Tests/gershwin-dev/run.sh shell      a shell in the running desktop
#   Tests/gershwin-dev/run.sh stop       stop the desktop
#
# Your UDCalc checkout is mounted read-only at /src/UDCalc and built out of
# tree into /tmp/udcalc-build, so edits on the Mac are built from inside the
# container and nothing is written into the checkout. VNC_PASSWORD (default
# "gershwin") and GEOMETRY (default 1440x900) are passed through.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
IMAGE="${IMAGE:-gershwin-dev}"
NAME="${NAME:-gershwin-dev}"

case "${1:-}" in
  build)
    docker build -t "$IMAGE" "$HERE"
    ;;
  desktop)
    docker rm -f "$NAME" >/dev/null 2>&1 || true
    docker run -d --name "$NAME" --shm-size=1g \
      -p 127.0.0.1:5900:5900 \
      -e VNC_PASSWORD="${VNC_PASSWORD:-gershwin}" -e GEOMETRY="${GEOMETRY:-1440x900}" \
      -v "$REPO:/src/UDCalc:ro" "$IMAGE" >/dev/null
    echo "Starting; connect to vnc://localhost:5900 (password: ${VNC_PASSWORD:-gershwin})."
    echo "On macOS: open vnc://localhost:5900"
    docker logs -f "$NAME" &
    sleep 20; kill $! 2>/dev/null || true
    ;;
  selftest)
    shift
    docker run --rm --shm-size=1g -v "$REPO:/src/UDCalc:ro" "$IMAGE" bash -lc \
      '. /System/Library/Makefiles/GNUstep.sh && cd /src/UDCalc/Calculator \
       && make GNUSTEP_BUILD_DIR=/tmp/udcalc-build >/tmp/udcalc-build.log 2>&1 \
       || { tail -30 /tmp/udcalc-build.log; exit 1; }; \
       APP=/tmp/udcalc-build/Calculator.app/Calculator /src/UDCalc/Tests/run-self-test.sh "$@"' \
      selftest "$@"
    ;;
  shell)
    docker exec -it "$NAME" bash -l
    ;;
  stop)
    docker rm -f "$NAME"
    ;;
  *)
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
    ;;
esac
