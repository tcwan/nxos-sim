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

#ifdef __LEGONXT__
#include "base/boards/LEGO-NXT/at91sam7s256.h"
#endif
#include "base/drivers/systick.h"
#include "base/drivers/sound.h"

#include "base/lib/alerts/alerts.h"

void hello_alert(bool audible) {
  if (!audible)
    return;
  nx_sound_freq(1000, 100);
  nx_systick_wait_ms(50);
  nx_sound_freq(2000, 100);
  nx_systick_wait_ms(900);
}

void goodbye_alert(bool audible) {
  if (!audible)
    return;
  nx_sound_freq(2000, 100);
  nx_systick_wait_ms(50);
  nx_sound_freq(1000, 100);
  nx_systick_wait_ms(900);
}

