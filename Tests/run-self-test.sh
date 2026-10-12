#!/bin/sh
# Runs the calculator's self-test (Calculator/UDSelfTest.m) headless, the way
# CI would: a virtual X display, a throwaway home so the user's own defaults
# (mode, RPN, paper tape) neither leak in nor get overwritten.
#
#   Tests/run-self-test.sh                       every scenario
#   Tests/run-self-test.sh "menu"                features/scenarios matching "menu"
#   FIRST_RESPONDER=1 Tests/run-self-test.sh     leave menu items on the First
#                                                Responder (no explicit targets)
#
# Exits with the number of failed steps. Build first: (cd Calculator && make).
# On a running Gershwin desktop, run the app directly instead to test against
# the real Menu.app:  Calculator.app/Calculator --self-test
set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
APP="${APP:-$HERE/Calculator/Calculator.app/Calculator}"
FILTER="${1:-}"

if [ ! -x "$APP" ]; then
    echo "error: $APP not built; run make in Calculator/ first" >&2
    exit 2
fi

TESTHOME="$(mktemp -d "${TMPDIR:-/tmp}/udcalc-selftest.XXXXXX")"
trap 'rm -rf "$TESTHOME"' EXIT INT TERM

set -- --self-test
[ -n "$FILTER" ] && set -- "$@" "$FILTER"
[ "${FIRST_RESPONDER:-0}" = "1" ] && set -- "$@" -UDMenusUseFirstResponder YES

# Without a display, start one, with a pasteboard server for Copy/Paste;
# with one (a desktop session), use it as it is.
if [ -z "${DISPLAY:-}" ]; then
    env HOME="$TESTHOME" GNUSTEP_USER_ROOT="$TESTHOME/GNUstep" \
        xvfb-run -a -s "-screen 0 1280x1024x24" \
        sh -c '(command -v gpbs >/dev/null && gpbs >/dev/null 2>&1 &); sleep 1; exec "$0" "$@"' "$APP" "$@"
    exit $?
fi
env HOME="$TESTHOME" GNUSTEP_USER_ROOT="$TESTHOME/GNUstep" "$APP" "$@"
