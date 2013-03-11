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

/** @defgroup color color sensor SoftMAC driver
 *
 * The Color Sensor SoftMAC driver controls the LEGO Color Sensor over the NXT sensor
 * ports.
 */
/*@{*/

#if 0
/** Maximum transmitable data size. */
#define I2C_MAX_DATA_SIZE 16

/** I2C return codes. */
typedef enum {
  I2C_ERR_OK = 0,
  I2C_ERR_UNKNOWN_SENSOR,
  I2C_ERR_NOT_READY,
  I2C_ERR_TXN_FULL,
  I2C_ERR_DATA,
} i2c_txn_err;

/** Transaction mode definitions. */
typedef enum
{
  TXN_MODE_WRITE = 0,
  TXN_MODE_READ,
  TXN_MODE_COUNT,
} i2c_txn_mode;
#endif

/** Color Sensor mode. */
typedef enum
{
  COLOR_NONE = 0,
  COLOR_FULL,
  COLOR_RED,
  COLOR_GREEN,
  COLOR_BLUE,

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

/** Color Sensor config. */
typedef struct {
	color_mode mode;		/* Color Sensor LED mode */
	color_status status;	/* Color Sensor current status */
} color_config;

/** Color Sensor calibration point enums. */
typedef enum
{
	CAL_POINT0 = 0,
	CAL_POINT1,
	CAL_POINT2,
	NO_OF_CALPOINTS
} calibration_points;

/** Color Sensor calibration color enums. */
typedef enum
{
	CAL_RED = 0,
	CAL_GREEN,
	CAL_BLUE,
	CAL_NONE,
	NO_OF_CALCOLORS
} calibration_colors;

/** Color Sensor calibration data structure. */
typedef struct {
    U32 calibration[NO_OF_CALPOINTS][NO_OF_CALCOLORS];		/* 3 Cal Points x 4 Cal Colors = 12 32-bit values */
    U16 calibration_limits[NO_OF_CALPOINTS - 1];			/* 2 16-bit cal limits */
} color_cal_data;

#if 0
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
#endif


/** Initialize a LEGO Color Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 * @param mode   The color sensing mode (NONE, FULL, RED, GREEN, BLUE)
 * @param color_cal_data Calibration data pointer (must be pre-allocated)
 *
 * @note If no Color Sensor device were registered, a call to nx_color_register()
 * will setup the Color isr.
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

#if 0
/** Perform a I2C transaction with the device on port @a sensor.
 *
 * @param sensor The sensor port number.
 * @param mode The transaction mode (reading or writing form/to the device).
 * @param data The data to send to the device. In a read transaction, the data
 * contains the command to send to the device before reading from it.
 * @param data_size The size of the data to be sent.
 * @param recv_buf A receive buffer that will hold the received data.
 * @param recv_size The expected size of the received data.
 *
 * @note This function actually creates a series of asynchronous sub
 * transactions and immediately returns. Use nx_i2c_busy() and
 * nx_i2c_get_txn_status() to track the transaction's state.
 *
 * @warning The reception buffer @a recv_buf must be pre-allocated to hold at
 * least @a recv_size bytes.
 *
 * @return This function returns an I2C error code. I2C_ERR_OK will be returned
 * if the transaction has been successfully setup. Otherwise, the appropriate
 * error codes are returned (see i2c_txn_err).
 */
i2c_txn_err nx_i2c_start_transaction(U32 sensor, i2c_txn_mode mode,
                                     const U8 *data, U32 data_size,
                                     U8 *recv_buf, U32 recv_size);
#endif


/** Get the current LED mode of the LEGO Color Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 * *
 * @return Returns the mode of the LEGO Color Sensor on the
 * given sensor port.
 */
color_mode nx_color_get_mode(U32 sensor);


/*@}*/
/*@}*/

#endif
