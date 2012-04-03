/** @file grasper.S
 *  @brief Tribot Grasper Test Program
 *  Test Basic Tribot Functionality
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
#include "base/interwork.h"
#include "base/lib/scaffolding/scaffolding.h"
#include "armdebug/Debugger/debug_stub.h"

/* To disable Manual Breakpoints, change the following to #undef ENABLE_BREAKPOINTS */
#undef ENABLE_BREAKPOINTS
/* To disable Motor Debugging, change the following to #undef DEBUG_MOTOR */
#undef DEBUG_MOTOR
/* To disable Min-Max Debugging, change the following to #undef DEBUG_MIN_MAX */
#undef DEBUG_MIN_MAX

	.equ	MAX_ITERATIONS, 0x0FFFF
	.extern	nx_systick_wait_ms
	.equ	SYSTICK_1000MS, 1000
	.equ	SYSTICK_50MS,   50
	.equ	SYSTICK_3MS,    3
	.equ	SYSTICK_1MS,    1

	/* Sensor Port Assignments */
	.equ	TOUCH_PORT, 0		/* Sensor 1 */
	.equ	SOUND_PORT, 1		/* Sensor 2 */
	.equ	LIGHT_PORT, 2		/* Sensor 3 */
	.equ	ULSND_PORT, 3		/* Sensor 4 */
	.equ	DIGI0, 0
	.equ	DIGI1, 1

	/* Actuator Port Assignments */
	.extern nx_motors_rotate
	.extern nx_motors_stop
	.equ	PINCER_PORT, 0		/* Motor A */
	.equ	RWHEEL_PORT, 1		/* Motor B */
	.equ	LWHEEL_PORT, 2		/* Motor C */

	/* Min-Max constant */
    .equ n,5    /* Number of items in array */

	/* Light Sensor Color Detection Intensity (0-100) ranges */
	/* Light Sensor Raw Readings: White: 470-520; Edge: 540-580; Black: 680-700 */
	/* Changed the range so that it will be a smooth transition from White to Black */
	.equ	WHITE_MIN, 45
	.equ	WHITE_MAX, 51
	.equ	EDGE_MIN,  52
	.equ	EDGE_MAX,  60
	.equ	BLACK_MIN, 61
	.equ	BLACK_MAX, 70

	/* Touch Sensor Threshold */
	/* Touch Sensor Raw Readings: Pressed: 183; Released: 1023 */
	.equ	TOUCH_THRESH, 256

	/* Motor Control Constants */
	.equ	FWD_SPEED, 60
	.equ	FASTROT_SPEED, 50
	.equ	SLOWROT_SPEED, 30



/** @name Robot State Enums
 *
 * Robot State.
 * The enums must be consecutive, starting from 0
 */
/*@{*/
ENUM_BEGIN
ENUM_VALASSIGN(ROBOT_STOP, 0)   /**< Initial State. */
ENUM_VAL(ROBOT_FWD)             /**< Robot Moving Forward. */
ENUM_VAL(ROBOT_CW)        		/**< Robot Rotating Clockwise */
ENUM_VAL(ROBOT_CCW)        		/**< Robot Rotating Counter-Clockwise */
ENUM_END(robot_state_t)
/*@}*/

.data
.align 4

title:	 .asciz "Grasper ARM Prog"
pressed:  .asciz "Touch Pressed! "
released: .asciz "Touch Released!"
white:	 .asciz "White!  "
black:	 .asciz "Black!  "
edge:	 .asciz "Edge!   "
unknown: .asciz "Unknown!"


#ifdef DEBUG_MIN_MAX
minstring: .asciz "min: "
maxstring: .asciz "max: "
#endif

/* Light Sensor Variables */
readings: .space  n, 0x0
min:      .byte   0
max:      .byte   0
robot_state: .byte	0

/* Touch Sensor Variables */
touchval: .byte   0
grasper_closed: .byte	0

/*
 * Behavior State Variables
 */

/* Bitmasks for Suppression */
#define suppress_portA 0x80;
#define suppress_portB 0x40;
#define suppress_portC 0x20;
#define suppress_tone  0x10;

/* Inhibition Values */
#define MOTOR_INHIBITED 0x80;
#define TONE_INHIBITED 0x00;

follow_line_suppression:  .byte 0
follow_line_portA:        .byte #MOTOR_INHIBITED
follow_line_portB:        .byte #MOTOR_INHIBITED
follow_line_portC:        .byte #MOTOR_INHIBITED

grasp_object_suppression: .byte 0
grasp_object_portA:       .byte #MOTOR_INHIBITED
grasp_object_portB:       .byte #MOTOR_INHIBITED
grasp_object_portC:       .byte #MOTOR_INHIBITED

