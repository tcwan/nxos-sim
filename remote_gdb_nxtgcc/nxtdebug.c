#include "nxtdebug.h"

UBYTE usbOut[64] = { 0 };
ULONG usbOutLng;
UBYTE usbIn[64] = { 0 };
ULONG usbInLng;
UBYTE verQueLng = 2;
UBYTE versionQuery[2] = { 0x01, 0x88 };

UBYTE verMsgLng = 7;
UBYTE versionMsg[7] = { 0x02, 0x88, 0x00, 0x7C, 0x01, 0x1C, 0x01 };

ULONG mscnt = 0;

//extern void putDebugChar();
//extern int getDebugChar();
static void handle_exception(unsigned long *registers);

void waitOneMs() {
	ULONG USBTimeOut2 = ((*AT91C_PITC_PIIR) & AT91C_PITC_CPIV);

	while (!((USB_TIMEOUT < ((((*AT91C_PITC_PIIR) & AT91C_PITC_CPIV)
			- USBTimeOut2) & AT91C_PITC_CPIV)))) {
	};

}

// Wire connection and answering Fantom with USB configuration info
UWORD usbOK() {
	if (dUsbCheckConnection() == TRUE && dUsbIsConfigured() == TRUE)
		return TRUE;
	else
		return FALSE;
}

// non-blocking
void putDebugChar(int ch) {
	//ON(3);
	waitOneMs();
	while (!usbOK()) {
	};
	usbOutLng = dUsbWrite((UBYTE *) &ch, 1);
}

// blocking
int getDebugChar() {
	usbInLng = 0;

	while (1) {
		waitOneMs();

		while (!usbOK()) {
		};

		usbInLng = dUsbRead(usbIn, sizeof(usbIn));
		// Fantom will ask for a version when the NXT object is created from the iterator
		if (usbInLng == 2) {
			if (memcmp(usbIn, versionQuery, verQueLng) == 0) {
				dUsbWrite(versionMsg, verMsgLng);
				//ON(2);
			}
		}

		// wait for one char
		if (usbInLng == 1)
			break;
	}

	return (int) usbIn[0];
}

/*
 *  Trigger a breakpoint exception.
 */
__ramfunc void bsp_breakpoint(void) {
	//    HAL_BREAKPOINT(_x_bsp_breakinsn);
	//asm volatile (".word 0xE7FFDEFE");
	NXTGCCBREAK;

}

// this is called from main to get it to into undefined exception mode
__ramfunc void debuggdb() {
	START();
	ON(1);
	//ON(4);
	bsp_breakpoint();//datAbortHere();
	//ON(1);
	STOP();
}
/* BUFMAX defines the maximum number of characters in inbound/outbound buffers*/
/* at least NUMREGBYTES*2 are needed for register packets */
//#define BUFMAX 2048
#define BUFMAX 512
static char remcomInBuffer[BUFMAX];
static char remcomOutBuffer[BUFMAX];
// GDB exception handler
// this is called from the undefined exception mode and runs on the UND stack
__ramfunc void debuggogo(unsigned int* exceptionRegisers) {

	//while(!dUsbCheckConnection() == TRUE);
	//ON(2);
	//while(!dUsbIsConfigured() == TRUE);

	mscnt = 0;
	while (1) {
		waitOneMs();

		// cCommCtrl(); // this line works in itself

		if (dUsbCheckConnection() == TRUE) {
			if (dUsbIsConfigured() == TRUE) {
				usbInLng = dUsbRead(usbIn, sizeof(usbIn));
				if (usbInLng > 0) {
					//ON(2);
				}
				if (usbInLng == 2) {
					if (memcmp(usbIn, versionQuery, verQueLng) == 0) {
						dUsbWrite(versionMsg, verMsgLng);

						waitOneMs();
						waitOneMs();
						unsigned long testvar = 0;

						//handle_exception((unsigned long *)exceptionRegisers);
						// Not coming back
						handle_exception((unsigned long *) exceptionRegisers);
						STOP();
						UBYTE valgo[64] = { 3 };
						//UBYTE valgo = 1;
						ULONG lnggo = 2;
						//						for (ULONG ii = 0; ii < lnggo; lnggo++) {
						//							valgo[ii] = (UBYTE) ii;
						//						}
						while (1) {
							waitOneMs();
							while (!usbOK()) {
							};
							if (mscnt++ == 5000) {
								//ON(2);
								mscnt = 0;
								//dUsbWrite(&valgo, lnggo);
								putDebugChar(valgo[0]);
								//dUsbWrite(valgo, lnggo);
							}
						}
					}
				}
			}
		}
	}

}

