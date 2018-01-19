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


/* Fantom Message Types */
#define DIRECTCMD_MSGTYPE 0x00
#define SYSTEMCMD_MSGTYPE 0x01
#define REPLYCMD_MSGTYPE 0x02

/* Fantom Version System Command */
#define SYSCMD_VERSIONQUERY_LEN 2
static U8 SysCmd_VersionQuery[SYSCMD_VERSIONQUERY_LEN] = { SYSTEMCMD_MSGTYPE, 0x88 };
#define SYSCMD_VERSIONRESPONSE_LEN 7
/* FIXME: The following contains dummy data */
static U8 SysCmd_VersionResponse[SYSCMD_VERSIONRESPONSE_LEN] = { REPLYCMD_MSGTYPE, 0x88, 0x00,
      0x81, 0x01, /* Protocol Version: Minor (use 129+ for NxOS), Major (must be 1 for Fantom support) v.1.129 */
      0x81, 0x01  /* Firmware Version: Minor (use 129+ for NxOS), Major (must be 1 for Fantom support) v.1.129 */
};

/* Fantom Get Info System Command */
#define SYSCMD_GETINFOQUERY_LEN 2
static U8 SysCmd_GetInfoQuery[SYSCMD_GETINFOQUERY_LEN] = { SYSTEMCMD_MSGTYPE, 0x9B };
#define SYSCMD_GETINFORESPONSE_LEN 33
/* FIXME: The following contains dummy data */
static U8 SysCmd_GetInfoResponse[SYSCMD_GETINFORESPONSE_LEN] = { REPLYCMD_MSGTYPE, 0x9B, 0x00,
       0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* NXT Name: 14 + ASCIIZ */
       0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, /* BT Address: 7 bytes */
       0x00, 0x00, 0x00, 0x00, /* BT Signal Strength: U32 (Little Endian) */
       0x00, 0x00, 0x00, 0x00  /* Available Flash Size: U32 (Little Endian) */
};

static U8 fantombuf[NX_USB_PACKET_SIZE];

void fantom_init(void)
{
	/* Setup for USB */
	nx_usb_fantom_read(fantombuf, NX_USB_PACKET_SIZE);

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

	bool status = FALSE;

	// Dummy conditional test
	if (isBTComms)
		status = FALSE;		/* needed to stop compiler complaints about unused variable */

	if (*lenPtr == 0)
		return status;

	switch ((*msgPtr)[0]) {
	case SYSTEMCMD_MSGTYPE:
		if (*lenPtr == 2) {
                    if ((*msgPtr)[1] == SysCmd_VersionQuery[1]) {
                      *msgPtr = SysCmd_VersionResponse;
                      *lenPtr = SYSCMD_VERSIONRESPONSE_LEN;
                      status = TRUE;
                    } else if ((*msgPtr)[1] == SysCmd_GetInfoQuery[1]) {
                      *msgPtr = SysCmd_GetInfoResponse;
                      *lenPtr = SYSCMD_GETINFORESPONSE_LEN;
                      status = TRUE;
                    }
		}

		if (TRUE == status) {
                    /* fantom command processed: reset fantom_message buffer, reenable EP1 */
                    nx_usb_fantom_read(NULL, 0);
		}

		break;
#ifdef __DBGENABLE__
	/* WARNING: This assumes that any message matching the NXT_GDBMSG_TELEGRAMTYPE header is a GDB message packet.
	 * It will break any user data transmission containing such a packet starting byte in its data stream.
	 */
	case NXT_GDBMSG_TELEGRAMTYPE:
		nxos__handleDebug(*msgPtr, (isBTComms ? COMM_BT : COMM_USB), *lenPtr);
		/* Returned status ignored, since we don't want it to propagate up to caller */
                nx_usb_fantom_read(NULL, 0);
                status = TRUE;
		/* Fall through */
                __attribute__ ((fallthrough));	// GCC 7 warning fix
#endif
	default:
		*msgPtr = NULL;
		*lenPtr = 0;
		break;
	}
	return status;
}

