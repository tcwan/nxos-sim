/** @file grasper.S
 *  @brief Tribot Grasper Test Program
 *  Test Basic Tribot Functionality
 *
 * The following behaviors have been implemented
 * - Idle
 * - Follow Line
 * - Open Claws
 * - Grasp Object
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
#include "systems/tribot/include/macros.h"

/* To disable Manual Breakpoints, change the following to #undef ENABLE_BREAKPOINTS */
#undef ENABLE_BREAKPOINTS
/* To disable Claw Debugging, change the following to #undef DEBUG_CLAW */
#undef DEBUG_CLAW
/* To disable Min-Max Debugging, change the following to #undef DEBUG_MIN_MAX */
#undef DEBUG_MIN_MAX

	.equ	MAX_ITERATIONS, 0x0FFFF
	.equ	CLAWPOS_CHECK_INTERVAL, SYSTICK_100MS		/* Keep CLAWPOS_CHECK_INTERVAL <= ROBOT_SCHED_DURATION to avoid going out of sync */
	.equ	ROBOT_SCHED_DURATION,	SYSTICK_100MS		/* 100 ms per robot scheduler loop */

	/* LCD Display Constants */
	.equ	TOUCH_ROW, 3				/* Touch Display Row Index */
	.equ	BEHAVIOR_ROW, 6				/* Behavior Display Row Index */

	/* Light Sensor Color Detection Intensity (0-100) ranges */
	/* Light Sensor Raw Readings: White: 470-520; Edge: 540-580; Black: 680-700 */
	/* Changed the range so that it will be a smooth transition from White to Black */
	.equ	WHITE_MIN, 45
	.equ	WHITE_MAX, 53
	.equ	EDGE_MIN,  54
	.equ	EDGE_MAX,  64
	.equ	BLACK_MIN, 65
	.equ	BLACK_MAX, 70

	/* Touch Sensor Threshold */
	/* Touch Sensor Raw Readings: Pressed: 183; Released: 1023 */
	.equ	TOUCH_THRESH, 256

	/* Wheel Control Constants */
	.equ	STOP_SPEED, 0
	.equ	FWD_SPEED, 30
	.equ	FASTROT_SPEED, 40
	.equ	SLOWROT_SPEED, 20

	/* Claw Control Constants
	 *    Open and Close Speeds are directional (signed)
	 * WARNING: Be conservative with the Open and Close Speeds, since we
	 *    run the motors until it hits the limiters and the Tachometer stops changing.
	 *    Using too high a speed may pop the claw assembly!
	 */
	.equ	OPEN_SPEED, 10
	.equ	CLOSE_SPEED, -10
	.equ	TACHO_THRESH, 1						/* Need value of 1 for reliability of detecting limits */


/** @name Claw Movement State Enums
 *
 * Claw Movement State.
 * The enums must be consecutive, starting from 0
 */
/*@{*/
ENUM_BEGIN
ENUM_VALASSIGN(CLAW_STOPPED, 0)   /**< Initial State. */
ENUM_VAL(CLAW_OPENING)            /**< Claw Opening. */
ENUM_VAL(CLAW_CLOSING)        	  /**< Clow Closing. */
ENUM_END(claw_movement_state_t)
/*@}*/

.text
.align 4
title:	  .asciz "Grasper Bot"
pressed:  .asciz "Touch: Pressed "
released: .asciz "Touch: Released"
opened:   .asciz " Claw: Opened"
closed:   .asciz " Claw: Closed"
white:	  .asciz " Line: White  "
black:	  .asciz " Line: Black  "
edge:	  .asciz " Line: Edge   "
unknown:  .asciz " Line: Unknown"

graspobject_behavior: .asciz "BBR:Grasp-Object"
openclaws_behavior:	  .asciz "BBR:Open-Claws  "
followline_behavior:  .asciz "BBR:Follow-Line "
idle_behavior:        .asciz "BBR:Idle        "


.data
.align 4

/* Scheduler Timeout value */
sched_tick:	.word	0

#ifdef DEBUG_MIN_MAX
minstring: .asciz "min: "
maxstring: .asciz "max: "
#endif

/* Light Sensor Variables */
readings: .space  n, 0x0
min:      .byte   0
max:      .byte   0

