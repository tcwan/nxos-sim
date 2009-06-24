/** @file ht_accel.c
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

#include "base/display.h"
#include "base/util.h"
#include "base/drivers/i2c_memory.h"
#include "base/drivers/ht_accel.h"

/* The manufacturer. */
#define HT_ACCEL_MANUFACTURER_STR "HITECHNC"
/* The sensor type. */
#define HT_ACCEL_TYPE_STR "Accel.  "

/** Initializes the acceleration/tilt sensor.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_accel_init(U32 sensor) {
  nx_i2c_memory_init(sensor, HT_ACCEL_I2C_ADDRESS, FALSE);
}

/** Close the link to the acceleration/tilt sensor and disable the sensor port.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_accel_close(U32 sensor) {
  nx_i2c_memory_close(sensor);
}

/** Acceleration/Tilt Sensor detection.
 *
 * Tries to detect the presence of an acceleration/tilt sensor on the given port by
 * reading the device's manufacturer and sensor type and comparing it
 * to the defaults.
 *
 * @param sensor The sensor port number.
 *
 * @return True if an acceleration/tilt sensor was found.
 */
bool ht_accel_detect(U32 sensor) {
  U8 str[9];
  memset(str, 0, sizeof(str));
  if ( nx_i2c_memory_read(sensor, HT_ACCEL_MANUFACTURER, str, 8)
      != I2C_ERR_OK || ! streq((char *)str, HT_ACCEL_MANUFACTURER_STR) )
      return FALSE;
  memset(str, 0, sizeof(str));
  return nx_i2c_memory_read(sensor, HT_ACCEL_SENSOR_TYPE, str, 8)
      == I2C_ERR_OK && streq((char *)str, HT_ACCEL_TYPE_STR);
}

/** Read the acceleration/tilt-values.
 *
 * @param sensor The sensor port number.
 * @param values A pointer to an object of ht_accel_values where the
 *   readed values will be stored.
 *
 * @return True if the values could read.
 */
bool ht_accel_read_values(U32 sensor, ht_accel_values* values) {
  U8 buf[6];
  if( nx_i2c_memory_read(sensor, HT_ACCEL_VALUES, buf, 6) != I2C_ERR_OK )
    return FALSE;
  values->x = (((U16)buf[0])<<2) + buf[3];
  values->y = (((U16)buf[1])<<2) + buf[4];
  values->z = (((U16)buf[2])<<2) + buf[5];
  return TRUE;
}

/** Display connected acceleration/tilt sensor's information.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_accel_info(U32 sensor) {
  U8 buf[9];

  // Manufacturer (HITECHNC)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_ACCEL_MANUFACTURER, buf, 8);
  nx_display_string((char *)buf);
  nx_display_string(" ");

  // Sensor Type (Accel.)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_ACCEL_SENSOR_TYPE, buf, 8);
  nx_display_string((char *)buf);
//  nx_display_string(" ");

  // Version (V1.1)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_ACCEL_VERSION, buf, 8);
  nx_display_string((char *)buf);
  nx_display_end_line();

  ht_accel_values values;
  if ( ! ht_accel_read_values(sensor, &values) ) {
    nx_display_string("Error reading!");
    return;
  }
  nx_display_string("x: ");
  nx_display_uint(values.x);
  nx_display_end_line();
  nx_display_string("y: ");
  nx_display_uint(values.y);
  nx_display_end_line();
  nx_display_string("z: ");
  nx_display_uint(values.z);
  nx_display_end_line();
}
