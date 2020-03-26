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
#include "base/_interrupts.h"
#include "base/drivers/_aic.h"

#ifdef __DE1SOC__

/* Despite the name (AIC), this module is written for the Cortex-A9 GIC
 * The function name remains unchanged due to historical reasons.
 */
	// FIXME

/** Initialize the interrupt controller. */
void nx__aic_init(void);

/** Install @a isr as the handler for @a vector.
 *
 * @param vector The interrupt vector to configure.
 * @param prio The interrupt's priority.
 * @param trig_mode The interrupt's trigger mode.
 * @param isr The routine to call when the interrupt occurs.
 *
 * @note The interrupt line @a vector is enabled once the handler is
 * installed. There is no need to call nx_aic_enable() yourself.
 *
 * @warning If you install an ISR for a peripheral that already has
 * one installed, you @b will replace the original handler. Use with
 * care!
 */
void nx_aic_install_isr(nx_aic_vector_t vector, nx_aic_priority_t prio,
                        nx_aic_trigger_mode_t trig_mode, nx_closure_t isr);

/** Enable dispatching of @a vector.
 *
 * @param vector The interrupt vector to enable.
 */
void nx_aic_enable(nx_aic_vector_t vector);

/** Disable dispatching of @a vector.
 *
 * @param vector The interrupt vector to disable.
 */
void nx_aic_disable(nx_aic_vector_t vector);

/** Manually trigger the interrupt line @a vector.
 *
 * @param vector The interrupt vector to trigger.
 */
void nx_aic_set(nx_aic_vector_t vector);

/** Manually reset the interrupt line @a vector.
 *
 * @param vector The interrupt vector to reset.
 *
 * @note This should only be needed in the cases where the interrupt
 * line was triggered manually with nx_aic_set(). In other cases, each
 * peripheral has its own discipline for acknowledging the interrupt.
 */
void nx_aic_clear(nx_aic_vector_t vector);

#endif

#ifdef __LEGONXT__

void nx__aic_init(void) {
  int i;

  /* Prevent the ARM core from being interrupted while we set up the
   * AIC.
   */
  nx_interrupts_disable();

  /* If we're coming from a warm boot, the AIC may be in a weird
   * state. Do some cleaning up to bring the AIC back into a known
   * state:
   *  - All interrupt lines disabled,
   *  - No interrupt lines handled by the FIQ handler,
   *  - No pending interrupts,
   *  - AIC idle, not handling an interrupt.
   */
  *AT91C_AIC_IDCR = 0xFFFFFFFF;
  *AT91C_AIC_FFDR = 0xFFFFFFFF;
  *AT91C_AIC_ICCR = 0xFFFFFFFF;
  *AT91C_AIC_EOICR = 1;

  /* Enable debug protection. This is necessary for JTAG debugging, so
   * that the hardware debugger can read AIC registers without
   * triggering side-effects.
   */
  *AT91C_AIC_DCR = 1;

  /* Set default handlers for all interrupt lines. */
  for (i = 0; i < 32; i++) {
    AT91C_AIC_SMR[i] = 0;
    AT91C_AIC_SVR[i] = (U32) nx__default_irq;
  }
  AT91C_AIC_SVR[AT91C_ID_FIQ] = (U32) nx__default_fiq;
  *AT91C_AIC_SPU = (U32) nx__spurious_irq;

  nx_interrupts_enable();
}

void nx_aic_install_isr(nx_aic_vector_t vector, nx_aic_priority_t prio,
                     nx_aic_trigger_mode_t trig_mode, nx_closure_t isr) {
  /* Disable the interrupt we're installing. Getting interrupted while
   * we are tweaking it could be bad.
   */
  nx_aic_disable(vector);
  nx_aic_clear(vector);

  AT91C_AIC_SMR[vector] = (trig_mode << 5) | prio;
  AT91C_AIC_SVR[vector] = (U32)isr;

  nx_aic_enable(vector);
}

void nx_aic_enable(nx_aic_vector_t vector) {
  *AT91C_AIC_IECR = (1 << vector);
}

void nx_aic_disable(nx_aic_vector_t vector) {
  *AT91C_AIC_IDCR = (1 << vector);
}

void nx_aic_set(nx_aic_vector_t vector) {
  *AT91C_AIC_ISCR = (1 << vector);
}

void nx_aic_clear(nx_aic_vector_t vector) {
  *AT91C_AIC_ICCR = (1 << vector);
}
#endif
