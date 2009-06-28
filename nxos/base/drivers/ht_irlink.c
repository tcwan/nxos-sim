/** @file ht_irlink.c
 *  @brief HiTechnic IRLink Sensor driver.
 *
 * Driver for HiTechnic IRLink Sensor.
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
#include "base/assert.h"
#include "base/drivers/i2c_memory.h"
#include "base/drivers/systick.h"
#include "base/drivers/ht_irlink.h"

/* The manufacturer. */
#define HT_IRLINK_MANUFACTURER_STR "HiTechnc"
/* The sensor type. */
#define HT_IRLINK_TYPE_STR "IRLink  "

/** Initialize the IRLink Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_irlink_init(U32 sensor) {
  nx_i2c_memory_init(sensor, HT_IRLINK_I2C_ADDRESS, FALSE);
}

/** Close the link with the IRLink Sensor and disable him.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_irlink_close(U32 sensor) {
  nx_i2c_memory_close(sensor);
}

/** IRLink Sensor detection.
 *
 * Tries to detect the presence of an IRLink Sensor on the given port by
 * reading the device's manufacturer and sensor type and comparing it
 * to the defaults.
 *
 * @param sensor The sensor port number.
 *
 * @return True if an acceleration/tilt sensor was found.
 */
bool ht_irlink_detect(U32 sensor) {
  U8 str[9];
  memset(str, 0, sizeof(str));
  if ( nx_i2c_memory_read(sensor, HT_IRLINK_MANUFACTURER, str, 8)
      != I2C_ERR_OK || ! streq((char *)str, HT_IRLINK_MANUFACTURER_STR) )
      return FALSE;
  memset(str, 0, sizeof(str));
  return nx_i2c_memory_read(sensor, HT_IRLINK_SENSOR_TYPE, str, 8)
      == I2C_ERR_OK && streq((char *)str, HT_IRLINK_TYPE_STR);
}

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
U8 ht_irlink_get_receive_buffer(U32 sensor, U8* buf) {
  U8 count;
  if ( nx_i2c_memory_read(sensor, HT_IRLINK_RECEIVE_BUFFER_BYTE_COUNT, &count, 1)
      != I2C_ERR_OK )
      return 0;
  if(count > 15)
    return 0; /* wrong byte count */
  if ( nx_i2c_memory_read(sensor, HT_IRLINK_RECEIVE_BUFFER_BYTE_COUNT, buf, count)
      != I2C_ERR_OK )
      return 0;
  return count;
/* Reading every time 16 bytes at once doesn't seem to work:
  U8 buffer[16];
  if ( nx_i2c_memory_read(sensor, HT_IRLINK_RECEIVE_BUFFER_BYTE_COUNT, buffer, 16)
      != I2C_ERR_OK )
      return 0;
  if(buffer[0] > 15)
    return 0; // wrong byte count
  memcpy(buf, buffer, buffer[0];
  return buffer[0];
*/
}

/** Clear the contents of the receive buffer of an IRLink Sensor on port @a sensor.
 *
 * @param sensor The sensor port number.
 *
 * @return True if succesful, false otherwise.
 */
bool ht_irlink_clear_receive_buffer(U32 sensor) {
  static  U8 t = 0;
  return nx_i2c_memory_write(sensor, HT_IRLINK_RECEIVE_BUFFER_BYTE_COUNT, &t, 1)
      == I2C_ERR_OK;
}

/** Display connected IRLink sensor's information.
 *
 * @param sensor The sensor port number.
 *
 */
void ht_irlink_info(U32 sensor) {
  U8 buf[15];

  // Manufacturer (HiTechnc)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_IRLINK_MANUFACTURER, buf, 8);
  nx_display_string((char *)buf);
  nx_display_string(" ");

  // Sensor Type (IRLink)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_IRLINK_SENSOR_TYPE, buf, 8);
  nx_display_string((char *)buf);
//  nx_display_string(" ");

  // Version (V1.2)
  memset(buf, 0, sizeof(buf));
  nx_i2c_memory_read(sensor, HT_IRLINK_VERSION, buf, 8);
  nx_display_string((char *)buf);
  nx_display_end_line();

  // Receive buffer
  U8 count = ht_irlink_get_receive_buffer(sensor, buf);
  nx_display_string("Recv. buf. (");
  nx_display_uint(count);
  nx_display_string("):\n");
  for(unsigned i = 0; i < count; ++i) {
    nx_display_hex(buf[i]);
    nx_display_string(" ");
  }
}

/** Adds the checksum (LRC) to the PF-command */
static inline U16 addPFlrc(U16 pfdata)
{
  return ( 0x0f ^ (pfdata>>12) ^ ((pfdata>>8)&0x0f) ^ ((pfdata>>4)&0x0f) ) | pfdata;
}

/* We are using one toggle for all possible attached sensors.
 * Most people will only have on IRLink and the toggle-bit
 * is ignored for most commands, so this should be ok.
 */
static S16 pf_toggle = -1;

/** Builds the PF-command for the Combo direct Mode.
 *
 * @param channel The channel the command is for.
 * @param mode The Power Functions mode.
 * @param cmd The command. Use bitwise or to construct it.
 *
 * @return The bitstream (4 nibbles) which should be encoded and transmitted.
 *
 * @note The toggle bit is switched with every call of this function.
 */
