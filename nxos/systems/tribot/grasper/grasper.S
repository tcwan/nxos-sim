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

/* Copyright (C) 2007-2012 the NxOS developers
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
#include "systems/tribot/include/tribot.h"

/* To disable Manual Breakpoints, change the following to #undef ENABLE_BREAKPOINTS */
#define ENABLE_BREAKPOINTS
/* To disable Motor Debugging, change the following to #undef DEBUG_MOTOR */
#undef DEBUG_MOTOR
/* To disable Min-Max Debugging, change the following to #undef DEBUG_MIN_MAX */
#undef DEBUG_MIN_MAX

	.equ	MAX_ITERATIONS, 0x0FFFF


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

	/* Wheel Control Constants */
	.equ	FWD_SPEED, 60
	.equ	FASTROT_SPEED, 50
	.equ	SLOWROT_SPEED, 30

	/* Claw Control Constants
	 *    Open and Close Speeds are directional (signed)
	 * WARNING: Be conservative with the Open and Close Speeds, since we
	 *    run the motors until it hits the limiters and the Tachometer stops changing.
	 *    Using too high a speed may pop the claw assembly!
	 */
	.equ	OPEN_SPEED, 10
	.equ	CLOSE_SPEED, -10
	.equ	TACHO_THRESH, 1						/* Need value of 1 for reliability of detecting limits */

.data
.align 4

title:	 .asciz "Grasper Bot"
pressed:  .asciz "Touch Pressed! "
released: .asciz "Touch Released!"
opened:  .asciz "Claw Opened!"
closed:  .asciz "Claw Closed!"
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
touched:  .byte   0

/* Claw Variables */
claw_position: .word 0
claw_oldpos:   .word 0
claw_closed: .byte	0

/*
 * Behavior State Variables
 */


/* Signal Inhibition Values */
#define MOTOR_INHIBITED 0x80
#define TONE_INHIBITED 0x00
#define TONE_ENABLED_FREQ 2500		/* Hz */
#define TONE_ENABLED_DUR   500		/* ms */

/* Current Actuator Settings */
actuator_portA:          .byte MOTOR_INHIBITED
actuator_portB:          .byte MOTOR_INHIBITED
actuator_portC:          .byte MOTOR_INHIBITED

