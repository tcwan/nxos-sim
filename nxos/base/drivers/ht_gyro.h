/** @file ht_gyro.h
 *  @brief HiTechnic Gyro Sensor driver.
 *
 * Driver for HiTechnic Gyro Sensor.
 */

/* Copyright (C) 2009 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_HT_GYRO_H__
#define __NXOS_HT_GYRO_H__

#include "base/types.h"
#include "base/drivers/sensors.h"
#include "base/display.h"
#include "base/drivers/systick.h"

/** @addtogroup driver */
/*@{*/

/** @defgroup ht_gyro HiTechnic Gyro Sensor driver
 *
 * The ht_gyro driver provides a simple API to use a gyro sensor
 * from HiTechnic.
 */
/*@{*/

/** Initialize the gyro sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 */
inline void ht_gyro_init(U32 sensor);
inline void ht_gyro_init(U32 sensor) {
  nx_sensors_analog_enable(sensor);
}

/** Close the link with the gyro sensor.
 *
 * @param sensor The sensor port number.
 */
inline void ht_gyro_close(U32 sensor);
inline void ht_gyro_close(U32 sensor) {
  nx_sensors_analog_disable(sensor);
}

/** Read the rotation in degrees per second of rotation.
 *
 * @param sensor The sensor port number.
 *
 * @return The rotation in degrees per second of rotation. The axis of
 *   measurement is in the vertical plane with the gyro sensor positioned
 *   with the black end cap facing upwards. The rotation rate can be read up
 *   to approximately 300 times per second. The zero-point must be
 *   calculated while the sensor stands still (zero is around 600).
 */
inline U32 ht_gyro_get_value(U32 sensor);
inline U32 ht_gyro_get_value(U32 sensor) {
  return nx_sensors_analog_get(sensor);
}

/** Calculate the zero-point as an average of 8 values.
 *
 * @param sensor The sensor port number.
 *
 * @return The calculated zero-point.
 *
 * @note The sensor must stand still while the zero-point is calculated.
 *   This function needs 32ms to calculate the zero-point.
 *
 */
inline U32 ht_gyro_calculate_average_zero(U32 sensor);
inline U32 ht_gyro_calculate_average_zero(U32 sensor) {
  U32 zero = 0;
  for(U32 i = 0; i < 8; ++i) {
    zero += ht_gyro_get_value(sensor);
    nx_systick_wait_ms(4);
  }
  return zero>>3; /* = /8 */
}

/** Display the gyro sensor's information.
 *
 * Displays on the NXT screen the gyro sensor's information.
 *
 * @param sensor The sensor port number.
 */
inline void ht_gyro_info(U32 sensor);
inline void ht_gyro_info(U32 sensor) {
  nx_display_uint(ht_gyro_get_value(sensor));
  nx_display_end_line();
}

/*@}*/
/*@}*/

#endif /* __NXOS_HT_GYRO_H__ */
