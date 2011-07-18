/* Copyright (C) 2007-2011 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#include "base/at91sam7s256.h"
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

