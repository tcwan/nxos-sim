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

#include "base/types.h"
#include "base/interrupts.h"
#include "base/assert.h"
#include "base/drivers/aic.h"
#include "base/drivers/systick.h"

#include "base/drivers/_sound.h"
#include "base/drivers/_sound_def.h"

#undef __DEBUG_TONE_PATTERN__

#ifdef __DEBUG_TONE_PATTERN__
#include "base/display.h"
#endif

#ifdef __DE1SOC__


static const U32 tone_pattern[DE1_WAVEFORM_NUMSAMPLES] = {
  // Create a PCM waveform (note that the amplitude is non-linear)
  // With 16 samples, this is equivalent to a 500 Hz tone if every sample is played back
  // The default sampling rate for the DE1-SoC is 8K, with 24-bit samples.
  // Note that due to the Nyquist sampling theorem, frequencies > 2KHz cannot be played back properly
  // due to the distortion in the effective waveform.
  //
  0x60000000,0x70000000,
  0x80000000,0x90000000,
  0x9FFFFFFF,0x90000000,
  0x80000000,0x70000000,
  0x60000000,0x50000000,
  0x40000000,0x30000000,
  0x20000000,0x30000000,
  0x40000000,0x50000000
};

static volatile U32 total_samples;
static volatile U32 increment_q;			/* Increment per sample for waveform generation */
static volatile U32 accumulator_q;			/* Accumulator (counter) for waveform index calculation */


// FIXME
#define UNUSED(x) (void)(x);

void nx__sound_init(void) {

  ((HW_REG *) AUDIO_BASE)[AIO_CONTROL_INDEX] = 0;	/* Clear Audio Out FIFO, disable interrupts */
  total_samples = 0;
  increment_q = 0;									/* fixed point value */
  accumulator_q = 0;								/* fixed point value */


}

void nx_sound_freq_async(U32 freq, U32 ms) {
	UNUSED(freq);
	UNUSED(ms);
    NX_ASSERT_MSG(TRUE, "Asynch sound generator not implemented.\n");
}

static void nx__output_sound_sample(U32 sample) {
	while (	((((HW_REG *) AUDIO_BASE)[AIO_FIFOSPACE_INDEX] & AIO_WSLC_MASK) == 0) ||
			((((HW_REG *) AUDIO_BASE)[AIO_FIFOSPACE_INDEX] & AIO_WSRC_MASK) == 0) );
		/* Wait for non-zero space in the FIFO output buffer */

	// Write the same sample to both Left and Right channels
	((HW_REG *) AUDIO_BASE)[AIO_LEFTDATA_INDEX] =
	((HW_REG *) AUDIO_BASE)[AIO_RIGHTDATA_INDEX] = sample;
}

void nx_sound_freq(U32 freq, U32 ms) {
	NX_ASSERT_MSG(ms >= 300, "Due to driver bug ms must be >= 300 ms\n");
	NX_ASSERT_MSG(freq <= 2000, "Frequency must be <= 2kHz\n");
	total_samples = ms * (DE1_AIO_FREQ / 1000);	// Calculate duration in number of samples
	accumulator_q = 0;							// Reset accumulator

	// The following uses fixed point math, with 8 bits for the decimal portion.
	//
	// Next, we need to determine the number of samples for one waveform (cycle)
	// Nsc = Sampling Rate (Hz) / Freq (Hz).
	// However, this is a real number.
	// Give the number of samples DE1_WAVEFORM_NUMSAMPLES for the waveform,
	// we calculate the fraction of the waveform to advance, increment_q (fixed point number).
	// increment_q = Num. Waveform Samples / Sampling Rate (Hz) * Freq (Hz).
	//
	// increment_q will be added to accumulator_q (fixed point number) for each generated sample.
	// The waveform index i_w is calculated from the value of accumulator_q mod (Num. Waveform Samples)
	// This approach is based on waveform stretching and not waveform interpolation.

	increment_q = ((U32)(DE1_WAVEFORM_NUMSAMPLES * freq) << FIXED_POINT_NUMBITS)
					/ (U32)(DE1_AIO_FREQ);

#ifdef __DEBUG_TONE_PATTERN__

#undef __FIXED_POINT_MATH__

#ifdef __FIXED_POINT_MATH__
	increment_q = (freq * DE1_WAVEFORM_NUMSAMPLES) << FIXED_POINT_NUMBITS;

	nx_display_string("incr_q 1 = ");
	nx_display_uint(increment_q);
	nx_display_end_line();
	increment_q = increment_q / (DE1_AIO_FREQ);
	nx_display_string("incr_q 2 = ");
	nx_display_uint(increment_q);
	nx_display_end_line();
#else
	increment_q = (freq * DE1_WAVEFORM_NUMSAMPLES) / DE1_AIO_FREQ;			// integer math
#endif

#endif

	while (total_samples > 0) {
		int pattern_index = ((U32)(accumulator_q >> FIXED_POINT_NUMBITS)) % DE1_WAVEFORM_NUMSAMPLES;

#ifdef __DEBUG_TONE_PATTERN__

#ifdef __FIXED_POINT_MATH__
	    int calc_index = (accumulator_q >> FIXED_POINT_NUMBITS);
		int pattern_index = calc_index % DE1_WAVEFORM_NUMSAMPLES;
#else
		int pattern_index = accumulator_q % DE1_WAVEFORM_NUMSAMPLES;			// integer math
#endif

#if 0
		// This is very verbose if enabled
		nx_display_string("Idx = ");
		nx_display_int(pattern_index);
		nx_display_end_line();
#endif

#endif
		U32 sampleVal = tone_pattern[pattern_index];
		nx__output_sound_sample(sampleVal);			// send PCM sample to Audio Codec

		accumulator_q += increment_q;				// Advance waveform fraction
		total_samples--;
	}

}