// The original Sparc Stub

/****************************************************************************

 THIS SOFTWARE IS NOT COPYRIGHTED

 HP offers the following for use in the public domain.  HP makes no
 warranty with regard to the software or it's performance and the
 user accepts the software "AS IS" with all faults.

 HP DISCLAIMS ANY WARRANTIES, EXPRESS OR IMPLIED, WITH REGARD
 TO THIS SOFTWARE INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

 ****************************************************************************/

/****************************************************************************
 *  Header: remcom.c,v 1.34 91/03/09 12:29:49 glenne Exp $
 *
 *  Module name: remcom.c $
 *  Revision: 1.34 $
 *  Date: 91/03/09 12:29:49 $
 *  Contributor:     Lake Stevens Instrument Division$
 *
 *  Description:     low level support for gdb debugger. $
 *
 *  Considerations:  only works on target hardware $
 *
 *  Written by:      Glenn Engel $
 *  ModuleState:     Experimental $
 *
 *  NOTES:           See Below $
 *
 *  Modified for SPARC by Stu Grossman, Cygnus Support.
 *
 *  This code has been extensively tested on the Fujitsu SPARClite demo board.
 *
 *  To enable debugger support, two things need to happen.  One, a
 *  call to set_debug_traps() is necessary in order to allow any breakpoints
 *  or error conditions to be properly intercepted and reported to gdb.
 *  Two, a breakpoint needs to be generated to begin communication.  This
 *  is most easily accomplished by a call to breakpoint().  Breakpoint()
 *  simulates a breakpoint by executing a trap #1.
 *
 *************
 *
 *    The following gdb commands are supported:
 *
 * command          function                               Return value
 *
 *    g             return the value of the CPU registers  hex data or ENN
 *    G             set the value of the CPU registers     OK or ENN
 *
 *    mAA..AA,LLLL  Read LLLL bytes at address AA..AA      hex data or ENN
 *    MAA..AA,LLLL: Write LLLL bytes at address AA.AA      OK or ENN
 *
 *    c             Resume at current address              SNN   ( signal NN)
 *    cAA..AA       Continue at address AA..AA             SNN
 *
 *    s             Step one instruction                   SNN
 *    sAA..AA       Step one instruction from AA..AA       SNN
 *
 *    k             kill
 *
 *    ?             What was the last sigval ?             SNN   (signal NN)
 *
 * All commands and responses are sent with a packet which includes a
 * checksum.  A packet consists of
 *
 * $<packet info>#<checksum>.
 *
 * where
 * <packet info> :: <characters representing the command or response>
 * <checksum>    :: < two hex digits computed as modulo 256 sum of <packetinfo>>
 *
 * When a packet is received, it is first acknowledged with either '+' or '-'.
 * '+' indicates a successful transfer.  '-' indicates a failed transfer.
 *
 * Example:
 *
 * Host:                  Reply:
 * $m0,10#2a               +$00010203040506070809101112131415#42
 *
 ****************************************************************************/

//#include <string.h>
#include <signal.h>

/************************************************************************
 *
 * external low-level support routines
 */

//extern void putDebugChar();	/* write a single character      */
//extern int getDebugChar();	/* read and return a single char */

/************************************************************************/

static int initialized = 0; /* !0 means we've been initialized */

static void set_mem_fault_trap();

static const char hexchars[] = "0123456789abcdef";

