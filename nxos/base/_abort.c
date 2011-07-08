/* Copyright (C) 2007 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#include "base/types.h"
#include "base/display.h"
#include "base/interrupts.h"
#include "base/drivers/_lcd.h"

#include "base/_abort.h"

void nx__abort_info(U32 data, U32 pc, U32 cpsr) {
  nx_interrupts_disable();
  nx_display_auto_refresh(FALSE);
  nx_display_clear();
  if (data == ABORT_ILLEGAL) {
    nx_display_string("Illegal");
  } else if (data == ABORT_SPURIOUS) {
    nx_display_string("Spurious");
  } else if (data) {
    nx_display_string("Data");
  } else {
    nx_display_string("Prefetch");
  }
  nx_display_string(" abort\nPC: 0x");
  nx_display_hex(pc);
  nx_display_string("\nCPSR: 0x");
  nx_display_hex(cpsr);
  nx__lcd_sync_refresh();
  nx_interrupts_enable();
}

void nx__abort(U32 data, U32 pc, U32 cpsr) {
  nx__abort_info(data, pc, cpsr);
  nx_interrupts_disable();
  while(1);
}