play_tone_suppression:    .byte 0
play_tone_portA:          .byte #MOTOR_INHIBITED
play_tone_portB:          .byte #MOTOR_INHIBITED
play_tone_portC:          .byte #MOTOR_INHIBITED

tone_freq:    .word #TONE_INHIBITED
tone_dur:     .word #TONE_INHIBITED

/* New Actuator Settings */
arbiter_portA:           .byte #MOTOR_INHIBITED
arbiter_portB:           .byte #MOTOR_INHIBITED
arbiter_portC:           .byte #MOTOR_INHIBITED

/* Current Actuator Settings */
actuator_portA:          .byte #MOTOR_INHIBITED
actuator_portB:          .byte #MOTOR_INHIBITED
actuator_portC:          .byte #MOTOR_INHIBITED


.code 32
.text
.align 	4

/*	Min-Max Routine
 * R0: Temporary value storage
 * R1: counter
 * R2: readings Array Pointer
 * R3: min value
 * R4: max value
 */

	.global min_max
min_max:
	push	{r4, lr}
    MOV  	R4, #0         /* Initialize max to smallest 8-bit value */
    MOV  	R3, #255       /* Initialize min to largest 8-bit value */
    MOV  	R1, #n         /* Initialize counter */
    LDR  	R2, =readings  /* Array Address Pointer, setup outside loop */
min_max_loop:
    SUB  	R1, R1, #1     /* counter = counter - 1 */
    /* If */
    LDRB 	R0, [R2, R1]   /* Retrieve readings[counter] into R0 */
check_min:
    CMP  	R0, R3         /* check readings[counter] (in R0) < min */
    MOVLO  	R3, R0       /* Min = readings[counter] */
check_max:
    CMP  	R0, R4         /* check readings[counter] (in R0) > max */
    MOVHI  	R4, R0       /* Max = readings[counter] */
next_iter:
    TEQ  	R1, #0         /* Compare R1 against zero */
    BNE  	min_max_loop   /* NE: R1 is non-zero */
exit_min_max_loop:
    LDR  	R2, =min
    STRB 	R3, [R2], #1   /* Store min into memory location */
    STRB 	R4, [R2]       /* Store max into memory location */
done_min_max:
	pop		{r4, pc}


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

plap:
	push	{lr}
	ldr		r0, =1500
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

forward_motion:
	push	{lr}
/*	bl		plip */
	ldr		r0, =black
	bl		nx_progcontent

	ldr		r2, =robot_state
	mov		r1, #ROBOT_FWD
	ldrb	r0, [r2]
	teq		r0, r1
	beq		1f						/* Already in given state */
	strb	r1, [r2]				/* State Change: Update new state */

	mov		r0, #RWHEEL_PORT
	mov		r1, #FWD_SPEED
	bl		nx_motors_rotate
	mov		r0, #LWHEEL_PORT
	mov		r1, #FWD_SPEED
	bl		nx_motors_rotate
1:
	pop		{pc}

fast_cwrotate_motion:
	push	{lr}
/*	bl		plop */
	ldr		r0, =white
	bl		nx_progcontent

	ldr		r2, =robot_state
	mov		r1, #ROBOT_CW
	ldrb	r0, [r2]
	teq		r0, r1
	beq		1f						/* Already in given state */
	strb	r1, [r2]				/* State Change: Update new state */

	mov		r0, #RWHEEL_PORT
	mov		r1, #FALSE				/* Don't brake */
	bl		nx_motors_stop
	mov		r0, #LWHEEL_PORT
	mov		r1, #FASTROT_SPEED
	bl		nx_motors_rotate
1:
	pop		{pc}

slow_cwrotate_motion:
	push	{lr}
/*	bl		plap */
	ldr		r0, =edge
	bl		nx_progcontent

	ldr		r2, =robot_state
	mov		r1, #ROBOT_CCW
	ldrb	r0, [r2]
	teq		r0, r1
	beq		1f						/* Already in given state */
	strb	r1, [r2]				/* State Change: Update new state */

	mov		r0, #LWHEEL_PORT
	mov		r1, #FALSE				/* Don't brake */
	bl		nx_motors_stop
	mov		r0, #RWHEEL_PORT
	mov		r1, #SLOWROT_SPEED
	bl		nx_motors_rotate
1:
	pop		{pc}

stop_motion:
	push	{lr}
	ldr		r0, =unknown
	bl		nx_progcontent

	ldr		r2, =robot_state
	mov		r1, #ROBOT_STOP
	ldrb	r0, [r2]
	teq		r0, r1
	beq		1f						/* Already in given state */
	strb	r1, [r2]				/* State Change: Update new state */

	mov		r0, #RWHEEL_PORT
	mov		r1, #FALSE		/* Don't brake */
	bl		nx_motors_stop
	mov		r0, #LWHEEL_PORT
	mov		r1, #FALSE		/* Don't brake */
	bl		nx_motors_stop