#define NUMREGS 18//72
/* Number of bytes of registers.  */
#define NUMREGBYTES (NUMREGS * 4)
enum regnames {
	R0, //0
	R1, //1
	R2, //2
	R3, //3
	R4, //4
	R5, //5
	R6, //6
	R7, //7
	R8, //8
	R9, //9
	R10, //10
	R11, //11
	R12, //12
	R13, //13
	SP, //13
	LR, //14
	PC, //15
	CPSR = 0x19
//25
};

/***************************  ASSEMBLY CODE MACROS *************************/
/* 									   */

extern void trap_low();
//
//asm("
//	.reserve trapstack, 1000 * 4, \"bss\", 8
//
//	.data
//	.align	4
//
//in_trap_handler:
//	.word	0
//
//	.text
//	.align 4
//
//! This function is called when any SPARC trap (except window overflow or
//! underflow) occurs.  It makes sure that the invalid register window is still
//! available before jumping into C code.  It will also restore the world if you
//! return from handle_exception.
//
//	.globl _trap_low
//_trap_low:
//	mov	%psr, %l0
//	mov	%wim, %l3
//
//	srl	%l3, %l0, %l4		! wim >> cwp
//	cmp	%l4, 1
//	bne	window_fine		! Branch if not in the invalid window
//	nop
//
//! Handle window overflow
//
//	mov	%g1, %l4		! Save g1, we use it to hold the wim
//	srl	%l3, 1, %g1		! Rotate wim right
//	tst	%g1
//	bg	good_wim		! Branch if new wim is non-zero
//	nop
//
//! At this point, we need to bring a 1 into the high order bit of the wim.
//! Since we don't want to make any assumptions about the number of register
//! windows, we figure it out dynamically so as to setup the wim correctly.
//
//	not	%g1			! Fill g1 with ones
//	mov	%g1, %wim		! Fill the wim with ones
//	nop
//	nop
//	nop
//	mov	%wim, %g1		! Read back the wim
//	inc	%g1			! Now g1 has 1 just to left of wim
//	srl	%g1, 1, %g1		! Now put 1 at top of wim
//	mov	%g0, %wim		! Clear wim so that subsequent save
//	nop				!  won't trap
//	nop
//	nop
//
//good_wim:
//	save	%g0, %g0, %g0		! Slip into next window
//	mov	%g1, %wim		! Install the new wim
//
//	std	%l0, [%sp + 0 * 4]	! save L & I registers
//	std	%l2, [%sp + 2 * 4]
//	std	%l4, [%sp + 4 * 4]
//	std	%l6, [%sp + 6 * 4]
//
//	std	%i0, [%sp + 8 * 4]
//	std	%i2, [%sp + 10 * 4]
//	std	%i4, [%sp + 12 * 4]
//	std	%i6, [%sp + 14 * 4]
//
//	restore				! Go back to trap window.
//	mov	%l4, %g1		! Restore %g1
//
//window_fine:
//	sethi	%hi(in_trap_handler), %l4
//	ld	[%lo(in_trap_handler) + %l4], %l5
//	tst	%l5
//	bg	recursive_trap
//	inc	%l5
//
//	set	trapstack+1000*4, %sp	! Switch to trap stack
//
//recursive_trap:
//	st	%l5, [%lo(in_trap_handler) + %l4]
//	sub	%sp,(16+1+6+1+72)*4,%sp	! Make room for input & locals
// 					! + hidden arg + arg spill
//					! + doubleword alignment
//					! + registers[72] local var
//
//	std	%g0, [%sp + (24 + 0) * 4] ! registers[Gx]
//	std	%g2, [%sp + (24 + 2) * 4]
//	std	%g4, [%sp + (24 + 4) * 4]
//	std	%g6, [%sp + (24 + 6) * 4]
//
//	std	%i0, [%sp + (24 + 8) * 4] ! registers[Ox]
//	std	%i2, [%sp + (24 + 10) * 4]
//	std	%i4, [%sp + (24 + 12) * 4]
//	std	%i6, [%sp + (24 + 14) * 4]
//					! F0->F31 not implemented
//	mov	%y, %l4
//	mov	%tbr, %l5
//	st	%l4, [%sp + (24 + 64) * 4] ! Y
//	st	%l0, [%sp + (24 + 65) * 4] ! PSR
//	st	%l3, [%sp + (24 + 66) * 4] ! WIM
//	st	%l5, [%sp + (24 + 67) * 4] ! TBR
//	st	%l1, [%sp + (24 + 68) * 4] ! PC
//	st	%l2, [%sp + (24 + 69) * 4] ! NPC
//
//					! CPSR and FPSR not impl
//
//	or	%l0, 0xf20, %l4
//	mov	%l4, %psr		! Turn on traps, disable interrupts
//
//	call	_handle_exception
//	add	%sp, 24 * 4, %o0	! Pass address of registers
//
//! Reload all of the registers that aren't on the stack
//
//	ld	[%sp + (24 + 1) * 4], %g1 ! registers[Gx]
//	ldd	[%sp + (24 + 2) * 4], %g2
//	ldd	[%sp + (24 + 4) * 4], %g4
//	ldd	[%sp + (24 + 6) * 4], %g6
//
//	ldd	[%sp + (24 + 8) * 4], %i0 ! registers[Ox]
//	ldd	[%sp + (24 + 10) * 4], %i2
//	ldd	[%sp + (24 + 12) * 4], %i4
//	ldd	[%sp + (24 + 14) * 4], %i6
//
//	ldd	[%sp + (24 + 64) * 4], %l0 ! Y & PSR
//	ldd	[%sp + (24 + 68) * 4], %l2 ! PC & NPC
//
//	restore				! Ensure that previous window is valid
//	save	%g0, %g0, %g0		!  by causing a window_underflow trap
//
//	mov	%l0, %y
//	mov	%l1, %psr		! Make sure that traps are disabled
//					! for rett
//
//	sethi	%hi(in_trap_handler), %l4
//	ld	[%lo(in_trap_handler) + %l4], %l5
//	dec	%l5
//	st	%l5, [%lo(in_trap_handler) + %l4]
//
//	jmpl	%l2, %g0		! Restore old PC
//	rett	%l3			! Restore old nPC
//");

