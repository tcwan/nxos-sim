/** @file ht_irlink.h
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

#ifndef __NXOS_HT_IRLINK_H__
#define __NXOS_HT_IRLINK_H__

#include "base/types.h"

/** @addtogroup driver */
/*@{*/

/** @defgroup ht_irlink HiTechnic IRLink Sensor driver
 *
 * The ht_irlink driver provides a simple API to use an IRLink sensor
 * from HiTechnic.
 */
/*@{*/

/** I2C address.
 */
#define HT_IRLINK_I2C_ADDRESS  0x01

/** An enumeration with known IR-modes of the IRLink */
typedef enum {
  HT_IRLINK_MODE_RCX = 0, // TODO
  HT_IRLINK_MODE_TRAIN, // TODO
  HT_IRLINK_MODE_PF // Power Functions
} ht_irlink_mode;

/** Internal memory addresses.
 *
 * This enum contains the IRLink's internal memory addresses.
 */
typedef enum {
  HT_IRLINK_VERSION = 0, /* 8 Bytes */
  HT_IRLINK_MANUFACTURER = 0x08, /* 8 Bytes */
  HT_IRLINK_SENSOR_TYPE = 0x10, /* 8 Bytes */
  HT_IRLINK_TRANSMIT_BUFFER = 0x40, /* 13 Bytes */
  HT_IRLINK_TRANSMIT_BUFFER_BYTE_COUNT = 0x4d,
  HT_IRLINK_TRANSMIT_MODE = 0x4e,
  HT_IRLINK_TRANSMIT_BUFFER_FLAG = 0x4f,
  HT_IRLINK_RECEIVE_BUFFER_BYTE_COUNT = 0x50,
  HT_IRLINK_RECEIVE_BUFFER = 0x51, /* 15 Bytes */
} ht_irlink_memory_slot;

/** possible modes used in PF commands */
typedef enum {
  PF_COMBO_DIRECT = 1,
  PF_SINGLE_CONTINUOUS, /* no timeout */
  PF_SINGLE_TIMEOUT,
  PF_SINGLE_OUTPUT,
  PF_COMBO_PWM = 0x40 /* this just sets the escape-bit */
} pf_mode;

/** Combo direct commands will be executed (on the receiver side) for
 * about 1.2 seconds. So if you e.g. only want to drive forwards for 0.5s
 * you have to send another command afterwards. After the 1.2s the motors
 * will stop (timeout). That means to drive continuously you have to send
 * a combo-direct command every second.
 */
typedef enum {
  /* Motor A = red, motor B = blue */
  PF_MOTOR_FLOAT = 0, /* Used for both motors */
  PF_MOTOR_A_FORWARD,
  PF_MOTOR_A_BACKWARD,
  PF_MOTOR_A_BRAKE,
  PF_MOTOR_B_FORWARD,
  PF_MOTOR_B_BACKWARD = 0x08,
  PF_MOTOR_B_BRAKE = 0x0c,
} pf_combo_direct_cmd;

/** Combo PWM commands will be executed with a timeout (on the receiver sider)
 * like Combo direct commands. Please see there for a description of
 * the timeout.
 *
 * The enumeration doesn't look good here, but if used, it's descriptive.
 */
typedef enum {
  PF_PWM_FLOAT = 0,
  PF_PWM_MOTOR_FWD_1,
  PF_PWM_MOTOR_FWD_2,
  PF_PWM_MOTOR_FWD_3,
  PF_PWM_MOTOR_FWD_4,
  PF_PWM_MOTOR_FWD_5,
  PF_PWM_MOTOR_FWD_6,
  PF_PWM_MOTOR_FWD_7,
  PF_PWM_MOTOR_BREAK,
  PF_PWM_MOTOR_BACK_7,
  PF_PWM_MOTOR_BACK_6,
  PF_PWM_MOTOR_BACK_5,
  PF_PWM_MOTOR_BACK_4,
  PF_PWM_MOTOR_BACK_3,
  PF_PWM_MOTOR_BACK_2,
  PF_PWM_MOTOR_BACK_1,
} pf_combo_pwm;

/* Single Pin continuous commands will be executed without a timeout (on the
 * receiver side). That means if the IR-connection to the receiver will get
 * lost, the pin will stay in the mode set before.
 */

/** The function for single pin commands */
typedef enum {
  PF_PIN_NO_CHANGE = 0, /* used to prevent timeout */
  PF_PIN_CLEAR,
  PF_PIN_SET,
  PF_PIN_TOGGLE,
} pf_pin_function;

/** The output for single pin commands */
typedef enum {
  PF_PIN_OUTPUT_A = 0,
  PF_PIN_OUTPUT_B
} pf_pin_output;

/** The pin for single pin commands */
typedef enum {
  PF_PIN_C1 = 0,
  PF_PIN_C2
} pf_pin;

/** Initialize the IRLink Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 */
void ht_irlink_init(U32 sensor);

/** Close the link with the IRLink Sensor and disable him.
 *
 * @param sensor The sensor port number.
 */
void ht_irlink_close(U32 sensor);