/* Line Following Behavior Variables */
robot_state: .byte	0

/* Touch Sensor Variables */
touchval: .byte   0
touched:  .byte   0

.align 4
/*
 * GNU Assembler BUG?
 * We need to redefine word alignment here, else the
 * Assembler treats the following word variables as
 * shorts
 */

/* Claw Behavior Variables */
claw_timestamp: .word 0
claw_oldtstamp: .word 0
claw_position:  .word 0
claw_oldpos:    .word 0
claw_closed:    .byte 0
claw_movement:  .byte 0



/* Signal Inhibition Values */
#define MOTOR_INHIBITED 0xFFFFFF80
#define MOTOR_INHIBITED_BYTE (MOTOR_INHIBITED & 0xFF)		/* For data initialization use */

/* Current Actuator Settings */
actuator_speedA:         .byte MOTOR_INHIBITED_BYTE
actuator_speedB:         .byte MOTOR_INHIBITED_BYTE
actuator_speedC:         .byte MOTOR_INHIBITED_BYTE
actuator_brakeA:         .byte FALSE
actuator_brakeB:         .byte FALSE
actuator_brakeC:         .byte FALSE

/* Previous Actuator Settings */
actuator_oldspeedA:      .byte MOTOR_INHIBITED_BYTE
actuator_oldspeedB:      .byte MOTOR_INHIBITED_BYTE
actuator_oldspeedC:      .byte MOTOR_INHIBITED_BYTE
actuator_oldbrakeA:      .byte FALSE
actuator_oldbrakeB:      .byte FALSE
actuator_oldbrakeC:      .byte FALSE

.code 32
.text
.align 	4


/** print_claw_state
 *    Claw Status output to LCD
 */
print_claw_state:
	push	{lr}
	ldr		r1, =claw_closed	/* Use R1 as Pointer to claw_closed */
	ldrb	r0, [r1]			/* Retrieve claw_closed value to R0 */
	teq		r0, #FALSE
	ldreq	r0, =opened
	ldrne	r0, =closed
	bl		nx_progcontent2
	pop		{pc}

/** print_behavior_state
 *    Behavior output to LCD
 *		R0: Behavior Display String
 */
print_behavior_state:
	push	{lr}
	mov		r1, #BEHAVIOR_ROW
	bl		nx_progcontentX
	pop		{pc}

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


/* Sensor Primitives */
touch_detected:
	push	{lr}
	bl		plip
	ldr		r0, =pressed
	mov		r1, #TOUCH_ROW
	bl		nx_progcontentX
	pop		{pc}

touch_lost:
	push	{lr}
	bl		plop
	ldr		r0, =released
	mov		r1, #TOUCH_ROW
	bl		nx_progcontentX
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

/* Actuator Primitives */

/* Update Actuator State
 *    Program Actuator State into Array
 *	  Inputs:
 *		R0: Port Index
 *		R1: Motor Speed
 *		R2: Brake (Boolean)
 *
 *    Note: This is an internal routine shared by various functions
 */
_update_actuator_state:
	push	{lr}
	ldr		r3, =actuator_speedA	/* start address of actuator speed array */
	strb	r1, [r3, r0]			/* store OPEN_SPEED into speed[CLAW_PORT] */
	ldr		r3, =actuator_brakeA	/* start address of actuator brake array */
	strb	r2, [r3, r0]			/* store Brake status into brake[CLAW_PORT] */
	pop		{pc}

/* Brake Wheels
 *    Stop and Brake Wheel Motors
 */
brake_wheels:
	push	{lr}
	ldr		r2, =robot_state
	mov		r1, #ROBOT_STOP
	strb	r1, [r2]				/* State Change: Update new state */

	mov		r0, #RWHEEL_PORT
 	mov		r1, #STOP_SPEED
	mov		r2, #TRUE				/* Brake Wheels when activating claw */
	bl		_update_actuator_state	/* Does not modify R0, R1, R2 */
	mov		r0, #LWHEEL_PORT
	bl		_update_actuator_state	/* Does not modify R0, R1, R2 */

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

	mov		r1, #FWD_SPEED
	mov		r2, #FALSE				/* Don't brake */
	mov		r0, #RWHEEL_PORT
	bl		_update_actuator_state	/* Does not destroy R0, R1, R2 */
	mov		r0, #LWHEEL_PORT
	bl		_update_actuator_state	/* Does not destroy R0, R1, R2 */

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


	mov		r1, #STOP_SPEED
	mov		r2, #FALSE				/* Don't brake */
	mov		r0, #RWHEEL_PORT
	bl		_update_actuator_state	/* Does not destroy R0, R1, R2 */

	mov		r1, #FASTROT_SPEED
	mov		r0, #LWHEEL_PORT
	bl		_update_actuator_state	/* Does not destroy R0, R1, R2 */