1:
	pop		{pc}

/* get_light_readings
 *    Light Sensor Input Routine
 *    Collect n readings, and obtain min and max values
 */
get_light_readings:
	push	{r5, r6, lr}
	ldr		r5, =readings
	mov		r6, #n		/* Number of readings to collect */

light_loop:

	sub		r6, r6, #1	/* Convert to Index */
	mov		r0, #LIGHT_PORT
	bl		nx_sensors_analog_get_normalized	/* returned value in range 0-100% */
	strb	r0, [r5, r6]

	mov		r0, #SYSTICK_3MS
	bl		nx_systick_wait_ms	/* Delay 3 ms before next reading (Required by AVR A/D Converter) */

	cmp		r6, #0
	bhi		light_loop		/* Perform Min-Max calculation when we have enough samples */

calc_min_max:
	bl		min_max
	pop		{r5, r6, pc}

/* get_touch_status
 *    Retrieve Touch Sensor value
 */
 get_touch_status:
 	push	{lr}
	mov		r0, #TOUCH_PORT
	bl		nx_sensors_analog_get
	ldr		r1, =touchval
	strb	r0, [r1]		/* Store Touch Value */
 	pop		{pc}

/* Grasp Object Behavior
 *    TBD: ALGORITHM
 */

bbr_grasp_object:
	push	{lr}
	cmp		r0, #TOUCH_THRESH
	bgt		no_touch

touch:
	teq		r7, #FALSE				/* We can't teq #TRUE due to constant value exceeding 8 bits */
	bne		exit_touch
	mov		r7, #TRUE
	bl		light_led_disable
	bl		touch_detected
	b		exit_touch

no_touch:
	teq		r7, #FALSE
	beq		exit_touch
	mov		r7, #FALSE
	bl		light_led_enable
	bl		touch_lost

exit_touch:
	mov		r0, #SYSTICK_50MS
	bl		nx_systick_wait_ms

	pop		{pc}


/* Line Follower Behavior
 *
 */
bbr_line_follower:
	/* Line Follower Algorithm:
	 * 1. Determine if we're:
	 *     -- inside line
	 *     -- on edge
	 *     -- outside line
	 * 2. If Inside Line, move straight ahead
	 * 3. If On Edge, rotate slowly
	 * 4. If Outside Line, rotate quickly
	 */
	push	{lr}

	/* Get Light Sensor min and max values */
	ldr		r2, =min
	ldrb	r0, [r2]			/* min */
	ldrb	r1, [r2, #1]		/* max */

	/* Line Determination:
	 * The checks must be ordered from lower range to higher range
	 * so the sequence is opposite of that given in the algorithm pseudocode
	 */
check_white:
	cmp		r0, #WHITE_MIN
	blo		found_unknown
	cmp		r1, #WHITE_MAX
	bhi		check_edge
	bl		fast_cwrotate_motion
	b		exit_bbr_line_follower
check_edge:
	cmp		r0, #EDGE_MIN
	blo		found_unknown
	cmp		r1, #EDGE_MAX
	bhi		check_black
	bl		slow_cwrotate_motion
	b		exit_bbr_line_follower
check_black:
	cmp		r0, #BLACK_MIN
	blo		found_unknown
	cmp		r1, #BLACK_MAX
	bhi		found_unknown
	bl		forward_motion
	b		exit_bbr_line_follower

found_unknown:
	bl		stop_motion
exit_bbr_line_follower:
	pop		{pc}

/* main
 *    Main Program
 *		R5: Address Pointer to Light Sensor Readings Array
 *		R6: Index of Light Sensor Readings
 *		R7: Touched (boolean)
 *		R8: Iteration Counter (termination)
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

	mov		r7, #FALSE		// ????
	ldr		r8, =MAX_ITERATIONS

	ldr		r0, =title
	bl		nx_progtitle

#ifdef ENABLE_BREAKPOINTS
	dbg__bkpt_arm
#endif

break:
	nop		/* Prevent GDB from stepping inside nx_systick_wait_ms due to breakpoint */
	mov		r0, #SYSTICK_1000MS
	bl		nx_systick_wait_ms

	bl		light_led_enable

main_loop:
	subs	r8, r8, #1
	beq		exit_main

	/* Perform Sensor Readings */
	bl		get_light_readings
	bl		get_touch_status

	/* Evaluate Behaviors */
	bl		bbr_line_follower
	bl		bbr_grasp_object
	bl		bbr_play_tone

	/* Arbiter */
main_arbitration:
	bl		grasper_arbiter

	/* Actuators */
main_actuator:
	bl		grasper_actuation
	b		main_loop				/* continue event loop execution */

exit_main:
	bl		stop_motion				/* Stop motors */
	bl		light_led_disable
	bl		nx_progshutdown
	pop		{pc}

.end