/* Convert ch from a hex digit to an int */

static int hex(unsigned char ch) {
	if (ch >= 'a' && ch <= 'f')
		return ch - 'a' + 10;
	if (ch >= '0' && ch <= '9')
		return ch - '0';
	if (ch >= 'A' && ch <= 'F')
		return ch - 'A' + 10;
	return -1;
}

/* scan for the sequence $<data>#<checksum>     */

unsigned char *
getpacket(void) {
	unsigned char *buffer = &remcomInBuffer[0];
	unsigned char checksum;
	unsigned char xmitcsum;
	int count;
	char ch;

	while (1) {
		/* wait around for the start character, ignore all other characters */
		while ((ch = getDebugChar()) != '$')
			;
		//ok
		retry: checksum = 0;
		xmitcsum = -1;
		count = 0;

		/* now, read until a # or end of buffer is found */
		while (count < BUFMAX - 1) {
			ch = getDebugChar();
			if (ch == '$')
				goto retry;
			if (ch == '#')
				break;
			checksum = checksum + ch;
			buffer[count] = ch;
			count = count + 1;
		}
		buffer[count] = 0;
		//ok
		if (ch == '#') {
			ch = getDebugChar();
			xmitcsum = hex(ch) << 4;
			ch = getDebugChar();
			xmitcsum += hex(ch);

			if (checksum != xmitcsum) {
				putDebugChar('-'); /* failed checksum */
			} else {
				putDebugChar('+'); /* successful transfer */

				/* if a sequence char is present, reply the sequence ID */
				if (buffer[2] == ':') {
					putDebugChar(buffer[0]);
					putDebugChar(buffer[1]);

					return &buffer[3];
				}
				return &buffer[0];
			}
		}
	}
}

/* send the packet in buffer.  */

