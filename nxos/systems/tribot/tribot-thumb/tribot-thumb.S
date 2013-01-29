/** @file tribot.S
 *  @brief Tribot Full Test Program
 *
 * The following behaviors have been implemented
 * - Idle
 * - Follow Line
 * - Open Claws
 * - Grasp Object
 * - Move Object
 * - Avoid Obstacle
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
#include "systems/tribot/include/tribot.h"
#include "systems/tribot/include/macros.h"
#include "systems/tribot/include/pid_equates.h"

/* To disable Manual Breakpoints, change the following to #undef ENABLE_BREAKPOINTS */
#undef ENABLE_BREAKPOINTS
/* To disable Sound Input Level Debugging, change the following to #undef DEBUG_SOUND */
#undef DEBUG_ULTRASOUND
/* To disable Avoid Obstacles Behavior Debugging, change the following to #undef DEBUG_AVOID_OBSTACLE */
#define DEBUG_AVOID_OBSTACLE
/* To disable Avoid Obstacles Behavior Debugging, change the following to #undef DEBUG_AVOID_OBSTACLE */
#define DEBUG_PID
/* To use normal PID Convergence behavior, change the following to #undef ENABLE_PID_ABORT */
#undef ENABLE_PID_ABORT

	.equ	MAX_ITERATIONS, 0x0FFFF
	.equ	CLAWPOS_CHECK_INTERVAL, SYSTICK_100MS		/* Keep CLAWPOS_CHECK_INTERVAL <= ROBOT_SCHED_DURATION to avoid going out of sync */
	.equ	ROBOT_SCHED_DURATION,	SYSTICK_100MS		/* 100 ms per robot scheduler loop */

	.equ	IDLE_TONE_INTERVAL, SYSTICK_500MS			/* FIXME: May need to be > TONE_ENABLED_DUR to be safe */

	.equ	OBSTACLE_MINDIST, 10						/* FIXME: Set appropriate min distance (in cm) */
	.equ	OBSTACLE_STOPDIST, 20						/* FIXME: Set appropriate distance to stop avoiding obstacle (in cm) */

	/* PID Configuration Parameters
	 * FIXME: Need to be changed to actual values
	 * KP, KI, KD have the range of 16-bit integer values [MIN_SHORT,MAX_SHORT]
	 * This is multiplied by alpha to give 32-bit resolution values
	 * alphaKP, alphaKI, alphaKD BEFORE initializing the PID Controller
	 * The value of alpha is 2^SCALING_SHIFT, where SCALING_SHIFT is 16
	 * which gives alpha = 65536
	 */

	 /* Applying Kc = 3, T = 100 ms, Pc = 1 s, alpha = 65536 */
    .equ alphaKP, 127795				/* alphaKP = alpha x 0.65 x Kc = 127795 */
    .equ alphaKI, 25559					/* alphaKI = alpha x Kp x T / (0.5 x Pc) = 25559 */
    .equ alphaKD, 153354				/* alphaKD = alpha x Kp x 0.12 x Pc / T = 153354 */
    .equ STEADY_STATE_THRESHOLD, 1	    /* 0 = disabled, !0 = Stop PID Controller after x iterations */

	/* Ultrasound Sensor Calibration Offset */
	.equ	ULTRASOUND_ERR_OFFSET, 3	/* FIXME: Min measurable distance is about 3 cm (1 inch), but it always returns 6 */
	.equ	ULTRASOUND_ERRSTATE_COUNT, 5	/* Used to reset Detected Distances if too many unknown objects /error */

	/* LCD Display Constants */
	.equ	TOUCH_ROW, 3				/* Touch Display Row Index */
	.equ	SOUND_ROW, 4				/* Sound Display Row Index */
	.equ	PID_ROW, 5					/* PID Output Debug Display Row Index */
	.equ	BEHAVIOR_ROW, 6				/* Behavior Display Row Index */
	.equ	SNDLVL_ROW, 7				/* Sound Level Display Row Index */

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
	.equ	TOUCH_THRESH, 255

	/* Sound Sensor Threshold (0-100) range */
	/* Sound Sensor Readings: No Sound: 98+; Loud Sound: towards 0 */
	/* FIXME: Needs calibration based on ambient background noise, etc. */
	.equ	LOUD_MIN, 0
	.equ	LOUD_MAX, 69
	.equ	SOFT_MIN,   70
	.equ	SOFT_MAX,   84
	.equ	QUIET_MIN,   85
	.equ	QUIET_MAX,   100

	/* Sound Following Constants
	 *  (Sound Level Trigger is updated every ROBOT_SCHED_DURATION interval)
	 *  The increments and decrements should have some relationship to the
	 *  Sound Following Thresholds since the deltas are incremented every main loop.
     */
	.equ	SOUND_UNKNOWN_DECR, 1
	.equ	SOUND_QUIET_NORMAL_DECR, 1
	.equ	SOUND_QUIET_FOLLOWING_DECR, 5
	.equ	SOUND_SOFT_INCR, 5
	.equ	SOUND_LOUD_INCR, 10

	/* Sound Following Thresholds
	 *
	 *    Hysterisis is implemented
	 */
	.equ	WAITING_THRESH_INCR, 5
	.equ	WAITING_THRESH_DECR, 1
	.equ	SEEKING_THRESH_INCR, 30
	.equ	SEEKING_THRESH_DECR, 10
	.equ	FOLLOWING_THRESH_INCR, 50
	.equ	FOLLOWING_THRESH_DECR, 40

	/* Wheel Control Constants */
	.equ	STOP_SPEED, 0
	.equ	FWD_SPEED, 30
	.equ	FASTROT_SPEED, 40
	.equ	SLOWROT_SPEED, 20
	.equ	SEEK_SPEED, 30
	.equ	WHEEL_SPEED_MAX, 30
	.equ	WHEEL_SPEED_MIN, -30

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
	.equ	TONE_OBSTACLE_FREQ, 750				/* Hz */
	.equ	TONE_SILENCED_FREQ, 0				/* Hz */
	.equ	TONE_ENABLED_DUR, 100				/* ms */


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

/** @name Sound Following State Enums
 *
 * Sound Following State.
 * The enums must be consecutive, starting from 0
 */
/*@{*/
ENUM_BEGIN
ENUM_VALASSIGN(SOUND_IDLE, 0)     /**< Initial State. */
ENUM_VAL(SOUND_WAITING)           /**< Waiting for Sound Source. */
ENUM_VAL(SOUND_SEEKING)           /**< Seeking Sound Source. */
ENUM_VAL(SOUND_FOLLOWING)         /**< Following Sound Source. */
ENUM_END(sound_following_state_t)
/*@}*/

	.equ	NUM_SOUND_STATES, (SOUND_FOLLOWING+1)

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
ENUM_VAL(BBR_AVOID_OBSTACLE)        /**< Avoid Obstacle. */

ENUM_END(bbr_behavior_t)
/*@}*/

	.equ	BBR_LAST_BEHAVIOR, BBR_AVOID_OBSTACLE		/* FIXME: Need to update this if behavior list changes */
	.equ	NUM_BEHAVIORS, (BBR_LAST_BEHAVIOR+1)

.text
.align 4
title:	  .asciz "Tribot Bot"
pressed:  .asciz "Touch: Pressed "
released: .asciz "Touch: Released"
maxsound: .asciz "Sound: Following"
minsound: .asciz "Sound: Detected"
nosound:  .asciz "Sound: No Sound"
opened:   .asciz " Claw: Opened"
closed:   .asciz " Claw: Closed"
white:	  .asciz " Line: White  "
black:	  .asciz " Line: Black  "
edge:	  .asciz " Line: Edge   "
unknown:  .asciz " Line: Unknown"

bbr_inhibited_behavior:        .asciz "BBR:            "
avoidobstacle_idle_behavior:   .asciz "BBR:Avoid-Idle  "
moveobject_idle_behavior:      .asciz "BBR:Move-Idle   "
moveobject_waiting_behavior:   .asciz "BBR:Move-Waiting"
moveobject_seeking_behavior:   .asciz "BBR:Move-Seeking"
moveobject_following_behavior: .asciz "BBR:Move-Follow "
graspobject_behavior:          .asciz "BBR:Grasp-Object"
openclaws_behavior:	           .asciz "BBR:Open-Claws  "
followline_behavior:           .asciz "BBR:Follow-Line "
idle_behavior:                 .asciz "BBR:Idle        "

#if (defined DEBUG_ULTRASOUND || defined DEBUG_AVOID_OBSTACLE)
ultrasoundstr: .asciz "Radar: "
ultrasoundunits: .asciz " cm  "
#endif

#ifdef DEBUG_PID
pidstr:   .asciz "PID O/P: "
pidunits: .asciz "   "
#endif

ultrasound_error: .asciz "ERR: No USnd! "
ultrasound_found: .asciz "              "

.data
.align 4

/* Scheduler Timeout value */
sched_tick:	.word	0

/* Speaker Tone Timeout value */
speaker_timestamp: .word	0


/* Light Sensor Variables */
light_readings: .space  n, 0x0
light_min:      .byte   0
light_max:      .byte   0

/* Sound Sensor Variables */
sound_levels:	.space  n, 0x0
sound_min:		.byte   0
sound_max:		.byte	0

/* Ultrasound Sensor Variables */
ultrasoundval:	.byte	0
ultrasound_errcnt: .byte	0

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

/* Sound Following Behavior Variables */
sound_following_state:	.byte 0
sound_level_trigger:	.byte 0

/* Avoid Object Behavior Variables */
obstacle_detected:	.byte	0
obstacle_tone_active: .byte FALSE
.align
obstacle_tone_timestamp: .word 0

