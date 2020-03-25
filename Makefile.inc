# Makefile include used by all other Makefiles

# -- library name
TARGET = nxos
NXOSDIR = nxos


# ELF Architecture
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
LINK = arm-none-eabi-ar
else
CC = gcc
AS = as
CXX = g++
LINK = ar
endif

# -- command to create directories
MKDIR = mkdir -p

# -- static library link options
LIBLDFLAGS = rcs

# -- systems (app) link options
SYSLDFLAGS = -T -Os --gc-sections --no-check-sections
#		'$LINK -o $TARGET -T %s -Os --gc-sections --no-check-sections '
#        '$SOURCES' % app_kernel_lds)

# Enable Debug Symbols by default
# -- compiler flags
#CFLAGS = $(addprefix -I, $(D_H)) -O2 -std=gnu99 -W -Wall -Wno-comment -g
CFLAGS = $(addprefix -I, $(D_H)) -std=gnu99 -W -Wall -Wno-comment -g

ifeq ($(PLATFORM),__UNIX__)
CFLAGS := $(CFLAGS) -fPIC
endif

#CXXFLAGS = $(addprefix -I, $(D_H)) -O2 -ffast-math -funroll-loops -fno-exceptions -fomit-frame-pointer -g -W -Wall -Wno-comment -g
CXXFLAGS = $(addprefix -I, $(D_H)) -ffast-math -funroll-loops -fno-exceptions -fomit-frame-pointer -g -W -Wall -Wno-comment -g

ifeq ($(PLATFORM),__UNIX__)
CXXFLAGS := $(CXXFLAGS) -fPIC
endif

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
# Debugger Support Flags
#
# If ARM Debugging is desired, the following flags must be defined:
# __NXOS__, __DBGENABLE__
#
# (__NXOS__ selects armdebug for NxOS)
#
#################################################################
CFLAGS := $(CFLAGS) -D__NXOS__ -D__DBGENABLE__

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
