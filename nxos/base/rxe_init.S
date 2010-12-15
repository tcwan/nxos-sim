/*
   Sivan Toledo, May 2008
   to enable calling a native AT91SAM7 program
   from the NXT's firmware, using a modification
   implemented by John Hansen.

   (with very small modifications but large deletions from the NxOS-developers)

   The NXT firmware recognizes a native file by the
   string "NXTBINARY" at the beginning of the file.
   To keep the changes in the NXT's firmware minimal,
   the file name must be .rxe (same as the stadard
   NXT binaries which are for a virtual machine).

   When the NXT's firmware recognizes a native file,
   it calls a function at offset X in the file, where
   X is the 32-bit number stored in offset 12 in the file.
   The firmware passes two arguments to the function: the
   address of the file in flash, and the length of the file.

   The code in this file uses the arguments (location and size
   of the native file) to relocate the file (except for the first 16
   bytes, which are a header) to the beginning of RAM and calls
   the normal NxOS-startup.
*/

/*
   The NXT header must be 16 bytes, since the linker
   script locates it 16 bytes below the beginning of RAM,
   so the vectors will be at the beginning of RAM, which
   we memory map to address 0.
*/

#define __ASSEMBLY__
#include "base/at91sam7s256.h"

#define AT91C_RSTC_KEYA5        (0xA5 << 24)  /* Need correct key value to unlock RSTC */

#include "asm_decls.h"


    .section .rxe_init, "ax"
	.code 32 /* Assemble in ARM mode, not Thumb mode */

/*------------------------------------------------------------------------------
*- Area Definition
*------------------------------------------------------------------------------*/
        .global _startup
        .func   _startup

_startup:
/*
 * Entry into native code from NXT firmware;
 * this function must be located at offset 16 in the file
*/
NXT_Entry_Point:

	/* globally disable interrupts */
	STMDB	SP!, {R0}		/* Push R0. */
	MRS	R0, CPSR		/* Get CPSR. */
	ORR	R0, R0, #0xC0		/* Disable IRQ, FIQ. */
	MSR	CPSR, R0		/* Write back modified value. */
	LDMIA	SP!, {R0}		/* Pop R0. */

Copier:
 	add	r2, r0, r1      /* r2 now holds the address just beyong
                                 the end of this binary file */
	ldr	r1, _rxe_hdrsize    /* Retrieve size from a variable, so that Linker can fill value in for us */
	add r0, r0, r1          /* Skip NXTBINARY header and Runtime Copier */
    mov	r1, #RAM_START      /* beginning of RAM */

/*
 	b	CopierCompare
CopierLoop:
  	ldr	r3, [r0], #4
   	str	r3, [r1], #4
CopierCompare:
  	cmp	r0, r2
   	bcc	CopierLoop
 */

 /* Copier Loop modified from version found in
  * Miro Samek, "Building Bare-Metal ARM Systems with GNU"
  * http://www.state-machine.com/arm
  * Condition used is LO since addresses are unsigned
 */
 CopierLoop:
 	cmp	r0, r2
 	ldmloia	r0!, {r3}
 	stmloia r1!, {r3}
 	blo		CopierLoop

        /* Reset peripherals, needed to have defined states e.g. for the uart. */
        ldr     r0, =(AT91C_RSTC_KEYA5 | AT91C_RSTC_PERRST)
        ldr     r1, =AT91C_RSTC_RCR
        str     r0, [r1]

JumpToResetVector:
        ldr pc, =RAM_START
        .ltorg					/* Needed to force assembler to account for literals
        						   placed here, to calculate correct address offsets */
_rxe_hdrsize:  .word	(_rxe_init_end - _startup + 16)		/* Need to include NXTBINARY header */
_rxe_init_end:
  .size   _startup, . - _startup
  .endfunc

  .end
