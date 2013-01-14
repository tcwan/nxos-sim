/** @file mover.S
 *  @brief Tribot Mover Test Program
 *  Test Basic Tribot Functionality
 *
 * The following behaviors have been implemented
 * - Idle
 * - Follow Line
 * - Open Claws
 * - Grasp Object
 * - Move Object
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

	.equ	IDLE_TONE_INTERVAL, SYSTICK_500MS			/* FIXME: May need to be > TONE_ENABLED_DUR to be safe */

	/* LCD Display Constants */
	.equ	TOUCH_ROW, 3				/* Touch Display Row Index */
	.equ	SOUND_ROW, 4				/* Sound Display Row Index */
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

	/* Sound Sensor Threshold (0-100) range */
	.equ	SOUND_THRESH, 50			/* FIXME: Needs calibration */

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
	.equ	CLOSE_SPEED, -20
	.equ	TACHO_THRESH, 0						/* Need value of <= 1 for reliability of detecting limits */

	/* Tone Control Constants
	 */
	.equ	TONE_ENABLED_FREQ, 2500				/* Hz */
	.equ	TONE_ENABLED_DUR, 500				/* ms */


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

/** @name Behavior Enums
 *
 * Behaviors.
 * The enums must be consecutive, starting from 0
 */
/*@{*/
ENUM_BEGIN
ENUM_VALASSIGN(BBR_IDLE, 0)     	/**< Initial State. */
ENUM_VAL(BBR_FOLLOW_LINE)       	/**< Follow Line. */
ENUM_VAL(BBR_OPEN_CLAWS)        	/**< Open Claws. */
ENUM_VAL(BBR_GRASP_OBJECT)       	/**< Grasp Object. */
ENUM_VAL(BBR_MOVE_OBJECT)        	/**< Move Object. */
ENUM_END(bbr_behavior_t)
/*@}*/

	.equ	BBR_LAST_BEHAVIOR, BBR_MOVE_OBJECT		/* Need to update this if behavior list changes */
	.equ	NUM_BEHAVIORS, (BBR_LAST_BEHAVIOR+1)

.text
.align 4
title:	  .asciz "Grasper Bot"
pressed:  .asciz "Touch: Pressed "
released: .asciz "Touch: Released"
sound:    .asciz "Sound: Detected"
nosound:  .asciz "Sound: No Sound"
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

/* Speaker Tone Timeout value */
speaker_timestamp: .word	0

#ifdef DEBUG_MIN_MAX
minstring: .asciz "min: "
maxstring: .asciz "max: "
#endif

/* Light Sensor Variables */
readings: .space  n, 0x0
min:      .byte   0
max:      .byte   0

#if 0
/* Line Following Behavior Variables */
robot_state: .byte	0
#endif

/* Sound Sensor Variables */
soundval: .byte   0

/* Touch Sensor Variables */
touchval: .byte   0
touched:  .byte   0

/* Idle Behavior Variables */
tone_active:    .byte FALSE
.align
tone_timestamp: .word 0

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
#define TONE_INHIBITED 0x80000000

/*
 * Whenever we change data types, we need to reinvoke alignment,
 * else the Assembler treats subsequent word variables as shorts
 */

/* Actuator State Data Structure
 *	typedef struct {
 *		SBYTE    speedA;
 *		UBYTE    brakeA;
 *		SBYTE    speedB;
 *		UBYTE    brakeB;
 *		SBYTE    speedC;
 *		UBYTE    brakeC;
 *      UBYTE    curr_state;
 *		// 1-byte padding inserted by Compiler
 *		ULONG    tone_freq;
 *		ULONG    tone_dur;
 *	} actuator_state;         // sizeof (actuator_state) = 16 bytes
 */

	.macro	init_actuator_state state_label, \
			speedA, brakeA, speedB, brakeB, \
			speedC, brakeC, curr_state, tone_freq, tone_dur
	/* Common Structure used to keep latest actuation values */
.align			/* Start structure on an aligned address */
\state_label:
		.byte	\speedA
		.byte	\brakeA
		.byte	\speedB
		.byte	\brakeB
		.byte	\speedC
		.byte	\brakeC
		.byte   \curr_state
.align			/* Needed to force word alignment padding */
		.word	\tone_freq
		.word	\tone_dur
	.endm

.align
actuator_state:
speedA:		.byte	MOTOR_INHIBITED_BYTE
brakeA:		.byte	FALSE
speedB:		.byte	MOTOR_INHIBITED_BYTE
brakeB:		.byte	FALSE
speedC:		.byte	MOTOR_INHIBITED_BYTE
brakeC:		.byte	FALSE
curr_state: .byte	ROBOT_STOP
.align			/* Needed to force word alignment padding */
tone_freq:	.word	TONE_INHIBITED
tone_dur:	.word	TONE_INHIBITED

	.equ	SIZEOF_ACTUATOR_STATE, (. - actuator_state)
	.equ	SPEEDA, (speedA - actuator_state)
	.equ	BRAKEA, (brakeA - actuator_state)
	.equ	SPEEDB, (speedB - actuator_state)
	.equ	BRAKEB, (brakeB - actuator_state)
	.equ	SPEEDC, (speedC - actuator_state)
	.equ	BRAKEC, (brakeC - actuator_state)
	.equ	CURR_STATE, (curr_state - actuator_state)
	.equ	TONE_FREQ, (tone_freq - actuator_state)
	.equ	TONE_DUR, (tone_dur - actuator_state)

