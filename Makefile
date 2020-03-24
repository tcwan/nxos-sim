#Top level makefile
include Makefile.inc

DIRS = nxos/systems/*
NXOSDIR = nxos

NXOSLIBS = $(NXOSDIR)/lib$(TARGET).a

# meta builds

.PHONY: libs \
		clean clean-libs \
		all docs

nxos-libs:: $(NXOSLIBS)


libs:: nxos-libs

clean::
	@echo "Cleaning ..." ${DIRS}
	@for i in ${DIRS}; \
	do \
	make -f Makefile.proj -C $${i} clean; \
	done

clean-nxos-libs::
	make -f makefile.base -C $(NXOSDIR)/base clean-libs

clean-libs:: clean-nxos-libs


all:: $(NXOSLIBS)
	@echo "Making ..." ${DIRS}
	@for i in ${DIRS}; \
	do \
	make -f Makefile.proj -C $${i}; \
	done

systems/*::
	make -f Makefile.proj -C $(NXOSDIR)/$@;
	
systems/*/*::
	make -f Makefile.subproject -C $(NXOSDIR)/$@;

docs::
	cd $(NXOSDIR)/base; \
	doxygen
	
# Actual builds
$(NXOSLIBS)::
	make -f makefile.base -C $(NXOSDIR)/base libs
