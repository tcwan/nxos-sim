# This is the make file for the GDB debugger 
# http://nxtgcc.sf.net

CFLAGS =	-O2 -g -fmessage-length=0
CDEFS =  -DMINGW32
CLIBS = -lfantom -lws2_32 -L.

SRC = 		main.c

OBJS =		main.o 

LIBS =

TARGET =	main.exe

$(TARGET):	$(OBJS)
	$(CC) -o $(TARGET) $(OBJS) $(CFALGS) $(CDEFS) $(CLIBS)

all:	$(TARGET) info

#all:	$(OBJS)

info:
	@echo Now you can start the NXTGCC GDB Fantom debugger by right-clicking on the project and select Run AS Local c/C++ Application

clean:
	rm -f $(OBJS) $(TARGET)