/* PID State Variables */
.align
pid:	.space  SIZEOF_PID_CONTROL, 0x0
.align
system_output: .word 0x0		/* FIXME */
system_jitter: .word 0x100		/* FIXME */

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
	/* GNU As BUG: DO NOT define equates based on TONE_FREQ and TONE_DUR,
	 * the offsets come out incorrect, and TONE_FREQ and TONE_DUR are modified as well ??!! */

#if 0
/* Debug offset calculations */
actuator_state_offsets:
	.byte SPEEDA, BRAKEA, SPEEDB, BRAKEB
	.byte SPEEDC, BRAKEC, CURR_STATE
	.byte TONE_FREQ, TONE_DUR
	.byte SIZEOF_ACTUATOR_STATE
#endif

.align
prev_actuator_state: .space	SIZEOF_ACTUATOR_STATE, 0x0
.align
behavior_actuations: .space	(SIZEOF_ACTUATOR_STATE * NUM_BEHAVIORS), 0x0

.text
.align 4
	/* Predefined Actuator Outputs for various behaviors */
	init_actuator_state bbr_behavior_inhibited, MOTOR_INHIBITED_BYTE, FALSE, MOTOR_INHIBITED_BYTE, FALSE, MOTOR_INHIBITED_BYTE, FALSE, ROBOT_STOP, TONE_INHIBITED, TONE_INHIBITED
			/* Inhibit Behavior */

	/* Avoid-Obstacle Behavior Actuation Outputs */
	init_actuator_state bbr_avoid_obstacle_on, MOTOR_INHIBITED_BYTE, TRUE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_AVOID, TONE_OBSTACLE_FREQ, TONE_ENABLED_DUR
			/* Avoid Obstacle Template, Tone On */
	init_actuator_state bbr_avoid_obstacle_off, MOTOR_INHIBITED_BYTE, TRUE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_AVOID, TONE_SILENCED_FREQ, TONE_ENABLED_DUR
			/* Avoid Obstacle Template, Tone Off */

	/* Move-Object Behavior Actuation Outputs */
	init_actuator_state bbr_move_object_idle, CLOSE_SPEED, TRUE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_STOP, TONE_INHIBITED, TONE_INHIBITED
			/* Idle */
	init_actuator_state bbr_move_object_waiting, CLOSE_SPEED, TRUE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_STOP, TONE_SILENCED_FREQ, ROBOT_SCHED_DURATION
			/* Waiting */
	init_actuator_state bbr_move_object_seeking, CLOSE_SPEED, TRUE, SEEK_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_SEEK, TONE_SILENCED_FREQ, ROBOT_SCHED_DURATION
			/* Seeking */
	init_actuator_state bbr_move_object_following, CLOSE_SPEED, TRUE, FWD_SPEED, TRUE, FWD_SPEED, TRUE, ROBOT_FWD, TONE_SILENCED_FREQ, ROBOT_SCHED_DURATION
			/* Follow */

	/* Open-Claws/Grasp-Object Behavior Actuation Outputs */
	init_actuator_state bbr_claws_open, OPEN_SPEED, FALSE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_STOP, TONE_SILENCED_FREQ, ROBOT_SCHED_DURATION
			/* Open Claws */
	init_actuator_state bbr_claws_close, CLOSE_SPEED, FALSE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_STOP, TONE_SILENCED_FREQ, ROBOT_SCHED_DURATION
			/* Close Claws (Grasp Object) */
	init_actuator_state bbr_claws_unlock, STOP_SPEED, FALSE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_STOP, TONE_SILENCED_FREQ, ROBOT_SCHED_DURATION
			/* Unlock Claws */
	init_actuator_state bbr_claws_lock, STOP_SPEED, TRUE, STOP_SPEED, TRUE, STOP_SPEED, TRUE, ROBOT_STOP, TONE_SILENCED_FREQ, ROBOT_SCHED_DURATION
			/* Lock Claws */

	/* Follow-Line Behavior Actuation Outputs for Line Types */
	init_actuator_state bbr_follow_line_black,	MOTOR_INHIBITED_BYTE, FALSE, FWD_SPEED, FALSE, FWD_SPEED, FALSE, ROBOT_FWD, TONE_SILENCED_FREQ, ROBOT_SCHED_DURATION
			/* Forward motion */
	init_actuator_state bbr_follow_line_edge, MOTOR_INHIBITED_BYTE, FALSE, SLOWROT_SPEED, FALSE, STOP_SPEED, FALSE, ROBOT_CCW, TONE_SILENCED_FREQ, ROBOT_SCHED_DURATION
			/* CCW slow rotation */
	init_actuator_state bbr_follow_line_white, MOTOR_INHIBITED_BYTE, FALSE, STOP_SPEED, FALSE, FASTROT_SPEED, FALSE, ROBOT_CW, TONE_SILENCED_FREQ, ROBOT_SCHED_DURATION
			/* CW fast rotation */

	/* Idle Behavior Actuation Outputs */
	init_actuator_state bbr_idle_on, MOTOR_INHIBITED_BYTE, FALSE, MOTOR_INHIBITED_BYTE, FALSE, MOTOR_INHIBITED_BYTE, FALSE, ROBOT_STOP, TONE_ENABLED_FREQ, TONE_ENABLED_DUR
			/* Idle Behavior (sound on) */
	init_actuator_state bbr_idle_off, MOTOR_INHIBITED_BYTE, FALSE, MOTOR_INHIBITED_BYTE, FALSE, MOTOR_INHIBITED_BYTE, FALSE, ROBOT_STOP, TONE_SILENCED_FREQ, TONE_ENABLED_DUR
			/* Idle Behavior (sound off) */

/* Line Classification Advanced Jump Table */
/* Use macros to make line classification declaration consistent */
    .macro  adv_jump_table_item entry_label, minval, maxval, action_routine
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
    .equ    SIZEOF_ADV_JUMP_TABLE_ITEM, 8

/* The execution clauses for each line_type enum are implemented
 * as routines which do not need any input parameters
 * Each row (item) in the Jump Table takes 8 bytes (with 2 bytes padding)
 */

.text
.align 4
/* The Line Classification bounds is sorted from low to high range */
line_classification_jumptable:
    adv_jump_table_item line_outside, WHITE_MIN, WHITE_MAX, fast_cwrotate_motion
    adv_jump_table_item line_edge, EDGE_MIN, EDGE_MAX, slow_ccwrotate_motion
    adv_jump_table_item line_line, BLACK_MIN, BLACK_MAX, forward_motion
    adv_jump_table_item line_unknown, 0, 255, stop_motion

/* End of Table address constant */
    .equ    line_classification_jumptable_end, .

/* The Sound Following boundsis sorted from low to high range. When sound is detected, the value is lower */
sound_following_jumptable:
    adv_jump_table_item sound_loud, LOUD_MIN, LOUD_MAX, sound_loud_handler
    adv_jump_table_item sound_soft, SOFT_MIN, SOFT_MAX, sound_soft_handler
    adv_jump_table_item sound_quiet, QUIET_MIN, QUIET_MAX, sound_quiet_handler
    adv_jump_table_item sound_unknown, 0, 255, sound_unknown_handler

/* End of Table address constant */
    .equ    sound_following_jumptable_end, .

/* Table has Lower Bounds, Next State */
sound_state_hysterisis_incr:
	.byte	WAITING_THRESH_INCR, SOUND_WAITING		/* Sound Idle State */
	.byte	SEEKING_THRESH_INCR, SOUND_SEEKING		/* Sound Waiting State */
	.byte	FOLLOWING_THRESH_INCR, SOUND_FOLLOWING	/* Sound Seeking State */
	.byte	FOLLOWING_THRESH_INCR, SOUND_FOLLOWING	/* Sound Following State */

/* Table has Upper Bounds, Next State */
sound_state_hysterisis_decr:
	.byte	WAITING_THRESH_DECR, SOUND_IDLE			/* Sound Idle State */
	.byte	WAITING_THRESH_DECR, SOUND_IDLE			/* Sound Waiting State */
	.byte	SEEKING_THRESH_DECR, SOUND_WAITING		/* Sound Seeking State */
	.byte	FOLLOWING_THRESH_DECR, SOUND_SEEKING	/* Sound Following State */

/* Table has Behavior Outputs, Behavior Display String */
move_object_output_table:
	.word	bbr_move_object_idle, moveobject_idle_behavior				/* Sound Idle State */
	.word	bbr_move_object_waiting, moveobject_waiting_behavior		/* Sound Waiting State */
	.word	bbr_move_object_seeking, moveobject_seeking_behavior		/* Sound Seeking State */
	.word	bbr_move_object_following, moveobject_following_behavior	/* Sound Following State */


/* BBR Dispatcher Jump Table Definition */
.text
.align

dispatcher_behavior_jumptable:
	.word	bbr_idle
	.word	bbr_follow_line
	.word	bbr_open_claws
	.word	bbr_grasp_object
	.word	bbr_move_object
	.word	bbr_avoid_obstacle

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
	thumb_interwork print_claw_state
	push	{lr}
	ldr		r1, =claw_closed	/* Use R1 as Pointer to claw_closed */
	ldrb	r1, [r1]			/* Retrieve claw_closed value to R1 */

	ldr		r0, =opened			/* Preload claw_closed == FALSE output value */
	cmp		r1, #FALSE
	beq		0f
	ldr		r0, =closed			/* claw_closed == TRUE output value */
0:
	bl		nx_progcontent2
	pop		{r1}
	bx		r1					/* Thumb Interworking Return */

/** print_behavior_state
 *    Behavior output to LCD
 *		R0: Behavior Display String
 */
	thumb_interwork print_behavior_state
	push	{lr}
	mov		r1, #BEHAVIOR_ROW
	bl		nx_progcontentX
	thumb_iret	r1					/* Thumb Interworking Return */

