/** @file _color.h
 *  @brief Color internal interface.
 */

/* Copyright (C) 2007-2013 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_DRIVERS__COLOR_H__
#define __NXOS_BASE_DRIVERS__COLOR_H__

#include "base/types.h"
#include "base/drivers/color.h"

/** @addtogroup driverinternal */
/*@{*/

/** @defgroup colorinternal Color interface */
/*@{*/

/** Initialize the NXT to allow Color Sensor Support.
 */
void nx__color_init(void);

/** Disable color_isr if no active color sensor.
 */
void nx__color_check_disable_isr(void);

/* Initiate A/D conversion for all active Color Sensors
 */
void nx__color_adc_get(U32 aden, color_struct_colors index);

/** Retrieve A/D samples for all active Color Sensors
 */
void nx__color_adc_get_samples(U32 aden, U32 adclk);

/** Setup transmission parameters for Color Bus.
 */
void nx__colorbus_setup_txbyte(U32 sensor, U8 val);

/** Setup reception parameters for Color Bus.
 */
void nx__colorbus_setup_rxbyte(U32 sensor);

/** Verify CRC for Calibration Data.
 */
bool nx__color_calibration_crc(color_cal_data *caldataptr, U16 crcval);

/** Adjust Raw Inputs using Color Calibration Data.
 */
void nx__color_calibrate_inputs(color_values *rawvalues, color_cal_data *caldata);

/*@}*/
/*@}*/

#endif /* __NXOS_BASE_DRIVERS__COLOR_H__ */
