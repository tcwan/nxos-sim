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
#include "base/interrupts.h"
#include "base/assert.h"
#include "base/drivers/aic.h"
#include "base/drivers/systick.h"

#ifdef __DE1SOC__

#include "base/drivers/_button.h"

void nx_de1_button_init(void) {
  // FIXME: Do nothing as we're not going to enable interrupts
}

nx_de1_button_t nx_de1_get_button(void) {

  HW_REG *buttonreg = (HW_REG *) KEY_BASE;

  int buttonInput = (*buttonreg & BUTTON_ALLMASK);
  if (buttonInput & BUTTON_3_MASK)
	return BUTTON_3;
  else if (buttonInput & BUTTON_2_MASK)
	return BUTTON_2;
  else if (buttonInput & BUTTON_1_MASK)
    return BUTTON_1;
  else if (buttonInput & BUTTON_0_MASK)
	return BUTTON_0;
  else
  	return BUTTON_NONE;

}

#endif /* __DE1SOC__ */
