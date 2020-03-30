/** @file _systick.h
 *  @brief System timer internal interface.
 */

/* Copyright (C) 2020 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_DRIVERS__SYSTICK_DEF_H__
#define __NXOS_BASE_DRIVERS__SYSTICK_DEF_H__

#ifdef __DE1SOC__

#define DE1_CLOCK_FREQ 200000000L
#define US_COUNT (DE1_CLOCK_FREQ/1000000L)
/* We want a timer interrupt 1000 times per second. */
#define SYSIRQ_FREQ 1000

//#define SYSTICK_DBG_INTERVAL DE1_CLOCK_FREQ		// 1 s @ 200 MHz
#define SYSTICK_DBG_INTERVAL US_COUNT*SYSIRQ_FREQ	// 1 ms @ 200 MHz


/* Cortex A9 Private Timer Defines */
#define MPT_LOAD_INDEX 		0
#define MPT_COUNTER_INDEX	1
#define MPT_CONTROL_INDEX	2
#define MPT_INTSTAT_INDEX	3

#define PTEN_MASK	0x7			// int mask = 1, mode = 1, enable = 1
#define PTINTR_ACK	0x1			// acknowldge interrupt mask

#endif

#ifdef __LEGONXT__

/* The main clock is at 48MHz, and the PIT divides that by 16 to get
 * its base timer frequency.
 */

#define NXT_CLOCK_FREQ 48000000

#define PIT_BASE_FREQUENCY (NXT_CLOCK_FREQ/16)

/* PIT count for 1 us */
#define US_COUNT (PIT_BASE_FREQUENCY/1000000L)

/* We want a timer interrupt 1000 times per second. */
#define SYSIRQ_FREQ 1000

#endif

#endif /* __NXOS_BASE_DRIVERS__SYSTICK_DEF_H__ */
