#!/bin/bash
# The self-test's scenarios that pass on both systems, in a fresh home;
# before signing and after.
set -euo pipefail
export HOME=$(mktemp -d)
export CFFIXED_USER_HOME="$HOME"
for scenario in Arithmetic Updates; do
  "$1/Contents/MacOS/Calculator" --self-test "$scenario"
done
