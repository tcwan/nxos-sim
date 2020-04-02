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

#define GIC_INTRID_MASK	0x3FF						/**< GIC Interrupt ID bitmask  */

/** Macro to define IVR lookup table
 *
 *  Entries should be arranged with highest priority first for fast lookup
 *  Last entry must have Interrupt ID of INVALID_INTR_ID to indicate end of table.
 *
 *  Respective IVRs are exported to allow for installation of new interrupt handlers.
 *
 *  @param isr_vec: name of ISR vector
 *  @param intr_id: Interrupt ID value
 *  @param intr_routine: Interrupt Handler routine pointer
 *
 */
/** @cond DOXYGEN_SKIP */
	.macro gic_vector_entry isr_vec, intr_id, intr_routine
	.align
/** @endcond */

	.global \isr_vec								/**< Export vector address for overrides */
\isr_vec:
	.word	\intr_id								/**< Interrupt ID value  */
	.word	\intr_routine							/**< Interrupt Handler pointer  */
	.endm

	.equ	GIC_VEC_ENTRY_ISR_ID, 0					/**< ISR vector Interrupt ID offset */
	.equ	GIC_VEC_ENTRY_ISR_OFFSET, 4				/**< ISR vector Interrupt Handler offset */
	.equ	SIZEOF_GIC_VEC_ENTRY, 8					/**< ISR vector entry size */
	.equ	INVALID_INTR_ID, 0xFFFFFFFF				/**< ISR vector Invalid Interrupt ID value */

#endif /* __IVR_TABLE_H__ */
