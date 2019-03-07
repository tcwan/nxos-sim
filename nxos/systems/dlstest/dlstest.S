/** @file duallightsensortest.S
 *  @brief Dual Light Sensor Line Follower Program
 *  Test Basic Tribot Functionality
 *
 * The following behaviors have been implemented
 * - Line following (Light Sensor)
 *
 * This file must be processed using cpp before assembly.
 */

/* Copyright (C) 2007-2013 the NxOS developers
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

	/* Timer Constants */
	.extern	nx_systick_wait_ms
	.equ	SYSTICK_1000MS, 1000
	.equ	SYSTICK_500MS,  500
	.equ	SYSTICK_100MS,  100
	.equ	SYSTICK_50MS,   50
	.equ	SYSTICK_3MS,    3
	.equ	SYSTICK_1MS,    1


	.equ	LIGHT_PORT1, 0		/* Sensor 1 */
	.equ	LIGHT_PORT2, 1		/* Sensor 2 */
	.equ	TOUCH_PORT,  3		/* Sensor 4 */

	/* sensors.h enum */
	.equ	DIGI0, 0
	.equ	DIGI1, 1

	/* Actuator Port Assignments */
	.extern nx_motors_rotate
	.extern nx_motors_stop
	.equ	CLAW_PORT, 0		/* Motor A */
	.equ	RWHEEL_PORT, 1		/* Motor B */
	.equ	LWHEEL_PORT, 2		/* Motor C */

	/* Min-Max constant */
    .equ	n, 5		/* Number of items in array */

/** @name Robot State Enums
 *
 * Robot State.
 * The enums must be consecutive, starting from 0
 */
/*@{*/
ENUM_BEGIN
ENUM_VALASSIGN(ROBOT_STOP, 0)   /**< Initial State. */
ENUM_VAL(ROBOT_FWD)             /**< Robot Moving Forward. */
ENUM_VAL(ROBOT_CW)        	/**< Robot Rotating Clockwise */
ENUM_VAL(ROBOT_CCW)        	/**< Robot Rotating Counter-Clockwise */
ENUM_VAL(ROBOT_TURN)		/**< Robot Seeking Motion (mover, tribot only) */
ENUM_VAL(ROBOT_AVOID)		/**< Robot Avoid Obstacle Motion (tribot only) */
ENUM_END(robot_state_t)
/*@}*/


/* To disable Manual Breakpoints, change the following to #undef ENABLE_BREAKPOINTS */
#undef ENABLE_BREAKPOINTS
/* To disable Tones, change the following to #undef ENABLE_TONES */
#define ENABLE_TONES
/* To disable Motor Debugging, change the following to #undef DEBUG_MOTOR */
#undef DEBUG_MOTOR
/* To disable Min-Max Debugging, change the following to #undef DEBUG_MIN_MAX */
#define DEBUG_MIN_MAX

#ifdef DEBUG_MIN_MAX
	.equ	MAX_ITERATIONS, 100
#else
	.equ	MAX_ITERATIONS, 0x0FFFF
#endif


	/* Light Sensor Color Detection Intensity (0-100) ranges */
	/* 8547 TestPad White: 49-50; Edge: 54; Black: 66-67; Blue: 60-64 */
	/* Changed the range so that it will be a smooth transition from White to Black */
	.equ	WHITE_MIN, 45
	.equ	WHITE_MAX, 53
	.equ	EDGE_MIN,  54
	.equ	EDGE_MAX,  64
	.equ	BLACK_MIN, 65
	.equ	BLACK_MAX, 70

	/* Motor Control Constants */
	.equ	FWD_SPEED, 50
	.equ	FASTROT_SPEED, 40
	.equ	SLOWROT_SPEED, 20
	.equ	REV_SPEED, -20



.data
.align 4

title:	 .asciz "DualSensor Bot"
white:	 .asciz "White!  "
black:	 .asciz "Black!  "
edge:	 .asciz "Edge!   "
gray:	 .asciz "Gray!   "
unknown: .asciz "Unknown!"


#ifdef DEBUG_MIN_MAX
minmaxstr: .asciz "     min   max"
sensor1id: .asciz "[1]: "
sensor2id: .asciz "[2]: "
spacestr:  .asciz "   "
#endif

