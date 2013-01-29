/** @file macros.h
 *  @brief Definitions of common Tribot macros.
 */

/* Copyright (C) 2012-2013 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_SYSTEMS_MACROS_H__
#define __NXOS_SYSTEMS_MACROS_H__


	.macro time_elapsed	curr_time, prev_time, interval
	/*
	 * Dealing with elapsed time timestamp rollover:
	 * http://www.arduino.cc/playground/Code/TimingRollover
	 * Return TRUE only if (long)( current time - (prev_time + interval) ) >= 0
	 *    Note: This used signed compare to come up with the correct decision
	 */
	add		\prev_time, \prev_time, \interval
	rsbs	\curr_time, \prev_time, \curr_time
/*	cmp		\curr_time, #0 */
	movlt	r0, #FALSE
	movge	r0, #TRUE
	.endm

	.macro toggle_boolean_byte	reg
	/* This macro toggles 8-bit Boolean TRUE (0xFF) to FALSE (0x00) and vice versa using ARM instructions */
	mvn		\reg, \reg						/* Invert status */
	and		\reg, \reg, #0xFF				/* Mask to 8-bits */
	.endm

	.macro thumb_toggle_boolean_byte	reg
	/* This macro toggles 8-bit Boolean TRUE (0xFF) to FALSE (0x00) and vice versa using Thumb instructions */
	mvn		\reg, \reg						/* Invert status */
	lsl		\reg, #24
	lsr		\reg, #24						/* Mask to 8-bits */
	.endm

#endif /* __NXOS_SYSTEMS_MACROS_H__ */
