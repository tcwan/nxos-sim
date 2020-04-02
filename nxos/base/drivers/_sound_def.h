/** @file _sound.h
 *  @brief Sound module internal interface.
 */

/* Copyright (C) 2020 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_DRIVERS__SOUND_DEF_H__
#define __NXOS_BASE_DRIVERS__SOUND_DEF_H__

#ifdef __DE1SOC__

#define FIXED_POINT_NUMBITS		8				// 8 bits of fixed point
#define DE1_AIO_FREQ			8000			// 8K samples per second
#define DE1_AIO_MAXBUFSIZE 		128				// 128 sample buffer
#define DE1_AIO_MINBUFSIZE		32				// 25% buffer capacity will trigger interrupt
#define DE1_WAVEFORM_NUMSAMPLES 16

/* Audio Input/Output Module Defines */
#define AIO_CONTROL_INDEX		0
#define AIO_FIFOSPACE_INDEX		1
#define AIO_LEFTDATA_INDEX		2
#define AIO_RIGHTDATA_INDEX		3

#define AIO_WI_MASK		0x0200		/**< AIO Write Interrupt Pending */
#define AIO_RI_MASK		0x0100		/**< AIO Read Interrupt Pending */
#define AIO_CW_MASK		0x0008		/**< AIO Clear Write FIFO */
#define AIO_CR_MASK		0x0004		/**< AIO Clear Read FIFO */
#define AIO_WE_MASK		0x0002		/**< AIO Write Interrupt Enable */
#define AIO_RE_MASK		0x0001		/**< AIO Read Interrupt Enable */


#define AIO_WSLC_MASK	0xFF000000
#define AIO_WSRC_MASK	0x00FF0000
#define AIO_RALC_MASK	0x0000FF00
#define AIO_RARC_MASK	0x000000FF


#endif

#endif /* __NXOS_BASE_DRIVERS__SOUND_DEF_H__ */