/* Actuator Primitives */
	thumb_interwork plip
	push	{lr}
	ldr		r0, =3000
	mov		r1, #100
	bl		nx_sound_freq
	thumb_iret	r1					/* Thumb Interworking Return */

	thumb_interwork plop
	push	{lr}
	ldr		r0, =500
	mov		r1, #100
	bl		nx_sound_freq
	thumb_iret	r1					/* Thumb Interworking Return */

	thumb_interwork plap
	push	{lr}
	ldr		r0, =1500
	mov		r1, #100
	bl		nx_sound_freq
	thumb_iret	r1					/* Thumb Interworking Return */

/* Sensor Primitives */
	thumb_interwork touch_detected
	push	{lr}
	bl		plip
	ldr		r0, =pressed
	mov		r1, #TOUCH_ROW
	bl		nx_progcontentX
	thumb_iret	r1					/* Thumb Interworking Return */

	thumb_interwork touch_lost
	push	{lr}
	bl		plop
	ldr		r0, =released
	mov		r1, #TOUCH_ROW
	bl		nx_progcontentX
	thumb_iret	r1					/* Thumb Interworking Return */

	thumb_interwork sound_activated
	push	{lr}
	ldr		r0, =maxsound
	mov		r1, #SOUND_ROW
	bl		nx_progcontentX
	thumb_iret	r1					/* Thumb Interworking Return */

	thumb_interwork sound_detected
	push	{lr}
	ldr		r0, =minsound
	mov		r1, #SOUND_ROW
	bl		nx_progcontentX
	thumb_iret	r1					/* Thumb Interworking Return */

	thumb_interwork sound_absent
	push	{lr}
	ldr		r0, =nosound
	mov		r1, #SOUND_ROW
	bl		nx_progcontentX
	thumb_iret	r1					/* Thumb Interworking Return */

	thumb_interwork light_led_enable
	push	{lr}
	mov		r0, #LIGHT_PORT
	mov		r1, #DIGI0
	bl		nx_sensors_analog_digi_set
	thumb_iret	r1					/* Thumb Interworking Return */

	thumb_interwork light_led_disable
	push	{lr}
	mov		r0, #LIGHT_PORT
	mov		r1, #DIGI0
	bl		nx_sensors_analog_digi_clear
	thumb_iret	r1					/* Thumb Interworking Return */

/* Needed for Thumb Literal Pools since offsets have limited range */
.ltorg

/* Sensor Input Routine */

/* get_light_reading
 *    Light Sensor Input Routine
 *    Collect one light sensor reading
 * On Exit:
 *     R0: Collected Sample (unsigned byte)
 */
	thumb_interwork get_light_reading
	push	{lr}
	mov		r0, #LIGHT_PORT
	bl		nx_sensors_analog_get_normalized	/* returned value in range 0-100% */
	thumb_iret	r1					/* Thumb Interworking Return */

/* calc_light_min_max
 *    Calculate Min-Max for n Light Readings
 */

	thumb_interwork calc_light_min_max
	push	{lr}
	mov		r0, #n
	ldr		r1, =light_readings
	ldr		r2, =light_min
	ldr		r3, =light_max
	bl		min_max_ubyte
	thumb_iret	r1					/* Thumb Interworking Return */

/* get_sound_level
 *    Sound Sensor Input Routine
 *    Collect one sound sensor reading
 * On Exit:
 *     R0: Collected Sample (unsigned byte)
 */
	thumb_interwork get_sound_level
 	push	{lr}
	mov		r0, #SOUND_PORT
	bl		nx_sensors_analog_get_normalized	/* returned value in range 0-100% */
	thumb_iret	r1					/* Thumb Interworking Return */

/* calc_sound_min_max
 *    Calculate Min-Max for n Sound Readings
 */
	thumb_interwork calc_sound_min_max
	push	{lr}
	mov		r0, #n
	ldr		r1, =sound_levels
	ldr		r2, =sound_min
	ldr		r3, =sound_max
	bl		min_max_ubyte

exit_get_sound_levels:
	thumb_iret	r1					/* Thumb Interworking Return */

/* collect_samples
 *    Sensor Sample Collection Routine
 *    This routine calls the respective sensor input collection routine n times
 *
 *    >>>Add additional sensor input routines here<<<
 *
 *    Note: This routine blocks until n samples have been collected
 *			(Max. delay is ~ 3 * n ms)
 *
 * Register Usage:
 *		R4: Sensor Readings Array Index
 *      R5: Light Readings Array Pointer
 *		R6: Sound Levels Array Pointer
 */
	thumb_interwork collect_samples
	push	{r4, r5, r6, lr}
	mov		r4, #n		/* Number of readings to collect */
	ldr		r5, =light_readings
	ldr		r6, =sound_levels

sample_loop:
	sub		r4, r4, #1				/* Convert Number of readings to collect into Array Index */
	blt		done_collect_samples	/* We're done when index is negative */

	/* Sensor Input routines */
	bl		get_light_reading
	strb	r0, [r5, r4]

	bl		get_sound_level
	strb	r0, [r6, r4]

	/* A/D Converter Delay */
	mov		r0, #SYSTICK_3MS
	bl		nx_systick_wait_ms		/* Delay 3 ms before next reading (Required by AVR A/D Converter) */
	b		sample_loop				/* Next Iteration */