1:
	pop		{pc}

slow_ccwrotate_motion:
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

	mov		r1, #STOP_SPEED
	mov		r2, #FALSE				/* Don't brake */
	mov		r0, #LWHEEL_PORT
	bl		_update_actuator_state	/* Does not destroy R0, R1, R2 */

	mov		r1, #SLOWROT_SPEED
	mov		r0, #RWHEEL_PORT
	bl		_update_actuator_state	/* Does not destroy R0, R1, R2 */
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

	mov		r1, #STOP_SPEED
	mov		r2, #FALSE				/* Don't brake */
	mov		r0, #LWHEEL_PORT
	bl		_update_actuator_state	/* Does not destroy R0, R1, R2 */

	mov		r0, #RWHEEL_PORT
	bl		_update_actuator_state	/* Does not destroy R0, R1, R2 */
1:
	pop		{pc}

/* Sensor Input Routine */

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
	mov		r0, #n
	ldr		r1, =readings
	ldr		r2, =min
	ldr		r3, =max
	bl		min_max_ubyte
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
 *	FIXME: Currently we force a 3 ms delay in this routine.
 *			It should be handled using timestamps similar to Claw Position Detection
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

	bl		nx_systick_get_ms
	str		r0, [r4, #-8]			/* Store 32-bit timestamp in claw_timestamp */

	bl		print_claw_state

exit_get_claw_status:
	pop		{r4, pc}

/* Behavior Support Routines */

/* Open Claw
 *    Activate Claw Motor (Open), Don't Brake
 */
open_claw:
	push	{lr}
	mov		r0, #CLAW_PORT
 	mov		r1, #OPEN_SPEED
	mov		r2, #FALSE				/* Don't brake when opening claw */
	bl		_update_actuator_state	/* Store in Actuator State Array */

	mov		r0, #RWHEEL_PORT
 	mov		r1, #STOP_SPEED
	mov		r2, #TRUE				/* Brake Wheels when activating claw */
	bl		_update_actuator_state	/* Store in Actuator State Array */
	mov		r0, #LWHEEL_PORT
	bl		_update_actuator_state	/* Store in Actuator State Array */

	bl		brake_wheels
	pop		{pc}

/* Close Claw
 *    Activate Claw Motor (Close), Don't Brake
 */
close_claw:
	push	{lr}
	mov		r0, #CLAW_PORT
 	mov		r1, #CLOSE_SPEED
	mov		r2, #FALSE				/* Don't brake when closing claw */
	bl		_update_actuator_state	/* Store in Actuator State Array */

	bl		brake_wheels
	pop		{pc}

/* Lock Claw
 *    Stop Claw Motor, Brake
 */
lock_claw:
	push	{lr}
	mov		r0, #CLAW_PORT
 	mov		r1, #STOP_SPEED
	mov		r2, #TRUE				/* Brake when locking claw */
	bl		_update_actuator_state	/* Store in Actuator State Array */

	bl		brake_wheels
	pop		{pc}

/* Unlock Claw
 *    Stop Motor, Brake
 */
unlock_claw:
	push	{lr}
	mov		r0, #CLAW_PORT
 	mov		r1, #STOP_SPEED
	mov		r2, #FALSE				/* Don't Brake when unlocking claw */
	bl		_update_actuator_state	/* Store in Actuator State Array */
	pop		{pc}

/* Has Claw Started Moving
 *
 * Returns: Boolean (TRUE if Claw Actuator Speed is non-zero)
 *    Check if the Claw Actuator Speed is non-zero
 */
has_claw_started_moving:
	push	{r4, lr}
	ldr		r4, =actuator_speedA
	ldr		r2, =MOTOR_INHIBITED
	ldrb	r0, [r4, #CLAW_PORT]	/* Retrieve currently programmed claw actuator speed */
	teq		r0, r2
	beq		claw_is_stopped			/* If Motor Inhibited, it is equivalent to Stopped */
	teq		r0, #STOP_SPEED
	movne	r0, #TRUE				/* Return TRUE if Claw Acutuator Speed is non-zero */
	bne		exit_has_claw_started_moving
claw_is_stopped:
	mov		r0, #FALSE
exit_has_claw_started_moving:
	pop		{r4, pc}

/* Has Claw Fully Stopped
 *
 * Returns: Boolean (TRUE if Claw Fully Stopped)
 *    Check if the Claw Open/Close Action is completed
 *    Some debouncing of inputs is done here.
 *    We only update the status every CLAWPOS_CHECK_INTERVAL
 */
has_claw_fully_stopped:
	push	{r4, lr}
claw_check_update_interval:
	/* Check time of last claw_position update */
	ldr		r4, =claw_position		/* pointer into claw variables */
	ldr		r0, [r4, #-8]			/* retrieve current timestamp */
	ldr		r1, [r4, #-4]			/* retrieve previous timestamp */
	time_elapsed r0, r1, #CLAWPOS_CHECK_INTERVAL
	cmp		r0, #FALSE
	beq		exit_has_claw_fully_stopped	/* Has not reached target update time interval yet, return FALSE */

claw_update_pos:
	ldr		r0, [r4, #-8]
	str		r0, [r4, #-4]			/* update previous timestamp = current timestamp */
	ldr		r0, [r4]				/* retrieve current claw position */
	ldr		r1, [r4, #4]			/* retrieve previous claw position */
	str		r0, [r4, #4]			/* update previous claw position = current claw position */
	subs	r2, r0, r1				/* current claw position - previous claw position */
	rsblt	r2, r0, r1				/* absolute difference in R2 */
	cmp		r2, #TACHO_THRESH		/* is it within margin of error? */
	movhi	r0, #FALSE				/* (difference > TACHO_THRESH) ? FALSE : TRUE */
	movls	r0, #TRUE				/* Return claw_fully_stopped status in R0 */
exit_has_claw_fully_stopped:
	pop		{r4, pc}

/* Behavior Routines */

/* Line Follower Behavior
 *    Always Activated
 *
 */
bbr_idle:
	push	{lr}
	bl		brake_wheels
	pop		{pc}

/* Line Follower Behavior
 *
 * Returns:
 *    Activated : Boolean
 */
bbr_line_follower:
	/* Line Follower Algorithm:
	 *    If Not Touched
	 * 	     1. Determine if we're:
	 *          -- inside line
	 *          -- on edge
	 *          -- outside line
	 *       2. If Inside Line, move straight ahead
	 *       3. If On Edge, rotate slowly
	 *       4. If Outside Line, rotate quickly
	 *       5. If Unknown, Stop Moving
	 *		 Activate Behavior
	 *    Else
	 *		 Deactivate Behavior
	 */
	push	{lr}

	ldr		r2, =touched
	ldrb	r0, [r2]
	teq		r0, #FALSE				/* Touched Activated returns 255, not equal to #TRUE */
	movne	r0, #FALSE				/* Touched (TRUE), deactivate Behavior and exit */
	bne		exit_bbr_line_follower

line_follower_check_line:
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
	b		activate_bbr_line_follower
check_edge:
	cmp		r0, #EDGE_MIN
	blo		found_unknown
	cmp		r1, #EDGE_MAX
	bhi		check_black
	bl		slow_ccwrotate_motion
	b		activate_bbr_line_follower
check_black:
	cmp		r0, #BLACK_MIN
	blo		found_unknown
	cmp		r1, #BLACK_MAX
	bhi		found_unknown
	bl		forward_motion
	b		activate_bbr_line_follower

found_unknown:
	/* If we can't determine the color, stop moving */
	bl		stop_motion

activate_bbr_line_follower:
	mov		r0, #TRUE					/* Always activated */
exit_bbr_line_follower:
	pop		{pc}

/* Open Claws Behavior
 *
 * Returns:
 *    Activated : Boolean
 *
 *    Registers Used:
 *       R4: claw_movement pointer
 *       R5: touched pointer
 *       R6: claw_closed pointer
 */
bbr_open_claws:
	/* Open Claws Algorithm:
	 *    If Claw Movement == STOPPED
	 *	    If Not Touched AND Claw Closed
	 *		  Claw Movement == OPENING
	 *		  Open Claw
	 *		  Activate Behavior
	 *      Else
	 *        Deactivate Behavior
	 *    Else if Claw Movement == OPENING
	 *      If Claw Opening has fully stopped
	 *		  Claw Closed = False
	 *        Claw Movement == STOPPED
	 *        Lock Claw
	 *		Activate Behavior
	 *    Else
	 *      Deactivate Behavior
	 */
	push	{r4, r5, r6, lr}
	/* Setup Pointers at start of routine */
	ldr		r4, =claw_movement
	ldr		r5, =touched
	ldr		r6, =claw_closed

	ldrb	r0, [r4]				/* retrieve Claw Movement Status */
	teq		r0, #CLAW_STOPPED
	bne		bbr_claw_check_still_opening	/* still moving, check if we should stop */

bbr_check_open_claws:
	/* (!touched && claw_closed)
	 * Negate expression for branch to Else Clause
	 * Using De-Morgan's Law, the Else trigger clause is:
	 * (touched || !claw_closed)
	 */
	ldrb	r0, [r5]
	teq		r0, #FALSE				/* Touched Activated returns 255, not equal to #TRUE */
	movne	r0, #FALSE				/* Touched (TRUE), deactivate Behavior and exit */
	bne		exit_bbr_open_claws

	/* Check Claw Status */
	ldrb	r0, [r6]				/* retrieve Claw Closed Status */
	teq		r0, #FALSE
	beq		exit_bbr_open_claws		/* If Opened (Claw Closed == False), deactivate Behavior and exit */

bbr_start_opening_claws:
	mov		r0, #CLAW_OPENING
	strb	r0, [r4]				/* Claw Movement = OPENING */

	bl		unlock_claw				/* start opening claw */
	b		bbr_open_claws_active	/* let controller do its work */

bbr_claw_check_still_opening:
	teq		r0, #CLAW_OPENING
	movne	r0, #FALSE				/* Not Claw Opening Movement, deactivate Behavior and exit */
	bne		exit_bbr_open_claws

bbr_claw_still_opening:
	bl		has_claw_started_moving
	teq		r0, #FALSE				/* Check if claw motor is moving (non-zero speed) */
	bleq	open_claw				/* Keep opening claw */
	beq		bbr_open_claws_active	/* No, still Opening, keep Behavior active */

	bl		has_claw_fully_stopped
	teq		r0, #FALSE				/* check if the movement is complete */
	beq		bbr_open_claws_active	/* No, still Opening, keep Behavior active */

bbr_claw_opening_stopped:
	mov		r0, #FALSE
	strb	r0, [r6]				/* update Claw Closed Status */

	mov		r0, #CLAW_STOPPED
	strb	r0, [r4]				/* Update Claw Movement Status */

	bl		lock_claw				/* Keep Behavior Active for one more iteration */

bbr_open_claws_active:
	mov		r0, #TRUE				/* Activate Behavior */

exit_bbr_open_claws:
	pop		{r4, r5, r6, pc}

/* Grasp Object Behavior
 *
 * Returns:
 *    Activated : Boolean
 *
 *    Registers Used:
 *       R4: claw_movement pointer
 *       R5: touched pointer
 *       R6: claw_closed pointer
 */
bbr_grasp_object:
	/* Grasp Object Algorithm:
	 *    If Claw Movement == STOPPED
	 *	    If Touched AND Not Claw Closed (i.e., Claw Open)
	 *		  Claw Movement == CLOSING
	 *		  Close Claw
	 *		  Activate Behavior
	 *      Else
	 *        Deactivate Behavior
	 *    *** Note: If (Touched AND Claw Closed), the behavior is disabled currently
	 *    Else if Claw Movement == CLOSING
	 *      If Claw Closing has fully stopped
	 *		  Claw Closed = True
	 *        Claw Movement == STOPPED
	 *        Lock Claw
	 *		Activate Behavior
	 *    Else
	 *      Deactivate Behavior
	 */
	push	{r4, r5, r6, lr}
	/* Setup Pointers at start of routine */
	ldr		r4, =claw_movement
	ldr		r5, =touched
	ldr		r6, =claw_closed

	ldrb	r0, [r4]				/* retrieve Claw Movement Status */
	teq		r0, #CLAW_STOPPED
	bne		bbr_claw_check_still_closing	/* still moving, check if we should stop */

bbr_check_grasp_object:
	/* (touched && !claw_closed)
	 * Negate expression for branch to Else Clause
	 * Using De-Morgan's Law, the Else trigger clause is:
	 * (!touched || claw_closed)
	 */
	ldrb	r0, [r5]
	teq		r0, #FALSE				/* Touched Activated returns 255, not equal to #TRUE */
	beq		exit_bbr_grasp_object	/* Touched (R0 == FALSE), deactivate Behavior and exit */

	/* Check Claw Status */
	ldrb	r0, [r6]				/* retrieve Claw Closed Status */
	teq		r0, #FALSE
	movne	r0, #FALSE				/* Claw Closed (TRUE), deactivate Behavior and exit */
	bne		exit_bbr_grasp_object	/* If Claw Closed, deactivate Behavior and exit */

bbr_start_grasp_object:
	mov		r0, #CLAW_CLOSING
	strb	r0, [r4]				/* Claw Movement = CLOSING */

	bl		unlock_claw				/* start closing claw */
	b		bbr_grasp_object_active	/* let controller do its work */

bbr_claw_check_still_closing:
	teq		r0, #CLAW_CLOSING
	movne	r0, #FALSE				/* Not Claw Closing Movement, deactivate Behavior and exit */
	bne		exit_bbr_grasp_object

bbr_claw_still_closing:
	bl		has_claw_started_moving
	teq		r0, #FALSE				/* Check if claw motor is moving (non-zero speed) */
	bleq	close_claw				/* No, Keep closing claw */
	beq		bbr_grasp_object_active	/* No, still Closing, keep Behavior active */

	bl		has_claw_fully_stopped
	teq		r0, #FALSE				/* check if the movement is complete */
	beq		bbr_grasp_object_active	/* No, still Closing, keep Behavior active */

bbr_claw_closing_stopped:
	mov		r0, #TRUE
	strb	r0, [r6]				/* update Claw Closed Status */

	mov		r0, #CLAW_STOPPED
	strb	r0, [r4]				/* Update Claw Movement Status */

	bl		lock_claw				/* Keep Behavior Active for one more iteration */

bbr_grasp_object_active:
	mov		r0, #TRUE				/* Activate Behavior */

exit_bbr_grasp_object:
	pop		{r4, r5, r6, pc}

/* Grasper Arbiter
 *	 The Arbiter implemented here is a strict priority arbiter
 *   with lazy evaluation. i.e., behaviors are evaluated from highest
 *   priority to lowest priority. As soon as the evaluated behavior
 *   is active, it will ignore all lower priority behaviors and
 *   proceed to actuation. Otherwise, if the evaluated behavior is
 *   not active, the behavior with the next highest priority will be
 *   evaluated.
 *
 *   The lowest priority behavior will always be active as long as
 *   all other behaviors are not activated.
 *
 *   This is accomplished using a if-then-elseif-else control structure.
 *   All defined behaviors will be accessed via direct subroutine calls.
 */

grasper_arbiter:
	push	{lr}
	/* Evaluate Behaviors */
eval_grasp_object:
	bl		bbr_grasp_object
	teq		r0, #FALSE
	ldrne	r0, =graspobject_behavior
	bne		exit_grasper_arbiter		/* Activated, skip other behaviors */
eval_open_claws:
	bl		bbr_open_claws
	teq		r0, #FALSE
	ldrne	r0, =openclaws_behavior
	bne		exit_grasper_arbiter		/* Activated, skip other behaviors */
eval_line_follower:
	bl		bbr_line_follower
	teq		r0, #FALSE
	ldrne	r0, =followline_behavior
	bne		exit_grasper_arbiter		/* Activated, skip other behaviors */

arbiter_idle:
	bl		bbr_idle
	ldr		r0, =idle_behavior

exit_grasper_arbiter:
	bl		print_behavior_state
	pop		{pc}

/* Grasper Actuator Controller
 *
 *		(Scratch)
 *		R0: Motor Index for calling nx_motors_* routines
 *		R1: Speed or Brake settings for calling nx_motors_* routines
 *		R2: MOTOR_INHIBITED Constant for comparisons
 *
 *		(Preserved)
 *		R4: Address Pointer to Actuator Speed variables
 *		R5: Address Pointer to Actuator Brake variables
 *		R6: Address Pointer to Previous Actuator Speed variables
 *		R7: Address Pointer to Previous Actuator Brake variables
 *		R8: Motor Port Index
 */
grasper_controller:
	push	{r4-r8, lr}

	/* Motor Actuation State Addresses
	 */
	ldr		r4, =actuator_oldspeedA	/* Previous Speed Base Address */
	ldr		r5, =actuator_speedA	/* Speed Base Address */
	ldr		r6, =actuator_oldbrakeA	/* Previous Brake Base Address */
	ldr		r7, =actuator_brakeA	/* Brake Base Address */
	mov		r8, #LWHEEL_PORT		/* Use Port Index as loop counter */

controller_motor_loop:

/*		(Scratch)
 *		R0: Previous Speed Settings
 *		R1: Current Speed Settings
 *		R2: Previous Brake settings
 *		R3: Current Brake Settings
 */
	/* Check against Previous Settings */
	/* Note: We need to use LDR Signed Byte to make sure that negative Speed values are loaded correctly */

	ldrsb	r0, [r4, r8]			/* Previous Motor Speed, retrieved from Speed Base Address + (Port Index) */
	ldrsb	r1, [r5, r8]			/* Current: Motor Speed, retrieved from Speed Base Address + (Port Index) */
	ldrb	r2, [r6, r8]			/* Previous Brake (bool), retrieved from Brake Base Address + (Port Index) */
	ldrb	r3, [r7, r8]			/* Current Brake (bool), retrieved from Brake Base Address + (Port Index) */

	teq		r0, r1
	bne		controller_update_settings	/* Different settings, so process it */
	teq		r2, r3
	beq		controller_motor_cont	/* All settings unchanged, just skip to next entry */

controller_update_settings:
	strb	r1, [r4, r8]
	strb	r3, [r6, r8]			/* Copy Current Settings to Previous Settings */

/*		(Scratch)
 *		R0: Motor Index for calling nx_motors_* routines
 *		R1: Speed or Brake settings for calling nx_motors_* routines
 *		R2: MOTOR_INHIBITED Constant for comparisons
 */

check_new_motor_speed:
	mov		r0, r8					/* Copy to Param 1 register for calling nx_motors_* routines */
	ldr		r2, =MOTOR_INHIBITED	/* Explicit load into R2. We can't use MOTOR_INHIBITED as an Operand 2 constant value */
	teq		r1, r2					/* If Inhibited or Stopped, Stop Motor */
	beq		controller_motor_stop
	teq		r1, #STOP_SPEED
	beq		controller_motor_stop

controller_motor_rotate:
 	bl		nx_motors_rotate
	b		controller_motor_cont	/* Check next loop */

controller_motor_stop:
	mov		r1, r3					/* Copy Brake to Param 2 register (R1) for calling nx_motors_* routines */
	bl		nx_motors_stop

controller_motor_cont:
	subs	r8, r8, #1				/* Decrement Port Index */
	bpl		controller_motor_loop	/* Exit when Index is negative */

exit_grasper_controller:
	pop		{r4-r8, pc}


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


	mov		r0, #TRUE			/* force claw opening on init via Open-Claws Behavior */
	ldr		r1, =claw_closed
	strb	r0, [r1]			/* claw_closed boolean */

	mov		r0, #CLAW_STOPPED
	ldr		r1, =claw_movement
	strb	r0, [r1]			/* claw_movement enum */
	mov		r0, #FALSE
	ldr		r1, =touched
	strb	r0, [r1]			/* touched boolean */
	ldr		r4, =claw_oldpos
	str		r0, [r4]			/* Initialize Old Position = 0 (default initial position after nx__motors_init) */
	ldr		r4, =claw_oldtstamp
	str		r0, [r4]			/* Initialize Claw Position Old Timestamp = 0 */

#if 0
	bl		claw_open_immediate			/* Disabled, use BBR Behavior Open-Claws instead */
#endif

	bl		light_led_enable
	ldr		r8, =MAX_ITERATIONS	/* Execution Lifetime Iteration Limiter */

	bl		nx_systick_get_ms				/* Current systick */
	add		r0, r0, #ROBOT_SCHED_DURATION	/* Next Scheduler Timeout value */
	ldr		r2, =sched_tick
	str		r0, [r2]						/* Update Scheduler Timeout */

	pop		{pc}

/** sleep_robot
 *    Run loop scheduler timing task
 *    This routine will wait till the next scheduler interval, then continue execution of Run Loop
 *    R2: Pointer to sched_tick (previous timer expiry timestamp)
 *    Note: This is a busy wait implementation
 */
sleep_robot:
	push	{lr}
	ldr		r2, =sched_tick					/* Setup Pointer to sched_tick */

cont_sleep:
	bl		nx_systick_get_ms				/* Current systick in R0 */
	ldr		r1, [r2]						/* Prev systick in R1 */
	time_elapsed r0, r1, #ROBOT_SCHED_DURATION	/* Returns TRUE if timer exceeded duration */

	cmp		r0, #FALSE						/* If Timer reached, return value is TRUE */
	beq		cont_sleep						/* Scheduler Timeout < Systick, so exit */

next_sleep_robot:
	bl		nx_systick_get_ms				/* Current systick in R0 */
	str		r0, [r2]						/* Update sched_tick with current systick */

exit_sleep_robot:
	pop		{pc}

/** shutdown_robot
 *    Robot Specific Shutdown tasks
 *    Customize this routine for your needs
 *
 */
shutdown_robot:
	push	{lr}
	bl		claw_close_immediate	/* FIXME: Can we replace it with another routne? */
	bl		stop_motion				/* Stop motors */
	bl		light_led_disable
	pop		{pc}

/* Non-BBR Actuator Routines */

#ifdef DEBUG_CLAW

/* claw_open_immediate
 *    Open Claws to maximum aperature.
 *      Keep motor engaged until tachometer shows no progress
 *      Note: This is best done using slower speed to the Motor (within Threshold value)
 *		R4: Address Pointer to Claw variables
 */
claw_open_immediate:
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

#endif


/* claw_close_immediate
 *    Close Claws to minimum aperature (gripping object).
 *      Keep motor engaged until tachometer shows no progress (within Threshold value)
 *      Note: This is best done using slower speed to the Motor
 *		R4: Address Pointer to Claw variables
 *
 *    Note: This routine is needed by shutdown_robot as we're no longer running the main loop.
 */

claw_close_immediate:
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

	ldr		r4, =claw_closed
 	mov		r0, #TRUE
 	strb	r0, [r4, #8]		/* Update claw_closed */

	ldr		r0, =closed
	bl		nx_progcontent2
	pop		{r4, pc}



/** main
 *    Main Program
 *		R7: Touched (boolean)
 *		R8: Iteration Counter (termination)
 */
	.type   main, %function
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
	bl		get_claw_status

#ifdef DEBUG_CLAW

	// Debug Grasping Function using Direct Claw Motor Actuation
	ldr		r4, =touched
	ldrb	r0, [r4]
	teq		r0, #FALSE				/* Touched Activated returns 255, not equal to #TRUE */
	blne	claw_close_immediate
	bleq	claw_open_immediate

#else

main_arbitration:
	bl		grasper_arbiter			/* Behavior Arbiter */

main_actuation:
	bl		grasper_controller		/* Actuator Controller */

#endif

	bl		sleep_robot				/* Scheduler Wait Loop */
	b		main_loop				/* continue event loop execution */

robot_stop:
	bl		shutdown_robot			/* Stop motors */

/********************** End Customization Here **********************/
exit_main:
	bl		nx_progshutdown
	pop		{pc}

.end