/** Check the presence of an IRLink Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 *
 * @note The device on port @a sensor first needs to be initialized with
 * ht_irlink_init().
 *
 * @return True if an IRLink Sensor was found, false otherwise.
 */
bool ht_irlink_detect(U32 sensor);

/** Get the contents of the receive buffer of an IRLink Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 * @param buffer The buffer where the contents will be stored. The buffer
 * must have at least space for 15 bytes.
 *
 * @return The number of bytes the IRLink Sensor has received and which are
 * copied into the buffer (0-15).
 *
 * @note Receiving is disabled while transmitting commands.
 */
U8 ht_irlink_get_receive_buffer(U32 sensor, U8* buffer);

/** Clear the contents of the receive buffer of an IRLink Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 *
 * @return True if succesful, false otherwise.
 */
bool ht_irlink_clear_receive_buffer(U32 sensor);

/** Builds the PF-command for the Combo direct Mode.
 *
 * @param channel The channel the command is for.
 * @param cmd The command. Use bitwise or to construct it.
 *
 * @return The 4 nibbles which should be encoded and transmitted.
 *
 * @note The toggle bit is switched with every call of this function.
 */
U16 build_bitstream_PF_direct(U8 channel, U8 cmd);

/** Builds the PF-command for the Combo PWM Mode.
 *
 * @param channel The channel the command is for.
 * @param motor_a The command for motor A.
 * @param motor_b The command for motor B.
 *
 * @return The 4 nibbles which should be encoded and transmitted.
 */
U16 build_bitstream_PF_pwm(U8 channel, pf_combo_pwm motor_a, pf_combo_pwm motor_b);

/** Builds the PF-command for the Single pin timeout mode.
 *
 * @param channel The channel the command is for.
 * @param output The output.
 * @param pin The pin.
 * @param function The function for the specified pin.
 *
 * @return The 4 nibbles which should be encoded and transmitted.
 *
 * @note The toggle bit is switched with every call of this function.
 * @note If a motor is attached the following can be used:
 * Forward => C1 = 1, C2 =0, Backwards => C1=0, C2=1 and Brake => C1,C2 = 0.
 */
U16 build_bitstream_PF_single_pin_timeout(U8 channel, pf_pin_output output,
  pf_pin pin, pf_pin_function function);

/** Builds the PF-command for the Single pin continuous mode.
 *
 * @param channel The channel the command is for.
 * @param output The output.
 * @param pin The pin.
 * @param function The function for the specified pin.
 *
 * @return The 4 nibbles which should be encoded and transmitted.
 *
 * @note The toggle bit is switched with every call of this function.
 * @note If a motor is attached the following can be used:
 * Forward => C1 = 1, C2 =0, Backwards => C1=0, C2=1 and Brake => C1,C2 = 0.
 */
U16 build_bitstream_PF_single_pin_continuous(U8 channel, pf_pin_output output,
  pf_pin pin, pf_pin_function function);

/* TODO: build_bitstream_PF_single_output() */

/** Encode a bitstream for sending it to the IRLink Sensor.
 *
 * @param mode The Transmit mode send to the IRLink.
 * @param bitstream The bitstream (16 bits) to encode.
 * @param buffer The buffer where the encoded bitstream will be stored. The
 * buffer must have at least space for 14 bytes.
 *
 * @return The number of bytes to send to the IRLink. The buffer has to send
 * to register 0x50 - count.
 */
U8 ht_irlink_encode_bitstream(ht_irlink_mode mode, U16 bitstream, U8* buffer);

/** Sends a buffer for transmitting to the IRLink sensor.
 *
 * @param sensor The sensor port number.
 * @param buffer The bytes to send (including byte-count, mode and flag).
 * @param size The number of bytes in the buffer (max 15).
 *
 * @return The number of bytes the IRLink will transmit. Zero will be an error.
 * . Use this number to calculate the time the IRLink needs to transmit
 *   the message. It is approximately 5 * number of bytes.
 *
 * @note In the PF-documentation is stated, that a command should be send
 *   4 times to be sure the receiver receives it. This function here transmits
 *   the buffer only once, so you might call this 4 times with the same
 *   parameters (and some time (see above) in between, to give the IRLink the
 *   needed time to send it).
 */
U8 ht_irlink_transmit_buffer(U32 sensor, const U8* buffer, U8 size);

/** Sends a buffer 4 times with the needed time in between for transmitting
 *  by the IRLink sensor.
 *
 * @param sensor The sensor port number.
 * @param buffer The bytes to send (including byte-count, mode and flag).
 * @param size The number of bytes in the buffer (max 15).
 *
 * @return The number of bytes the IRLink will transmit each time. Zero will
 *   be an error.
 *
 * @note When this function returns, the IRLink Sensor still needs the time
 * to send the last sequence before it can used again.
 */
U8 ht_irlink_transmit_buffer_4x(U32 sensor, const U8* buffer, U8 size);

/** Display the IRLink Sensor's information.
 *
 * Displays on the NXT screen the IRLink sensor's information, including the
 * manufacturer, sensor type, device version and receive buffer.
 *
 * @param sensor The sensor port number.
 */
void ht_irlink_info(U32 sensor);

/*@}*/
/*@}*/

#endif /* __NXOS_HT_IRLINK_H__ */
