/** @file _button.h
 *  @brief Button system internal interface.
 */

/* Copyright (C) 2020 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_DRIVERS__BUTTON_H__
#define __NXOS_BASE_DRIVERS__BUTTON_H__

#include "base/drivers/button.h"

/** @addtogroup driverinternal */
/*@{*/

/** @defgroup buttoninternal Button */
/*@{*/

#define BUTTON_ALLMASK 0x0F		/**< Bitmask for all buttons */
#define BUTTON_0_MASK 0x01		/**< Bitmask for button 0 status */
#define BUTTON_1_MASK 0x02		/**< Bitmask for button 1 status */
#define BUTTON_2_MASK 0x04		/**< Bitmask for button 2 status */
#define BUTTON_3_MASK 0x08		/**< Bitmask for button 3 status */

/** Initialize the button driver. */
void nx_de1_button_init(void);

/*@}*/
/*@}*/

#endif /* __NXOS_BASE_DRIVERS__BUTTON_H__ */
