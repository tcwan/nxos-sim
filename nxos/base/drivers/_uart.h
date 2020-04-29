/** @file _uart.h
 *  @brief UART system internal interface.
 */

/* Copyright (C) 2020 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_DRIVERS__UART_H__
#define __NXOS_BASE_DRIVERS__UART_H__

#include "base/drivers/uart.h"

/** @addtogroup driverinternal */
/*@{*/

/** @defgroup uartinternal UART */
/*@{*/

/**
 * UART I/O register constants
 */
#define UART_DATA_INDEX 0x0					/**< 32-bit Index for UART Data Register */
#define UART_RDATA_SHORT_INDEX  0x0			/**< 16-bit Index for UART Read Data Lo Register */
#define UART_RAVAIL_SHORT_INDEX 0x1			/**< 16-bit Index for UART Read Data Hi Register */

#define UART_DATAREG_MASK 0xFF				/**< UART Data Register Data Buffer Mask */
#define RVALID_MASK 0x00008000				/**< UART Data Register Data Valid Mask */
#define RAVAIL_MASK 0xFFFF0000				/**< UART Data Register Data Available Register Mask */
#define RAVAIL_SHIFT 16						/**< UART Data Register Data Available Bitshift */

#define UART_CONTROL_INDEX 0x1				/**< 32-bit Index for UART Control Register */
#define UART_WDATA_BYTE_INDEX 0x0			/**<  8-bit Index for UART Write Data Register */
#define UART_WSPACE_SHORT_INDEX  0x3		/**<  16-bit Index for UART Control Write Buffer Register */
#define WSPACE_MASK 0xFFFF0000				/**< UART Control Register Write Buffer Register Mask */
#define WSPACE_SHIFT 16						/**< UART Control Register Write Buffer Available Bitshift */

#define UART_INTR_RE_MASK 0x0001			/**< UART Control Register Interrupt RE Mask */
#define UART_INTR_WE_MASK 0x0002			/**< UART Control Register Interrupt WE Mask */
#define UART_INTR_RI_MASK 0x0100			/**< UART Control Register Interrupt RI Mask */
#define UART_INTR_WI_MASK 0x0200			/**< UART Control Register Interrupt WI Mask */
#define UART_INTR_AC_MASK 0x0400			/**< UART Control Register Interrupt AC Mask */

/** Initialize the UART driver. */
void nx__uart_init(void);

/*@}*/
/*@}*/

#endif /* __NXOS_BASE_DRIVERS__UART_H__ */
