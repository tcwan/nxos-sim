#Top level makefile
TOP = .
# ---------------------------------
include $(TOP)/Makefile.inc
# ---------------------------------

DIRS = nxos/systems/*/
DOCDIRS = $(NXOSDIR)/doc/base

# meta builds

.PHONY: libs \
		clean clean-libs  \
		all docs clean-docs

default: all

nxos-libs:: $(NXOSLIBS)

libs:: nxos-libs

clean:: 
	make -f makefile.systems -C $(NXOSSYSDIR) clean

#	@echo "Cleaning ..." ${DIRS}
#	@for i in ${DIRS}; \
#	do \
#	make -f makefile.proj -C $${i} clean; \
#	done

clean-nxos-libs::
	make -f makefile.base -C $(NXOSLIBDIR) clean-libs

clean-libs:: clean-nxos-libs


all:: $(NXOSLIBS) $(CPULATORINC)
	make -f makefile.systems -C $(NXOSSYSDIR)
	
#	@echo "Making ..." ${DIRS}
#	@for i in ${DIRS}; \
#	do \
#	make -f makefile.proj -C $${i}; \
#	done

# Actual builds
# -- handle directory names with or without training slash
nxos/systems/*/:: nxos-libs
	make -f makefile.systems -C $(NXOSSYSDIR) $(basename $(notdir $(@:%/=%)));

nxos/systems/*:: nxos-libs
	make -f makefile.systems -C $(NXOSSYSDIR) $(basename $(notdir $(@:%/=%)));

# disable subproject builds to make it easier for makefile.systems
#nxos/systems/*/*/::
#	make -f makefile.systems -C $(NXOSSYSDIR) $(basename $(notdir $(@:%/=%)));
#
#nxos/systems/*/*::
#	make -f makefile.systems -C $(NXOSSYSDIR) $(basename $(notdir $(@:%/=%)));


docs::
	cd $(NXOSDIR)/base; \
	doxygen

clean-docs::
	rm -rf $(DOCDIRS)

$(NXOSLIBS)::
	make -f makefile.base -C $(NXOSLIBDIR) libs
