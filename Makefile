# Wrapper for BSD make — delegates to GNU make with GNUmakefile.
#
# On BSD systems (e.g. GershwinBSD, FreeBSD), 'make' is BSD make,
# which does not read GNUmakefile.  This thin wrapper forwards all
# targets to gmake so that a plain 'make' just works.
#
# If you already have GNU make as 'make' (most Linux distros), this
# file is harmless — GNU make prefers GNUmakefile over Makefile.

GMAKE ?= gmake

.DEFAULT:
	$(GMAKE) -f GNUmakefile $(MAKECMDGOALS)

all:
	$(GMAKE) -f GNUmakefile all

clean:
	$(GMAKE) -f GNUmakefile clean

# Tests live in a separate makefile (GNUmakefile.tests) because they
# require special linker flags for gnustep-xctest.
check:
	$(GMAKE) -f GNUmakefile.tests check
