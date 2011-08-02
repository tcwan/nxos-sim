/* Copyright (c) 2009 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

/* Motor control example.
 *
 * This example demonstrates the use of the motors API to control the
 * motors that can be connected to the NXT. If you want to run this
 * demo, plug a motor into the first output port. It is best to leave
 * it unconnected, as it may have movements that could damage a robot.
 */

#include "base/drivers/motors.h"
#include "base/drivers/systick.h" /* For nx_systick_wait_ms */
#include "base/drivers/sound.h"
#include "base/display.h" /* for nx_display_uint */

#define MOTOR_PORT 1

/* Small delaying helper, which we use to give you time to see the
 * effects of the commands.
 */
static void wait() {
  nx_systick_wait_ms(2000);
}

void main() {
  S8 speed;
  /* On bootup, all the motors are stopped. Let's start one in
   * continuous mode. In this mode, the motor will continue at the
   * given speed until explicitely told to stop or do something else.
   */

  nx_display_clear();
  nx_display_cursor_set_pos(0, 0);
  nx_display_string("Rotate Full Fwd");

  nx_motors_rotate(MOTOR_PORT, 100);

  wait();

  /* Speed control goes from -100 (full reverse) to 100 (full
   * forward). Let's reverse the motor's direction.
   */
  nx_display_clear();
  nx_display_cursor_set_pos(0, 0);
  nx_display_string("Rotate Full Rev,");
  nx_display_string("Stop with Brakes");

  nx_motors_rotate(MOTOR_PORT, -100);

  wait();

  /* Now, stop the motor. There are two options here. Either don't
   * apply brakes, which lets the motor continue for a short while on
   * its inertia, or apply braking, which forcefully tries to bring
   * the motor to a halt as fast as possible. The following will
   * demonstrate both stop modes. First, a braking stop.
   */

  nx_motors_stop(MOTOR_PORT, TRUE);

  wait();

  nx_display_clear();
  nx_display_cursor_set_pos(0, 0);
  nx_display_string("Rotate Full Fwd,");
  nx_display_string("Stop with Coasting");
  nx_motors_rotate(MOTOR_PORT, 100);
  wait();

  /* And here, a coasting stop. */
  nx_motors_stop(MOTOR_PORT, FALSE);

  wait();

  /* Vary Speed 100 (full forward) to -100 (full
   * reverse).
   */
  for (speed = 100; speed >= -100; speed -= 10) {

      nx_sound_freq(1500, 100);
      nx_motors_rotate(MOTOR_PORT, speed);
      nx_display_clear();
      nx_display_cursor_set_pos(0, 0);
      nx_display_string("Motor Speed: ");
      nx_display_int(speed);
      wait();
  }

  nx_motors_stop(MOTOR_PORT, FALSE);
  nx_sound_freq(3000, 100);
  wait();

  /* You can also request rotation by a given angle, instead of just
   * blazing the motor on without limits. Note that there is no
   * precise feedback control built into the motor driver (yet), which
   * can cause it to overshoot the target angle because of its own
   * inertia. Let's rotate 90 degrees, with a braking finish.
   */
  nx_motors_rotate_angle(MOTOR_PORT, 100, 90, TRUE);

  wait();

  /* Finally, rotation can be set to stop after a given time. The
   * function call returns immediately, and the motor driver will take
   * care of stopping the motor after the specified time has
   * elapsed. Let's rotate in reverse, for 1 second, with a braking
   * finish.
   */
  nx_motors_rotate_time(MOTOR_PORT, -100, 1000, TRUE);

  wait();

  /* Finally, if this information has any value to you, you can query
   * the motor's current rotational position relative to its position
   * when it booted up. What you actually get here is the raw value of
   * the motor's tachymeter, which you should modulo 360 to get a more
   * sensible angular value.
   */
  nx_display_clear();
  nx_display_cursor_set_pos(0, 0);
  nx_display_string("Tach Count: ");
  nx_display_uint(nx_motors_get_tach_count(MOTOR_PORT));

  wait();
}
