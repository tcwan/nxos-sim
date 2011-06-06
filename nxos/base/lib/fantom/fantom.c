/* Copyright (C) 2007 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#include "base/at91sam7s256.h"

#include "base/types.h"
#include "base/assert.h"
#include "base/util.h"

#include "base/drivers/usb.h"

#include "base/lib/fantom/fantom.h"

#ifdef __DBGENABLE__
#include "armdebug/Debugger/debug_stub.h"
#include "armdebug/Debugger/debug_internals.h"
#endif

/* Fantom Version System Command */
#define SYSCMD_MSGTYPE 0x01
#define SYSCMD_VERSIONQUERY_LEN 2
static U8 SysCmd_VersionQuery[SYSCMD_VERSIONQUERY_LEN] = { SYSCMD_MSGTYPE, 0x88 };
#define SYSCMD_VERSIONRESPONSE_LEN 7
static U8 SysCmd_VersionResponse[SYSCMD_VERSIONRESPONSE_LEN] = { 0x02, 0x88, 0x00, 0x7C, 0x01, 0x1C, 0x01 };



void fantom_init(U8 *fantom_msg, U32 size)
{
	/* Setup for USB */
	nx_usb_fantom_read(fantom_msg, size);

	/* TODO: Setup for Bluetooth */
}

/* Filter Fantom related traffic (queries, GDB protocol) */
bool fantom_filter_packet(U8 **msgPtr, U32 *lenPtr, bool isBTComms)
{
  /* WARNING: This routine is called from the ISR.
   * Consequently, the amount of processing done here must be as little as possible.
   * Otherwise it'll severely impact the ISR response time.
   *
   * This routine handles the Fantom Version Query Packet
   * As well as trap GDB remote protocol
   */

	bool status = (isBTComms != isBTComms);	/* FALSE: needed to stop compiler complaints about unused variable */

	if (*lenPtr == 0)
		return status;

	switch ((*msgPtr)[0]) {
	case SYSCMD_MSGTYPE:
		if ((*lenPtr == 2) && ((*msgPtr)[1] == SysCmd_VersionQuery[1])) {
			*msgPtr = SysCmd_VersionResponse;
			*lenPtr = SYSCMD_VERSIONRESPONSE_LEN;
                        /* fantom command processed: reset fantom_message buffer, reenable EP1 */
			nx_usb_fantom_read(NULL, 0);
			status = TRUE;
		}
		break;
#ifdef __DBGENABLE__
	/* WARNING: This assumes that any message matching the NXT_GDBMSG_TELEGRAMTYPE header is a GDB message packet.
	 * It will break any user data transmission containing such a packet starting byte in its data stream.
	 */
	case NXT_GDBMSG_TELEGRAMTYPE:
		nxos__handleDebug(*msgPtr, (isBTComms ? COMM_BT : COMM_USB), *lenPtr);
		/* Returned status ignored, since we don't want it to propagate up to caller */
                status = TRUE;
		/* Fall through */
#endif
	default:
		*msgPtr = NULL;
		*lenPtr = 0;
		break;
	}
	return status;
}
