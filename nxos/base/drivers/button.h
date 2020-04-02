/** @file button.h
 *  @brief Push Button system interface.
 */

/* Copyright (C) 2020 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_DRIVERS_BUTTON_H__
#define __NXOS_BASE_DRIVERS_BUTTON_H__

#include "base/types.h"

#ifdef __DE1SOC__

/** @addtogroup driver */
/*@{*/

/** @defgroup button Button
 *
 * The button driver provides a very simple API to read the status of the Push Buttons.
 * This is meant for the Altera DE1-SoC board implemneted by CPUlator. It does not support
 * LEGO_NXT buttons.
 *
 * @warning Currently the button driver retrieves the status of the button when called.
 * It does not handle debouncing or other hardware issues.
 */
/*@{*/

/** The type of button press that has been detected. */
typedef enum {
  BUTTON_NONE = 0, /**< No button pressed. */
  BUTTON_0, /**< Button 0 pressed. */
  BUTTON_1, /**< Button 1 pressed. */
  BUTTON_2, /**< Button 2 pressed. */
  BUTTON_3, /**< Button 3 pressed. */
} nx_de1_button_t;

/** Return the state of the push buttons.
 *
 * @return A <tt>nx_button_t</tt> value.
 *
 * @note This routine only reports the highest enum button as being pressed.
 * Thus if multiple buttons are being pressed at once, the lower numbered
 * buttons are not reported.
 */
nx_de1_button_t nx_de1_get_button(void);

/*@}*/
/*@}*/

#endif /* __DE1SOC__ */
#endif /* __NXOS_BASE_DRIVERS_BUTTON_H__ */