static void putpacket(unsigned char *buffer) {
	unsigned char checksum;
	int count;
	unsigned char ch;
	// Not getting here

	/*  $<packet info>#<checksum>. */
	//do {
	putDebugChar('$');
	checksum = 0;
	count = 0;

	while (ch = buffer[count]) {
		putDebugChar(ch);
		checksum += ch;
		count += 1;
	}

	putDebugChar('#');
	putDebugChar(hexchars[checksum >> 4]);
	putDebugChar(hexchars[checksum & 0xf]);

	//} while (getDebugChar() != '+');
	while (getDebugChar() != '+') {
	};
	// Lets see if we can get the acknowledgement
	//ok to here. Disables repeated sends
}

/* Indicate to caller of mem2hex or hex2mem that there has been an
 error.  */
static volatile int mem_err = 0;

/* Convert the memory pointed to by mem into hex, placing result in buf.
 * Return a pointer to the last char put in buf (null), in case of mem fault,
 * return 0.
 * If MAY_FAULT is non-zero, then we will handle memory faults by returning
 * a 0, else treat a fault like any other fault in the stub.
 */

static unsigned char *
mem2hex(unsigned char *mem, unsigned char *buf, int count, int may_fault) {
	unsigned char ch;
//	char dbgstr[20];
//	sprintf(dbgstr, "%p", mem);
//    showDebugString(dbgstr, 4,1);
	//set_mem_fault_trap(may_fault);

	while (count-- > 0) {
		if(mem < 0x210000)
		  ch = *mem++;
		else
		  ch = 0xDE;

//		if (mem_err)
//			return 0;
		*buf++ = hexchars[ch >> 4];
		*buf++ = hexchars[ch & 0xf];
	}

	*buf = 0;

	//set_mem_fault_trap(0);

	return buf;
}

/* convert the hex array pointed to by buf into binary to be placed in mem
 * return a pointer to the character AFTER the last byte written */

static char *
hex2mem(unsigned char *buf, unsigned char *mem, int count, int may_fault) {
	int i;
	unsigned char ch;

	set_mem_fault_trap(may_fault);

	for (i = 0; i < count; i++) {
		ch = hex(*buf++) << 4;
		ch |= hex(*buf++);
		*mem++ = ch;
		if (mem_err)
			return 0;
	}

	set_mem_fault_trap(0);

	return mem;
}

/* This table contains the mapping between SPARC hardware trap types, and
 signals, which are primarily what GDB understands.  It also indicates
 which hardware traps we need to commandeer when initializing the stub. */

static struct hard_trap_info {
	unsigned char tt; /* Trap type code for SPARClite */
	unsigned char signo; /* Signal that we map this trap into */
} hard_trap_info[] = { { 1, SIGSEGV }, /* instruction access error */
{ 2, SIGILL }, /* privileged instruction */
{ 3, SIGILL }, /* illegal instruction */
{ 4, SIGEMT }, /* fp disabled */
{ 36, SIGEMT }, /* cp disabled */
{ 7, SIGBUS }, /* mem address not aligned */
{ 9, SIGSEGV }, /* data access exception */
{ 10, SIGEMT }, /* tag overflow */
{ 128 + 1, SIGTRAP }, /* ta 1 - normal breakpoint instruction */
{ 0, 0 } /* Must be last */
};

/* Set up exception handlers for tracing and breakpoints */

void set_debug_traps(void) {
	//  struct hard_trap_info *ht;
	//
	//  for (ht = hard_trap_info; ht->tt && ht->signo; ht++)
	//    exceptionHandler(ht->tt, trap_low);
	//
	//  initialized = 1;
}
//
//asm ("
//! Trap handler for memory errors.  This just sets mem_err to be non-zero.  It
//! assumes that %l1 is non-zero.  This should be safe, as it is doubtful that
//! 0 would ever contain code that could mem fault.  This routine will skip
//! past the faulting instruction after setting mem_err.
//
//	.text
//	.align 4
//
//_fltr_set_mem_err:
//	sethi %hi(_mem_err), %l0
//	st %l1, [%l0 + %lo(_mem_err)]
//	jmpl %l2, %g0
//	rett %l2+4
//");

static void set_mem_fault_trap(int enable) {
	//  extern void fltr_set_mem_err();
	//  mem_err = 0;
	//
	//  if (enable)
	//    exceptionHandler(9, fltr_set_mem_err);
	//  else
	//    exceptionHandler(9, trap_low);
}

