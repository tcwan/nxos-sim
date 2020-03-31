/** @file ivr_table.h
 *  @brief Define macros to support ARMv7 GIC IVR Lookups
 *
 */

/* Copyright (C) 2007,2020 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __IVR_TABLE_H__
#define __IVR_TABLE_H__

#define GIC_INTRID_MASK	0x3FF

/** Macro to define IVR lookup table
 *
 *  Entries should be arranged with highest priority first for fast lookup
 *  Last entry must have Interrupt ID of INVALID_INTR_ID to indicate end of table.
 *
 *  Respective IVRs are exported to allow for installation of new interrupt handlers.
 *
 */

	.macro gic_vector_entry isr_vec, intr_id, intr_routine
	.align
	/* Export vector address for overrides */
	.global \isr_vec
\isr_vec:
	.word	\intr_id
	.word	\intr_routine
	.endm

	.equ	GIC_VEC_ENTRY_ISR_ID, 0
	.equ	GIC_VEC_ENTRY_ISR_OFFSET, 4
	.equ	SIZEOF_GIC_VEC_ENTRY, 8
	.equ	INVALID_INTR_ID, 0xFFFFFFFF

#endif /* __IVR_TABLE_H__ */
