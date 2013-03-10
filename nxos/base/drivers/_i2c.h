/** @file _i2c.h
 *  @brief i2c internal interface.
 */

/* Copyright (C) 2007-2013 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_DRIVERS__I2C_H__
#define __NXOS_BASE_DRIVERS__I2C_H__

#include "base/types.h"
#include "base/drivers/i2c.h"

/** @addtogroup driverinternal */
/*@{*/

/** @defgroup colorinternal Color interface */
/*@{*/

/** I2C bus control parameters.
 *
 * Note that in practice, on the bus, a RESTART is the same as a new
 * START bit (when running in normal bus mode).
 *
 * Pre (resp post) control values must only be used in pre_control
 * (resp post_control).
 */
typedef enum {
  I2C_CONTROL_NONE = 0,

  /* Pre control bits. */
  I2C_CONTROL_START,
  I2C_CONTROL_RESTART,

  /* Post control bits. */
  I2C_CONTROL_STOP,
} i2c_control;

/** Initialize the NXT to allow I2C communication.
 */
void nx__i2c_init(void);


/*@}*/
/*@}*/

#endif /* __NXOS_BASE_DRIVERS__I2C_H__ */
