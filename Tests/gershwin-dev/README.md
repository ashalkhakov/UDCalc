# Gershwin dev in Docker

Gershwin's unstable desktop (the `dev` branches), built from source in an
Ubuntu 24.04 image, for trying UDCalc on the real global menu bar. It runs
headless; you look at it over VNC.

```sh
Tests/gershwin-dev/run.sh build       # once, ~30-40 min
Tests/gershwin-dev/run.sh desktop     # then: open vnc://localhost:5900  (password: gershwin)
Tests/gershwin-dev/run.sh selftest    # Calculator --self-test, headless
Tests/gershwin-dev/run.sh shell       # a shell inside the running desktop
Tests/gershwin-dev/run.sh stop
```

`desktop` mounts this checkout read-only at `/src/UDCalc`, builds it out of
tree into `/tmp/udcalc-build` and starts the calculator in the session;
nothing is written into your checkout. To pick up a change, rebuild and
relaunch from `shell`:

```sh
pkill Calculator
cd /src/UDCalc/Calculator && make GNUSTEP_BUILD_DIR=/tmp/udcalc-build \
  && /tmp/udcalc-build/Calculator.app/Calculator &
```

GNUstep's Command key is the left Alt/Option key. Logs are in
`/tmp/gershwin-logs` inside the container.

## What is in the image besides Gershwin dev

Fixes that UDCalc needs and that are not merged yet. Each is skipped
automatically once it is in the tree, so the image keeps building after
they land:

- libs-gui `tableview-prototype-identifier`, from gnustep-patches (pinned
  commit `GNUSTEP_PATCHES_SHA`). Without it the calculator's window is empty:
  the nib with the RPN stack table does not load.
- libs-gui `scrollview-autohide-reentrancy`, `patches/` here: the same change
  as in gnustep-patches, regenerated against Gershwin's own patched
  `NSScrollView.m`. Without it the default (non-Eau) theme crashes.
- Eau `fix/menu-action-state-push` (gershwin-eau-theme#31), fetched from the
  fork branch. Without it a mode chosen from the global menu leaves the
  check mark on the old one.

To see stock dev behaviour, leave fixes out with empty build arguments:
`docker build --build-arg EAU_FIX_REF= -t gershwin-dev-stock Tests/gershwin-dev`
(Eau fix), `--build-arg GNUSTEP_PATCHES_SHA=` (both libs-gui fixes; the
calculator window is then empty).

To rebuild against newer dev, `docker build --no-cache` (the clone of
gershwin-developer is cached otherwise).
