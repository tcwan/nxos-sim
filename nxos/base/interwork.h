/** @file interwork.h
 *  @brief Interworking Macros for Assembly Language Routines.
 */

/* Copyright (c) 2011 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_INTERWORK_H__
#define __NXOS_BASE_INTERWORK_H__

#ifdef __ASSEMBLY__
/** Macro to call Interworked ARM Routine
 *
 *      arm_icall       <target_arm_routine>
 *
 */
	.macro arm_icall arm_routine
	BL     \arm_routine        @ Linker will generate veneer automatically
	.endm
	
/** Macro to declare Interworking ARM Routine
 *
 *      arm_interwork   <arm_routine_name>
 *
 */
	.macro arm_interwork arm_routine
	.align 4
	.arm
	.global \arm_routine
\arm_routine:
	.endm
	
/** Macro to call Interworked Thumb Routine
 *
 *      thumb_icall     <target_thumb_routine>
 *
 */
	.macro thumb_icall thumb_routine
	BL     \thumb_routine      @ Linker will generate veneer automatically
	.endm
	
/** Macro to declare Interworking Thumb Routine
 *
 *      thumb_interwork <thumb_routine_name>
 *
 */
	.macro thumb_interwork thumb_routine
	.align 2
	.thumb_func
	.global \thumb_routine
\thumb_routine:
	.endm

#endif  /* __NXOS_BASE_INTERWORK_H__ */