actuator_tone_freq:      .word TONE_INHIBITED
actuator_tone_dur:       .word TONE_INHIBITED

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
 *    Note: This routine blocks until all samples have been collected
 *		R5: Address Pointer to Light Sensor Readings Array
 *		R6: Index of Light Sensor Readings
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
 *    Retrieve Touch Sensor value and store in variable touchval,
 *    Update Touch Status Boolean touched, possibly perform debouncing
 *      This routine converts raw A/D input value to an 8-bit Boolean
 *      TRUE (0xFF)/FALSE (0x00) flag.
 *      In addition, it updates the LCD display;
 *          and disables the Light Sensor LED output when active,
 *          and reenables the Light Sensor LED output when not active.
 *
 *		R4: Address Pointer to Touch variables
 */
 get_touch_status:
 	push	{r4, lr}
	mov		r0, #TOUCH_PORT
	bl		nx_sensors_analog_get
	ldr		r4, =touchval
	strb	r0, [r4]		/* Store Touch Value */

	cmp		r0, #TOUCH_THRESH
	ldrb	r0, [r4, #1]			/* Retrieve Touch Status to R0, Note: Does not modify flags */
	bgt		no_touch

touch:
	teq		r0, #FALSE				/* We can't teq #TRUE due to constant value exceeding 8 bits */
	bne		exit_get_touch_status
	mov		r0, #TRUE
	strb	r0, [r4, #1]			/* Update Touch Status (non-zero value, truncated to 8 bits) */
	bl		light_led_disable
	bl		touch_detected
	b		exit_get_touch_status

no_touch:
	teq		r0, #FALSE
	beq		exit_get_touch_status
	mov		r0, #FALSE
	strb	r0, [r4, #1]			/* Update Touch Status (zero value, truncated to 8 bits) */
	bl		light_led_enable
	bl		touch_lost

exit_get_touch_status:
	mov		r0, #SYSTICK_3MS
	bl		nx_systick_wait_ms	/* Delay 3 ms before next reading (Required by AVR A/D Converter) */
 	pop		{r4, pc}

/* get_claw_status
 *    Retrieve Claw Motor Tachometer value and store in variable claw_position.
 *		R4: Address Pointer to Claw variables
 */
 get_claw_status:
 	push	{r4, lr}
 	mov		r0, #CLAW_PORT	/* Specify Claw Motor Port */
 	bl		nx_motors_get_tach_count
	ldr		r4, =claw_position
	str		r0, [r4]			/* Store 32-bit tachometer count */

exit_get_claw_status:
	pop		{r4, pc}


/* claw_open
 *    Open Claws to maximum aperature.
 *      Keep motor engaged until tachometer shows no progress
 *      Note: This is best done using lower speed to the Motor (within Threshold value)
 *		R4: Address Pointer to Claw variables
 */
claw_open:
 	push	{r4, lr}
	ldr		r4, =claw_position

claw_start_opening:
 	mov		r0, #CLAW_PORT
 	mov		r1, #OPEN_SPEED
 	bl		nx_motors_rotate
claw_keep_opening:
	mov		r0, #SYSTICK_100MS
	bl		nx_systick_wait_ms	/* Wait 100 ms before checking Tachometer */
	bl		get_claw_status

	ldr		r0, [r4]			/* Current Claw Position */
	ldr		r1, [r4, #4]		/* Old Claw Position */
	subs	r2, r0, r1			/* Current - Old Positions */
	rsblt	r2, r0, r1			/* Absolute difference in R2 */
	str		r0, [r4, #4]		/* Store Current Claw Position as Old Claw Position */
	cmp		r2, #TACHO_THRESH	/* Is it within margin of error? */
	bhi		claw_keep_opening

claw_stop_opening:
 	mov		r0, #CLAW_PORT
 	mov		r1, #TRUE			/* We want braking */
	bl		nx_motors_stop

 	mov		r0, #FALSE
 	strb	r0, [r4, #8]		/* Update claw_closed */

	ldr		r0, =opened
	bl		nx_progcontent2
	pop		{r4, pc}

/* claw_close
 *    Close Claws to minimum aperature (gripping object).
 *      Keep motor engaged until tachometer shows no progress (within Threshold value)
 *      Note: This is best done using lower speed to the Motor
 *		R4: Address Pointer to Claw variables
 */
claw_close:
 	push	{r4, lr}
	ldr		r4, =claw_position

claw_start_closing:
 	mov		r0, #CLAW_PORT
 	mov		r1, #CLOSE_SPEED
 	bl		nx_motors_rotate
claw_keep_closing:
	mov		r0, #SYSTICK_100MS
	bl		nx_systick_wait_ms	/* Wait 100 ms before checking Tachometer */
	bl		get_claw_status

	ldr		r0, [r4]			/* Current Claw Position */
	ldr		r1, [r4, #4]		/* Old Claw Position */
	subs	r2, r0, r1			/* Current - Old Positions */
	rsblt	r2, r0, r1			/* Absolute difference in R2 */
	str		r0, [r4, #4]		/* Store Current Claw Position as Old Claw Position */
	cmp		r2, #TACHO_THRESH	/* Is it within margin of error? */
	bhi		claw_keep_closing

claw_stop_closing:
 	mov		r0, #CLAW_PORT
 	mov		r1, #TRUE			/* We want braking */
	bl		nx_motors_stop

 	mov		r0, #TRUE
 	strb	r0, [r4, #8]		/* Update claw_closed */

	ldr		r0, =closed
	bl		nx_progcontent2
	pop		{r4, pc}

/* Grasp Object Behavior
 *    TBD: ALGORITHM
 */

bbr_grasp_object:
	push	{lr}

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

/* Play Tone Behavior
 *
 */
bbr_play_tone:
	/* Play Tone Algorithm:
	 *    Determine if Touch Sensor is Activated
	 *    and Claw is Closed
	 *    If True, enable Tone Playback
	 *    Else, keep silent.
	 */
	push	{lr}
	ldr		r2, =actuator_tone_freq	/* Pointer to Tone Variables */

	ldr		r1, =touched
	ldrb	r0, [r1]		/* retrieve Touched status */
	cmp		r0, #FALSE
	beq		keep_silent
	ldr		r1, =claw_closed
	ldrb	r0, [r1]		/* retrieve Claw Status */
	cmp		r0, #FALSE
	beq		keep_silent

enable_tone:
	ldr		r0, =TONE_ENABLED_FREQ
	str		r0, [r2]			/* Frequency */
	mov		r0, #TONE_ENABLED_DUR
	str		r0, [r2, #4]		/* Duration */
	b		exit_bbr_play_tone
keep_silent:
	mov		r0, #TONE_INHIBITED
	str		r0, [r2]			/* Frequency */
	str		r0, [r2, #4]		/* Duration */

exit_bbr_play_tone:
	pop		{pc}

/* Grasper Arbiter
 *
 */

grasper_arbiter:
	push	{lr}
exit_grasper_arbiter:
	pop		{pc}

/* Grasper Actuator
 *
 */
grasper_actuation:
	push	{lr}

	/* Speaker Actuation */
	ldr		r2, =actuator_tone_freq
	ldr		r0, [r2]			/* Frequency */
	ldr		r1, [r2, #4]		/* Duration */
	cmp		r0, #TONE_INHIBITED
	blne	nx_sound_freq		/* Play Tone if Not TONE_INHIBITED */

exit_grasper_actuation:
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
	mov		r0, #LIGHT_PORT
	bl		nx_sensors_analog_enable
	mov		r0, #TOUCH_PORT
	bl		nx_sensors_analog_enable


	mov		r0, #FALSE
	ldr		r1, =touched
	strb	r0, [r1]			/* touched boolean */
	ldr		r1, =claw_closed
	strb	r0, [r1]			/* claw_closed boolean */
	ldr		r4, =claw_oldpos
	str		r0, [r4]			/* Initialize Old Position = 0 (default initial position after nx__motors_init) */

	bl		nx__motors_init		/* Initialize Motors */

	ldr		r2, =actuator_tone_freq		/* Pointer to Tone Variables */
	mov		r0, #TONE_INHIBITED
	str		r0, [r2]			/* Frequency */
	str		r0, [r2, #4]		/* Duration */

	bl		claw_open
	bl		light_led_enable
	ldr		r8, =MAX_ITERATIONS	/* Execution Lifetime Iteration Limiter */

	pop		{pc}

/** shutdown_robot
 *    Robot Specific Shutdown tasks
 *    Customize this routine for your needs
 *
 */
shutdown_robot:
	push	{lr}
	bl		stop_motion				/* Stop motors */
	bl		light_led_disable
	pop		{pc}

/** main
 *    Main Program
 *		R7: Touched (boolean)
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

main_loop:
	subs	r8, r8, #1
	beq		robot_stop

	/* Perform Sensor Readings */
	bl		get_light_readings
	bl		get_touch_status

#if 1
	// Debug Grasping Function
	ldr		r4, =touched
	ldrb	r0, [r4]
	teq		r0, #FALSE			/* Touched Activated returns 255, not equal to #TRUE */
	blne	claw_close
	bleq	claw_open
#endif

	/* Evaluate Behaviors */
//	bl		bbr_line_follower
//	bl		bbr_grasp_object
//	bl		bbr_play_tone

	/* Arbiter */
main_arbitration:
//	bl		grasper_arbiter

	/* Actuators */
main_actuator:
//	bl		grasper_actuation

#if 1
	// For Debugging
	mov		r0, #SYSTICK_500MS
	bl		nx_systick_wait_ms
#endif

	b		main_loop				/* continue event loop execution */

robot_stop:
	bl		shutdown_robot				/* Stop motors */

/********************** End Customization Here **********************/
exit_main:
	bl		nx_progshutdown
	pop		{pc}

.end