#endif

#ifdef __LEGONXT__
/* Statically defined digitized sine wave, used for tone
 * generation.
 */
static const U32 tone_pattern[16] = {
  0xF0F0F0F0,0xF0F0F0F0,
  0xFCFCFCFC,0xFCFCFCFC,
  0xFFFFFFFF,0xFFFFFFFF,
  0xFCFCFCFC,0xFCFCFCFC,
  0xF0F0F0F0,0xF0F0F0F0,
  0xC0C0C0C0,0xC0C08080,
  0x00000000,0x00000000,
  0x8080C0C0,0xC0C0C0C0
};

/* When a tone is playing, this value contains the number of times the
 * previous digitized sine wave is to be played.
 */
static volatile U32 tone_cycles;

static void sound_isr(void) {
  if (tone_cycles--) {
    /* Tell the DMA controller to stream the static sine wave, 16
     * words of data.
     */
    *AT91C_SSC_TNPR = (U32) tone_pattern;
    *AT91C_SSC_TNCR = 16;
  } else {
    /* Transmit complete, disable sound again. */
    *AT91C_SSC_IDR = AT91C_SSC_ENDTX;
  }
}

void nx__sound_init(void) {
  nx_interrupts_disable();

  /* Start by inhibiting all sound output. Then enable power to the
   * SSC peripheral and do a software reset. The combination of these
   * three actions will get the controller reinitialized whether we
   * are warm- or cold-booting the NXT.
   */
  *AT91C_PMC_PCER = (1 << AT91C_ID_SSC);
  *AT91C_SSC_IDR = ~0;
  *AT91C_SSC_CR = AT91C_SSC_SWRST;

  /* Configure the transmit clock to be based on the board master
   * clock, to clock continuously (don't stop sending a clock signal
   * when there is no data), and set transmissions to start as soon as
   * there is data available to send.
   */
  *AT91C_SSC_TCMR = (AT91C_SSC_CKS_DIV |
                     AT91C_SSC_CKO_CONTINOUS |
                     AT91C_SSC_START_CONTINOUS);

  /* Configure the framing mode for transmission: 32-bit data words, 8
   * words per frame, most significant bit first. Also set the default
   * driven value (when there is no data being streamed) to 1.
   */
  *AT91C_SSC_TFMR =
    31 | AT91C_SSC_DATDEF | AT91C_SSC_MSBF | (7 << 8);

  /* Idle the output data pin of the SSC. The value on the pin will
   * now be whatever the SSC pumps out.
   */
  *AT91C_PIOA_PDR = AT91C_PA17_TD;

  /* Start transmitting. */
  *AT91C_SSC_CR = AT91C_SSC_TXEN;

  /* Install the interrupt routine that will feed data to the DMA
   * controller when we are outputting data.
   */
  nx_aic_install_isr(AT91C_ID_SSC, AIC_PRIO_DRIVER,
		     AIC_TRIG_LEVEL, sound_isr); // Level or edge?

  nx_interrupts_enable();
}

void nx_sound_freq_async(U32 freq, U32 ms) {
  /* Due to a bug in the sound driver, too short a beep will crash
   * it. So, we check.
   */
  NX_ASSERT_MSG(ms >= 100, "Due to driver bug\nms must be\n>= 100 ms");

  /* Set the master clock divider to output the correct frequency.
   *
   * The values are currently magic borrowed from Lejos.
   * TODO: Figure this out and document it.
   */
  *AT91C_SSC_CMR = ((96109714 / 1024) / freq) + 1;
  tone_cycles = (freq * ms) / 2000 - 1;

  /* Enable handling of the transmit end interrupt. */
  *AT91C_SSC_IER = AT91C_SSC_ENDTX;

  /* Tell the DMA controller to start transmitting. This will cause an
   * interrupt, and the interrupt handler will point the DMA
   * controller at the data.
   */
  *AT91C_SSC_PTCR = AT91C_PDC_TXTEN;
}

void nx_sound_freq(U32 freq, U32 ms) {
  nx_sound_freq_async(freq, ms);
  nx_systick_wait_ms(ms);
}
#endif
