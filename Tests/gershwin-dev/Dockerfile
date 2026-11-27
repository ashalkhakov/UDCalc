# Gershwin, unstable (the dev branches), built from source, with the fixes
# UDCalc needs that are not merged yet. Builds natively on arm64 (Apple
# Silicon) and x86_64. See README.md; normally driven by ./run.sh.
FROM ubuntu:24.04

ARG GERSHWIN_DEVELOPER_REF=dev
# gnustep-patches commit carrying libs-gui/tableview-prototype-identifier.
# Empty: leave the libs-gui fixes out.
ARG GNUSTEP_PATCHES_SHA=945c2fe719e19efb2324ad87c9ad9212ae1c5189

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

# Everything after this fetches packages over HTTPS: over plain HTTP the
# Ubuntu mirrors' downloads can arrive corrupt or cut short (hash sum
# mismatches) behind some networks, and the build fails at random packages.
# The few packages fetched before there are certificates to check HTTPS
# with are retried instead.
RUN printf 'Acquire::Retries "10";\nAcquire::http::Pipeline-Depth "0";\n' > /etc/apt/apt.conf.d/80-retries \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates git make sudo patch \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i 's|http://|https://|g' /etc/apt/sources.list.d/ubuntu.sources

# The whole desktop: gershwin-developer installs its own build dependencies
# (bootstrap.sh), checks out every repository on the dev branch where it has
# one, and builds and installs the System domain. Takes a while.
RUN umask 022 \
 && git clone -b "$GERSHWIN_DEVELOPER_REF" https://github.com/gershwin-desktop/gershwin-developer /Developer \
 && cd /Developer \
 && BRANCH=dev SELF_UPDATE=0 make install \
 && rm -rf /var/lib/apt/lists/*

COPY patches/ /tmp/udcalc-patches/

# Unmerged fixes. Each step skips a fix that is already in the tree (it
# reverse-applies), so the image keeps building after they land upstream.
# libs-gui goes back into the System domain over Gershwin's own copy: in the
# default (Local) domain there would be two, and a login shell's library
# path finds the unpatched System one first.
RUN set -e; umask 022; \
    applyp() { if patch -p1 -F0 -R --dry-run -s -f < "$1" >/dev/null 2>&1; then \
                 echo "already applied: $1"; \
               else patch -p1 -F0 -s < "$1"; echo "applied: $1"; fi; }; \
    cd /Developer/Library/Sources/libs-gui; \
    if [ -n "$GNUSTEP_PATCHES_SHA" ]; then \
      mkdir /tmp/gnustep-patches && git -C /tmp/gnustep-patches init -q \
        && git -C /tmp/gnustep-patches fetch -q --depth 1 https://github.com/ashalkhakov/gnustep-patches "$GNUSTEP_PATCHES_SHA" \
        && git -C /tmp/gnustep-patches checkout -q FETCH_HEAD; \
      applyp /tmp/gnustep-patches/libs-gui/tableview-prototype-identifier/0001-tableview-prototype-identifier.patch; \
      applyp /tmp/udcalc-patches/libs-gui-scrollview-autohide-reentrancy.patch; \
    fi; \
    . /System/Library/Makefiles/GNUstep.sh; \
    cd /Developer/Library/Sources/libs-gui && make -j"$(nproc)" >/tmp/libs-gui.log 2>&1 && make install GNUSTEP_INSTALLATION_DOMAIN=SYSTEM >>/tmp/libs-gui.log 2>&1 \
      || { tail -40 /tmp/libs-gui.log; exit 1; }; \
    rm -rf /tmp/gnustep-patches /tmp/udcalc-patches

# What the desktop needs to run without a screen: a virtual display, a VNC
# server to look at it, and the tools the self-test and debugging use.
RUN apt-get update \
 && apt-get install -y --no-install-recommends xvfb x11vnc dbus-x11 xdotool x11-utils \
      imagemagick gdb fonts-dejavu \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash gershwin \
 && echo 'gershwin ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/gershwin \
 && echo '. /System/Library/Makefiles/GNUstep.sh' >> /home/gershwin/.bashrc

COPY desktop.sh /usr/local/bin/gershwin-desktop
RUN chmod 755 /usr/local/bin/gershwin-desktop

USER gershwin
WORKDIR /home/gershwin
EXPOSE 5900
CMD ["gershwin-desktop"]
