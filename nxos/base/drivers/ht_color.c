/** @file ht_accel.c
 *  @brief HiTechnic Color Sensor driver.
 *
 * Driver for HiTechnic Color Sensor.
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
#include "base/drivers/ht_color.h"

/* The manufacturer. */
#define HT_COLOR_MANUFACTURER_STR "HiTechnc"
/* The sensor type. */
#define HT_COLOR_TYPE_STR "ColorPD "

/** Initializes the color sensor.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_color_init(U32 sensor) {
  nx_i2c_memory_init(sensor, HT_COLOR_I2C_ADDRESS, FALSE);
}

/** Close the link to the color sensor and disable the sensor port.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_color_close(U32 sensor) {
  nx_i2c_memory_close(sensor);
}

/** color Sensor detection.
 *
 * Tries to detect the presence of an color sensor on the given port by
 * reading the device's manufacturer and sensor type and comparing it
 * to the defaults.
 *
 * @param sensor The sensor port number.
 *
 * @return True if an color sensor was found.
 */
bool ht_color_detect(U32 sensor) {
  U8 str[9];
  memset(str, 0, sizeof(str));

  #if 0
  nx_i2c_memory_read(sensor, HT_COLOR_MANUFACTURER, str, 8);
  if (streq((char *)str, HT_COLOR_MANUFACTURER_STR))
	  nx_display_string("Manuf. Matched!\n");
  memset(str, 0, sizeof(str));
  nx_i2c_memory_read(sensor, HT_COLOR_SENSOR_TYPE, str, 8);
  if (streq((char *)str, HT_COLOR_TYPE_STR))
	  nx_display_string("Type Matched!\n");

  return TRUE;
#else
  if ( nx_i2c_memory_read(sensor, HT_COLOR_MANUFACTURER, str, 8)
      != I2C_ERR_OK || ! streq((char *)str, HT_COLOR_MANUFACTURER_STR) )
      return FALSE;
  memset(str, 0, sizeof(str));
  return nx_i2c_memory_read(sensor, HT_COLOR_SENSOR_TYPE, str, 8)
      == I2C_ERR_OK && streq((char *)str, HT_COLOR_TYPE_STR);
#endif
}


/** Read the color-values.
 *
 * @param sensor The sensor port number.
 * @param values A pointer to an object of ht_color_values where the
 *   read values will be stored.
 *
 * @return True if the values could be read.
 */
bool ht_color_read_values(U32 sensor, ht_color_values* values) {
  U8 buf[4];
  if( nx_i2c_memory_read(sensor, HT_COLOR_VALUES, buf, 4) != I2C_ERR_OK )
    return FALSE;
  values->colornum = buf[0];	/* The raw value needs to be scaled */
  values->redval   = buf[1];
  values->greenval = buf[2];
  values->blueval  = buf[3];
  return TRUE;
}

/** Display connected color sensor's information.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_color_info(U32 sensor) {
  U8 buf[9];

  // Manufacturer (HITECHNC)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_COLOR_MANUFACTURER, buf, 8);
  nx_display_string((char *)buf);
  nx_display_string(" ");

  // Sensor Type (ColorPD)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_COLOR_SENSOR_TYPE, buf, 8);
  nx_display_string((char *)buf);
//  nx_display_string(" ");

  // Version (V1.5)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_COLOR_VERSION, buf, 8);
  nx_display_string((char *)buf);
  nx_display_end_line();

  ht_color_values values;
  if ( ! ht_color_read_values(sensor, &values) ) {
    nx_display_string("Error reading!");
    return;
  }
  nx_display_cursor_set_pos(0, 5);
  nx_display_string("#: ");
  nx_display_int(values.colornum);
  nx_display_string("      ");
  nx_display_cursor_set_pos(9, 5);
  nx_display_string("R: ");
  nx_display_int(values.redval);
  nx_display_string("      ");
  nx_display_cursor_set_pos(0, 6);
  nx_display_string("G: ");
  nx_display_int(values.greenval);
  nx_display_string("      ");
  nx_display_cursor_set_pos(9, 6);
  nx_display_string("B: ");
  nx_display_int(values.blueval);
  nx_display_string("      ");
  nx_display_end_line();
}
