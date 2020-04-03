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

/** @defgroup soundinternal UART */
/*@{*/

/**
 * UART I/O register constants
 */
#define UART_DATA_INDEX 0x0					/* Index must be based on the data type (U32) */
#define UART_RDATA_SHORT_INDEX  0x0			/* Index must be based on the data type (U16) */
#define UART_RAVAIL_SHORT_INDEX 0x1			/* Index must be based on the data type (U16) */

#define UART_DATAREG_MASK 0xFF
#define RVALID_MASK 0x00008000
#define RAVAIL_MASK 0xFFFF0000
#define RAVAIL_SHIFT 16

#define UART_CONTROL_INDEX 0x1				/* Index must be based on the data type (U32) */
#define UART_WDATA_BYTE_INDEX 0x0			/* Index must be based on the data type (U8) */
#define UART_WSPACE_SHORT_INDEX  0x3		/* Index must be based on the data type (U16) */
#define WSPACE_MASK 0xFFFF0000
#define WSPACE_SHIFT 16

#define UART_INTR_RE_MASK 0x0001
#define UART_INTR_WE_MASK 0x0002
#define UART_INTR_RI_MASK 0x0100
#define UART_INTR_WI_MASK 0x0200
#define UART_INTR_AC_MASK 0x0400

/** Initialize the UART driver. */
void nx__uart_init(void);

/*@}*/
/*@}*/

#endif /* __NXOS_BASE_DRIVERS__UART_H__ */