U16 build_bitstream_PF_direct(U8 channel, U8 cmd)
{
  /* A PF-combo-direct command (4 nibbles, 16 bit) looks like this:
   * T E C C  a M M M  D D D D  L L L L
   * with T = toggle, E = escape (0), C = channel, a = address (0),
   * M = mode, D = data and L = LRC
   */
  pf_toggle = -pf_toggle; /* Switch toggle bit */
  return addPFlrc((pf_toggle & 0x8000) | (channel<<12) | (PF_COMBO_DIRECT<<8 ) | (cmd<<4));
}

/** Builds the PF-command for the Combo PWM Mode.
 *
 * @param channel The channel the command is for.
 * @param motor_a The command for motor A.
 * @param motor_b The command for motor B.
 *
 * @return The 4 nibbles which should be encoded and transmitted.
 */
U16 build_bitstream_PF_pwm(U8 channel, pf_combo_pwm motor_a, pf_combo_pwm motor_b)
{
  /* A PF-combo-pwm command (4 nibbles, 16 bit) looks like this:
   * a E C C  B B B B  A A A A  L L L L
   * a = address (0), E = escape (1), C = channel,
   * B = PWM Motor B, A = PWM motor A and L = LRC
   */
  return addPFlrc(0x4000 | (channel<<12) | (motor_b<<8) | (motor_a<<4));
}

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
  pf_pin pin, pf_pin_function function)
{
  /* A PF-single-pin-timeout-mode command (4 nibbles, 16 bit) looks like this:
   * T e C C  a M M M  O P F F  L L L L
   * T = toggle, E = escape (0), C = channel, a = address (0)
   * M = mode, O = output, P = pin, F = function and L = LRC
   */
  pf_toggle = -pf_toggle; /* Switch toggle bit */
  return addPFlrc((pf_toggle & 0x8000) | (channel<<12) |
    (PF_SINGLE_TIMEOUT<<8) | (output <<7) | (pin<<6) | (function<<4));
}

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
  pf_pin pin, pf_pin_function function)
{
  /* A PF-single-pin-continuous-mode command (4 nibbles, 16 bit) looks like this:
   * T e C C  a M M M  O P F F  L L L L
   * T = toggle, E = escape (0), C = channel, a = address (0)
   * M = mode, O = output, P = pin, F = function and L = LRC
   */
  pf_toggle = -pf_toggle; /* Switch toggle bit */
  return addPFlrc((pf_toggle & 0x8000) | (channel<<12) |
    (PF_SINGLE_CONTINUOUS<<8) | (output <<7) | (pin<<6) | (function<<4));
}

/** Encode a bitstream for sending it to the IRLink Sensor.
 *
 * @param mode The transmit mode.
 * @param bitstream The bitstream (16 bits) to encode.
 * @param buffer The buffer where the encoded bitstream will be stored. The
 * buffer must have at least space for 14 bytes.
 *
 * @return The number of bytes to send to the IRLink. The buffer has to send
 * to register 0x50 - count.
 */
U8 ht_irlink_encode_bitstream(ht_irlink_mode mode, U16 bitstream, U8* buffer)
{
  /* Painful and ugly bit shuffling.
   * In short: we are going through the bits to send adding the representations
   * of them (1 = 10000, 0 = 100) one after another to the output buffer.
   * For a detailed explanation please read the documentation for PF encoding
   * from Lego and the documentation for the HiTechnic IRLink Sensor.
   *
   * Don't be afraid about all the shifting, >>3 is just /8, the shifting is
   * just for the case a stupid compiler is used.
   */

  memset(buffer+1, 0, 10); /* 16bits, each one => 10 bytes + stuff at max. */
  buffer[0] = 0x80; /* Start bit */
  int bufferbit = 8;
  for (unsigned bsbit = 0; bsbit < 16; ++bsbit) {
    buffer[bufferbit >> 3] |= (0x80 >> (bufferbit & 7)); /* set the 1 bit */
    bufferbit += ((bitstream << bsbit) & 0x8000) ? 5 : 3; /* add the zeros */
  }
  buffer[bufferbit >> 3] |= (0x80 >> (bufferbit & 7)); /* Stop bit */
  /* we are now changing the bufferbit into the byte count to use it as such. */
  bufferbit >>= 3;
  ++bufferbit; /* + 8 bits = 1 byte for the stop bit added above */
  buffer[bufferbit] = bufferbit; /* Transmit buffer byte count */
  buffer[++bufferbit] = mode; /* Transmit mode */
  buffer[++bufferbit] = 0x01; /* Transmit buffer flag */
  return ++bufferbit;
}

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
U8 ht_irlink_transmit_buffer(U32 sensor, const U8* buffer, U8 size)
{
  NX_ASSERT(size < 16);
  NX_ASSERT(buffer[size-3] == size - 3);
  if( nx_i2c_memory_write(sensor, 0x50-size, buffer, size) != I2C_ERR_OK)
    return 0;
  return size-3;
}

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
U8 ht_irlink_transmit_buffer_4x(U32 sensor, const U8* buffer, U8 size)
{
  U8 count = ht_irlink_transmit_buffer(sensor, buffer, size);
  for(unsigned i = 0; i < 3; ++i) {
    nx_systick_wait_ms(count*5);
    ht_irlink_transmit_buffer(sensor, buffer, size);
  }
  return count;
}
