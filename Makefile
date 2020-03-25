#Top level makefile
TOP = .
# ---------------------------------
include $(TOP)/Makefile.inc
# ---------------------------------

DIRS = nxos/systems/*/

# meta builds

.PHONY: libs \
		clean clean-libs \
		all docs

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


all:: $(NXOSLIBS)
	make -f makefile.systems -C $(NXOSSYSSDIR)
	
#	@echo "Making ..." ${DIRS}
#	@for i in ${DIRS}; \
#	do \
#	make -f makefile.proj -C $${i}; \
#	done

# Actual builds

nxos/systems/*::
	make -f makefile.systems -C $(NXOSSYSSDIR) $@;

nxos/systems/*/*::
	make -f makefile.systems -C $(NXOSSYSSDIR) $@;

docs::
	cd $(NXOSDIR)/base; \
	doxygen

$(NXOSLIBS)::
	make -f makefile.base -C $(NXOSLIBDIR) libs
