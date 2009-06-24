/** @file ht_compass.c
 *  @brief HiTechnic Compass Sensor driver.
 *
 * Driver for HiTechnic compass.
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
#include "base/drivers/ht_compass.h"

/* The manufacturer. */
#define HT_COMPASS_MANUFACTURER_STR "HiTechnc"
/* The sensor type. */
#define HT_COMPASS_TYPE_STR "Compass "

/** Initializes the compass.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_compass_init(U32 sensor) {
  nx_i2c_memory_init(sensor, HT_COMPASS_I2C_ADDRESS, FALSE);
}

/** Close the compass and disable the sensor port.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_compass_close(U32 sensor) {
  nx_i2c_memory_close(sensor);
}

/** Compass detection.
 *
 * Tries to detect the presence of a compass on the given port by
 * reading the device's manufacturer and sensor type and comparing it
 * to the defaults.
 *
 * @param sensor The sensor port number.
 *
 * @return True if a compass was found.
 */
bool ht_compass_detect(U32 sensor) {
  U8 str[9];
  memset(str, 0, sizeof(str));
  if ( nx_i2c_memory_read(sensor, HT_COMPASS_MANUFACTURER, str, 8)
      != I2C_ERR_OK || ! streq((char *)str, HT_COMPASS_MANUFACTURER_STR) )
      return FALSE;
  memset(str, 0, sizeof(str));
  return nx_i2c_memory_read(sensor, HT_COMPASS_SENSOR_TYPE, str, 8)
      == I2C_ERR_OK && streq((char *)str, HT_COMPASS_TYPE_STR);
}

/** Read the heading in degrees.
 *
 * @param sensor The sensor port number.
 *
 * @return The heading in degrees.
 */
U16 ht_compass_read_heading(U32 sensor) {
/*
  U8 heading[2] = {0, 0};
  nx_i2c_memory_read(sensor, HT_COMPASS_HEADING_2DEGREE, heading, 2);
  // Heading = (two degree heading *2) + one degree adder.
  return ((U16)(heading[0])<<1) + heading[1];
*/
  U16 heading = 0;
  nx_i2c_memory_read(sensor, HT_COMPASS_HEADING_LOWHIGH, (U8*)&heading, 2);
  return heading;
}

/** Starts calibration of the compass connected on port @a sensor.
 *
 * Instructs the compass to start calibration.
 *
 * @param sensor The sensor port number.
 *
 * @return True if the calibration was started, false otherwise.
 */
bool ht_compass_start_calibration(U32 sensor) {
  if ( nx_i2c_busy(sensor) )
    return FALSE;

  U8 cmd = 0x43; /* enter hard-iron calibrate mode */
  return nx_i2c_memory_write(sensor, HT_COMPASS_MODE_CONTROL, &cmd, 1)
    == I2C_ERR_OK;
}

/** Stop calibration of the compass connected on port @a sensor.
 *
 * Instructs the compass to stop calibration and checks if
 * calibration was successful.
 *
 * @param sensor The sensor port number.
 *
 * @return True if the calibration was successful, false otherwise.
 */
bool ht_compass_stop_calibration(U32 sensor) {
  if ( nx_i2c_busy(sensor) )
    return FALSE;

  U8 cmd = 0x00; /* enter measurement mode */
  if(nx_i2c_memory_write(sensor, HT_COMPASS_MODE_CONTROL, &cmd, 1)
    != I2C_ERR_OK )
    return FALSE;

  /* If the calibration failed, the register contains a 2 instead of 0 */
  return nx_i2c_memory_read(sensor, HT_COMPASS_MODE_CONTROL, &cmd, 1)
      == I2C_ERR_OK && ! cmd;
}

/** Display connected compass's information.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_compass_info(U32 sensor) {
  U8 buf[9];

  // Manufacturer (HiTechnc)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_COMPASS_MANUFACTURER, buf, 8);
  nx_display_string((char *)buf);
  nx_display_string(" ");

  // Sensor Type (Compass)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_COMPASS_SENSOR_TYPE, buf, 8);
  nx_display_string((char *)buf);
//  nx_display_string(" ");

  // Version (V1.27)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_COMPASS_VERSION, buf, 8);
  nx_display_string((char *)buf);
  nx_display_end_line();

  // Heading
  nx_display_string("Heading: ");
  nx_display_uint(ht_compass_read_heading(sensor));
  nx_display_end_line();
}
