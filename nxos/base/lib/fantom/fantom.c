/* Copyright (C) 2007 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#include "base/at91sam7s256.h"

#include "base/types.h"
#include "base/interrupts.h"
#include "base/assert.h"
#include "base/drivers/systick.h"
#include "base/drivers/aic.h"
#include "base/util.h"

#include "base/lib/fantom/fantom.h"

/* Filter Fantom related traffic (queries, GDB protocol) */
bool fantom_filter_packet(U8 *data, U32 dataLen, U8 **reply, U32 *replyLen)
{
  /* WARNING: This routine is called from the ISR.
   * Consequently, the amount of processing done here must be as little as possible.
   * Otherwise it'll severely impact the ISR response time.
   *
   * This routine handles the Fantom Version Inquiry Packet
   * As well as trap GDB remote protocol
   */
  if (dataLen == 0)
    data[0] = '\0';
  *reply = NULL;
  *replyLen = 0;
  return FALSE;
}
