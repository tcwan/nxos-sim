/** @file tribot.S
 *  @brief Tribot Test Program
 *  Test Tribot
 *
 * The following behaviors have been implemented
 * - Line following (Light Sensor: WIP)
 * - Object Detection (Touch)
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
#include "tribot.h"
#include "base/interwork.h"
#include "armdebug/Debugger/debug_stub.h"

	.extern	nx_systick_wait_ms
	.equ	SYSTICK_1000MS, 1000
	.equ	SYSTICK_50MS, 50
	.equ	TOUCH_THRESH, 256

	/* Sensor Port Assignments */
	.equ	TOUCH_PORT, 0		/* Sensor 1 */
	.equ	SOUND_PORT, 1		/* Sensor 2 */
	.equ	LIGHT_PORT, 2		/* Sensor 3 */
	.equ	ULSND_PORT, 3		/* Sensor 4 */
	.equ	DIGI0, 0
	.equ	DIGI1, 1

	/* Actuator Port Assignments */
	.equ	PINCER_PORT, 0		/* Motor A */
	.equ	RWHEEL_PORT, 1		/* Motor B */
	.equ	LWHEEL_PORT, 2		/* Motor C */


.data
.align 4

title:	 .asciz "Tribot ARM Prog"
pressed:  .asciz "Touch Pressed! "
released: .asciz "Touch Released!"

.code 32
.text
.align 	4


/* Actuator Primitives */
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

touch_detected:
	push	{lr}
	bl		plip
	ldr		r0, =pressed
	bl		nx_progcontent
	pop		{pc}

touch_lost:
	push	{lr}
	bl		plop
	ldr		r0, =released
	bl		nx_progcontent
	pop		{pc}

light_led_enable:
	push	{lr}
	mov		r0, #LIGHT_PORT
	mov		r1, #DIGI0
	bl		nx_sensors_analog_digi_set
	pop		{pc}

light_led_disable:
	push	{lr}
	mov		r0, #LIGHT_PORT
	mov		r1, #DIGI0
	bl		nx_sensors_analog_digi_clear
	pop		{pc}

/* main
 *    Main Program
 *		R7: Touched (boolean)
 */
	.global	main
main:
	push	{lr}

	/* Configure Sensors */
	mov		r0, #LIGHT_PORT
	bl		nx_sensors_analog_enable
	mov		r0, #TOUCH_PORT
	bl		nx_sensors_analog_enable

	bl		nx_proginit

	mov		r7, #FALSE

	ldr		r0, =title
	bl		nx_progtitle

	/* dbg__bkpt_arm */

break:
	nop		/* Prevent GDB from stepping inside nx_systick_wait_ms due to breakpoint */
	mov		r0, #SYSTICK_1000MS
	bl		nx_systick_wait_ms

	/* Line Follower Algorithm:
	 * 1. Collect Samples
	 * 2. Find Min-Max (range)
	 * 3. Determine if we're:
	 *     -- inside line
	 *     -- on edge
	 *     -- outside line
	 * 4. If Inside Line, move straight ahead
	 * 5. If On Edge, rotate slowly
	 * 6. If Outside Line, rotate quickly
	 */
	bl		light_led_enable

loop:
	mov		r0, #LIGHT_PORT
	bl		nx_sensors_analog_get
	dbg__bkpt_arm
	b		loop

#if 0
loop:
	mov		r0, #TOUCH_PORT
	bl		nx_sensors_analog_get
	/* Touch Sensor: Released: #1023, Pressed: #183 */
	cmp		r0, #TOUCH_THRESH
	bgt		no_touch

touch:
	teq		r7, #FALSE				/* We can't teq #TRUE due to constant value exceeding 8 bits */
	bne		exit_touch
	mov		r7, #TRUE
	bl		light_led_enable
	bl		touch_detected
	b		exit_touch

no_touch:
	teq		r7, #FALSE
	beq		exit_touch
	mov		r7, #FALSE
	bl		light_led_disable
	bl		touch_lost

exit_touch:
	mov		r0, #SYSTICK_50MS
	bl		nx_systick_wait_ms
	b		loop

#endif

exit_main:
	bl		nx_progshutdown
	pop		{pc}

.end
