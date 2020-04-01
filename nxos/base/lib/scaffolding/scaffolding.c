/* Copyright (C) 2007-2011 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */


/* Override extern declaration in header */
#ifdef FUNCDEF
#undef FUNCDEF
#endif
#define FUNCDEF

/* Include as necessary */
#include "base/types.h"
#include "base/core.h"
#include "base/drivers/systick.h"
#include "base/drivers/button.h"
#include "base/display.h"
#include "base/lib/alerts/alerts.h"

#include "scaffolding.h"

static bool audible = TRUE;

/* Internal Routines */

/** Security hook. A press on Cancel will unconditionally halt the brick.
 */
static void watchdog(void) {
#if 0
	// FIXME
 if (nx_avr_get_button() == BUTTON_CANCEL)
    nx_core_halt();
#endif
}

/* Public Routines */

FUNCDEF void nx_proginit(void) {
  /* Program Initialization Routine */
  nx_systick_install_scheduler(watchdog);
  hello_alert(audible);
}

FUNCDEF void nx_progshutdown(void) {
  /* Program Initialization Routine */
  goodbye_alert(audible);
}

FUNCDEF void nx_progtitle(char *string) {
  /* Display Title string on LCD Screen */
  nx_display_clear();
  nx_display_cursor_set_pos(0, 0);
  nx_display_string(string);

}

FUNCDEF void nx_progcontent(char *string) {
  /* Display Content string on LCD Screen */
  nx_display_cursor_set_pos(0, 2);
  nx_display_string(string);

}

FUNCDEF void nx_progcontent2(char *string) {
  /* Display Content string on LCD Screen */
  nx_display_cursor_set_pos(0, 4);
  nx_display_string(string);

}

FUNCDEF void nx_progcontentX(char *string, int row) {
  /* Display Content string on LCD Screen */
  nx_display_cursor_set_pos(0, row);
  nx_display_string(string);

}

FUNCDEF nx_button_t nx_getbutton(void) {
	/* Retrieve enum value of DE1 Button press */
	return nx_de1_get_button();
}