readings1: .space  n, 0x0
	.equ	MIN_OFFSET, .-readings1
min1:      .byte   0
	.equ	MAX_OFFSET, .-readings1
max1:      .byte   0

readings2: .space  n, 0x0
min2:      .byte   0
max2:      .byte   0
robot_state: .byte	0

.code 32
.text
.align 	4

/*	Min-Max Routine
 * R0: Temporary value storage
 * R1: counter
 * R2: readings Array Pointer (Input to subroutine)
 * R3: min value
 * R4: max value
 */

	.global min_max
min_max:
	push	{r4, lr}
    MOV  	R4, #0         /* Initialize max to smallest 8-bit value */
    MOV  	R3, #255       /* Initialize min to largest 8-bit value */
    MOV  	R1, #n         /* Initialize counter */
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
    STRB 	R3, [R2, #MIN_OFFSET]   /* Store min into memory location */
    STRB 	R4, [R2, #MAX_OFFSET]  /* Store max into memory location */
done_min_max:
	pop		{r4, pc}


/* Actuator Primitives */
#ifdef ENABLE_TONES
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
#endif

/**
 * Inputs:
 *    R0: Port index
 */
light_led_enable:
	push	{lr}
	mov		r1, #DIGI0
	bl		nx_sensors_analog_digi_set
	pop		{pc}

/**
 * Inputs:
 *    R0: Port index
 */
light_led_disable:
	push	{lr}
	mov		r1, #DIGI0
	bl		nx_sensors_analog_digi_clear
	pop		{pc}

black_detected:
	push	{lr}
#ifdef ENABLE_TONES
	bl		plip
#endif
	ldr		r0, =black
	mov		r1, #5
	bl		nx_progcontentX

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

white_detected:
	push	{lr}
#ifdef ENABLE_TONES
	bl		plop
#endif
	ldr		r0, =white
	mov		r1, #5
	bl		nx_progcontentX

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

edge_detected:
	push	{lr}
#ifdef ENABLE_TONES
	bl		plap
#endif
	ldr		r0, =edge
	mov		r1, #5
	bl		nx_progcontentX

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

gray_detected:
	push	{lr}
#ifdef ENABLE_TONES
	bl		plap
#endif
	ldr		r0, =gray
	mov		r1, #5
	bl		nx_progcontentX

	ldr		r2, =robot_state
	mov		r1, #ROBOT_TURN
	ldrb	r0, [r2]
	teq		r0, r1
	beq		1f						/* Already in given state */
	strb	r1, [r2]				/* State Change: Update new state */

	mov		r0, #LWHEEL_PORT
	mov		r1, #REV_SPEED
	bl		nx_motors_rotate
	mov		r0, #RWHEEL_PORT
	mov		r1, #SLOWROT_SPEED
	bl		nx_motors_rotate
1:
	pop		{pc}


unknown_detected:
	push	{lr}
	ldr		r0, =unknown
	mov		r1, #5
	bl		nx_progcontentX

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

/** init_robot
 *    Robot Specific Initialization tasks
 *    Customize this routine for your needs
 *
 *    Note: Modifies various register contents on exit
 */
init_robot:
	push	{lr}
	/* Configure Sensors */
	mov		r0, #LIGHT_PORT1
	bl		nx_sensors_analog_enable
	mov		r0, #LIGHT_PORT2
	bl		nx_sensors_analog_enable
	mov		r0, #TOUCH_PORT
	bl		nx_sensors_analog_enable

	ldr		r5, =readings1
	ldr		r6, =readings2
	ldr		r8, =MAX_ITERATIONS
	pop		{pc}

/** shutdown_robot
 *    Robot Specific Shutdown tasks
 *    Customize this routine for your needs
 *
 */
shutdown_robot:
	push	{lr}
	bl		unknown_detected		/* Stop motors */
	pop		{pc}

/** main
 *    Main Program
 *		R5: Address Pointer to Light Sensor Readings 1 Array
 *		R6: Address Pointer to Light Sensor Readings 2 Array
 *		R7: Index of Light Sensor Readings
 *		R8: Iteration Counter (termination)
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

	bl		init_robot


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

	mov		r0, #LIGHT_PORT1
	bl		light_led_enable
	mov		r0, #LIGHT_PORT2
	bl		light_led_enable
	mov		r7, #n		/* Number of readings to collect */

main_loop:
#ifdef DEBUG_MIN_MAX
	mov		r0, #SYSTICK_1000MS
	bl		nx_systick_wait_ms
#endif

	subs	r8, r8, #1
	beq		robot_stop

get_light_readings:
	sub		r7, r7, #1	/* Convert to Index */
	mov		r0, #LIGHT_PORT1
	bl		nx_sensors_analog_get_normalized	/* returned value in range 0-100% */
	strb	r0, [r5, r7]

	mov		r0, #LIGHT_PORT2
	bl		nx_sensors_analog_get_normalized	/* returned value in range 0-100% */
	strb	r0, [r6, r7]

	mov		r0, #SYSTICK_3MS
	bl		nx_systick_wait_ms	/* Delay 3 ms before next reading (Required by AVR A/D Converter) */

	cmp		r7, #0
	bhi		check_light_readings		/* Skip new Min-Max calculation until we have enough samples */

calc_min_max:
    ldr  	r2, =readings1  	/* Array 1 Address Pointer, setup outside loop */
	bl		min_max
    ldr  	r2, =readings2  	/* Array 2 Address Pointer, setup outside loop */
	bl		min_max
	mov		r7, #n				/* Reset Number of readings to collect */

#ifdef ENABLE_BREAKPOINTS
	dbg__bkpt_arm
#endif

check_light_readings:


#ifdef DEBUG_MIN_MAX
	ldr		r2, =readings1
	ldrb	r9, [r2, #MIN_OFFSET]		/* min1 */
	ldrb	r10, [r2, #MAX_OFFSET]		/* max1 */

	ldr		r0, =minmaxstr
	bl 		nx_progcontent

	mov		r0, #0
	mov		r1, #3
	bl 		nx_display_cursor_set_pos
	ldr		r0, =sensor1id
	bl		nx_display_string

	mov		r0, r9
	bl		nx_display_int

	ldr		r0, =spacestr
	bl		nx_display_string

	mov		r0, r10
	bl		nx_display_int

	ldr		r2, =readings2
	ldrb	r9, [r2, #MIN_OFFSET]		/* min2 */
	ldrb	r10, [r2, #MAX_OFFSET]		/* max2 */

	mov		r0, #0
	mov		r1, #4
	bl 		nx_display_cursor_set_pos
	ldr		r0, =sensor2id
	bl		nx_display_string

	mov		r0, r9
	bl		nx_display_int

	ldr		r0, =spacestr
	bl		nx_display_string

	mov		r0, r10
	bl		nx_display_int


	b		main_loop
#else

	ldr		r9, =readings1
	ldrb	r0, [r9, #MIN_OFFSET]		/* min1 */
	ldrb	r1, [r9, #MAX_OFFSET]		/* max1 */

// Line Follower code ignores second light sensor
//	ldr		r9, =readings2
//	ldrb	r2, [r9, #MIN_OFFSET]		/* min2 */
//	ldrb	r3, [r9, #MAX_OFFSET]		/* max2 */

	/* Line Determination:
	 * The checks must be ordered from lower range to higher range */
check_white:
	cmp		r0, #WHITE_MIN
	blo		found_unknown
	cmp		r1, #WHITE_MAX
	bhi		check_edge
	bl		white_detected
	b		main_loop
check_edge:
	cmp		r0, #EDGE_MIN
	blo		found_unknown
	cmp		r1, #EDGE_MAX
	bhi		check_black
	bl		edge_detected
	b		main_loop
check_black:
	cmp		r0, #BLACK_MIN
	blo		found_unknown
	cmp		r1, #BLACK_MAX
	bhi		found_unknown
	bl		black_detected
	b		main_loop

found_unknown:
	bl		unknown_detected
	b		main_loop
#endif

robot_stop:
	bl		shutdown_robot

/********************** End Customization Here **********************/
exit_main:
	bl		nx_progshutdown
	pop		{pc}

.end
