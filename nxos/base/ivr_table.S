/* Copyright (C) 2020 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#include "asm_decls.h"
#define __ASSEMBLY__

#ifdef __DE1SOC__
#include "base/boards/DE1-SoC/address_map_arm.h"
#include "base/boards/DE1-SoC/interrupt_ID.h"
#include "base/ivr_table.h"
#endif

#ifdef __LEGONXT__
#include "base/boards/LEGO-NXT/at91sam7s256.h"
#endif

#ifdef __DE1SOC__

.data
.align

/*
 * Altera DE1-SoC FPGA Board ISR Interrupt Vectors
 *
 * To override the vectors, the isr_vec label must be known.
 * The entries are sorted by priority (highest first)
 *
 */

	.global de1_soc_ivr_table
de1_soc_ivr_table:
	gic_vector_entry ivr_a9prtmr, MPCORE_PRIV_TIMER_IRQ, systick_isr	// Cortex-A9 Private Timer Interrupt
	gic_vector_entry ivr_invalid, INVALID_INTR_ID, nx__spurious_irq		// Guard Entry (must be last item in table)

	.equ	de1_soc_ivr_table_end, .

#endif
