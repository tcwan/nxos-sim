/** @file alerts.h
 *  @brief Generate default audio alerts
 */

/* Copyright (c) 2007-2011 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_LIB_ALERTS_H__
#define __NXOS_BASE_LIB_ALERTS_H__

#include "base/types.h"

/** @addtogroup lib */
/*@{*/

/** @defgroup alerts Alert Sounds
 *
 * The Alerts library generate audio tones that can be used to indicate
 * system startup and shutdown.
 */
/*@{*/

/** Hello (startup) tone sequence
 *
 * @param audible: True for alert sequence to be generated
 * @return None
 *
 * The boolean parameter can be used to enable/disable alert
 * tone generation in the calling program
 */
void hello_alert(bool audible);

/** Goodbye (shutdown) tone sequence
 *
 * @param audible: True for alert sequence to be generated
 * @return None
 * The boolean parameter can be used to enable/disable alert
 * tone generation in the calling program
 */
void goodbye_alert(bool audible);

/*@}*/
/*@}*/

#endif /* __NXOS_BASE_LIB_FANTOM_H__ */
