/** @file ht_accel.h
 *  @brief HiTechnic Acceleration/Tilt Sensor driver.
 *
 * Driver for HiTechnic Acceleration/Tilt Sensor.
 */

/* Copyright (C) 2009 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_HT_ACCEL_H__
#define __NXOS_HT_ACCEL_H__

#include "base/types.h"

/** @addtogroup driver */
/*@{*/

/** @defgroup ht_accel HiTechnic Acceleration/Tilt Sensor driver
 *
 * The ht_accel driver provides a simple API to use an acceleration/tilt sensor
 * from HiTechnic.
 */
/*@{*/

/** I2C address.
 */
#define HT_ACCEL_I2C_ADDRESS  0x01

/** A type for the returned acceleration values */
typedef struct {
  S16 x;
  S16 y;
  S16 z;
} ht_accel_values;

/** Internal memory addresses.
 *
 * This enum contains the acceleration/tilt sensor's internal memory addresses.
 */
typedef enum {
  HT_ACCEL_VERSION = 0, /* 8 Bytes */
  HT_ACCEL_MANUFACTURER = 0x08, /* 8 Bytes */
  HT_ACCEL_SENSOR_TYPE = 0x10, /* 8 Bytes */
  HT_ACCEL_VALUES = 0x42 /* 6 Bytes */
} ht_accel_memory_slot;

/** Initialize the acceleration/tilt sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 */
void ht_accel_init(U32 sensor);

/** Close the link with the acceleration/tilt sensor and disable him.
 *
 * @param sensor The sensor port number.
 */
void ht_accel_close(U32 sensor);

/** Check the presence of an acceleration/tilt sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 *
 * @note The device on port @a sensor first needs to be initialized with
 * ht_accel_init().
 *
 * @return True if an acceleration/tilt sensor was found, false otherwise.
 */
bool ht_accel_detect(U32 sensor);

/** Read the heading in degrees (0-359).
 *
 * @param sensor The sensor port number.
 * @param values A pointer to an object of ht_accel_values where the
 *   readed values will be stored.
 *
 * @return True if values could be read, false otherwise.
 */
bool ht_accel_read_values(U32 sensor, ht_accel_values* values);

/** Display the acceleration/tilt sensor's information.
 *
 * Displays on the NXT screen the acceleration/tilt sensor's information, including the
 * manufacturer, sensor type, device version and acceleration values.
 *
 * @param sensor The sensor port number.
 */
void ht_accel_info(U32 sensor);

/*@}*/
/*@}*/

#endif /* __NXOS_HT_ACCEL_H__ */
