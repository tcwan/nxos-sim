# Makefile include used by all other Makefiles
# -- TOP must be defined in enclosing makefile

# -- library name and paths
TARGET = nxos
NXOSDIR = $(TOP)/nxos
NXOSLIBS = $(NXOSDIR)/lib$(TARGET).a

# -- project path
NXOSOBJDIR = $(NXOSDIR)/obj
NXOSLIBDIR = $(NXOSDIR)/base
NXOSSYSDIR = $(NXOSDIR)/systems

# -- dummy temporary libs
LIBDRIVERS = $(NXOSOBJDIR)/drivers.built
LIBLIB = $(NXOSOBJDIR)/lib.built

# -- executable related
NXOSLD = $(NXOSSYSDIR)/nxos-sim.ld
EXECEXT = .elf

# -- paths
# -- library directory
D_BIN = $(NXOSDIR)

# -- object directory
D_OBJ = $(NXOSOBJDIR)

# -- Configuration constants
# -- ELF Architecture
CPUARCH = arm7tdmi

# -- platform
ifeq ($(OS),Windows_NT)
# WIN32
PLATFORM = __MINGW__
else
# UNIX
PLATFORM = __UNIX__
endif

# -- compiler
ifeq ($(PLATFORM),__UNIX__)
CC = arm-none-eabi-gcc
AS = arm-none-eabi-as
CXX = arm-none-eabi-g++
AR = arm-none-eabi-ar
LINKER = arm-none-eabi-ld
MAKE = make
else
CC = gcc
AS = as
CXX = g++
AR = ar
LINKER = ld
MAKE = make
endif

# -- command to create directories
MKDIR = mkdir -p

# -- static library link options
LIBLDFLAGS = -rcs

# -- systems (app) link options
# -- the parameter order matters! (-l should appear last with the libraries in sequence of resolution)
# -- make sure that '-o' is the last parameter for SYSLDFLAGS
#
# -- evaluate libgcc path
LIBGCCDIR = $(dir $(shell $(CC) -print-libgcc-file-name))
SYSLDFLAGS = -L$(NXOSDIR) -L$(NXOSOBJDIR) -L$(LIBGCCDIR) -T $(NXOSLD) -Os --gc-sections --no-check-sections -o
SYSLDLIBS = -lnxos -lgcc

# -- compiler flags
#CFLAGS = $(addprefix -I, $(D_H)) -O2 -std=gnu99 -W -Wall -Wno-comment -g
# Enable Debug Symbols by default
CFLAGS = -std=gnu99 -W -Wall -Wno-comment -g

ifeq ($(PLATFORM),__UNIX__)
CFLAGS := $(CFLAGS) -fPIC
endif

#CXXFLAGS = $(addprefix -I, $(D_H)) -O2 -ffast-math -funroll-loops -fno-exceptions -fomit-frame-pointer -g -W -Wall -Wno-comment -g
# Enable Debug Symbols by default
CXXFLAGS = -ffast-math -funroll-loops -fno-exceptions -fomit-frame-pointer -g -W -Wall -Wno-comment -g

ifeq ($(PLATFORM),__UNIX__)
CXXFLAGS := $(CXXFLAGS) -fPIC
endif

# Enable Debug Symbols by default
ASMFLAGS = -Wall -g

# ---------------------------------
# NxOS specific compiler flags
# Note1: -mthummb-interwork (ARM-Thumb Interworking) is not enabled
# Note2: -mthumb (generate Thumb code) is not enabled
# ---------------------------------
CFLAGS := $(CFLAGS) -mcpu=$(CPUARCH) -Os -Wextra -Werror -Wno-div-by-zero \
-Wfloat-equal -Wshadow -Wpointer-arith -Wbad-function-cast -Wmissing-prototypes -ffreestanding \
-fsigned-char -ffunction-sections -fdata-sections -fomit-frame-pointer -msoft-float -ggdb

CXXFLAGS := $(CXXFLAGS) -mcpu=$(CPUARCH)

ASMFLAGS := $(ASMFLAGS) -mcpu=$(CPUARCH) -W -Werror -Os

#################################################################
# NxOS Configuration Flags
#
# If ARM Debugging is desired, the following flag must be defined:
# __DBGENABLE__
#
# Note: The following flags are MUTUALLY EXCLUSIVE (only one should be defined)
# __DE1SOC__ configures NxOS for the CPUlator DE1-SoC board configuration
# __LEGONXT__ configures NxOS for the LEGO Mindstorms NXT board configuration
#
# If __DE1SOC__ is enabled, configure __CPULATOR__ to configure Interrupts etc.
# for the simulator environment to reduce the system overheads.
# Otherwise hardware platform is assumed.
#
#################################################################
CFLAGS := $(CFLAGS) -D__DBGENABLE__ -D__DE1SOC__ -D__CPULATOR__
ASMFLAGS := $(ASMFLAGS) -D__DBGENABLE__ -D__DE1SOC__ -D__CPULATOR__

# ---------------------------------
#   file suffixes
# ---------------------------------
E_H = .h
E_C = .c
E_CXX = .cpp
E_ASM = .S

# -- object suffix
E_OBJ = .o

# -- static library suffix
ifeq ($(OS),Windows_NT)
E_BIN = .a
else
E_BIN = .a
endif

# ---------------------------------
#   commands
# ---------------------------------

_BASH = 1

ifeq ($(OS),Windows_NT)
ifdef ComSpec
_BASH = 0
endif
endif

ifeq ($(_BASH),0)
# -- cmd
RM = cmd /c del /f
else
# -- sh (MSYS)
RM = rm -rf
endif

# -- wrap compiler arguments
ifeq ($(OS),Windows_NT)
# -- too long command line workaround
define wrap
	echo $2 > args
	$1 @args
	-$(RM) args
endef
else
define wrap
	$1 $2
endef
endif

# -- optional final tools
define final
endef
