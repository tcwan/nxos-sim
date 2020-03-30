/* Copyright (c) 2007,2008 the NxOS developers
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
#include "base/_display.h"
#include "base/assert.h"
#include "base/memmap.h"
#include "drivers/_aic.h"
#include "drivers/_systick.h"
#include "drivers/_sound.h"
#include "drivers/_lcd.h"

#include "base/_core.h"


/* main() is the entry point into the custom payload, not included in
 * the NxOS core.
 */
extern void main(void);
extern void main_entry(void);

/* Application kernels can register a shutdown handler, which we keep here. */
static nx_closure_t shutdown_handler = NULL;

static void core_init(void) {
  nx__aic_init();
  nx__systick_init();
  nx__sound_init();
  nx__lcd_init();
  nx__display_init();
  nx_interrupts_enable();		// We must call this once before passing control over to main() to enable interrupts

#ifndef __CPULATOR__
  /* Delay a little post-init, to let all the drivers settle down. */
  nx_systick_wait_ms(100);
#endif
}

#ifdef __DE1SOC__
/* Checks whether the system rebooted due to some kind of external
 * failure, and report if so.
 *
 * This is a dummy function in CPUlator
 */
static void check_boot_errors(void) {
	// Do nothing
}
#endif

#ifdef __LEGONXT__
/* Checks whether the system rebooted due to some kind of external
 * failure, and report if so.
 *
 * Currently detects brownout and watchdog resets.
 */
static void check_boot_errors(void) {
  int reset_status = *AT91C_RSTC_RSR;
  reset_status &= AT91C_RSTC_RSTTYP;

  /* A watchdog reset should never happen, given that we disable it
   * immediately at bootup. This is just a bug guard.
   */
  if (reset_status == AT91C_RSTC_RSTTYP_WATCHDOG) {
    NX_FAIL("**************\n"
	    "Watchdog fault\n"
	    "**************\n");
  } else if (reset_status == AT91C_RSTC_RSTTYP_BROWNOUT) {
    NX_FAIL("**************\n"
	    "Brownout fault\n"
	    "**************\n");
  }
}
#endif

void nx_core_halt(void) {
  if (shutdown_handler)
    shutdown_handler();
  nx__lcd_shutdown();
}

void nx_core_reset(void) {
  if (shutdown_handler)
    shutdown_handler();
  nx__lcd_shutdown();

#ifdef __DE1SOC__
  // FIXME: Halt the processor
  while (1);
#endif

#ifdef __LEGONXT__
  /* Total reset of the NXT's processor. */
  *AT91C_RSTC_RCR = 0xA5000005;
#endif
}

void nx_core_register_shutdown_handler(nx_closure_t handler) {
  shutdown_handler = handler;
}

void nx__kernel_main(void) {
  core_init();
  check_boot_errors();
#ifdef TEST_DBGBKPT
  dbg__test_arm_bkpt();                 /* Routine to trigger a manual ARM Breakpoint */
  dbg__test_thumb_bkpt();               /* Routine to trigger a manual Thumb Breakpoint */
#endif


#if __CPULATOR__
  // CPUlator defaults to start from main when loading a pre-compiled ELF executable, skipping the RESET handler call
  // This works around the problem by invoking nx_start() from main when program is started, and continuing with main_entry()
  main_entry();
#else
  main();
#endif

  if( NX_BOOT_FROM_ENH_FW )
    nx_core_reset();
  else
    nx_core_halt();
}
