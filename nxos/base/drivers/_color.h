/** @file _color.h
 *  @brief Color internal interface.
 */

/* Copyright (C) 2007-2013 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_DRIVERS__COLOR_H__
#define __NXOS_BASE_DRIVERS__COLOR_H__

#include "base/types.h"
#include "base/drivers/color.h"

/** @addtogroup driverinternal */
/*@{*/

/** @defgroup colorinternal Color interface */
/*@{*/

/** Initialize the NXT to allow Color Sensor Support.
 */
void nx__color_init(void);

/** Get the actual configuration status of the LEGO Color Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 * *
 * @return Returns the actual status of the LEGO Color Sensor on the
 * given sensor port.
 */
color_status nx__color_update_status(U32 sensor);


/*@}*/
/*@}*/

#endif /* __NXOS_BASE_DRIVERS__COLOR_H__ */
