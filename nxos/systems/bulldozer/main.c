/* Copyright (c) 2007,2008 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 *
 * This is a simple demo which drives a Motorized Bulldozer (8275) with
 * an attached NXT, HiTechnic IRLink and Compass along a square (almost,
 * because we don't have feedback from the motors).
 * It shows how to use a compass sensor and the IRLink.
 */

#include <base/types.h>
#include <base/core.h>
#include <base/display.h>
#include <base/drivers/avr.h>
#include <base/drivers/systick.h>
#include <base/drivers/sound.h>
#include <base/drivers/i2c.h>
#include <base/drivers/ht_compass.h>
#include <base/drivers/ht_irlink.h>
#include <base/util.h>

/* Using PWM while turning enables us to turn more precisly, but this
 * heavily depends on the surface the bulldozer drives over and might not work
 */
/* #define TURN_SLOW */

/* Sensor port definitions. */
#define SENSOR_COMPASS 2
#define SENSOR_IRLINK 1

/* Security hook. A press on cancel will inconditionally halt the brick. */
static void watchdog(void)
{
  if (nx_avr_get_button() == BUTTON_CANCEL)
    nx_core_halt();
}

static void make_sound(void)
{
  nx_sound_freq(2000, 100);
  nx_systick_wait_ms(50);
  nx_sound_freq(1000, 100);
  nx_systick_wait_ms(900);
}

static void init(void)
{
  nx_systick_install_scheduler(watchdog);
  nx_i2c_init();
  nx_display_clear();
  nx_display_cursor_set_pos(0, 0);
  nx_display_string("Bulldozer-Test\n\n");
  ht_compass_init(SENSOR_COMPASS);
  if( ! ht_compass_detect(SENSOR_COMPASS) ) {
    nx_display_string("\nNo compass!\n");
    nx_sound_freq(500, 100);
  }
  while (nx_i2c_busy(SENSOR_COMPASS))
    nx_systick_wait_ms(1);
  ht_irlink_init(SENSOR_IRLINK);
  if( ! ht_irlink_detect(SENSOR_IRLINK) ) {
    nx_display_string("No IRLink!\n");
    nx_sound_freq(500, 100);
  }
  make_sound();
}

/* This needs only to be called once for a model, the calibration result is
   stored permanent and survives a power-off */
static void calibrate_compass(void)
{
  U8 buffer[15];
  ht_compass_start_calibration(SENSOR_COMPASS);
  U8 count = ht_irlink_encode_bitstream(HT_IRLINK_MODE_PF,
    build_bitstream_PF_direct(0, PF_MOTOR_A_FORWARD | PF_MOTOR_B_FORWARD),
    buffer);
  /* Turn right about 2 rounds */
  for ( unsigned i = 0; i < 6; ++i ) {
    ht_irlink_transmit_buffer_4x(SENSOR_IRLINK, buffer, count);
    nx_systick_wait_ms(1000);
  }
  if( ! ht_compass_stop_calibration(SENSOR_COMPASS) )
    nx_sound_freq(500, 100);
}

static void drive_forward_about_1m(void)
{
  /*
   * Forward drive motor A (left) and backward drive motor B (right)
   * on channel 0 with full power for 5s to drive the bulldozer
   * about 1m forwards.
   */
  U8 buffer[15];
  U8 count = ht_irlink_encode_bitstream(HT_IRLINK_MODE_PF,
    build_bitstream_PF_direct(0, PF_MOTOR_A_FORWARD | PF_MOTOR_B_BACKWARD),
    buffer);
  for ( unsigned i = 0; i < 4; ++i ) {
    ht_irlink_transmit_buffer_4x(SENSOR_IRLINK, buffer, count);
    nx_systick_wait_ms(1000);
  }
}

static void lift_blade_and_ripper(void)
{
  /*
   *  Backward drive motor A (red, blade) and forward drive
   *  motor B (blue, ripper) on channel 1 with full power for 7s to
   *  be sure the front blade and the ripper are up.
   */
  U8 buffer[15];
  U8 count = ht_irlink_encode_bitstream(HT_IRLINK_MODE_PF,
    build_bitstream_PF_direct(1, PF_MOTOR_A_BACKWARD | PF_MOTOR_B_FORWARD),
    buffer);
  for ( unsigned i = 0; i < 7; ++i ) {
    ht_irlink_transmit_buffer_4x(SENSOR_IRLINK, buffer, count);
    nx_systick_wait_ms(1000);
  }
}