/* NXT Motor Port to Actuator State variable Mapping */
	.equ	MOTOR_CLAW_OFFSET, (CLAW_PORT * 2)
	.equ	MOTOR_RWHEEL_OFFSET, (RWHEEL_PORT * 2)
	.equ	MOTOR_LWHEEL_OFFSET, (LWHEEL_PORT * 2)
	.equ	MOTOR_STATE_OFFSET, CURR_STATE
	.equ	SPEAKER_TONE_OFFSET, TONE_FREQ
	.equ	SPEAKER_DURATION_OFFSET, TONE_DUR

#if 0
/* Debug offset calculations */
actuator_state_offsets:
	.byte SPEEDA, BRAKEA, SPEEDB, BRAKEB
	.byte SPEEDC, BRAKEC, CURR_STATE, TONE_FREQ, TONE_DUR
	.byte SIZEOF_ACTUATOR_STATE
#endif

.align
prev_actuator_state: .space	SIZEOF_ACTUATOR_STATE, 0x0
.align
behavior_actuations: .space	(SIZEOF_ACTUATOR_STATE * NUM_BEHAVIORS), 0x0

.text
.align 4
	/* Predefined Actuator Outputs for various behaviors */

	/* Move-Object Behavior Actuation Outputs */
	init_actuator_state bbr_move_object_seek, CLOSE_SPEED, TRUE, SLOWROT_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_SEEK, TONE_INHIBITED, TONE_INHIBITED
			/* Seeking */
	init_actuator_state bbr_move_object_follow, CLOSE_SPEED, TRUE, FWD_SPEED, TRUE, FWD_SPEED, TRUE, ROBOT_FWD, TONE_INHIBITED, TONE_INHIBITED
			/* Follow */

	/* Open-Claws/Grasp-Object Behavior Actuation Outputs */
	init_actuator_state bbr_claws_open, OPEN_SPEED, FALSE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_STOP, TONE_INHIBITED, TONE_INHIBITED
			/* Open Claws */
	init_actuator_state bbr_claws_close, CLOSE_SPEED, FALSE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_STOP, TONE_INHIBITED, TONE_INHIBITED
			/* Close Claws (Grasp Object) */
	init_actuator_state bbr_claws_unlock, STOP_SPEED, FALSE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_STOP, TONE_INHIBITED, TONE_INHIBITED
			/* Unlock Claws */
	init_actuator_state bbr_claws_lock, STOP_SPEED, TRUE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_STOP, TONE_INHIBITED, TONE_INHIBITED
			/* Lock Claws */

	/* Follow-Line Behavior Actuation Outputs for Line Types */
	init_actuator_state bbr_follow_line_black,	MOTOR_INHIBITED_BYTE, FALSE, FWD_SPEED, FALSE, FWD_SPEED, FALSE, ROBOT_FWD, TONE_INHIBITED, TONE_INHIBITED
			/* Forward motion */
	init_actuator_state bbr_follow_line_edge, MOTOR_INHIBITED_BYTE, FALSE, SLOWROT_SPEED, FALSE, STOP_SPEED, FALSE, ROBOT_CCW, TONE_INHIBITED, TONE_INHIBITED
			/* CCW slow rotation */
	init_actuator_state bbr_follow_line_white, MOTOR_INHIBITED_BYTE, FALSE, STOP_SPEED, FALSE, FASTROT_SPEED, FALSE, ROBOT_CW, TONE_INHIBITED, TONE_INHIBITED
			/* CW fast rotation */
	init_actuator_state bbr_follow_line_unknown, MOTOR_INHIBITED_BYTE, FALSE, STOP_SPEED, FALSE, STOP_SPEED, FALSE, ROBOT_STOP, TONE_INHIBITED, TONE_INHIBITED
			/* Stop motion (cruise) */

	/* Idle Behavior Actuation Outputs */
	init_actuator_state bbr_idle_on, MOTOR_INHIBITED_BYTE, FALSE, MOTOR_INHIBITED_BYTE, FALSE, MOTOR_INHIBITED_BYTE, FALSE, ROBOT_STOP, TONE_ENABLED_FREQ, TONE_ENABLED_DUR
			/* Idle Behavior (sound on) */
	init_actuator_state bbr_idle_off, MOTOR_INHIBITED_BYTE, FALSE, MOTOR_INHIBITED_BYTE, FALSE, MOTOR_INHIBITED_BYTE, FALSE, ROBOT_STOP, 0x0, TONE_ENABLED_DUR
			/* Idle Behavior (sound off) */

/* Line Classification Advanced Jump Table */
/* Use macros to make line classification declaration consistent */
    .macro  line_classification_item entry_label, minval, maxval, action_routine
.align
\entry_label:
    .byte   \minval, \maxval
.align
    .word   \action_routine
    .endm

