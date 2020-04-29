/** @file uart.h
 *  @brief UART driver for serial communications.
 *
 */

/* Copyright (C) 2020 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_DRIVERS_UART_H__
#define __NXOS_BASE_DRIVERS_UART_H__

#include "base/types.h"

/** @addtogroup driver */
/*@{*/

/** @defgroup uart UART
 *
 * The UART controller is a serial interface for bidirectional communications.
 */
/*@{*/

/**
 * Buffer size for UART messages.
 */
#define UART_RXBUFSIZE 64		/**< UART Receive Buffer Size */
#define UART_TXBUFSIZE 64		/**< UART Transmit Buffer Size */


/** Check if the UART can be read from.
 *
 * Indicates how many bytes the UART has available to read
 */
U32 nx_uart_read_avail(void);

/** Check if the UART can be written to.
 *
 * Indicates how many bytes the UART has available to write
 */
U32 nx_uart_write_avail(void);

/** Get a character from the UART.
 *
 * This routine is blocking, and will not return until a character has been read
 *
 * @return readchar: character read from UART
 */
U8 nx_uart_getchar(void);

/** Put a character to the UART
 *
 * This routine is blocking, and will not return until a character has been written
 *
 * @param writechar: character to write to UART
 */
void nx_uart_putchar(U8 writechar);

/** Read @a length bytes to @a buf over the UART bus.
 *
 * The space for buf must be allocated by the caller
 *
 * This routine is non-blocking. If no bytes are available, it will set length = 0
 * The maximum length is UART_RXBUFSIZE
 *
 * @param *buf A pointer to buffer to place read bytes
 * @param *length pointer to number of bytes read
 */
void nx_uart_readbuf(U8 *buf, U32 *length);

/** Write @a length bytes from @a buf over the UART bus.
 *
 * The space for buf must be allocated by the caller
 *
 * This routine is blocking, and will not return until the entire buf
 * has been written to the FIFO.
 *
 * To avoid excessive blocking the buf length should be <= UART_TXBUFSIZE
 *
 * @param buf A pointer to the buffer to write.
 * @param length The number of bytes to write.
 */
void nx_uart_writebuf(const U8 *buf, U32 length);

/*@}*/
/*@}*/

#endif
