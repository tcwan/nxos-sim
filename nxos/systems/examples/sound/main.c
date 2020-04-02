/* Copyright (c) 2009 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

/* Sound driver example.
 *
 * The sound driver is one of the simplest drivers in NxOS, producing
 * beeps at a specified frequency on demand.
 */

#include "base/drivers/sound.h"
#include "base/drivers/systick.h" /* For nx_systick_wait_ms */

void main() {
/* Needed to support CPUlator system init
 * since it starts execution from main() and does not go through the system reset handler
 */
#include "cpulator_stub.inc"

  /* Play a silent tone for 300 ms. This function waits for the tone
   * to finish before continuing.
   * Silent tones are needed to prime the audio out before playing short tones (~ 300 ms)
   */
  nx_sound_freq(0, 300);
  nx_systick_wait_ms(500);

  /* Play a 1kHz tone for 1 second. This function waits for the tone
   * to finish before continuing.
   */
  nx_sound_freq(1000, 1000);
  nx_systick_wait_ms(500);

  /* Play a 1.5kHz tone for 1 second. This function waits for the tone
   * to finish before continuing.
   */
  nx_sound_freq(1500, 1000);
  nx_systick_wait_ms(500);

  /* Play a 2kHz tone for 1 second. This function waits for the tone
   * to finish before continuing.
   */
  nx_sound_freq(2000, 1000);
  nx_systick_wait_ms(500);

  /* Play a 500Hz tone for 1 second. This function waits for the tone
   * to finish before continuing.
   */
  nx_sound_freq(500, 1000);
  nx_systick_wait_ms(500);

  /* Play a 250Hz tone for 0.5 second. This function waits for the tone
   * to finish before continuing.
   */
  nx_sound_freq(250, 500);
  nx_systick_wait_ms(500);

  /* Play a 100Hz tone for 0.5 second. This function waits for the tone
   * to finish before continuing.
   */
  nx_sound_freq(100, 500);
  nx_systick_wait_ms(500);

  /* Play a 50Hz tone for 0.5 second. This function waits for the tone
   * to finish before continuing.
   */
  nx_sound_freq(50, 500);
  nx_systick_wait_ms(500);

#ifndef __DE1SOC__
  //
  // 4kHz tone not feasible for DE1-SoC due to the default 8kHz sampling rate of the Audio Codec
  //
  /* Another tone, at 4kHz, for 2 seconds. This time, we'll use the
   * asynchronous tone function, which just starts the tone and
   * returns immediately. The tone will play for the duration you
   * specified, or until the brick is halted, whichever happens first.
   */
  nx_sound_freq_async(4000, 2000);

  /* We'll use the explicit wait function to wait for the tone to
   * finish.
   */
  nx_systick_wait_ms(3000);
#endif
}
