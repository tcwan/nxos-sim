/** @file buttontest.S
 *  @brief NXT Button Test
 *   [What does this component do?]
 *
 *
 * [Optionally, more stuff about the component in general.]
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
#include "base/lib/scaffolding/scaffolding.h"
#include "base/debug_stub.h"

/* To disable Manual Breakpoints, change the following to #undef ENABLE_BREAKPOINTS */
#define ENABLE_BREAKPOINTS

	.extern	nx_systick_wait_ms
	.equ	SYSTICK_1000MS, 1000
	.equ	SYSTICK_500MS, 500
	.equ	SYSTICK_100MS, 100
	.equ	LOOPCNT, 5


.data
.align 4

title:	 .asciz "Button Test Prog"
prompt:	 .asciz "Press a Button"
leftPressed: .asciz "Pressed Left"
rightPressed: .asciz "Pressed Right"
OKPressed: .asciz "Pressed OK"
bye:	 .asciz "Exiting Button Press Program"

.code 32
.text
.align 	4

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

#ifdef ENABLE_BREAKPOINTS
	dbg__bkpt_arm
#else
	mov		r0, #SYSTICK_1000MS
	bl		nx_systick_wait_ms
#endif

break:
	nop		/* Provide GDB with a safe instruction to breakpoint at */

/********************* Begin Customization Here *********************/

	mov		r7, #LOOPCNT
loop:
	ldr		r0, =prompt
	bl		nx_progtitle

	bl		nx_getbutton		/* Button value in R0 */
	mov		r4, r0				/* Keep button for release checking */

check_exit:
	cmp		r0, #DE1_BTN_0
	beq		exit_main

check_ok:
	cmp		r0, #DE1_BTN_2
	bne		check_left
	ldr		r0, =OKPressed
	bl		nx_progcontent
	bl		plap
	b		button_pressed

check_left:
	cmp		r0, #DE1_BTN_1
	bne		check_right
	ldr		r0, =leftPressed
	bl		nx_progcontent
	bl		plip
	b		button_pressed
	
check_right:
	cmp		r0, #DE1_BTN_3
	bne		done_checking
	ldr		r0, =rightPressed
	bl		nx_progcontent
	bl		plop
	b		button_pressed

done_checking:
	mov		r0, #SYSTICK_100MS		/* Wait 100 ms */
	bl		nx_systick_wait_ms
	b		loop

button_pressed:
	mov		r0, #SYSTICK_500MS		/* Wait 500 ms */
	bl		nx_systick_wait_ms
	bl		nx_getbutton			/* Button value in R0 */
	cmp		r0, r4					/* Did button change? */
	beq		button_pressed			/* Still unchanged, wait for release or new button */

button_released:

/* Change '0' to '1' to enable program loop */
#if 1
	subs	r7, r7, #1
	bne		loop
#endif

/********************** End Customization Here **********************/
exit_main:
	ldr		r0, =bye
	bl		nx_progcontent2		/* Display bye */

	bl		nx_progshutdown
	pop		{r4-r12,pc}			// Restore all AAPCS registers to avoid CPUlator warnings.

plip:
	push	{lr}
	ldr		r0, =3000
	mov		r1, #100
	bl		nx_sound_freq
	pop		{pc}

plop:
	push	{lr}
	ldr		r0, =500
	mov		r1, #100
	bl		nx_sound_freq
	pop		{pc}

plap:
	push	{lr}
	ldr		r0, =1500
	mov		r1, #100
	bl		nx_sound_freq
	pop		{pc}

.end
