/** @file ht_compass.h
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

#ifndef __NXOS_HT_COMPASS_H__
#define __NXOS_HT_COMPASS_H__

#include "base/types.h"

/** @addtogroup driver */
/*@{*/

/** @defgroup ht_compass HiTechnic Compass driver
 *
 * The ht_compass driver provides a simple API to use a digital compass
 * from HiTechnic.
 */
/*@{*/

/** I2C address.
 */
#define HT_COMPASS_I2C_ADDRESS  0x01

/** Internal memory addresses.
 *
 * This enum contains the compass's internal memory addresses.
 */
typedef enum {
  HT_COMPASS_VERSION = 0, /* 8 Bytes */
  HT_COMPASS_MANUFACTURER = 0x08, /* 8 Bytes */
  HT_COMPASS_SENSOR_TYPE = 0x10, /* 8 Bytes */
  HT_COMPASS_MODE_CONTROL = 0x41,
  HT_COMPASS_HEADING_2DEGREE = 0x42,
  HT_COMPASS_HEADING_1DEGREE = 0x43,
  HT_COMPASS_HEADING_LOWHIGH = 0x44 /* 2 Bytes */
} ht_compass_memory_slot;

/** Initialize the compass on port @a sensor.
 *
 * @param sensor The sensor port number.
 */
void ht_compass_init(U32 sensor);

/** Close the link with the compass and disable the sensor.
 *
 * @param sensor The sensor port number.
 */
void ht_compass_close(U32 sensor);

/** Check the presence of a compass on port @a sensor.
 *
 * @param sensor The sensor port number.
 *
 * @note The device on port @a sensor first needs to be initialized with
 * ht_compass_init().
 *
 * @return True if a compass was found, false otherwise.
 */
bool ht_compass_detect(U32 sensor);

/** Read the heading in degrees (0-359).
 *
 * @param sensor The sensor port number.
 *
 * @return The heading in degrees (0-359).
 */
U16 ht_compass_read_heading(U32 sensor);

/** Display the compass's information.
 *
 * Displays on the NXT screen the compass's information, including the
 * manufacturer, sensor type, device version and heading.
 *
 * @param sensor The sensor port number.
 */
void ht_compass_info(U32 sensor);

/** About the calibration (quoted from HiTechnic):
 * To calibrate the compass under program control, select calibration mode
 * (...) and then program your robot to rotate (turn in a tight circle)
 * between 1.5 and 2 times (more than 360 degrees) so it completes a full turn
 * in about 20 seconds.  Once the turns have been completed, set [...]
 * and the compass will be calibrated.  The compass will retain the calibration
 * settings until another calibration is performed, even if it is unplugged.
 */

/** Starts calibration of the compass connected on port @a sensor.
 *
 * Instructs the compass to start the calibration.
 *
 * @param sensor The sensor port number.
 *
 * @return True if the calibration started successful, false otherwise.
 */
bool ht_compass_start_calibration(U32 sensor);

/** Stops calibration of the compass connected on port @a sensor.
 *
 * Instructs the compass to end the calibration.
 *
 * @param sensor The sensor port number.
 *
 * @return True if the calibration was successful, false otherwise.
 */
bool ht_compass_stop_calibration(U32 sensor);

/*@}*/
/*@}*/

#endif /* __NXOS_HT_COMPASS_H__ */
