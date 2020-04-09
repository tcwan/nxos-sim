/** @file uartloop.S
 *  @brief UART Loopback Program
 *
 * Test UART loopback
 * Echo what is sent to the UART to the output
 * The input is also displayed on the LCD text terminal
 *
 * This file must be processed using cpp before assembly.
 */

/* Copyright (C) 2007-2011 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#define __ASSEMBLY__
#include "base/interwork.h"
#include "base/debug_stub.h"
#include "base/lib/scaffolding/scaffolding.h"

/* Reference C functions which do not have ASM headers */
	.extern nx_uart_read_avail
	.extern nx_uart_write_avail
	.extern	nx_uart_getchar
	.extern nx_uart_putchar
	.extern nx_uart_readbuf
	.extern nx_uart_writebuf
	.equ	UART_RXBUFSIZE, 64

#define ESC_CHAR	0x1B			/**< Escape Character ASCII value */

#define USE_BUFFEREDIO				/* Use buffered reads/writes instead of character read/write */

/* To disable Manual Breakpoints, change the following to #undef ENABLE_BREAKPOINTS */
#define ENABLE_BREAKPOINTS

	.extern	nx_systick_wait_ms
	.equ	SYSTICK_1000MS, 1000
	.equ	SYSTICK_500MS, 500
	.equ	LOOPCNT, 3

.data
.align 4

#ifdef USE_BUFFEREDIO

buflen:  .word 0
charbuf: .space UART_RXBUFSIZE, 0

#endif

title:	 .asciz "UART Loopback Prog"
prompt:	 .asciz "Type into the UART pane\nESC to exit\n"
bye:	 .asciz "\nBye!\n"
uartchr: .asciz "_"				// dummy string for output

.code 32
.text
.align 	4

// WARNING: Don't put any routines here between the .text and the main: label.
// CPUlator will point the starting PC to the beginning of the .text section and start executing from there.

/** main
 *    Main Program
 */
	.global	main
main:
/* Needed to support CPUlator system init
 * since it starts execution from main() and does not go through the system reset handler
 */
#include "cpulator_stub.inc"

	push	{r4-r12,lr}			// Preserve all AAPCS registers to avoid CPUlator warnings.

	bl		nx_proginit

	ldr		r0, =title
	bl		nx_progtitle

#ifdef __CPULATOR__
	// Allow CPUlator to execute ISR before hitting the breakpoint
	mov		r0, #SYSTICK_500MS
	bl		nx_systick_wait_ms
#endif

#ifdef ENABLE_BREAKPOINTS
	dbg__bkpt_arm
#else
	mov		r0, #SYSTICK_1000MS
	bl		nx_systick_wait_ms
#endif

break:
	nop		/* Provide GDB with a safe instruction to breakpoint at */

/********************* Begin Customization Here *********************/

	ldr		r0, =prompt
	bl		nx_progcontent

	mov		r0, #SYSTICK_500MS		/* Wait 500 ms */
	bl		nx_systick_wait_ms


#ifdef USE_BUFFEREDIO
	ldr		r5, =charbuf
	ldr		r6, =buflen

loop:
	mov		r0, #SYSTICK_1000MS		/* Wait 1000 ms to let buffer fill */
	bl		nx_systick_wait_ms

	/* read buffer from UART */
	mov		r0, r5
	mov		r1, r6
	bl		nx_uart_readbuf			/* parameters: &charbuf, &buflen */

	ldr		r1, [r6]				/* retrieve number of chars read */
	cmp		r1, #0
	beq		loop					/* Nothing read, so wait */

	mov		r0, r5					/* r1 already contains buflen */
	/* echo it to the UART */
	bl		nx_uart_writebuf		/* parameters: &charbuf, buflen */

echo_display:
	mov		r7, r5					/* iterate through charbuf using r7 */
	ldr		r8, [r6]				/* Use r8 as a counter */
	mov		r9, #0					/* Use r9 to flag exit */

display_loop:
	ldrb	r4, [r7], #1			/* retrieve character from charbuf */
	ldr		r0, =uartchr
	strb	r4, [r0]				/* setup display string (char) */
	bl		nx_display_string		/* Display it on the LCD */
	cmp		r4, #ESC_CHAR			/* exit? */
	moveq	r9, #1					/* yes, set exit flag */
	subs	r8, r8, #1
	bne		display_loop			/* iterate through the rest of the charbuf contents */

	cmp		r9, #1					/* test exit flag */
	bne		loop					/* continue if not exit */

#else

loop:
	bl		nx_uart_getchar			/* get input from UART */
	mov		r4, r0					/* keep for LCD display */
	bl		nx_uart_putchar			/* echo it to the UART */

echo_display:
	ldr		r0, =uartchr
	strb	r4, [r0]				/* setup display string (char) */
	bl		nx_display_string		/* Display it on the LCD */
	cmp		r4, #ESC_CHAR			/* exit? */
	bne		loop

#endif

exit_loop:
	ldr		r0, =bye
	bl		nx_display_string

/********************** End Customization Here **********************/
exit_main:
	bl		nx_progshutdown
	pop		{r4-r12,pc}			// Restore all AAPCS registers to avoid CPUlator warnings.


.end
