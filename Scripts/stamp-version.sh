#!/bin/bash
# Write a version into everything that carries one, so that a tagged build
# says what it is. Ported from HomeRow's (after XFormsKit's).
#
#   ./Scripts/stamp-version.sh v0.1.0
#
# Apple's keys must be numeric ("0.1.0"); GNUstep's take the tag as it is
# minus the "v" ("0.1.0-rc1"). Sparkle compares CFBundleVersion
# (CURRENT_PROJECT_VERSION) to tell an update from what is installed.
set -euo pipefail

version=${1:-}
if [ -z "$version" ]; then
    echo "usage: $0 <version>" >&2
    exit 2
fi

display=${version#v}
numeric=$(printf '%s' "$display" | sed -n 's/^\([0-9][0-9.]*\).*/\1/p' | sed 's/\.$//')
if [ -z "$numeric" ]; then
    echo "$0: '$version' has no leading number; using 0.0.0 where Apple needs one" >&2
    numeric=0.0.0
fi

root=$(cd "$(dirname "$0")/.." && pwd)

python3 - "$root" "$display" "$numeric" <<'PY'
import re, sys
root, display, numeric = sys.argv[1:4]

def stamp(path, patterns):
    text = open(path, encoding="utf-8").read()
    for pattern, value in patterns:
        text, n = re.subn(pattern, lambda m: m.group(1) + value + m.group(2), text)
        if n == 0:
            raise SystemExit("%s: nothing matched %s" % (path, pattern))
    open(path, "w", encoding="utf-8").write(text)

stamp(root + "/Calculator/CalculatorInfo.plist",
      [(r'(ApplicationRelease = ")[^"]*(";)', display),
       (r'(FullVersionID = ")[^"]*(";)', display)])
stamp(root + "/Calculator/GNUmakefile", [(r'(?m)^(VERSION = ).*()$', display)])
stamp(root + "/Calculator.xcodeproj/project.pbxproj",
      [(r'(\bMARKETING_VERSION = )[^;]*(;)', numeric),
       (r'(\bCURRENT_PROJECT_VERSION = )[^;]*(;)', numeric)])
PY

echo "stamped $display, and $numeric where Apple parses it"
