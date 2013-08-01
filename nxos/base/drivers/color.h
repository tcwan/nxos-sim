/** @file color.h
 *  @brief LEGO Color Sensor SoftMAC driver.
 *
 * Hybrid Sensor communication protocol implementation.
 */

/* Copyright (C) 2007-2013 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_COLOR_H__
#define __NXOS_COLOR_H__

#include "base/types.h"

/** @addtogroup driver */
/*@{*/

/** @defgroup color Lego Color Sensor SoftMAC driver
 *
 * The Color Sensor SoftMAC driver controls the LEGO Color Sensor over the NXT sensor
 * ports.
 */
/*@{*/

#if 0

/** Transaction mode definitions. */
typedef enum
{
  TXN_MODE_WRITE = 0,
  TXN_MODE_READ,
  TXN_MODE_COUNT,
} i2c_txn_mode;
#endif

/** Color Detected enums. */
typedef enum
{
  COLOR_DETECT_UNKNOWN = 0,
  COLOR_DETECT_BLACK,
  COLOR_DETECT_BLUE,
  COLOR_DETECT_GREEN,
  COLOR_DETECT_YELLOW,
  COLOR_DETECT_RED,
  COLOR_DETECT_WHITE,
  NO_OF_DETECTED_COLORS,
} color_detected;

/** Color Sensor mode. */
typedef enum
{
  COLOR_MODE_NONE = 0,
  COLOR_MODE_FULL,
  COLOR_MODE_RED,
  COLOR_MODE_GREEN,
  COLOR_MODE_BLUE,

  COLOR_NUM_MODES,
} color_mode;

/** Color Sensor status. */
typedef enum
{
  COLOR_NOTFOUND = 0,
  COLOR_CALIBRATE,
  COLOR_READY,
  COLOR_EXIT,
} color_status;

/** Color Sensor config.
 *
 * These parameters are configuration requests to the actual SoftMAC driver
 *
 * mode	Color sensing mode (NONE, FULL, RED, GREEN, BLUE)
 * statereq  Color sensor state request
 */
typedef struct {
	color_mode mode;		/**< Color Sensor LED mode */
	color_status statereq;	/**< Color Sensor state request */
} color_config;

/** Color Sensor calibration point enums. */
typedef enum
{
	CAL_POINT0 = 0,
	CAL_POINT1,
	CAL_POINT2,
	NO_OF_CALPOINTS
} calibration_points;

/** Color Sensor data structure enums. */
typedef enum
{
	COLOR_NONE = 0,
	COLOR_RED,
	COLOR_GREEN,
	COLOR_BLUE,
	NO_OF_COLOR_CHANNELS
} color_struct_colors;

/** Color Sensor calibration data structure.
 *
 * Returned by the LEGO Color Sensor
 *
 */
typedef struct {
    U32 calibration[NO_OF_CALPOINTS][NO_OF_COLOR_CHANNELS];	/**< 3 Cal Points x 4 Cal Colors = 12 32-bit values */
    U16 calibration_limits[NO_OF_CALPOINTS - 1];			/**< 2 16-bit cal limits */
} color_cal_data;

/** Color Sensor A/D values data structure.
 *
 * Read from LEGO Color Sensor
 *
 * @note The raw values are not scaled. Scaled valued are obtained via nx_color_scale_input()
 */
typedef struct {
    U32 colorval[NO_OF_COLOR_CHANNELS];						/**< 4 32-bit Colors (10 bit significance) */
} color_values;

/** Initialize a LEGO Color Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 * @param mode   The color sensing mode (NONE, FULL, RED, GREEN, BLUE)
 * @param caldata Calibration data pointer (must be pre-allocated)
 *
 * @note If no Color Sensor device were registered, a call to nx_color_init()
 * will enable the Color isr.
 */
void nx_color_init(U32 sensor, color_mode mode, color_cal_data *caldata);

/** Close the link to the color sensor and disable the color sensor on on port @a sensor.
 *
 * @param sensor The sensor port number.
 *
 * @note If you're unregistering the last Color Sensor device, the Color isr will be
 * disabled until another device is registered.
 */
void nx_color_close(U32 sensor);

/** Check the presence and status of a lego color sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 *
 * @note The device on port @a sensor first needs to be initialized with
 * nx_color_init().
 *
 * @return color_status of lego color sensor.
 */
color_status nx_color_detect(U32 sensor);

/** Recalibrate the color sensor connected on port @a sensor.
 *
 * Recalibrate the color sensor configuration.
 *
 * @param sensor The sensor port number.
 * @param mode   The color sensing mode (NONE, FULL, RED, GREEN, BLUE)
 */
void nx_color_reset(U32 sensor, color_mode mode);

/** Display the color sensor's information.
 *
 * Displays on the NXT screen the color sensor's color mode and calibration information.
 *
 * @param sensor The sensor port number.
 */
void nx_color_info(U32 sensor);

/** Get the current LED mode of the LEGO Color Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 * *
 * @return Returns the mode of the LEGO Color Sensor on the
 * given sensor port.
 */
color_mode nx_color_get_mode(U32 sensor);

/** Get the current (user) requested state of the LEGO Color Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 * *
 * @return Returns the (user) requested state of the LEGO Color Sensor on the
 * given sensor port.
 */
color_status nx_color_get_statereq(U32 sensor);

/** Get the current status of the LEGO Color Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 * *
 * @return Returns the actual status of the LEGO Color Sensor on the
 * given sensor port.
 */
color_status nx_color_get_status(U32 sensor);

/** Read all color sensor raw values
 *
 *  The color_values structure contain all channels (RED, GREEN, BLUE, NONE) regardless of
 *  the color_mode setting. Only the values for the active color_mode are valid.
 *
 *    Note: The values are only updated once every 3 ms
 *
 * @param sensor The sensor port number.
 * @param rawvalues A pointer to an object of color_values where the
 *   read values will be stored.
 *
 * @return True if values could be read, false otherwise (e.g., in Calibration mode).
 */
bool nx_color_read_all_raw(U32 sensor, color_values* rawvalues);

/** Read color sensor raw value for given mode
 *
 *  Return the raw value for the given color_mode.
 *  Only the value for the active color_mode are valid.
 *  For COLOR_MODE_FULL, the value for NONE is returned.
 *
 *    Note: The values are only updated once every 3 ms
 *
 * @param sensor The sensor port number.
 *
 * @returns 0 value if values cannot be read (e.g., in Calibration mode).
 */
U32 nx_color_read_mode_raw(U32 sensor);

/** Scale Raw Color Inputs to full ADC range.
 *
 * @param rawvalue Raw Color Value from ADC (unscaled).
 *
 */
U32 nx_color_scale_input(U32 rawvalue);

/** Classify color given raw inputs
 *
 *  Return the classified color enum for the given raw inputs.
 *  The color mode is assumed to be COLOR_MODE_FULL as all
 *  channels are used for the detection.
 *
 * @param rawvalues A pointer to an object of color_values where the
 *   uncalibrated read values will be stored.
 *   NOTE: The values will be modified if color calibration desired
 *         (i.e., caldata is not NULL)
 *
 * @param caldata A pointer to the calibration data for the color sensor.
 *                NULL means that no calibration is required.
 *
 * @returns COLOR_DETECT_UNKNOWN if color is not recognized
 */
color_detected nx_color_classifier(color_values* rawvalues, color_cal_data *caldata);

/** Convert detected color to string for display
 *
 * @param thecolor	color_detected enum
 *
 * @returns	The detected color string for the given enum.
 */
char *nx_color2str(color_detected thecolor);

/*@}*/
/*@}*/

#endif
