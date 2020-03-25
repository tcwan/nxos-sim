/** @file randtest.S
 *  @brief PRNG Test program based on armskel
 *   [What does this component do?]
 *
 *
 * [Optionally, more stuff about the component in general.]
 * This file must be processed using cpp before assembly.
 */

/* Copyright (C) 2007-2016 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#define __ASSEMBLY__
#include "base/interwork.h"
#include "base/lib/scaffolding/scaffolding.h"
#include "base/lib/prng/prng.h"
#include "base/debug_stub.h"

/* To disable Manual Breakpoints, change the following to #undef ENABLE_BREAKPOINTS */
#define ENABLE_BREAKPOINTS
#define USE_CONST_INIT


	.extern	nx_systick_wait_ms
	.equ	SYSTICK_1000MS, 1000
	.equ	SYSTICK_500MS, 500
	.equ	LOOPCNT, 5
	.equ	RAND_INIT, 0x25AF31EE

.data
.align 4

title:	 .asciz "Randtest Prog"
prompt:	 .asciz "Random Numbers: "
donestr: .asciz "Done!"
spacestr: .asciz ", "

.code 32
.text
.align 	4

/** main
 *    Main Program
 */
	.global	main
main:
	push	{lr}
	bl		nx_proginit

	ldr		r0, =title
	bl		nx_progtitle

#ifdef ENABLE_BREAKPOINTS
	dbg__bkpt_arm
#else
	mov		r0, #SYSTICK_1000MS
	bl		nx_systick_wait_ms
#endif

break:
	nop		/* Provide GDB with a safe instruction to breakpoint at */

/********************* Begin Customization Here *********************/
#ifdef USE_CONST_INIT
	ldr		r0, =RAND_INIT
#else
	bl		nx_systick_get_ms		/* get current system tick */
#endif
	bl		srand					/* Init pseudo random number generator */

	mov		r7, #LOOPCNT
	ldr		r0, =prompt
	bl		nx_progtitle

loop:
	mov		r0, #SYSTICK_500MS		/* Wait 500 ms */
	bl		nx_systick_wait_ms

	bl		rand					/* get random number */
display:
	bl		nx_display_int

	ldr		r0, =spacestr
	bl		nx_display_string

	mov		r0, #SYSTICK_1000MS		/* Wait 1000 ms */
	bl		nx_systick_wait_ms

/* Change '0' to '1' to enable program loop */
#if 1
	subs	r7, r7, #1
	bne		loop
#endif

	ldr		r0, =donestr
	bl		nx_display_string

	mov		r0, #SYSTICK_1000MS		/* Wait 1000 ms */
	bl		nx_systick_wait_ms

/********************** End Customization Here **********************/
exit_main:
	bl		nx_progshutdown
	pop		{pc}

.end
