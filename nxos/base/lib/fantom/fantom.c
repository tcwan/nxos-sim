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
#include "armdebug/Debugger/debug_stub.h"

/* Fantom Version System Command */
#define SYSCMD_MSGTYPE 0x01
#define SYSCMD_VERSIONQUERY_LEN 2
static U8 SysCmd_VersionQuery[2] = { SYSCMD_MSGTYPE, 0x88 };
#define SYSCMD_VERSIONRESPONSE_LEN 7
static U8 SysCmd_VersionResponse[7] = { 0x02, 0x88, 0x00, 0x7C, 0x01, 0x1C, 0x01 };

/* GDB Protcol Message Type */
#define GDB_PROTO_MSGTYPE 0x8d		/* Defined here to avoid including debug_internals.h */

/* Filter Fantom related traffic (queries, GDB protocol) */
bool fantom_filter_packet(U8 *data, U32 dataLen, U8 **reply, U32 *replyLen, bool isBTComms)
{
  /* WARNING: This routine is called from the ISR.
   * Consequently, the amount of processing done here must be as little as possible.
   * Otherwise it'll severely impact the ISR response time.
   *
   * This routine handles the Fantom Version Query Packet
   * As well as trap GDB remote protocol
   */

	bool status = FALSE;
	comm_chan_t comms;

	*reply = NULL;
	*replyLen = 0;
	if (dataLen == 0)
		return status;

	switch (data[0]) {
	case SYSCMD_MSGTYPE:
		if ((dataLen == 2) && (data[1] == SysCmd_VersionQuery[1])) {
			*reply = SysCmd_VersionResponse;
			*replyLen = SYSCMD_VERSIONRESPONSE_LEN;
			status = TRUE;
		}
		break;

	case GDB_PROTO_MSGTYPE:
		comms = isBTComms ? COMM_BT : COMM_USB;
		status = nxos__handleDebug(data, comms, dataLen);
		break;

	default:
		break;
	}
	return status;
}