/* Convert the SPARC hardware trap type code to a unix signal number. */

static int computeSignal(int tt) {
	struct hard_trap_info *ht;

	for (ht = hard_trap_info; ht->tt && ht->signo; ht++)
		if (ht->tt == tt)
			return ht->signo;

	return SIGHUP; /* default for things we don't know about */
}

/*
 * While we find nice hex chars, build an int.
 * Return number of chars processed.
 */

static int hexToInt(char **ptr, int *intValue) {
	int numChars = 0;
	int hexValue;

	*intValue = 0;

	while (**ptr) {
		hexValue = hex(**ptr);
		if (hexValue < 0)
			break;

		*intValue = (*intValue << 4) | hexValue;
		numChars++;

		(*ptr)++;
	}

	return (numChars);
}

/*
 * This function does all command procesing for interfacing to gdb.  It
 * returns 1 if you should skip the instruction at the trap address, 0
 * otherwise.
 */

extern void breakinst();

static void handle_exception(unsigned long *registers) {
	//int tt;			/* Trap type */
	int tt = 3; /* Trap type */
	int sigval;
	int addr;
	int length;
	char *ptr;
	unsigned long *sp;
    //rup
//sprintf(DebugString,"0x%p", registers);
	UBYTE dbgstr[20];
	sprintf(dbgstr,"%p", registers);
	showDebugString(dbgstr, 1, 0);
	sprintf(dbgstr,"%d", *registers);
	showDebugString(dbgstr, 2, 0);
	/* First, we must force all of the windows to be spilled out */
	//
	//  asm("	save %sp, -64, %sp
	//	save %sp, -64, %sp
	//	save %sp, -64, %sp
	//	save %sp, -64, %sp
	//	save %sp, -64, %sp
	//	save %sp, -64, %sp
	//	save %sp, -64, %sp
	//	save %sp, -64, %sp
	//	restore
	//	restore
	//	restore
	//	restore
	//	restore
	//	restore
	//	restore
	//	restore
	//");
	//
	//  if (registers[PC] == (unsigned long)breakinst)
	//    {
	//      registers[PC] = registers[NPC];
	//      registers[NPC] += 4;
	//    }
	//	for (int ii = 0; ii < 4; ii++) {
	//		putDebugChar(ii);
	//OK here
	//	}

	//	ON(3);
	//	STOP();

	//sp = (unsigned long *) registers[SP];

	//tt = (registers[TBR] >> 4) & 0xff;

	/* reply to host that an exception has occurred */
	sigval = computeSignal(tt);
	ptr = remcomOutBuffer;
	//ok
	*ptr++ = 'T';
	*ptr++ = hexchars[sigval >> 4];
	*ptr++ = hexchars[sigval & 0xf];

	// general regs
	for (int i = 0; i < 15; i++) {
		*ptr++ = hexchars[i >> 4];
		*ptr++ = hexchars[i & 0xf];
		*ptr++ = ':';
		ptr = mem2hex((char *) &registers[i], ptr, 4, 0);
		*ptr++ = ';';
	}

	// PC
	*ptr++ = hexchars[PC >> 4];
	*ptr++ = hexchars[PC & 0xf];
	*ptr++ = ':';
	ptr = mem2hex((char *) &registers[PC], ptr, 4, 0);
	*ptr++ = ';';

	*ptr++ = hexchars[CPSR >> 4];
	*ptr++ = hexchars[CPSR & 0xf];
	*ptr++ = ':';
	// correct it
	ptr = mem2hex((char *) &registers[PC], ptr, 4, 0);
	*ptr++ = ';';

	*ptr = 0;

	putpacket(remcomOutBuffer);
	//ok
	while (1) {
		remcomOutBuffer[0] = 0;

		ptr = getpacket();
		switch (*ptr++) {
		case '?':
			remcomOutBuffer[0] = 'S';
			remcomOutBuffer[1] = hexchars[sigval >> 4];
			remcomOutBuffer[2] = hexchars[sigval & 0xf];
			remcomOutBuffer[3] = 0;
			break;

		case 'd': /* toggle debug flag */
			break;

		case 'T': /* Say OK to whatever thread GDB wants */
		{
			remcomOutBuffer[0] = 'O';
			remcomOutBuffer[1] = 'k';
			remcomOutBuffer[2] = 0;
		}
			break;

		case 'g': /* return the value of the CPU registers */
		{
			ptr = remcomOutBuffer;
			ptr = mem2hex((char *) registers, ptr, 18 * 4, 0); /* G & O regs */
		}
			break;

		case 'G': /* set the value of the CPU registers - return OK */
		{
			//			unsigned long *newsp, psr;
			//
			//			psr = registers[PSR];
			//
			//			hex2mem(ptr, (char *) registers, 16 * 4, 0); /* G & O regs */
			//			//hex2mem(ptr + 16 * 4 * 2, sp + 0, 16 * 4, 0); /* L & I regs */
			//			//hex2mem(ptr + 64 * 4 * 2, (char *) &registers[Y], 8 * 4, 0); /* Y, PSR, WIM, TBR, PC, NPC, FPSR, CPSR */
			//
			//			/* See if the stack pointer has moved.  If so, then copy the saved
			//			 locals and ins to the new location.  This keeps the window
			//			 overflow and underflow routines happy.  */
			//
			//			newsp = (unsigned long *) registers[SP];
			//			if (sp != newsp)
			//				sp = memcpy(newsp, sp, 16 * 4);
			//
			//			/* Don't allow CWP to be modified. */
			//
			//			if (psr != registers[PSR])
			//				registers[PSR] = (psr & 0x1f) | (registers[PSR] & ~0x1f);
			//
			strcpy(remcomOutBuffer, "OK");
		}
			break;

		case 'm': /* mAA..AA,LLLL  Read LLLL bytes at address AA..AA */
			/* Try to read %x,%x.  */
		{
			if (hexToInt(&ptr, &addr) && *ptr++ == ',' && hexToInt(&ptr,
					&length)) {
				if (mem2hex((char *) addr, remcomOutBuffer, length, 1))
					break;

				strcpy(remcomOutBuffer, "E03");
			} else
				strcpy(remcomOutBuffer, "E01");
		}

			break;

		case 'M': /* MAA..AA,LLLL: Write LLLL bytes at address AA.AA return OK */
			/* Try to read '%x,%x:'.  */

			//			if (hexToInt(&ptr, &addr) && *ptr++ == ',' && hexToInt(&ptr,
			//					&length) && *ptr++ == ':') {
			//				if (hex2mem(ptr, (char *) addr, length, 1))
								strcpy(remcomOutBuffer, "OK");
			//				else
			//					strcpy(remcomOutBuffer, "E03");
			//			} else
			//				strcpy(remcomOutBuffer, "E02");
			break;

		case 'c': /* cAA..AA    Continue at address AA..AA(optional) */
			/* try to read optional parameter, pc unchanged if no parm */

			//			if (hexToInt(&ptr, &addr)) {
			//				registers[PC] = addr;
			//				registers[NPC] = addr + 4;
			//			}

			/* Need to flush the instruction cache here, as we may have deposited a
			 breakpoint, and the icache probably has no way of knowing that a data ref to
			 some location may have changed something that is in the instruction cache.
			 */

			//			flush_i_cache();
			return;

			/* kill the program */
		case 'k': /* do nothing */
			break;
			//#if 0
			//	case 't':		/* Test feature */
			//	  asm (" std %f30,[%sp]");
			//	  break;
			//#endif
		case 'r': /* Reset */
			//	  asm ("call 0
			//		nop ");
			break;
		} /* switch */

		/* reply to the request */
		putpacket(remcomOutBuffer);
		ON(3);

	}
	STOP();
}

/* This function will generate a breakpoint exception.  It is used at the
 beginning of a program to sync up with a debugger and can be used
 otherwise as a quick means to stop program execution and "break" into
 the debugger. */

void breakpoint(void) {
	if (!initialized)
		return;

	//  asm("	.globl _breakinst
	//
	//	_breakinst: ta 1
	//      ");
}

