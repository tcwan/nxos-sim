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
#include "base/drivers/aic.h"
#include "base/drivers/_lcd.h"

#include "base/drivers/_systick.h"

/* The main clock is at 48MHz, and the PIT divides that by 16 to get
 * its base timer frequency.
 */

#define NXT_CLOCK_FREQ 48000000

#define PIT_BASE_FREQUENCY (NXT_CLOCK_FREQ/16)

/* PIT count for 1 us */
#define US_COUNT (PIT_BASE_FREQUENCY/1000000L)

/* We want a timer interrupt 1000 times per second. */
#define SYSIRQ_FREQ 1000

#ifdef __LEGONXT__

/* The system IRQ processing takes place in two different interrupt
 * handlers: the main PIT interrupt handler runs at a high priority,
 * keeps the system time accurate, and triggers the lower priority
 * IRQ.
 *
 * All other periodic processing (needed eg. by drivers) takes place
 * in this lower priority interrupt handler. This ensures that we
 * don't miss a clock beat.
 *
 * As the PIT only has one interrupt line, we steal the PWM
 * controller's interrupt line and use it as our low-priority system
 * interrupt. The PWM controller is unused on the NXT, so this is no
 * problem.
 */
#define SCHEDULER_SYSIRQ AT91C_ID_PWMC

#endif

/* The system timer. Counts the number of milliseconds elapsed since
 * the system's initialization.
 */
static volatile U32 systick_time;

/* The scheduler callback. Application kernels can set this to their own
 * callback function, to do scheduling in the high priority systick
 * interrupt.
 */
static nx_closure_t scheduler_cb = NULL;

/* The scheduler mask. If TRUE, the scheduler callback will not be
 * invoked from the high priority interrupt handler.
 */
static bool scheduler_inhibit = FALSE;

/* Low priority handler, called 1000 times a second by the high
 * priority handler if a scheduler callback is registered.
 */
static void systick_sched(void) {
  /* Acknowledge the interrupt. */
#ifdef __LEGONXT__
  nx_aic_clear(SCHEDULER_SYSIRQ);
#endif

  /* Call into the scheduler. */
  if (scheduler_cb)
    scheduler_cb();
}

/* High priority handler, called 1000 times a second */
static void systick_isr(void) {
  volatile U32 status __attribute__ ((unused));
  /* The PIT's value register must be read to acknowledge the
   * interrupt.
   */

#ifdef __LEGONXT__
  status = *AT91C_PITC_PIVR;
#endif

  /* Do the system timekeeping. */
  systick_time++;

  /* Keeping up with the AVR link is a crucial task in the system, and
   * must absolutely be kept up with at all costs. Thus, handling it
   * in the low-level dispatcher is not enough, and we promote it to
   * being handled directly here.
   *
   * As a result, this handler must be *very* fast.
   */

  /* The LCD dirty display routine can be done here too, since it is
   * very short.
   */
  nx__lcd_fast_update();

  if (!scheduler_inhibit)
    nx_systick_call_scheduler();
}

void nx__systick_init(void) {
  nx_interrupts_disable();

#ifdef __DE1SOC__
	// FIXME
#define UNUSED(x) (void)(x)
  	  UNUSED(systick_sched);
  	  UNUSED(systick_isr);
#endif

#ifdef __LEGONXT__
  /* Install both the low and high priority interrupt handlers, ready
   * to handle periodic updates.
   */
  nx_aic_install_isr(SCHEDULER_SYSIRQ, AIC_PRIO_SCHED,
		     AIC_TRIG_EDGE, systick_sched);
  nx_aic_install_isr(AT91C_ID_SYS, AIC_PRIO_TICK,
		     AIC_TRIG_EDGE, systick_isr);


  /* Configure and enable the Periodic Interval Timer. The counter
   * value is 1/16th of the master clock (base frequency), divided by
   * our desired interrupt period of 1ms.
   */
  *AT91C_PITC_PIMR = (((PIT_BASE_FREQUENCY / SYSIRQ_FREQ) - 1) |
                      AT91C_PITC_PITEN | AT91C_PITC_PITIEN);
#endif

  nx_interrupts_enable();
}

U32 nx_systick_get_ms(void) {
  return systick_time;
}

void nx_systick_wait_ms(U32 ms) {
  U32 final = systick_time + ms;

  /* Dealing with systick_time rollover:
   * http://www.arduino.cc/playground/Code/TimingRollover
   * Exit only if (long)( systick_time - final ) >= 0
   *    Note: This used signed compare to come up with the correct decision
   */
#if 0
  while (systick_time < final);
#else
  while ((long) (systick_time - final) < 0);
#endif

}

void nx_systick_wait_us(U32 us) {

#ifdef __DE1SOC__
	  U32 pittime = 0;	// FIXME
#endif

#ifdef __LEGONXT__
  U32 pittime = (*AT91C_PITC_PIIR);
#endif
  U32 final = pittime + (US_COUNT * us);

  /* Dealing with systick_time rollover:
   * http://www.arduino.cc/playground/Code/TimingRollover
   * Exit only if (long)( pittime - final ) >= 0
   *    Note: This used signed compare to come up with the correct decision
   */
  while ((long) (pittime - final) < 0) {
#ifdef __DE1SOC__
	  pittime = 0;	// FIXME
#endif

	  #ifdef __LEGONXT__
	  pittime = (*AT91C_PITC_PIIR);
#endif
	}
}

void nx_systick_wait_ns(U32 ns) {
  volatile U32 x = (ns >> 7) + 1;

  while (x--);
}

void nx_systick_install_scheduler(nx_closure_t sched_cb) {
  nx_interrupts_disable();
  scheduler_cb = sched_cb;
  nx_interrupts_enable();
}

void nx_systick_call_scheduler(void) {
  /* If the application kernel set a scheduling callback, trigger the
   * lower priority IRQ in which the scheduler runs.
   */
#ifdef __LEGONXT__
  if (scheduler_cb)
    nx_aic_set(SCHEDULER_SYSIRQ);
#endif
}

void nx_systick_mask_scheduler(void) {
  scheduler_inhibit = TRUE;
}

void nx_systick_unmask_scheduler(void) {
  scheduler_inhibit = FALSE;
}