/* Element Offsets for Table Lookup */
    .equ    MINVAL_OFFSET, 0
    .equ    MAXVAL_OFFSET, 1
    .equ    ACTION_ROUTINE_OFFSET, 4

/* The execution clauses for each line_type enum are implemented
 * as routines which do not need any input parameters
 * Each row (item) in the Jump Table takes 8 bytes (with 2 bytes padding)
 */

.text
.align 4
line_classification_jumptable:
    line_classification_item line_outside, WHITE_MIN, WHITE_MAX, fast_cwrotate_motion
    line_classification_item line_edge, EDGE_MIN, EDGE_MAX, slow_ccwrotate_motion
    line_classification_item line_line, BLACK_MIN, BLACK_MAX, forward_motion
    line_classification_item line_unknown, 0, 255, stop_motion

/* End of Table address constant */
    .equ    line_classification_jumptable_end, .
    .equ    SIZEOF_LINE_CLASSIFICATION_ITEM, 8

/* BBR Dispatcher Jump Table Definition */
.text
.align

dispatcher_behavior_jumptable:
	.word	bbr_idle
	.word	bbr_follow_line
	.word	bbr_open_claws
	.word	bbr_grasp_object
#if 0		/* FIXME: Undefined Behavior */
	.word	bbr_move_object
#endif
	.equ	NUM_DISPATCHER_ENTRIES, (. - dispatcher_behavior_jumptable)/4

output_arbiter_jumptable:
	.word	tone_generator_arbiter
	.word	grasping_arbiter
	.word	movement_arbiter

	.equ	NUM_ARBITER_ENTRIES, (. - output_arbiter_jumptable)/4


actuation_controller_jumptable:
	.word	speaker_controller
	.word	claw_controller
	.word	motor_controller

	.equ	NUM_CONTROLLER_ENTRIES, (. - actuation_controller_jumptable)/4

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

sound_detected:
	push	{lr}
	ldr		r0, =sound
	mov		r1, #SOUND_ROW
	bl		nx_progcontentX
	pop		{pc}

sound_absent:
	push	{lr}
	ldr		r0, =nosound
	mov		r1, #SOUND_ROW
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

#if 0
/* Actuator Primitives */

/* Enable Tone
 *    Play a Tone via Speaker
 */
