#!/bin/bash
# The self-test's scenarios that pass on both systems.
set -euo pipefail
for scenario in Arithmetic Updates; do
  timeout 300 xvfb-run -a -s "-screen 0 1280x1024x24" "$1" --self-test "$scenario"
done
