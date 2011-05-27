/** @file fantom.h
 *  @brief Fantom Communications Protocol support.
 */

/* Copyright (c) 2007-2011 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_LIB_FANTOM_H__
#define __NXOS_BASE_LIB_FANTOM_H__

#include "base/types.h"

/** @addtogroup lib */
/*@{*/

/** @defgroup fantom Fantom Communications Protcol Support
 *
 * The Fantom Communications Protocol library interfaces between the PC Host
 * and the NXT brick running NxOS for remote debugging suppport.
 * Only critical handshaking protcol messages are supported.
 */
/*@{*/

/** Filter Fantom related traffic (queries, GDB protocol).
 *
 * @param data The received message
 * @param dataLen Length of the received message
 * @param reply Pointer to reply message
 * @param replyLen Length of the reply message
 * @return True: packet filtered, False: Not a Fantom Packet.
 */
bool fantom_filter_packet(U8 *data, U32 dataLen, U8 **reply, U32 *replyLen);

/*@}*/
/*@}*/

#endif /* __NXOS_BASE_LIB_FANTOM_H__ */
