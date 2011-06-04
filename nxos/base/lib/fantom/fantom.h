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
 * @param msgPtr Received/Reply message pointer
 * @param lenPtr Received/Reply message length pointer
 * @param isBTComms True if Bluetooth Comms used
 * @param isrReturnAddress Address of Instruction interrupted by IRQ
 * @return True: packet filtered, False: Not a Fantom Packet.
 *
 * If False, msgPtr and lenPtr unchanged.
 * If True, msgPtr and lenPtr will indicate reply if *lenPtr > 0
 */
bool fantom_filter_packet(U8 **msgPtr, U32 *lenPtr, bool isBTComms);

/*@}*/
/*@}*/

#endif /* __NXOS_BASE_LIB_FANTOM_H__ */