static void turn(int degrees)
{
  U16 heading = ht_compass_read_heading(SENSOR_COMPASS);
  heading += 360; /* we don't want to get negativ values for the target */
  U16 target = (heading + degrees) % 360;
  U8 buffer[15];
  U8 count;
#ifdef TURN_SLOW
  if( degrees > 0 )
    count = ht_irlink_encode_bitstream(HT_IRLINK_MODE_PF,
      build_bitstream_PF_pwm(0, PF_PWM_MOTOR_FWD_3, PF_PWM_MOTOR_FWD_3),
      buffer);
  else
    count = ht_irlink_encode_bitstream(HT_IRLINK_MODE_PF,
      build_bitstream_PF_pwm(0, PF_PWM_MOTOR_BACK_3, PF_PWM_MOTOR_BACK_3),
      buffer);
#else
   if( degrees > 0 )
     count = ht_irlink_encode_bitstream(HT_IRLINK_MODE_PF,
      build_bitstream_PF_direct(0, PF_MOTOR_A_FORWARD | PF_MOTOR_B_FORWARD),
      buffer);
  else
    count = ht_irlink_encode_bitstream(HT_IRLINK_MODE_PF,
      build_bitstream_PF_direct(0, PF_MOTOR_A_BACKWARD | PF_MOTOR_B_BACKWARD),
      buffer);
#endif
  U32 ms_start = nx_systick_get_ms();
  /* Start turning. */
  ht_irlink_transmit_buffer_4x(SENSOR_IRLINK, buffer, count);
  for(;;) {
    heading = ht_compass_read_heading(SENSOR_COMPASS) + 360;
#ifdef TURN_SLOW
    /* this needs really a slow turning because we have to recognize almost every
     * degree while turning and we need some time to send the ir-command to
     * stop the motors. Tests to reach exactly the correct target ( heading = target)
     * were not succesful here, so we allow 1 degree difference.
     */
    if( (heading - target) % 360 < 2 ) {
#else
    /* We stop turning if the difference is less than three degrees.
     * Using less than 3 as difference would need a slower
     * rate of turning, which is difficult, because turning the Bulldozer
     * while driving both motors needs a lot of power. A possible solution would be
     * to drive only one motor using PF_PWM_MOTOR*, which we are not doing for this
     * simple demo.
     */
    if( (heading - target) % 360 < 3 ) {
#endif
      /* Turn complete, stop motors. */
      count = ht_irlink_encode_bitstream(HT_IRLINK_MODE_PF,
        build_bitstream_PF_direct(0, PF_MOTOR_A_BRAKE | PF_MOTOR_B_BRAKE),
        buffer);
      ht_irlink_transmit_buffer_4x(SENSOR_IRLINK, buffer, count);
      break;
    }
    else if( nx_systick_get_ms() > ms_start + 1000 ) {
      ms_start = nx_systick_get_ms();
      /* Send another command to keep the Bulldozer turning. */
      ht_irlink_transmit_buffer_4x(SENSOR_IRLINK, buffer, count);
    }
  }
}

static void countdown(unsigned seconds)
{
  for(unsigned i = 1; i < seconds; ++i) {
    nx_sound_freq_async(1000+100*i, 200);
    nx_systick_wait_ms(1000);
  }
  nx_sound_freq(1000+100*seconds, 1000);
}

void main(void)
{
  init();
  nx_display_string("LEFT for compass\n-calibration\nOK to start\n");
  U32 button = nx_avr_get_button();
  while(button != BUTTON_OK && button != BUTTON_LEFT) {
    nx_systick_wait_ms(10);
    button = nx_avr_get_button();
  }
  countdown(10);
  lift_blade_and_ripper();
  if(button == BUTTON_LEFT)
    calibrate_compass();
  else {
    for(unsigned i = 0; i < 4; ++i) {
      drive_forward_about_1m();
      turn(90);
    }
    for(unsigned i = 0; i < 4; ++i) {
      drive_forward_about_1m();
      turn(-90);
    }
  }
  make_sound();
  nx_display_string("Completed.\n");
  nx_systick_wait_ms(12000);
  ht_compass_close(SENSOR_COMPASS);
  ht_irlink_close(SENSOR_IRLINK);
}