enable_tone:
	push	{lr}
	ldr		r2, =actuator_tone_freq	/* Pointer to Tone Variables */
	ldr		r0, =TONE_ENABLED_FREQ
	str		r0, [r2]			/* Frequency */
	mov		r0, #TONE_ENABLED_DUR
	str		r0, [r2, #4]		/* Duration */
	pop		{pc}

/* Disable Tone
 *    Silence Speaker
 */
disable_tone:
	push	{lr}
	ldr		r2, =actuator_tone_freq	/* Pointer to Tone Variables */
	mov		r0, #TONE_INHIBITED
	str		r0, [r2]			/* Frequency */
	str		r0, [r2, #4]		/* Duration */
	pop		{pc}
#endif


/* BBR Copy Actuator Outputs
 *    Copy Activated Behavior Outputs to Arbiter behavior_actuations array
 *	  Inputs:
 *		R0: behavior_actuations Index
 *		R1: Pointer to Predefined Actuator Outputs for Behavior
 *
 *    Note: This is an internal routine shared by various functions
 */

bbr_copy_actuator_outputs:
	push	{lr}
	ldr		r3, =behavior_actuations			/* candidate actuations array start address */
	mov		r2, #SIZEOF_ACTUATOR_STATE			/* number of bytes per actuator_state struct */
	mla		r0, r2, r0, r3						/* r0 = (sizeof(actuator_state) (r2) * index (r0)) + behavior_actuations start (r3) */
	bl		memmove								/* r0: destination pointer, r1: source pointer, r2: number of bytes to copy */
	pop		{pc}


#if 0
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
#endif

forward_motion:
	push	{lr}
/*	bl		plip */
	ldr		r0, =black
	bl		nx_progcontent

	mov		r0, #BBR_FOLLOW_LINE
	ldr		r1, =bbr_follow_line_black
	bl		bbr_copy_actuator_outputs
	pop		{pc}

fast_cwrotate_motion:
	push	{lr}
/*	bl		plop */
	ldr		r0, =white
	bl		nx_progcontent

	mov		r0, #BBR_FOLLOW_LINE
	ldr		r1, =bbr_follow_line_white
	bl		bbr_copy_actuator_outputs
	pop		{pc}

slow_ccwrotate_motion:
	push	{lr}
/*	bl		plap */
	ldr		r0, =edge
	bl		nx_progcontent

	mov		r0, #BBR_FOLLOW_LINE
	ldr		r1, =bbr_follow_line_edge
	bl		bbr_copy_actuator_outputs
	pop		{pc}

stop_motion:
	push	{lr}
	ldr		r0, =unknown
	bl		nx_progcontent

	mov		r0, #BBR_FOLLOW_LINE
	ldr		r1, =bbr_follow_line_unknown
	bl		bbr_copy_actuator_outputs
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

#if 0
	/* We don't need to delay since the main_loop spaces out the frequency of the A/D call */
	mov		r0, #SYSTICK_3MS
	bl		nx_systick_wait_ms	/* Delay 3 ms before next reading (Required by AVR A/D Converter) */
#endif

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
#if 0
	/* We don't need to delay since the main_loop spaces out the frequency of the A/D call */
	mov		r0, #SYSTICK_3MS
	bl		nx_systick_wait_ms	/* Delay 3 ms before next reading (Required by AVR A/D Converter) */
#endif
 	pop		{r4, pc}

/* get_sound_level
 *    Retrieve Sound Sensor level and store in variable soundval
 *
 *		R4: Address Pointer to Sound variables
 */
get_sound_level:
 	push	{r4, lr}
	mov		r0, #SOUND_PORT
	bl		nx_sensors_analog_get_normalized	/* returned value in range 0-100% */
	ldr		r4, =soundval
	strb	r0, [r4]							/* Store Sound Value */

exit_get_sound_status:
#if 0
	/* We don't need to delay since the main_loop spaces out the frequency of the A/D call */
	mov		r0, #SYSTICK_3MS
	bl		nx_systick_wait_ms	/* Delay 3 ms before next reading (Required by AVR A/D Converter) */
#endif
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
 *
 *	  Input:
 *		R0: behavior_actuations Index
 */
open_claw:
	push	{lr}
	ldr		r1, =bbr_claws_open
	bl		bbr_copy_actuator_outputs
	pop		{pc}

/* Close Claw
 *    Activate Claw Motor (Close), Don't Brake
 *
 *	  Input:
 *		R0: behavior_actuations Index
 */
close_claw:
	push	{lr}
	ldr		r1, =bbr_claws_close
	bl		bbr_copy_actuator_outputs
	pop		{pc}

/* Lock Claw
 *    Stop Claw Motor, Brake
 *
 *	  Input:
 *		R0: behavior_actuations Index
 */
lock_claw:
	push	{lr}
	ldr		r1, =bbr_claws_lock
	bl		bbr_copy_actuator_outputs
	pop		{pc}

/* Unlock Claw
 *    Stop Motor, Brake
 *
 *	  Input:
 *		R0: behavior_actuations Index
 */
unlock_claw:
	push	{lr}
	ldr		r1, =bbr_claws_unlock
	bl		bbr_copy_actuator_outputs
	pop		{pc}

/* Has Claw Started Moving
 *
 * Returns: Boolean (TRUE if Claw Actuator Speed is non-zero)
 *    Check if the Claw Actuator Speed is non-zero
 */
has_claw_started_moving:
	push	{r4, lr}
	ldr		r4, =actuator_state
	ldr		r2, =MOTOR_INHIBITED
	ldrb	r0, [r4, #MOTOR_CLAW_OFFSET]	/* Retrieve currently programmed claw actuator speed */
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

/*
 * Line Classification Action Routine Dispatcher
 *
 *     Find Jump Table Item such that
 *        ((MINVAL <= Light Sensor Min Value) &&
 *         (Light Sensor Max Value <= MAXVAL))
 *
 * On Entry:
 *     R0: Light Sensor Min Value (8-bit unsigned)
 *     R1: Light Sensor Max Value (8-bit unsigned)
 *     Assumes that R0 <= R1 (i.e., min <= max)
 *
 * On Exit:
 *     R0: Line Classification Found (Boolean)
 *
 * Register Usage:
 *     R0: Light Sensor Min Value / Action Routine Address Pointer (if matched)
 *     R1: Light Sensor Max Value
 *     R2: Item Min Value (scratch register)
 *     R3: Item Max Value (scratch register)
 *     R4: Line Classification Table Item Pointer
 *     R5: Line Classification Table End Pointer
 *
 * Linear Search used, since number of cases are small
 */
line_classification_dispatcher:
    PUSH    {R4, R5, LR}
    LDR     R4, =line_classification_jumptable
    LDR     R5, =line_classification_jumptable_end


line_classification_loop:
    CMP    R4, R5
	MOVHS  R0, #FALSE
    BHS    exit_line_classification_dispatcher	/* Traversed entire table, exit (not found) */

    LDRB   R2, [R4, #MINVAL_OFFSET]         /* Retrieve Min & Max Bounds for Item */
    LDRB   R3, [R4, #MAXVAL_OFFSET]

check_bounds:
    CMP    R0, R3
    BLO    next_line_classification_item    /* R0 < MINVAL */
    CMP    R1, R4
    BHI    next_line_classification_item    /* R1 > MAXVAL */

matched_classification_item:
/* (MINVAL <= R0) && (R1 <= MAXVAL) */
    LDR    R0, [R4, #ACTION_ROUTINE_OFFSET] /* R0 contains action routine address */
    MOV    LR, PC                           /* LR = PC + 8 (pipeline) == done_execution */
    MOV    PC, R0                           /* Call Action Routines */
done_execution:
	MOV		R0, #TRUE					/* Return Line Classification Found (TRUE) */
    B       exit_line_classification_dispatcher

next_line_classification_item:
    ADD    R4, R4, #SIZEOF_LINE_CLASSIFICATION_ITEM
    B      line_classification_loop         /* Repeat for next item */

exit_line_classification_dispatcher:
    POP   {R4, R5, PC}

/* Arbiter Routines */

/* Get Actuation Element Double Unsigned Byte Macro
 *	Retrieve the Double Unsigned Byte at memory address given by:
 *    R0 = behavior_actuations_ptr_reg[array_index_reg] + element1_offset
 *    R1 = behavior_actuations_ptr_reg[array_index_reg] + element2_offset
 *
 * Inputs:
 *    behavior_actuations_ptr_reg: Register containing behavior_actuations pointer
 *    array_index_reg: Register containing array index
 *    element1_offset: Element 1 Offset
 *    element2_offset: Element 2 Offset
 *
 * Returns:
 *    R0: signed byte1 element value
 *    R1: signed byte2 element value
 *
 * Register Usage:
 *    R1: Pointer calculation register
 *
 */
	.macro get_actuation_element_double_unsigned_byte behavior_actuations_ptr_reg, array_index_reg, element1_offset, element2_offset
	mov		r1, #SIZEOF_ACTUATOR_STATE
	mla		r1, \array_index_reg, r1, \behavior_actuations_ptr_reg	/* r1 = (index (array_index_reg) * sizeof(actuator_state) (r1)) + behavior_actuations_ptr_reg */
	ldrb	r0, [r1, \element1_offset]
	ldrb	r1, [r1, \element2_offset]
	.endm

/* Get Actuation Element Double Signed Byte Macro
 *	Retrieve the Double Signed Byte at memory address given by:
 *    R0 = behavior_actuations_ptr_reg[array_index_reg] + element1_offset
 *    R1 = behavior_actuations_ptr_reg[array_index_reg] + element2_offset
 *
 * Inputs:
 *    behavior_actuations_ptr_reg: Register containing behavior_actuations pointer
 *    array_index_reg: Register containing array index
 *    element1_offset: Element 1 Offset
 *    element2_offset: Element 2 Offset
 *
 * Returns:
 *    R0: signed byte1 element value
 *    R1: signed byte2 element value
 *
 * Register Usage:
 *    R1: Pointer calculation register
 *
 */
	.macro get_actuation_element_double_signed_byte behavior_actuations_ptr_reg, array_index_reg, element1_offset, element2_offset
	mov		r1, #SIZEOF_ACTUATOR_STATE
	mla		r1, \array_index_reg, r1, \behavior_actuations_ptr_reg	/* r1 = (index (array_index_reg) * sizeof(actuator_state) (r1)) + behavior_actuations_ptr_reg */
	ldrsb	r0, [r1, \element1_offset]
	ldrsb	r1, [r1, \element2_offset]							/* Technically we want unsigned byte, but it doesn't make a difference since we store the byte without checking it */
	.endm

/* Get Actuation Element Double Word Macro
 *	Retrieve the Double Word at memory address given by:
 *    R0 = behavior_actuations_ptr_reg[array_index_reg] + element1_offset
 *    R1 = behavior_actuations_ptr_reg[array_index_reg] + element2_offset
 *
 * Inputs:
 *    behavior_actuations_ptr_reg: Register containing behavior_actuations pointer
 *    array_index_reg: Register containing array index
 *    element1_offset: Element 1 Offset
 *    element2_offset: Element 2 Offset
 *
 * Returns:
 *    R0: word1 element value
 *    R1: word2 element value
 *
 * Register Usage:
 *    R1: Pointer calculation register
 *
 */
	.macro get_actuation_element_double_word behavior_actuations_ptr_reg, array_index_reg, element1_offset, element2_offset
	mov		r1, #SIZEOF_ACTUATOR_STATE
	mla		r1, \array_index_reg, r1, \behavior_actuations_ptr_reg	/* r1 = (index (array_index_reg) * sizeof(actuator_state) (r1)) + behavior_actuations_ptr_reg */
	ldr		r0, [r1, \element1_offset]
	ldr		r1, [r1, \element2_offset]
	.endm

/* Movement Arbiter
 *	Determine the Movement (Wheel) Actuation output values
 *
 * Register Usage:
 *    R4: Pointer to behavior_actuations Array, actuator_state struct
 *    R5: Number of Behaviors
 *
 */

movement_arbiter:
	push	{r4-r9, lr}
	ldr		r4, =behavior_actuations
	mov		r5, #NUM_BEHAVIORS				/* Assume at least 1 */
movement_arbiter_loop:
	subs	r5, r5, #1						/* Convert behavior count to array index */
	blt		movement_copy_output			/* Last entry is Inhibited, copy it over anyway */

	/* Right Wheel Outputs */
	get_actuation_element_double_signed_byte r4, r5, #MOTOR_RWHEEL_OFFSET, #(MOTOR_RWHEEL_OFFSET+1)
	mov		r6, r0
	mov		r7, r1

	/* Left Wheel Outputs */
	get_actuation_element_double_signed_byte r4, r5, #MOTOR_LWHEEL_OFFSET, #(MOTOR_LWHEEL_OFFSET+1)
	mov		r8, r0
	mov		r9, r1

	/* Robot State value */
	get_actuation_element_double_unsigned_byte r4, r5, #MOTOR_STATE_OFFSET, #(MOTOR_STATE_OFFSET+1) /* Padding offset */
	/* R0: curr_state, R1: Padding */

	/* Movement is Inhibited if either of the Movement Speed is MOTOR_INHIBITED */
	cmp		r6, #MOTOR_INHIBITED
	beq		movement_arbiter_loop			/* Movement output is Inhibited, skip to next Behavior */
	cmp		r8, #MOTOR_INHIBITED
	beq		movement_arbiter_loop			/* Movement output is Inhibited, skip to next Behavior */

movement_copy_output:
	ldr		r4, =actuator_state
	strb	r6, [r4, #MOTOR_RWHEEL_OFFSET]
	strb	r7, [r4, #(MOTOR_RWHEEL_OFFSET+1)]
	strb	r8, [r4, #MOTOR_LWHEEL_OFFSET]
	strb	r9, [r4, #(MOTOR_LWHEEL_OFFSET+1)]
	strb	r0, [r4, #MOTOR_STATE_OFFSET]		/* Store activated Movement Speeds, Brake Statuses, and Motor State to actuator_state */
	strb	r1, [r4, #(MOTOR_STATE_OFFSET+1)]

exit_movement_arbiter:
	pop		{r4-r9, pc}						/* and exit */

/* Grasping Arbiter
 *	Determine the Grasping Actuation output values
 *
 * Register Usage:
 *    R4: Pointer to behavior_actuations Array, actuator_state struct
 *    R5: Number of Behaviors
 *
 */

grasping_arbiter:
	push	{r4, r5, lr}
	ldr		r4, =behavior_actuations
	mov		r5, #NUM_BEHAVIORS				/* Assume at least 1 */
grasping_arbiter_loop:
	subs	r5, r5, #1						/* Convert behavior count to array index */
	blt		grasping_copy_output			/* Last entry is Inhibited, copy it over anyway */

	get_actuation_element_double_signed_byte r4, r5, #MOTOR_CLAW_OFFSET, #(MOTOR_CLAW_OFFSET+1)

	/* Grasping is Inhibited if Grasping Speed is MOTOR_INHIBITED */
	cmp		r0, #MOTOR_INHIBITED
	beq		grasping_arbiter_loop			/* Actuator output is Inhibited, skip to next Behavior */

grasping_copy_output:
	ldr		r4, =actuator_state
	strb	r0, [r4, #MOTOR_CLAW_OFFSET]	/* Store activated Grasping Speed and Brake Status to actuator_state */
	strb	r1, [r4, #(MOTOR_CLAW_OFFSET+1)]

exit_grasping_arbiter:
	pop		{r4, r5, pc}						/* and exit */


/* Tone Generator Arbiter
 *	Determine the Tone Generator Actuation output values
 *
 * Register Usage:
 *    R4: Pointer to behavior_actuations Array, actuator_state struct
 *    R5: Number of Behaviors
 *
 */

tone_generator_arbiter:
	push	{r4, r5, lr}
	ldr		r4, =behavior_actuations
	mov		r5, #NUM_BEHAVIORS				/* Assume at least 1 */
tone_generator_arbiter_loop:
	subs	r5, r5, #1						/* Convert behavior count to array index */
	blt		tone_generator_copy_output		/* Last entry is Inhibited, copy it over anyway */

	get_actuation_element_double_word r4, r5, #SPEAKER_TONE_OFFSET, #SPEAKER_DURATION_OFFSET

	/* Tone is Inhibited if both Tone and Duration are TONE_INHIBITED */
	cmp		r0, #TONE_INHIBITED
	bne		tone_generator_copy_output		/* Found a non-Inhibited entry, copy it over */

	cmp		r1, #TONE_INHIBITED
	beq		tone_generator_arbiter_loop		/* Actuator output is Inhibited, skip to next Behavior */

tone_generator_copy_output:
	ldr		r4, =actuator_state
	str		r0, [r4, #SPEAKER_TONE_OFFSET]	/* Store activated Tone and Duration to actuator_state */
	str		r1, [r4, #SPEAKER_DURATION_OFFSET]

exit_tone_generator_arbiter:
	pop		{r4, r5, pc}					/* and exit */

/* Actuator Routines */

/* Motor Actuator
 *    Internal routine to program motor if it has a new setting
 *
 * On Entry:
 *     R0: Motor Index
 *
 * Scratch Registers:
 *		R1: Current Speed Settings
 *		R2: Current Brake Settings
 *		R3: Previous Speed Settings
 *		R4: Previous Brake settings
 *      R5: Pointer to Actuator State variables
 *      R6: Pointer to Previous Actuator State variables
 */
motor_actuator:
	push	{r4, r5, r6, lr}

	/* Motor Actuation */
	ldr		r5, =actuator_state
	ldr		r6, =prev_actuator_state
	add		r5, r5, r0, lsl #1				/* Point to Current Motor Speed (offset = index x 2) */
	add		r6, r6, r0, lsl #1				/* Point to Previous Motor Speed (offset = index x 2) */

	/* Check against Previous Settings */
	/* Note: We need to use LDR Signed Byte to make sure that negative Speed values are loaded correctly */
	ldrsb	r1, [r5]				/* Current Motor Speed */
	ldrb	r2, [r5, #1]			/* Current Brake (bool) */
	ldrsb	r3, [r6]				/* Previous Motor Speed */
	ldrb	r4, [r6, #1]			/* Previous Brake (bool) */

	teq		r1, r3
	bne		motor_update_settings	/* Different settings, so process it */
	teq		r2, r4
	beq		exit_motor_actuator		/* All settings unchanged, just skip to next entry */

motor_update_settings:
	strb	r1, [r6]
	strb	r2, [r6, #1]			/* Copy Current Settings to Previous Settings */

/*		(Scratch)
 *		R0: Motor Index for calling nx_motors_* routines
 *		R1: Speed or Brake settings for calling nx_motors_* routines
 *		R3: MOTOR_INHIBITED Constant for comparisons
 */

motor_check_new_speed:
	ldr		r3, =MOTOR_INHIBITED	/* Explicit load into R2. We can't use MOTOR_INHIBITED as an Operand 2 constant value */
	teq		r1, r3					/* If Inhibited or Stopped, Stop Motor */
	beq		motor_stop
	teq		r1, #STOP_SPEED
	beq		motor_stop

motor_rotate:
 	bl		nx_motors_rotate		/* R1 contains Current Speed Settings */
	b		exit_motor_actuator		/* Done */

motor_stop:
	mov		r1, r2					/* Copy Brake settings into Param 2 register (R1) */
	bl		nx_motors_stop			/* R1 contains Current Brake Settings */

exit_motor_actuator:
	pop		{r4, r5, r6, lr}

/* Motor Controller
 *
 *    Used to drive tribot wheels
 */
motor_controller:
	push	{lr}
	/* FIXME: input checking, etc. */
	mov		r0, #MOTOR_RWHEEL_OFFSET
	bl		motor_actuator
	mov		r0, #MOTOR_LWHEEL_OFFSET
	bl		motor_actuator
	pop		{lr}

/* Claw Controller
 *
 *    Used to control tribot claws
 */
claw_controller:
	push	{lr}
	/* FIXME: input checking, etc. */
	mov		r0, #MOTOR_CLAW_OFFSET
	bl		motor_actuator
	pop		{lr}

/* Speaker Actuator Controller
 *
 *    If Tone_Parameters(actuator_state) == Tone_Parameters(prev_actuator_state)
 *       Check for tone duration expiry
 *           If tone duration expired, inhibit Tone by updating prev_actuator_state
 *    Else
 *       Update prev_actuator_state with new tone parameters
 *       Activate Speaker if not Tone Inhibited
 *       Save timestamp for tone expiry
 *    Endif
 *
 * Registers:
 *    R0: Current Tone Freq
 *    R1: Current Tone Duration
 *    R2: Previous Tone Freq
 *    R3: Previous Tone Duration
 *    R4: Actuator State Struct Pointer
 *    R5: Previous Actuator State Struct Pointer
 *    R6: Speaker Timestamp Pointer
 */
speaker_controller:
	push	{r4, r5, r6, lr}
	/* Speaker Actuation */
	ldr		r4, =actuator_state
	ldr		r5, =prev_actuator_state
	ldr		r6, =speaker_timestamp	/* Setup Pointer to speaker_timestamp */

	ldr		r0, [r4, #TONE_FREQ]
	ldr		r1, [r4, #TONE_DUR]
	ldr		r2, [r5, #TONE_FREQ]
	ldr		r3, [r5, #TONE_DUR]

	cmp		r0, r2
	bne		speaker_update_outputs
	cmp		r1, r3
	bne		speaker_update_outputs	/* If different, do the update */

speaker_outputs_unchanged:
	/* Assume that the freq and duration are both TONE_INHIBITED if any one is TONE_INHIBITED */
	cmp		r2, #TONE_INHIBITED
	beq		exit_speaker_controller
	cmp		r3, #TONE_INHIBITED
	beq		exit_speaker_controller	/* Skip update since we're already inhibited */

	bl		nx_systick_get_ms		/* Current systick in R0 */
	ldr		r1, [r6]				/* Prev speaker_timestamp in R1 */
	time_elapsed r0, r1, r3			/* Returns TRUE if timer exceeded duration TONE_DUR (R3) */
	cmp		r0, #FALSE				/* If Timer reached, return value is TRUE */
	beq		exit_speaker_controller	/* Elapsed Duration < TONE_DUR, so exit */
	mov		r0, #TONE_INHIBITED
	mov		r1, #TONE_INHIBITED		/* Force update of Speaker Output */

speaker_update_outputs:
	str		r0, [r5, #TONE_FREQ]
	str		r1, [r5, #TONE_DUR]		/* Store new tone in previous actuator state */
	cmp		r0, #TONE_INHIBITED
	blne	nx_sound_freq_async		/* Play Tone if Not TONE_INHIBITED */

speaker_update_timestamp:
	bl		nx_systick_get_ms		/* Current systick in R0 */
	str		r0, [r6]				/* Store current systick in speaker_timestamp */

exit_speaker_controller:
	pop		{r4, r5, r6, pc}

/* Behavior Routines */

/* Idle Behavior
 *    Always Activated
 *    Play a Tone while Active
 *      This is accomplished by switching between Tone generation and Silence
 *      to give a punctuated tone output (Beep....Beep....Beep...)
 *
 */
bbr_idle:
	push	{r4, r5, lr}
	/* Check time of last tone change */
	ldr		r4, =tone_timestamp		/* pointer to tone_timestamp */
	bl		nx_systick_get_ms		/* R0 has current timestamp */
	mov		r5, r0					/* Store current timestamp in R5 for later use */

	ldr		r1, [r4]			    /* retrieve previous tone_timestamp */
	time_elapsed r0, r1, #IDLE_TONE_INTERVAL
	cmp		r0, #FALSE
	beq		exit_bbr_idle			/* Has not reached target update time interval yet, exit */

idle_switch_state:
	str		r5, [r4]				/* Store current timestamp in tone_timestamp */

	ldr		r2, =tone_active
	ldrb	r0, [r2]					/* Get Tone Active status */
	teq		r0, #FALSE					/* Check Tone Active status */
	moveq	r0, #TRUE
	ldreq	r1, =bbr_idle_on			/* False, enable tone */
	movne	r0, #FALSE
	ldrne	r1, =bbr_idle_off			/* True, disable tone */
	strb	r0, [r2]					/* Toggle Tone Active Status */

	mov		r0, #BBR_IDLE
	bl		bbr_copy_actuator_outputs
exit_bbr_idle:
    mov     r0, #TRUE					/* Always activated */
	pop		{r4, r5, pc}

/* Line Follower Behavior
 *
 * Returns:
 *    Activated : Boolean
 */
bbr_follow_line:
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
	bne		exit_bbr_follow_line

follow_line_check_line:
	/* Retrieve current min / max values */
	ldr		r2, =min
	ldrb	r0, [r2]			/* min */
	ldrb	r1, [r2, #1]		/* max */

	bl		line_classification_dispatcher

exit_bbr_follow_line:
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

	mov		r0, #BBR_OPEN_CLAWS
	bl		unlock_claw				/* start opening claw */
	b		bbr_open_claws_active	/* let controller do its work */

bbr_claw_check_still_opening:
	teq		r0, #CLAW_OPENING
	movne	r0, #FALSE				/* Not Claw Opening Movement, deactivate Behavior and exit */
	bne		exit_bbr_open_claws

bbr_claw_still_opening:
	bl		has_claw_started_moving
	teq		r0, #FALSE				/* Check if claw motor is moving (non-zero speed) */

	moveq		r0, #BBR_OPEN_CLAWS
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

	mov		r0, #BBR_OPEN_CLAWS
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

	mov		r0, #BBR_GRASP_OBJECT
	bl		unlock_claw				/* start closing claw */
	b		bbr_grasp_object_active	/* let controller do its work */

bbr_claw_check_still_closing:
	teq		r0, #CLAW_CLOSING
	movne	r0, #FALSE				/* Not Claw Closing Movement, deactivate Behavior and exit */
	bne		exit_bbr_grasp_object

bbr_claw_still_closing:
	bl		has_claw_started_moving
	teq		r0, #FALSE				/* Check if claw motor is moving (non-zero speed) */
	moveq	r0, #BBR_GRASP_OBJECT
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

	mov		r0, #BBR_GRASP_OBJECT
	bl		lock_claw				/* Keep Behavior Active for one more iteration */

bbr_grasp_object_active:
	mov		r0, #TRUE				/* Activate Behavior */

exit_bbr_grasp_object:
	pop		{r4, r5, r6, pc}


/* Mover Dispatcher
 *
 *   In this implementation, we iterate from lowest priority to highest priority behaviors
 */
mover_dispatcher:
	push	{lr}
	ldr		r0, =dispatcher_behavior_jumptable
	mov		r1, #NUM_DISPATCHER_ENTRIES
	bl		jumptable_dispatcher

exit_mover_dispatcher:
	pop		{pc}

#if 0
//////// FIXME: Replace Grasper Arbiter with generic Dispatcher ///////////

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
#endif



/* Mover Arbiter
 *	This is just a dispatch routine used to call the respective arbiters.
 *
 *   In this implementation, we iterate from last entry to first entry
 */
mover_arbiter:
	push	{lr}
	ldr		r0, =output_arbiter_jumptable
	mov		r1, #NUM_ARBITER_ENTRIES
	bl		jumptable_dispatcher

exit_mover_arbiter:
	pop		{pc}

/* Mover Actuator Controller
 *	This is just a dispatch routine used to call the respective controllers.
 *
 *   In this implementation, we iterate from last entry to first entry
 */
mover_controller:
	push	{lr}
	ldr		r0, =actuation_controller_jumptable
	mov		r1, #NUM_CONTROLLER_ENTRIES
	bl		jumptable_dispatcher

exit_mover_controller:
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
	mov		r0, #SOUND_PORT
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
	bl		get_sound_level
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

main_dispatch:
	bl		mover_dispatcher

main_arbitration:
	bl		mover_arbiter			/* Behavior Arbiter */

main_actuation:
	bl		mover_controller		/* Actuator Controller */

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
