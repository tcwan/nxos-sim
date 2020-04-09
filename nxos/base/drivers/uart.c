/* Copyright (C) 2007-2020 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifdef __DE1SOC__
#include "base/boards/DE1-SoC/address_map_arm.h"
#include "base/boards/DE1-SoC/interrupt_ID.h"
#endif

#include "base/types.h"
#include "base/assert.h"
#include "base/interrupts.h"
#include "base/drivers/aic.h"
#include "base/drivers/systick.h"

#include "base/drivers/_uart.h"

static volatile struct {
  U32 num_read;
  U8 readbuf[UART_RXBUFSIZE]; 		/* Used for interrupt driven reads */

} uart_state = {
  0, {0}
};

#ifdef __DE1SOC__
	// FIXME
#define UNUSED(x) (void)(x)

/** Initialize the UART driver.
 *
 * @param callback The callback to fire when the UART receives data.
 */
void nx__uart_init(void) {
	nx_uart_readbuf((U8 *)&uart_state.readbuf, (U32 *)&uart_state.num_read);		// Clear UART read buffer
	uart_state.num_read = 0;
}
U32 nx_uart_read_avail(void) {
	// U32 rdata = ((HW_REG *)JTAG_UART_BASE)[UART_DATA_INDEX];
	// return (U32) ravail;
	return (U16) ((HW_REG16 *)JTAG_UART_BASE)[UART_RAVAIL_SHORT_INDEX];
}

U32 nx_uart_write_avail(void) {
	return (U16) ((HW_REG16 *)JTAG_UART_BASE)[UART_WSPACE_SHORT_INDEX];
	//return (U32) ((((HW_REG *)JTAG_UART_BASE)[UART_CONTROL_INDEX] & WSPACE_MASK) >> WSPACE_SHIFT);
}

U8 nx_uart_getchar(void) {

	while (nx_uart_read_avail() == 0);
	U16 rdata = ((HW_REG16 *)JTAG_UART_BASE)[UART_RDATA_SHORT_INDEX];	// Read from FIFO, RAVAIL is decremented
	if (rdata & RVALID_MASK)
		return (U8) (rdata & UART_DATAREG_MASK);
	else
		return 0;			// return NUL if not valid
}

void nx_uart_putchar(U8 writechar) {

	while (nx_uart_write_avail() == 0);
	((HW_REG8 *)JTAG_UART_BASE)[UART_WDATA_BYTE_INDEX] = writechar;
}

void nx_uart_readbuf(U8 *buf, U32 *length) {

	int count = nx_uart_read_avail();
	*length = count;
	while (count > 0) {
		*buf = nx_uart_getchar();			// This is ok since it is a blocking call
		buf++;
		count--;
	}
}

void nx_uart_writebuf(const U8 *buf, U32 length) {

	// U32 availspace = nx_uart_write_avail();
	while (length > 0) {
		nx_uart_putchar(*buf);			// This is ok since it is a blocking call
		buf++;
		length--;
	}

}
#endif