done_collect_samples:
	pop		{r4, r5, r6}
	thumb_iret	r1					/* Thumb Interworking Return */

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
	thumb_interwork get_touch_status
 	push	{r4, lr}
	mov		r0, #TOUCH_PORT
	bl		nx_sensors_analog_get
	ldr		r4, =touchval
	strb	r0, [r4]		/* Store Touch Value */

	cmp		r0, #TOUCH_THRESH
	ldrb	r0, [r4, #1]			/* Retrieve Touch Status to R0, Note: Does not modify flags */
	bgt		no_touch

touch:
	cmp		r0, #FALSE				/* We can't teq #TRUE due to constant value exceeding 8 bits */
	bne		exit_get_touch_status
	mov		r0, #FALSE
	mvn		r0, r0					/* Set R0 to TRUE */
	strb	r0, [r4, #1]			/* Update Touch Status (non-zero value, truncated to 8 bits) */
	bl		light_led_disable
	bl		touch_detected
	b		exit_get_touch_status

no_touch:
	cmp		r0, #FALSE
	beq		exit_get_touch_status
	mov		r0, #FALSE
	strb	r0, [r4, #1]			/* Update Touch Status (zero value, truncated to 8 bits) */
	bl		light_led_enable
	bl		touch_lost

exit_get_touch_status:
#if 0
	/* We do not need to delay since the main_loop spaces out the frequency of the A/D call */
	mov		r0, #SYSTICK_3MS
	bl		nx_systick_wait_ms	/* Delay 3 ms before next reading (Required by AVR A/D Converter) */
#endif
 	pop		{r4}
	thumb_iret	r1					/* Thumb Interworking Return */

/* get_claw_status
 *    Retrieve Claw Motor Tachometer value and store in variable claw_position.
 *		R4: Address Pointer to Claw variables
 */
 	thumb_interwork get_claw_status
 	push	{lr}
 	mov		r0, #CLAW_PORT	/* Specify Claw Motor Port */
 	bl		nx_motors_get_tach_count
	ldr		r1, =claw_position
	str		r0, [r1]			/* Store 32-bit tachometer count */

	bl		nx_systick_get_ms
	ldr		r1, =claw_timestamp
	str		r0, [r1]			/* Store 32-bit timestamp in claw_timestamp */

	bl		print_claw_state

exit_get_claw_status:
	thumb_iret	r1					/* Thumb Interworking Return */


/* get_obstacle_distance
 *    Retrieve Ultrasound reading, and perform input sanity checking
 */
	thumb_interwork get_obstacle_distance
	push	{lr}
	mov		r0, #ULSND_PORT
	mov		r1, #0							/* Continue Reading only returns Object 0 */
	bl		nx_radar_read_distance			/* Return distance in R0 */
	ldr		r2, =ultrasoundval
	cmp		r0, #0
	cmp		r0, #RADAR_DIST_NOOBJECT
	beq		get_obstacle_distance_err		/* Weed out invalid readings (0 == no object) */
	cmp		r0, #RADAR_DIST_ERR
	beq		get_obstacle_distance_err		/* Weed out invalid readings (255 == error) */
	sub		r0, r0, #ULTRASOUND_ERR_OFFSET	/* Adjust read value with calibration offset */
	mov		r1, #0							/* Reset Error Count */
	b		update_obstacle_distance_errcnt

get_obstacle_distance_err:
	ldrb	r0, [r2]						/* Retrieve last reading */
	ldrb	r1, [r2, #1]					/* Retrieve ultrasound_errcnt */
	add		r1, r1, #1
	cmp		r1, #ULTRASOUND_ERRSTATE_COUNT
	blo		update_obstacle_distance_errcnt
	mov		r1, #0							/* Reset ultrasound_errcnt if limit reached */
	mov		r0, #RADAR_DIST_ERR				/* Store reading as error distance (for real) */

update_obstacle_distance_errcnt:
	strb	r0, [r2]						/* Store new distance reading (if valid) */
	strb	r1, [r2, #1]					/* Update Error Count */

exit_get_obstacle_distance:

#if (defined DEBUG_ULTRASOUND || defined DEBUG_AVOID_OBSTACLE)
	mov		r0, #0
	mov		r1, #SNDLVL_ROW
	bl 		nx_display_cursor_set_pos
	ldr		r0, =ultrasoundstr
	bl		nx_display_string

	ldr		r1, =ultrasoundval
	ldrb	r0, [r1]
	bl		nx_display_int

	ldr		r0, =ultrasoundunits
	bl		nx_display_string

#endif
	thumb_iret	r1					/* Thumb Interworking Return */

/* Needed for Thumb Literal Pools since offsets have limited range */
.ltorg


/* Behavior Support Routines */

/* BBR Copy Actuator Outputs
 *    Copy Activated Behavior Outputs to Arbiter behavior_actuations array
 *	  Inputs:
 *		R0: behavior_actuations Index
 *		R1: Pointer to Predefined Actuator Outputs for Behavior
 *
 *    Note: This is an internal routine shared by various functions
 */

	thumb_interwork bbr_copy_actuator_outputs
	push	{lr}
	ldr		r3, =behavior_actuations			/* candidate actuations array start address */
	mov		r2, #SIZEOF_ACTUATOR_STATE			/* number of bytes per actuator_state struct */
@	mla		r0, r2, r0, r3						/* r0 = (sizeof(actuator_state) (r2) * index (r0)) + behavior_actuations start (r3) */
	mul		r0, r2, r0
	add		r0, r0, r3
	bl		memmove								/* r0: destination pointer, r1: source pointer, r2: number of bytes to copy */
	thumb_iret	r1								/* Thumb Interworking Return */

/* Forward Motion
 *    Move Forward, Don't Brake
 *
 */
	thumb_interwork forward_motion
	push	{lr}
/*	bl		plip */
	ldr		r0, =black
	bl		nx_progcontent

	mov		r0, #BBR_FOLLOW_LINE
	ldr		r1, =bbr_follow_line_black
	bl		bbr_copy_actuator_outputs
	thumb_iret	r1					/* Thumb Interworking Return */

/* Fast Clockwise Rotation
 *    Rotate CW, Don't Brake
 *
 */
	thumb_interwork fast_cwrotate_motion
	push	{lr}
/*	bl		plop */
	ldr		r0, =white
	bl		nx_progcontent

	mov		r0, #BBR_FOLLOW_LINE
	ldr		r1, =bbr_follow_line_white
	bl		bbr_copy_actuator_outputs
	thumb_iret	r1					/* Thumb Interworking Return */

/* Slow Counter Clockwise Rotation
 *    Rotate CCW, Don't Brake
 *
 */
	thumb_interwork slow_ccwrotate_motion
	push	{lr}
/*	bl		plap */
	ldr		r0, =edge
	bl		nx_progcontent

	mov		r0, #BBR_FOLLOW_LINE
	ldr		r1, =bbr_follow_line_edge
	bl		bbr_copy_actuator_outputs
	thumb_iret	r1					/* Thumb Interworking Return */

/* Stop Motion
 *    Stop Wheels, Don't Brake (Inhibit Follow Line Behavior Outputs)
 *
 */
	thumb_interwork stop_motion
	push	{lr}
	ldr		r0, =unknown
	bl		nx_progcontent

	mov		r0, #BBR_FOLLOW_LINE
	ldr		r1, =bbr_behavior_inhibited
	bl		bbr_copy_actuator_outputs
	thumb_iret	r1					/* Thumb Interworking Return */


/* Sound Update State and Output
 *    Update Sound State depending on Sound Level Trigger
 *	  Implements Hysterisis in state transitions
 *	  Generate appropriate Behavior Outputs
 *
 *	  Inputs:
 *		R0: Increasing (Boolean)
 *
 */
	thumb_interwork sound_update_state_output
	push	{r4, lr}

	ldr		r3, =sound_following_state
	ldrb	r1, [r3]							/* Sound Following State */
	cmp		r1, #NUM_SOUND_STATES
	bls		0f
	mov		r1, #NUM_SOUND_STATES				/* Force to sane state value */
0:
	ldrb	r2, [r3, #1]						/* Sound Level Trigger */


	cmp		r0, #FALSE
	beq		1f
	ldr		r4, =sound_state_hysterisis_incr
	b		sound_increasing					/* If Sound Increasing (TRUE), check INCR thresholds */
1:
	ldr		r4, =sound_state_hysterisis_decr

sound_decreasing:
@	add		r4, r4, r1, lsl #1					/* Point to Item Entry at sound_state_hysterisis + sound_following_state x 2 */
	add		r4, r4, r1
	add		r4, r4, r1							/* r4 = r4 + r1 + r1 */
	ldrb	r0, [r4]							/* Decreasing Threshold */
	cmp		r2, r0								/* Trigger - Threshold */
	bhs		sound_process_state
	ldrb	r1, [r4, #1]						/* Next State */
	strb	r1, [r3]							/* Update Sound Following State  if (Trigger < Threshold) */
	b		sound_process_state

sound_increasing:
@	add		r4, r4, r1, lsl #1					/* Point to Item Entry at sound_state_hysterisis + sound_following_state x 2 */
	add		r4, r4, r1
	add		r4, r4, r1							/* r4 = r4 + r1 + r1 */
	ldrb	r0, [r4]							/* Decreasing Threshold */
	cmp		r2, r0								/* Trigger - Threshold */
	blo		sound_process_state
	ldrb	r1, [r4, #1]						/* Next State */
	strb	r1, [r3]							/* Update Sound Following State  if (Trigger > Threshold) */

sound_process_state:
	ldr		r4, =move_object_output_table
@	add		r4, r4, r1, lsl #3					/* Point to Item Entry at move_object_output_table + sound_following_state x 8 */
	lsl		r2, r1, #3
	add		r4, r4, r2
	ldr		r1, [r4]							/* Idle State Behavior Output */

sound_do_update:
	mov		r0, #BBR_MOVE_OBJECT
	bl		bbr_copy_actuator_outputs			/* Update behavior outputs */

	ldr		r0, [r4, #4]						/* Display String */
	bl		print_behavior_state
	pop		{r4}
	thumb_iret	r1					/* Thumb Interworking Return */

/* Sound Loud Handler
 *    Increment Sound Level Trigger quickly
 *
 *    Note: This routine uses unsigned arithmetic to detect unsigned byte overflow
 *
 */
	thumb_interwork sound_loud_handler
	push	{lr}
	ldr		r1, =sound_following_state
	ldrb	r0, [r1, #1]						/* Sound Level Trigger */

	add		r0, r0, #SOUND_LOUD_INCR
	cmp		r0, #255
	bls		0f
	mov		r0, #255							/* Clamp to 255 if exceeded 8-bits */
0:	strb	r0, [r1, #1]

	mov		r0, #FALSE
	mvn		r0, r0								/* Convert to TRUE */
	bl		sound_update_state_output
	thumb_iret	r1					/* Thumb Interworking Return */

/* Sound Soft Handler
 *    Increment Sound Level Trigger moderately
 *
 *    Note: This routine uses unsigned arithmetic to detect unsigned byte overflow
 *
 */
	thumb_interwork sound_soft_handler
	push	{lr}
	ldr		r1, =sound_following_state
	ldrb	r0, [r1, #1]						/* Sound Level Trigger */

	add		r0, r0, #SOUND_SOFT_INCR
	cmp		r0, #255
	bls		0f
	mov		r0, #255							/* Clamp to 255 if exceeded 8-bits */
0:	strb	r0, [r1, #1]

	mov		r0, #FALSE
	mvn		r0, r0								/* Convert to TRUE */
	bl		sound_update_state_output
	thumb_iret	r1					/* Thumb Interworking Return */

/* Sound Quiet Handler
 *    Decrement Sound Level Trigger
 *
 *    Note: This routine uses signed arithmetic to detect underflow of unsigned byte value
 *
 */
	thumb_interwork sound_quiet_handler
	push	{lr}


	ldr		r1, =sound_following_state
	ldrb	r0, [r1, #1]						/* Sound Level Trigger */

	mov		r3, #SOUND_QUIET_NORMAL_DECR

	ldrb	r2, [r1]							/* Sound Following State */
	cmp		r2, #SOUND_FOLLOWING
	bne		0f
	mov		r3, #SOUND_QUIET_FOLLOWING_DECR		/* Decrement faster if in Following State */
0:
	sub		r0, r0, r3
	bhs		1f
	mov		r0, #0								/* Clamp to 0 if negative */
1:	strb	r0, [r1, #1]

	mov		r0, #FALSE
	bl		sound_update_state_output
	thumb_iret	r1					/* Thumb Interworking Return */

/* Sound Unknown Handler
 *    Force Sound Idle state, allow Idle behavior to Play Tone
 *
 */
	thumb_interwork sound_unknown_handler
	push	{lr}

	ldr		r1, =sound_following_state
	ldrb	r0, [r1, #1]						/* Sound Level Trigger */

	sub		r0, r0, #SOUND_UNKNOWN_DECR
	bhs		0f
	mov		r0, #0								/* Clamp to 0 if negative */
0:	strb	r0, [r1, #1]

	mov		r0, #FALSE
	bl		sound_update_state_output

	thumb_iret	r1					/* Thumb Interworking Return */

/* Open Claw
 *    Activate Claw Motor (Open), Don't Brake
 *
 *	  Input:
 *		R0: behavior_actuations Index
 */
	thumb_interwork open_claw
	push	{lr}
	ldr		r1, =bbr_claws_open
	bl		bbr_copy_actuator_outputs
	thumb_iret	r1					/* Thumb Interworking Return */

/* Close Claw
 *    Activate Claw Motor (Close), Don't Brake
 *
 *	  Input:
 *		R0: behavior_actuations Index
 */
	thumb_interwork close_claw
	push	{lr}
	ldr		r1, =bbr_claws_close
	bl		bbr_copy_actuator_outputs
	thumb_iret	r1					/* Thumb Interworking Return */

/* Lock Claw
 *    Stop Claw Motor, Brake
 *
 *	  Input:
 *		R0: behavior_actuations Index
 */
	thumb_interwork lock_claw
	push	{lr}
	ldr		r1, =bbr_claws_lock
	bl		bbr_copy_actuator_outputs
	thumb_iret	r1					/* Thumb Interworking Return */

/* Unlock Claw
 *    Stop Motor, Brake
 *
 *	  Input:
 *		R0: behavior_actuations Index
 */
	thumb_interwork unlock_claw
	push	{lr}
	ldr		r1, =bbr_claws_unlock
	bl		bbr_copy_actuator_outputs
	thumb_iret	r1					/* Thumb Interworking Return */

/* Has Claw Started Moving
 *
 * Returns: Boolean (TRUE if Claw Actuator Speed is non-zero)
 *    Check if the Claw Actuator Speed is non-zero
 */
	thumb_interwork has_claw_started_moving
	push	{r4, lr}
	ldr		r4, =actuator_state
	ldr		r2, =MOTOR_INHIBITED
	ldrb	r0, [r4, #MOTOR_CLAW_OFFSET]	/* Retrieve currently programmed claw actuator speed */
	cmp		r0, r2
	beq		claw_is_stopped			/* If Motor Inhibited, it is equivalent to Stopped */
	cmp		r0, #STOP_SPEED
	beq		claw_is_stopped
	mov		r0, #FALSE
	mvn		r0, r0								/* Convert to TRUE */
	b		exit_has_claw_started_moving
claw_is_stopped:
	mov		r0, #FALSE
exit_has_claw_started_moving:
	pop		{r4}
	thumb_iret	r1					/* Thumb Interworking Return */

/* Has Claw Fully Stopped
 *
 * Returns: Boolean (TRUE if Claw Fully Stopped)
 *    Check if the Claw Open/Close Action is completed
 *    Some debouncing of inputs is done here.
 *    We only update the status every CLAWPOS_CHECK_INTERVAL
 */
	arm_interwork has_claw_fully_stopped
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
	pop		{r4, lr}
	bx		lr

/* Needed for Thumb Literal Pools since offsets have limited range */
.ltorg


/* has_timer_elapsed
 *
 * Internal Support Routine used to determine whether
 * a given time interval has passed
 *
 * Inputs:
 *    R0: Pointer to Last Timestamp address
 *    R1: Time Interval for Time Expiry
 *
 * Returns:
 *    R0: Boolean (Timer Has Elapsed = TRUE)
 *    R1: Current Timestamp
 */
	arm_interwork has_timer_elapsed
	push	{r4, r5, lr}
	ldr		r4, [r0]			/* Retrieve Last Timestamp into R4 */
	mov		r5, r1				/* Keep Time Interval in R5 */
	bl		nx_systick_get_ms	/* R0 has current timestamp */
	mov		r1, r0				/* Copy to R1 for return value */
	time_elapsed r0, r4, r5		/* Boolean result in R0 */
	pop		{r4, r5, lr}
	bx		lr					/* Return to caller */

/*
 * Advanced Jump Table Action Routine Dispatcher
 *
 *     Find Jump Table Item such that
 *        ((MINVAL <= Input Min Value) &&
 *         (Input Max Value <= MAXVAL))
 *
 * On Entry:
 *     R0: Input Min Value (8-bit unsigned)
 *     R1: Input Max Value (8-bit unsigned)
 *     R2: Jump Table Item Pointer
 *     R3: Jump Table End Pointer
 *     Assumes that R0 <= R1 (i.e., min <= max)
 *
 * On Exit:
 *     R0: Jump Table Entry Found (Boolean)
 *
 * Register Usage:
 *     R0: Input Min Value / Action Routine Address Pointer (if matched)
 *     R1: Input Max Value
 *     R2: Item Min Value (scratch register)
 *     R3: Item Max Value (scratch register)
 *     R4: Jump Table Item Pointer
 *     R5: Jump Table End Pointer
 *
 * Linear Search used, since number of cases are small
 */
	thumb_interwork advanced_jump_table_dispatcher
    PUSH    {R4, R5, LR}
    MOV		R4, R2
    MOV		R5, R3

jump_table_loop:
    CMP    R4, R5
    BLO    0f
	MOV    R0, #FALSE
    B      exit_advanced_jump_table_dispatcher	/* Traversed entire table, exit (not found) */
0:
    LDRB   R2, [R4, #MINVAL_OFFSET]         /* Retrieve Min & Max Bounds for Item */
    LDRB   R3, [R4, #MAXVAL_OFFSET]

check_bounds:
    CMP    R0, R2
    BLO    next_jump_table_item    /* R0 < MINVAL */
    CMP    R1, R3
    BHI    next_jump_table_item    /* R1 > MAXVAL */

matched_classification_item:
/* (MINVAL <= R0) && (R1 <= MAXVAL) */
    LDR    R0, [R4, #ACTION_ROUTINE_OFFSET] /* R0 contains action routine address */
    B      0f
9:
    BX     R0                               /* register setup before indirect call */
0:
    BL     9b

done_execution:
	MOV     R0, #FALSE
	MVN     R0, R0
@	MOV		R0, #TRUE
    B       exit_advanced_jump_table_dispatcher

next_jump_table_item:
    ADD    R4, R4, #SIZEOF_ADV_JUMP_TABLE_ITEM
    B      jump_table_loop         /* Repeat for next item */

exit_advanced_jump_table_dispatcher:
    POP   {R4, R5}
	thumb_iret	R1					/* Thumb Interworking Return */

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
@	mla		r1, \array_index_reg, r1, \behavior_actuations_ptr_reg	/* r1 = (index (array_index_reg) * sizeof(actuator_state) (r1)) + behavior_actuations_ptr_reg */
	mul		r1, \array_index_reg, r1
	add		r1, r1, \behavior_actuations_ptr_reg
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
@	mla		r1, \array_index_reg, r1, \behavior_actuations_ptr_reg	/* r1 = (index (array_index_reg) * sizeof(actuator_state) (r1)) + behavior_actuations_ptr_reg */
	mul		r1, \array_index_reg, r1
	add		r1, r1, \behavior_actuations_ptr_reg
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
@	mla		r1, \array_index_reg, r1, \behavior_actuations_ptr_reg	/* r1 = (index (array_index_reg) * sizeof(actuator_state) (r1)) + behavior_actuations_ptr_reg */
	mul		r1, \array_index_reg, r1
	add		r1, r1, \behavior_actuations_ptr_reg
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

	arm_interwork movement_arbiter
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
	get_actuation_element_double_unsigned_byte r4, r5, #CURR_STATE, #(CURR_STATE+1) /* Padding offset */
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
	strb	r0, [r4, #CURR_STATE]		/* Store activated Movement Speeds, Brake Statuses, and Motor State to actuator_state */
	strb	r1, [r4, #(CURR_STATE+1)]

exit_movement_arbiter:
	pop		{r4-r9, lr}						/* and exit */
	bx		lr

/* Grasping Arbiter
 *	Determine the Grasping Actuation output values
 *
 * Register Usage:
 *    R4: Pointer to behavior_actuations Array, actuator_state struct
 *    R5: Number of Behaviors
 *
 */

	arm_interwork grasping_arbiter
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
	pop		{r4, r5, lr}						/* and exit */
	bx		lr

/* Tone Generator Arbiter
 *	Determine the Tone Generator Actuation output values
 *
 * Register Usage:
 *    R4: Pointer to behavior_actuations Array, actuator_state struct
 *    R5: Number of Behaviors
 *
 */

	arm_interwork tone_generator_arbiter
	push	{r4, r5, lr}
	ldr		r4, =behavior_actuations
	mov		r5, #NUM_BEHAVIORS				/* Assume at least 1 */
tone_generator_arbiter_loop:
	subs	r5, r5, #1						/* Convert behavior count to array index */
	blt		tone_generator_copy_output		/* Last entry is Inhibited, copy it over anyway */

	get_actuation_element_double_word r4, r5, #TONE_FREQ, #TONE_DUR

	/* Tone is Inhibited if both Tone and Duration are TONE_INHIBITED */
	cmp		r0, #TONE_INHIBITED
	bne		tone_generator_copy_output		/* Found a non-Inhibited entry, copy it over */

	cmp		r1, #TONE_INHIBITED
	beq		tone_generator_arbiter_loop		/* Actuator output is Inhibited, skip to next Behavior */

tone_generator_copy_output:
	ldr		r4, =actuator_state
	str		r0, [r4, #TONE_FREQ]	/* Store activated Tone and Duration to actuator_state */
	str		r1, [r4, #TONE_DUR]

exit_tone_generator_arbiter:
	pop		{r4, r5, lr}					/* and exit */
	bx		lr

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
	arm_interwork motor_actuator
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
	bx		lr

/* Motor Controller
 *
 *    Used to drive tribot wheels
 */
	thumb_interwork motor_controller
	push	{lr}
	/* FIXME: input checking, etc. */
	mov		r0, #RWHEEL_PORT
	bl		motor_actuator
	mov		r0, #LWHEEL_PORT
	bl		motor_actuator

	/* Update Robot State */
	ldr		r2, =actuator_state
	ldr		r3, =prev_actuator_state
	ldrb	r0, [r2, #CURR_STATE]
	ldrb	r1, [r2, #(CURR_STATE+1)]
	strb	r0, [r3, #CURR_STATE]
	strb	r1, [r3, #(CURR_STATE+1)]
	thumb_iret	r1					/* Thumb Interworking Return */

/* Claw Controller
 *
 *    Used to control tribot claws
 */
	thumb_interwork claw_controller
	push	{lr}
	/* FIXME: input checking, etc. */
	mov		r0, #CLAW_PORT
	bl		motor_actuator
	thumb_iret	r1					/* Thumb Interworking Return */

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
	thumb_interwork speaker_controller
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
	ldr		r0, =TONE_INHIBITED
	cmp		r2, r0					/* Check against TONE_INHIBITED in R0 */
	beq		exit_speaker_controller
	cmp		r3, r0					/* Check against TONE_INHIBITED in R0 */
	beq		exit_speaker_controller	/* Skip update since we're already inhibited */

	mov		r0, r6					/* Setup Pointer to speaker_timestamp, R1 already has current Tone Duration */
	bl		has_timer_elapsed
	cmp		r0, #FALSE
	beq		exit_speaker_controller	/* Has not reached target update time interval yet, exit */

	ldr		r0, =TONE_INHIBITED
	ldr		r1, =TONE_INHIBITED		/* Force update of Speaker Output */

speaker_update_outputs:
	str		r0, [r5, #TONE_FREQ]
	str		r1, [r5, #TONE_DUR]		/* Store new tone in previous actuator state */
	ldr		r2, =TONE_INHIBITED
	cmp		r0, r2					/* Check against TONE_INHIBITED in R2 */
	beq		speaker_update_timestamp
	cmp		r0, #TONE_SILENCED_FREQ
	beq		speaker_update_timestamp
	bl		nx_sound_freq_async		/* Play Tone if Not TONE_INHIBITED or TONE_SILENCED_FREQ */

speaker_update_timestamp:
	bl		nx_systick_get_ms		/* Current systick in R0 */
	str		r0, [r6]				/* Store current systick in speaker_timestamp */

exit_speaker_controller:
	pop		{r4, r5, r6}
	thumb_iret	r1					/* Thumb Interworking Return */

/* Needed for Thumb Literal Pools since offsets have limited range */
.ltorg

/* Behavior Routines */

/* Idle Behavior
 *    Always Activated
 *    Play a Tone while Active
 *      This is accomplished by switching between Tone generation and Silence
 *      to give a punctuated tone output (Beep....Beep....Beep...)
 *
 */
	thumb_interwork bbr_idle
	push	{lr}
	/* Check time of last tone change */

	ldr		r0, =tone_timestamp		/* pointer to tone_timestamp */
	ldr		r1, =IDLE_TONE_INTERVAL	/* Time Interval required */
	bl		has_timer_elapsed
	cmp		r0, #FALSE
	beq		exit_bbr_idle			/* Has not reached target update time interval yet, exit */

idle_switch_state:
	ldr		r0, =tone_timestamp		/* pointer to tone_timestamp */
	str		r1, [r0]				/* Store current timestamp in tone_timestamp */

	ldr		r2, =tone_active
	ldrb	r0, [r2]					/* Get Tone Active status */
	thumb_toggle_boolean_byte r0				/* Toggle Tone Active status */
	strb	r0, [r2]					/* Update Tone Active Status */

	ldr		r1, =bbr_idle_on			/* Assume True, enable tone */
	cmp		r0, #FALSE					/* Check Tone Active status */
	bne		0f
	ldr		r1, =bbr_idle_off			/* False, disable tone */
0:
	mov		r0, #BBR_IDLE
	bl		bbr_copy_actuator_outputs
exit_bbr_idle:
	mov		r0, #FALSE
	mvn		r0, r0					/* Load TRUE, Always Activate Behavior */
	thumb_iret	r1					/* Thumb Interworking Return */

/* Line Follower Behavior
 *
 * Returns:
 *    Activated : Boolean
 */
	thumb_interwork bbr_follow_line
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
	cmp		r0, #FALSE				/* Touched Activated returns 255, not equal to #TRUE */
	beq		follow_line_check_line	/* Not Touched, check Follow Line Behavior */

	/* Touch active, deactivate Behavior and exit */
	mov		r0, #BBR_FOLLOW_LINE
	ldr		r1, =bbr_behavior_inhibited
	bl		bbr_copy_actuator_outputs

	mov		r0, #FALSE				/* Deactivate Behavior Outputs */
	b		exit_bbr_follow_line

follow_line_check_line:
	/* Retrieve current min / max values */
	ldr		r2, =light_min
	ldrb	r0, [r2]			/* min */
	ldrb	r1, [r2, #1]		/* max */
	ldr		r2, =line_classification_jumptable
	ldr		r3, =line_classification_jumptable_end

	bl		advanced_jump_table_dispatcher

exit_bbr_follow_line:
	thumb_iret	r1					/* Thumb Interworking Return */

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
	thumb_interwork bbr_open_claws
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

	ldr		r5, =obstacle_detected
	ldrb	r0, [r5]
	cmp		r0, #FALSE
	bne		bbr_deactivate_open_claws

	/* Setup Pointers at start of routine */
	ldr		r4, =claw_movement
	ldr		r5, =touched
	ldr		r6, =claw_closed

	ldrb	r0, [r4]				/* retrieve Claw Movement Status */
	cmp		r0, #CLAW_STOPPED
	bne		bbr_claw_check_still_opening	/* still moving, check if we should stop */

bbr_check_open_claws:
	/* (!touched && claw_closed)
	 * Negate expression for branch to Else Clause
	 * Using De-Morgan's Law, the Else trigger clause is:
	 * (touched || !claw_closed)
	 */
	ldrb	r0, [r5]
	cmp		r0, #FALSE				/* Touched Activated returns 255, not equal to #TRUE */
	bne		bbr_deactivate_open_claws	/* Touched (TRUE), deactivate Behavior Outputs and exit */

	/* Check Claw Status */
	ldrb	r0, [r6]				/* retrieve Claw Closed Status */
	cmp		r0, #FALSE
	beq		bbr_deactivate_open_claws	/* If Opened (Claw Closed == False), deactivate Behavior Outputs and exit */

bbr_start_opening_claws:
	mov		r0, #CLAW_OPENING
	strb	r0, [r4]				/* Claw Movement = OPENING */

	mov		r0, #BBR_OPEN_CLAWS
	bl		unlock_claw				/* start opening claw */
	b		bbr_open_claws_active	/* let controller do its work */

bbr_claw_check_still_opening:
	cmp		r0, #CLAW_OPENING
	beq		bbr_claw_still_opening

bbr_deactivate_open_claws:
	/* Not Claw Opening Movement, deactivate Behavior and exit */
	mov		r0, #BBR_OPEN_CLAWS
	ldr		r1, =bbr_behavior_inhibited
	bl		bbr_copy_actuator_outputs

	mov		r0, #FALSE				/* Deactivate Behavior Outputs */
	b		exit_bbr_open_claws

bbr_claw_still_opening:
	bl		has_claw_started_moving
	cmp		r0, #FALSE				/* Check if claw motor is moving (non-zero speed) */
	bne		0f
	mov		r0, #BBR_OPEN_CLAWS
	bl		open_claw				/* Keep opening claw */
	b		bbr_open_claws_active	/* No, still Opening, keep Behavior active */
0:
	bl		has_claw_fully_stopped
	cmp		r0, #FALSE				/* check if the movement is complete */
	beq		bbr_open_claws_active	/* No, still Opening, keep Behavior active */

bbr_claw_opening_stopped:
	mov		r0, #FALSE
	strb	r0, [r6]				/* update Claw Closed Status */

	mov		r0, #CLAW_STOPPED
	strb	r0, [r4]				/* Update Claw Movement Status */

	mov		r0, #BBR_OPEN_CLAWS
	bl		lock_claw				/* Keep Behavior Active for one more iteration */

bbr_open_claws_active:
	mov		r0, #FALSE
	mvn		r0, r0					/* Load TRUE, Activate Behavior */

exit_bbr_open_claws:
	pop		{r4, r5, r6}
	thumb_iret	r1					/* Thumb Interworking Return */

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
	thumb_interwork bbr_grasp_object
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

	ldr		r5, =obstacle_detected
	ldrb	r0, [r5]
	cmp		r0, #FALSE
	bne		bbr_deactivate_grasp_object


	/* Setup Pointers at start of routine */
	ldr		r4, =claw_movement
	ldr		r5, =touched
	ldr		r6, =claw_closed

	ldrb	r0, [r4]				/* retrieve Claw Movement Status */
	cmp		r0, #CLAW_STOPPED
	bne		bbr_claw_check_still_closing	/* still moving, check if we should stop */

bbr_check_grasp_object:
	/* (touched && !claw_closed)
	 * Negate expression for branch to Else Clause
	 * Using De-Morgan's Law, the Else trigger clause is:
	 * (!touched || claw_closed)
	 */
	ldrb	r0, [r5]
	cmp		r0, #FALSE				/* Touched Activated returns 255, not equal to #TRUE */
	beq		bbr_deactivate_grasp_object	/* Not Touched (R0 == FALSE), deactivate Behavior Outputs and exit */

	/* Check Claw Status */
	ldrb	r0, [r6]				/* retrieve Claw Closed Status */
	cmp		r0, #FALSE
	bne		bbr_deactivate_grasp_object	/* If Claw Closed, deactivate Behavior Outputs and exit */

bbr_start_grasp_object:
	mov		r0, #CLAW_CLOSING
	strb	r0, [r4]				/* Claw Movement = CLOSING */

	mov		r0, #BBR_GRASP_OBJECT
	bl		unlock_claw				/* start closing claw */
	b		bbr_grasp_object_active	/* let controller do its work */

bbr_claw_check_still_closing:
	cmp		r0, #CLAW_CLOSING
	beq		bbr_claw_still_closing

bbr_deactivate_grasp_object:
	/* Not Claw Closing Movement, deactivate Behavior and exit */
	mov		r0, #BBR_GRASP_OBJECT
	ldr		r1, =bbr_behavior_inhibited
	bl		bbr_copy_actuator_outputs

	mov		r0, #FALSE				/* Deactivate Behavior Outputs */
	b		exit_bbr_grasp_object

bbr_claw_still_closing:
	bl		has_claw_started_moving
	cmp		r0, #FALSE				/* Check if claw motor is moving (non-zero speed) */
	bne		0f
	mov		r0, #BBR_GRASP_OBJECT
	bl		close_claw				/* No, Keep closing claw */
	b		bbr_grasp_object_active	/* No, still Closing, keep Behavior active */
0:
	bl		has_claw_fully_stopped
	cmp		r0, #FALSE				/* check if the movement is complete */
	beq		bbr_grasp_object_active	/* No, still Closing, keep Behavior active */

bbr_claw_closing_stopped:
	mov		r0, #FALSE
	mvn		r0, r0					/* Load TRUE */
	strb	r0, [r6]				/* update Claw Closed Status */

	mov		r0, #CLAW_STOPPED
	strb	r0, [r4]				/* Update Claw Movement Status */

	mov		r0, #BBR_GRASP_OBJECT
	bl		lock_claw				/* Keep Behavior Active for one more iteration */

bbr_grasp_object_active:
	mov		r0, #FALSE
	mvn		r0, r0					/* Load TRUE, Activate Behavior */

exit_bbr_grasp_object:
	pop		{r4, r5, r6}
	thumb_iret	r1					/* Thumb Interworking Return */

/* Move Object Behavior
 *
 * Returns:
 *    Activated : Boolean
 *
 *
 */
	thumb_interwork bbr_move_object
	/* Move Object Algorithm
	 *  If Not Object Detected
	 *    If Touched AND Claw Closed (i.e., Claw Open)
	 *		For each level increase, increment trigger exponentially
	 *		For each level decrease, decrement trigger arithmetically
	 *		Implement Hysterisis and Max threshold?
	 *		Once trigger level reached, move forward
	 *    Else
	 *       Deactivate Behavior
	 *  Else
	 *    Maintain current actuator outputs
	 *    Reset trigger level
	 */
	push	{r5, r6, lr}

bbr_check_obstacle:
	ldr		r5, =obstacle_detected
	ldrb	r0, [r5]
	cmp		r0, #FALSE
	bne		bbr_reset_sound_state_trigger

	ldr		r5, =touched
	ldr		r6, =claw_closed

bbr_check_move_object:
	/* (touched && claw_closed)
	 * Negate expression for branch to Else Clause
	 * Using De-Morgan's Law, the Else trigger clause is:
	 * (!touched || !claw_closed)
	 */
	ldrb	r0, [r5]
	cmp		r0, #FALSE				/* Touched Activated returns 255, not equal to #TRUE */
	beq		bbr_deactivate_move_object	/* Not Touched (R0 == FALSE), deactivate Behavior Outputs and exit */

	/* Check Claw Status */
	ldrb	r0, [r6]				/* retrieve Claw Closed Status */
	cmp		r0, #FALSE
	bne		move_object_check_soundlevel	/* If Claw Closed, check sound levels */

/* If Not Claw Closed, deactivate Behavior Outputs and exit */
bbr_deactivate_move_object:
	mov		r0, #BBR_MOVE_OBJECT
	ldr		r1, =bbr_behavior_inhibited
	bl		bbr_copy_actuator_outputs

	/* Update LCD Display */
	ldr		r0, =bbr_inhibited_behavior
	bl		print_behavior_state

bbr_reset_sound_state_trigger:
	/* Reset Sound Following State and Trigger Level */
	ldr		r1, =sound_following_state
	mov		r0, #SOUND_IDLE
	strb	r0, [r1]
	mov		r0, #0
	strb	r0, [r1, #1]		/* Sound Level Trigger */

	mov		r0, #FALSE				/* Deactivate Behavior Outputs */
	b		exit_bbr_move_object

move_object_check_soundlevel:
	/* Retrieve current min / max values */
	ldr		r2, =sound_min
	ldrb	r0, [r2]			/* min */
	ldrb	r1, [r2, #1]		/* max */
	ldr		r2, =sound_following_jumptable
	ldr		r3, =sound_following_jumptable_end

	bl		advanced_jump_table_dispatcher

bbr_move_object_active:
	mov		r0, #FALSE
	mvn		r0, r0					/* Load TRUE, Activate Behavior */

exit_bbr_move_object:
	pop		{r5, r6}
	thumb_iret	r1					/* Thumb Interworking Return */

/* Avoid Obstacle Behavior
 *
 * Avoid Obstacle Algorithm
 *    If Object < Obstacle Mininum Distance
 *        If Not Obstacle Detected
 *            Reset PID
 *        Else
 *            Converge PID
 *        If ((PID Output > 0) || (Not PID Ended))
 *           Set Obstacle Detected to TRUE
 *           Activate Behavior
 *        Else
 *           Set Obstacle Detected to FALSE
 *           Deactivate behavior
 *    Else
 *        Set Obstacle Detected to FALSE
 *        Deactivate behavior
 *
 * Returns:
 *    Activated : Boolean
 *
 *
 */
	thumb_interwork bbr_avoid_obstacle
	push	{r4, r5, r6, lr}
	ldr		r5, =obstacle_detected
	ldr		r6, =ultrasoundval
	ldrb	r0, [r6]							/* Retrieve Ultrasound Value (object distance) */

/* If ENABLE_PID_ABORT is defined, the PID Convergence process will be aborted and the Avoid Obstacle Behavior deactivate
 * once the obstacle minimum distance is reached. Otherwise, the normal PID convergence behavior will be used.
 */
#ifdef ENABLE_PID_ABORT
	cmp		r0, #OBSTACLE_STOPDIST
	bge		bbr_deactivate_avoid_obstacle		/* Disable behavior if Stop Distance Exceeded */
#endif

	ldrb	r1, [r5]							/* Check Obstacle Detected */
	cmp		r1, #FALSE
	bne		bbr_avoid_obstacle_pid_converge		/* True, so go perform PID control loop */

	cmp		r0, #OBSTACLE_MINDIST
	bge		bbr_deactivate_avoid_obstacle		/* Only enable behavior if Obstacle Min Distance breached */

bbr_avoid_obstacle_pid_reset:
	ldr		r0, =pid
	mov		r1, #OBSTACLE_STOPDIST
	bl		SetPIDReferenceVal					/* Set PID Reference Value to Obstacle Minimum Distance */

bbr_avoid_obstacle_pid_converge:
	ldr		r0, =pid
	ldrb	r1, [r6]							/* Retrieve ultrasound value again */
	bl		PIDController						/* Activate PID Controller */
	mov		r4, r0								/* Keep PID Controller Output in R4 for later use */

#ifdef DEBUG_PID
	mov		r0, #0
	mov		r1, #PID_ROW
	bl 		nx_display_cursor_set_pos
	ldr		r0, =pidstr
	bl		nx_display_string

	mov		r0, r4
	bl		nx_display_int

	ldr		r0, =pidunits
	bl		nx_display_string
#endif

	cmp		r4, #0								/* Check if the PID Output is non-zero */
	bne		bbr_activate_avoid_obstacle			/* If non-zero, continue updating motor actuator outputs */

bbr_avoid_obstacle_check_steady_state:
	ldr		r0, =pid
	bl		CheckPIDEnd
	cmp		r0, #FALSE
	bne		bbr_deactivate_avoid_obstacle		/* PID Steady State Reached, disable PID */

bbr_activate_avoid_obstacle:

	ldr		r0, =obstacle_tone_timestamp		/* pointer to tone_timestamp */
	ldr		r1, =IDLE_TONE_INTERVAL				/* Time Interval required */
	bl		has_timer_elapsed
	ldr		r2, =obstacle_tone_active			/* Use R2 as pointer to Obstacle Tone Active status */
	cmp		r0, #FALSE
	beq		avoid_obstacle_behavior_template	/* Has not reached target update time interval yet */

avoid_obstacle_switch_tone_state:
	ldr		r0, =obstacle_tone_timestamp		/* pointer to tone_timestamp */
	str		r1, [r0]					/* Store current timestamp in tone_timestamp */

	ldrb	r0, [r2]					/* Get Obstacle Tone Active status */
	thumb_toggle_boolean_byte r0				/* Toggle Obstacle Tone Active status */
	strb	r0, [r2]					/* Update Obstacle Tone Active Status */

avoid_obstacle_behavior_template:
	ldrb	r0, [r2]					/* Get Obstacle Tone Active status */

	ldr	r1, =bbr_avoid_obstacle_on	/* Assume True, enable tone */
	cmp		r0, #FALSE					/* Check Obstacle Tone Active status */
	bne		0f
	ldr		r1, =bbr_avoid_obstacle_off	/* False, disable tone */
0:
	mov		r0, #BBR_AVOID_OBSTACLE
	bl		bbr_copy_actuator_outputs	/* Setup Avoid Obstacle behavior template outputs */

	/* Convert PID Controller output in R4 into Motor Speed in R1 */
	neg		r1, r1						/* PID Controller output is positive, need negative motor speed for reverse */
@	rsb		r1, r4, #0

clamp_output_max:
	cmp		r1, #WHEEL_SPEED_MAX
	blt		clamp_output_min
	mov		r1, #WHEEL_SPEED_MAX		/* Clamp to WHEEL_SPEED_MAX if greater */

clamp_output_min:
	ldr		r2, =WHEEL_SPEED_MIN
	cmp		r1, r2
	bgt		done_clamp_output
	mov		r1, r2						/* Clamp to WHEEL_SPEED_MIN if less */

done_clamp_output:
	mov		r0, #BBR_AVOID_OBSTACLE
	ldr		r3, =behavior_actuations			/* candidate actuations array start address */
	mov		r2, #SIZEOF_ACTUATOR_STATE			/* number of bytes per actuator_state struct */
@	mla		r0, r2, r0, r3						/* r0 = (sizeof(actuator_state) (r2) * index (r0)) + behavior_actuations start (r3) */
	mul		r0, r2, r0
	add		r0, r0, r3

	strb	r1, [r0, #MOTOR_RWHEEL_OFFSET]
	strb	r1, [r0, #MOTOR_LWHEEL_OFFSET]		/* Set Wheel Speeds to actual calculated speeds */

	ldr		r0, =avoidobstacle_idle_behavior	/* Display String */
	bl		print_behavior_state
	b		bbr_avoid_obstacle_active

bbr_deactivate_avoid_obstacle:
	mov		r0, #BBR_AVOID_OBSTACLE
	ldr		r1, =bbr_behavior_inhibited
	bl		bbr_copy_actuator_outputs

	ldr		r0, =bbr_inhibited_behavior	/* Display String */
	bl		print_behavior_state

	mov		r0, #FALSE				/* Deactivate Behavior Outputs */
	b		exit_bbr_avoid_obstacle

bbr_avoid_obstacle_active:
	mov		r0, #FALSE
	mvn		r0, r0					/* Load TRUE, Activate Behavior */

exit_bbr_avoid_obstacle:
	strb	r0, [r5]				/* Update Obstacle Detected boolean */
	pop		{r4, r5, r6}
	thumb_iret	r1					/* Thumb Interworking Return */


/* Tribot Dispatcher
 *
 *   In this implementation, we iterate from lowest priority to highest priority behaviors
 */
	thumb_interwork tribot_dispatcher
	push	{lr}
	ldr		r0, =dispatcher_behavior_jumptable
	mov		r1, #NUM_DISPATCHER_ENTRIES
	bl		jumptable_dispatcher

exit_tribot_dispatcher:
	thumb_iret	r1					/* Thumb Interworking Return */


/* Tribot Arbiter
 *	This is just a dispatch routine used to call the respective arbiters.
 *
 *   In this implementation, we iterate from last entry to first entry
 */
	thumb_interwork tribot_arbiter
	push	{lr}
	ldr		r0, =output_arbiter_jumptable
	mov		r1, #NUM_ARBITER_ENTRIES
	bl		jumptable_dispatcher

exit_tribot_arbiter:
	thumb_iret	r1					/* Thumb Interworking Return */

/* Tribot Actuator Controller
 *	This is just a dispatch routine used to call the respective controllers.
 *
 *   In this implementation, we iterate from last entry to first entry
 */
	thumb_interwork tribot_controller
	push	{lr}
	ldr		r0, =actuator_state
	ldr		r1, =prev_actuator_state
	mov		r2, #SIZEOF_ACTUATOR_STATE
	bl		memcmp						/* returns 0 if identical */
	cmp		r0, #0
	beq		exit_tribot_controller		/* Nothing has changed, skip controller update */

	ldr		r0, =actuation_controller_jumptable
	mov		r1, #NUM_CONTROLLER_ENTRIES
	bl		jumptable_dispatcher

exit_tribot_controller:
	thumb_iret	r1					/* Thumb Interworking Return */


/** init_robot
 *    Robot Specific Initialization tasks
 *    Customize this routine for your needs
 *
 *    Note: Modifies various register contents on exit
 */
	thumb_interwork init_robot
	push	{lr}

	/* Init PID */
    mov		r0, #STEADY_STATE_THRESHOLD
    push 	{r0}                /* Insert Parameter onto Stack */
    ldr  	r0, =pid
    ldr  	r1, =alphaKP
    ldr  	r2, =alphaKI
    ldr  	r3, =alphaKD
	bl		InitPID
	pop		{r0}				/* Cleanup stack after routine call */

	/* Configure Sensors */
	mov		r0, #LIGHT_PORT
	bl		nx_sensors_analog_enable
	mov		r0, #TOUCH_PORT
	bl		nx_sensors_analog_enable
	mov		r0, #SOUND_PORT
	bl		nx_sensors_analog_enable

	mov		r0, #FALSE
	mvn		r0, r0
@	mov		r0, #TRUE			/* force claw opening on init via Open-Claws Behavior */
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


	ldr		r1, =sound_following_state
	mov		r0, #SOUND_IDLE
	strb	r0, [r1]
	mov		r0, #0
	strb	r0, [r1, #1]		/* Sound Level Trigger */

#if 0
	bl		claw_open_immediate	/* Disabled, use BBR Behavior Open-Claws instead */
#endif

	mov		r0, #ULSND_PORT
	bl		nx_radar_init					/* Initialize the Ultrasound Sensor */

retry_us_init:
	mov		r0, #SYSTICK_100MS
	bl		nx_systick_wait_ms				/* Wait 100 ms before checking Results */

	mov		r0, #ULSND_PORT
	bl		nx_radar_detect
	cmp		r0, #FALSE
	bne		continue_ultrasound_init

ultrasound_sensor_error:
	mov		r0, #0
	mov		r1, #1
	bl 		nx_display_cursor_set_pos
	ldr		r0, =ultrasound_error
	bl		nx_display_string
	b		retry_us_init

continue_ultrasound_init:
	mov		r0, #0
	mov		r1, #1
	bl 		nx_display_cursor_set_pos
	ldr		r0, =ultrasound_found
	bl		nx_display_string

	mov		r0, #ULSND_PORT
	mov		r1, #RADAR_MODE_CONTINUOUS
	bl		nx_radar_set_op_mode			/* Arm Ultrasound Sensor */

	mov		r0, #FALSE
	ldr		r1, =obstacle_detected
	strb	r0, [r1]

	bl		light_led_enable

	bl		nx_systick_get_ms				/* Current systick */
	add		r0, r0, #ROBOT_SCHED_DURATION	/* Next Scheduler Timeout value */
	ldr		r2, =sched_tick
	str		r0, [r2]						/* Update Scheduler Timeout */

	thumb_iret	r1					/* Thumb Interworking Return */

/** sleep_robot
 *    Run loop scheduler timing task
 *    This routine will wait till the next scheduler interval, then continue execution of Run Loop
 *    R2: Pointer to sched_tick (previous timer expiry timestamp)
 *    Note: This is a busy wait implementation
 */
	thumb_interwork sleep_robot
	push	{lr}

cont_sleep:
	ldr		r0, =sched_tick					/* pointer to sched_tick */
	mov		r1, #ROBOT_SCHED_DURATION		/* Time Interval required */
	bl		has_timer_elapsed				/* R0: Time Elapsed (Boolean), R1 contains current timestamp */
	cmp		r0, #FALSE						/* If Timer reached, return value is TRUE */
	beq		cont_sleep						/* Scheduler Timeout < Systick, so exit */

next_sleep_robot:
	ldr		r0, =sched_tick					/* pointer to sched_tick */
	str		r1, [r0]						/* Update sched_tick with current systick */

exit_sleep_robot:
	thumb_iret	r1					/* Thumb Interworking Return */

/** shutdown_robot
 *    Robot Specific Shutdown tasks
 *    Customize this routine for your needs
 *
 */
	thumb_interwork shutdown_robot
	push	{lr}
	bl		claw_close_immediate	/* FIXME: Can we replace it with another routne? */
	bl		stop_motion				/* Stop motors */
	bl		light_led_disable

	/* Disable Ultrasound Sensor */
	mov		r0, #ULSND_PORT
	bl		nx_radar_close
	thumb_iret	r1					/* Thumb Interworking Return */

/* Needed for Thumb Literal Pools since offsets have limited range */
.ltorg

/* Non-BBR Actuator Routines */

/* claw_close_immediate
 *    Close Claws to minimum aperature (gripping object).
 *      Keep motor engaged until tachometer shows no progress (within Threshold value)
 *      Note: This is best done using slower speed to the Motor
 *		R4: Address Pointer to Claw variables
 *
 *    Note: This routine is needed by shutdown_robot as we're no longer running the main loop.
 */

	thumb_interwork claw_close_immediate
 	push	{r4, lr}
	ldr		r4, =claw_position

claw_start_closing:
 	mov		r0, #CLAW_PORT
 	ldr		r1, =CLOSE_SPEED
 	bl		nx_motors_rotate

claw_keep_closing:
	mov		r0, #SYSTICK_100MS
	bl		nx_systick_wait_ms	/* Wait 100 ms before checking Tachometer */
	bl		get_claw_status

	ldr		r0, [r4]			/* Current Claw Position */
	ldr		r1, [r4, #4]		/* Old Claw Position */
	sub		r2, r0, r1			/* Current - Old Positions */
	bge		0f
	sub		r2, r1, r0			/* If negative, Old - Current Positions (Absolute difference in R2) */
@	rsb		r2, r0, r1			/* Absolute difference in R2 */
0:
	str		r0, [r4, #4]		/* Store Current Claw Position as Old Claw Position */
	cmp		r2, #TACHO_THRESH	/* Is it within margin of error? */
	bhi		claw_keep_closing

claw_stop_closing:
 	mov		r0, #CLAW_PORT
 	mov		r1, #FALSE			/* We want braking */
	mvn		r1, r1
	bl		nx_motors_stop

	ldr		r4, =claw_closed
 	mov		r0, #FALSE
 	mvn		r1, r1
 	strb	r0, [r4, #8]		/* Update claw_closed */

	ldr		r0, =closed
	bl		nx_progcontent2
	pop		{r4}
	thumb_iret	r1				/* Thumb Interworking Return */


/** main
 *    Main Program
 *		R7: Touched (boolean)
 *		R8: Iteration Counter (termination)
 */
	arm_interwork main
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
	ldr		r8, =MAX_ITERATIONS				/* Execution Lifetime Iteration Limiter */

main_loop:
	subs	r8, r8, #1
	beq		robot_stop

#ifdef DEBUG_ULTRASOUND

	mov		r0, #0
	mov		r1, #2
	bl 		nx_display_cursor_set_pos

	mov		r0, #ULSND_PORT
	bl		nx_radar_info
	bl		get_obstacle_distance

#else

	/* Perform Sensor Readings */
	bl		collect_samples				/* Combine multiple sensor readings in one routine */
	bl		calc_light_min_max			/* Calc min-max for light sensor inputs */
	bl		calc_sound_min_max			/* Calc min-max for sound level inputs */
	bl		get_touch_status
	bl		get_claw_status
	bl		get_obstacle_distance


main_dispatch:
	bl		tribot_dispatcher

main_arbitration:
	bl		tribot_arbiter			/* Behavior Arbiter */

main_actuation:
	bl		tribot_controller		/* Actuator Controller */

#endif

	bl		sleep_robot				/* Scheduler Wait Loop */
	b		main_loop				/* continue event loop execution */

robot_stop:
	bl		shutdown_robot			/* Stop motors */

/********************** End Customization Here **********************/
exit_main:
	bl		nx_progshutdown
	pop		{lr}
	bx		lr

.end
