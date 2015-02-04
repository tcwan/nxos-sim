/** @file ht_accel.h
 *  @brief HiTechnic Color Sensor driver.
 *
 * Driver for HiTechnic Color Sensor.
 */

/* Copyright (C) 2009-2013 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_HT_COLOR_H__
#define __NXOS_HT_COLOR_H__

#include "base/types.h"

/** @addtogroup driver */
/*@{*/

/** @defgroup ht_color HiTechnic Color Sensor driver
 *
 * The ht_color driver provides a simple API to use a Color sensor
 * from HiTechnic.
 */
/*@{*/

/** I2C address.
 */
#define HT_COLOR_I2C_ADDRESS  0x01

/** HT Color Sensor Color Calibration Magic Numbers
 */
/** WHite Point Calibration */
#define HT_COLOR_CAL_WHITEPOINT 0x43
/** Black Point Calibration */
#define HT_COLOR_CAL_BLACKPOINT 0x42

/** A type for the returned color values (8 bit)*/
typedef struct {
  /** color number 0: Black, ..., 17: White */
  U8 colornum;
  /** red channel value */
  U8 redval;
  /** green channel value */
  U8 greenval;
  /** blue channel value */
  U8 blueval;
} ht_color_values;

/** Internal memory addresses.
 *
 * This enum contains the color sensor's internal memory addresses.
 */
typedef enum {
  HT_COLOR_VERSION = 0, /* 8 Bytes */
  HT_COLOR_MANUFACTURER = 0x08, /* 8 Bytes */
  HT_COLOR_SENSOR_TYPE = 0x10, /* 8 Bytes */
  HT_COLOR_COMMAND = 0x41, /* 1 Byte (Reserved) */
  HT_COLOR_VALUES = 0x42 /* 4 Bytes */
} ht_color_memory_slot;

/** Initialize the color sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 */
void ht_color_init(U32 sensor);

/** Close the link with the color sensor and disable him.
 *
 * @param sensor The sensor port number.
 */
void ht_color_close(U32 sensor);

/** Check the presence of an color sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 *
 * @note The device on port @a sensor first needs to be initialized with
 * ht_color_init().
 *
 * @return True if an color sensor was found, false otherwise.
 */
bool ht_color_detect(U32 sensor);

/** Read the color values.
 *
 * @param sensor The sensor port number.
 * @param values A pointer to an object of ht_color_values where the
 *   read values will be stored.
 *
 * @return True if values could be read, false otherwise.
 */
bool ht_color_read_values(U32 sensor, ht_color_values* values);

/** Display the color sensor's information.
 *
 * Displays on the NXT screen the color sensor's information, including the
 * manufacturer, sensor type, device version and acceleration values.
 *
 * @param sensor The sensor port number.
 */
void ht_color_info(U32 sensor);

/*@}*/
/*@}*/

#endif /* __NXOS_HT_COLOR_H__ */
