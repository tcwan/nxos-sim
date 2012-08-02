#include "base/types.h"
#include "base/display.h"
#include "base/util.h"
#include "base/drivers/systick.h"
#include "base/drivers/motors.h"
#include "base/drivers/sensors.h"
#include "base/drivers/radar.h"

#define DISPLAY_OUT

S32 A = 0;

static U32 prng_get(void) {
  static U32 val = 42;
  val = (val + 134289) % 1031;
  return val;
}

void main(void) {
  U32 start;
  U32 end;
  U32 loopcount = 1;

#ifndef DISPLAY_OUT
  nx_display_cursor_set_pos(0,0);
  nx_display_string("Start...");
  nx_display_end_line();
#endif

  start = nx_systick_get_ms();
  end = start + 60000;

  /* Initialize sensors */
  nx_sensors_analog_enable(2);
  nx_radar_init(3);

  do {
#ifdef DISPLAY_OUT
    /* Note: The Sensor reading process is synced to the NXT<->AVR read interval
     *       The loopcount will be very low since each sensor read cycle takes 1 ms.
     */
    U32 light = nx_sensors_analog_get(2);
    U32 us = nx_radar_read_distance(3, 0);
    U32 angle = nx_motors_get_tach_count(1) % 360;
#endif
    U32 rn = (prng_get() % 100) + 1;

#ifdef DISPLAY_OUT
    nx_display_cursor_set_pos(0,0);

    nx_display_uint(angle);
    nx_display_string("     ");
    nx_display_end_line();
    nx_display_uint((light + us + angle)*100/rn);
    nx_display_string("     ");
    nx_display_end_line();
#endif
    nx_motors_rotate(1, rn);
    nx_motors_rotate(2, rn);

    if (rn > 50)
      A = MIN(A+1, 100);
    else if (rn < 50)
      A = MAX(A-1, -100);

#ifdef DISPLAY_OUT
    if (A>=0)
      nx_display_uint(A);
    else
      nx_display_uint(-A);
    nx_display_string("     ");
    nx_display_end_line();
#endif
    nx_motors_rotate(0, A);
#ifdef DISPLAY_OUT
    nx_display_uint(loopcount);
    nx_display_string("     ");
#endif
    loopcount++;
  } while(nx_systick_get_ms() < end);

#ifndef DISPLAY_OUT
  nx_display_uint(loopcount);
#endif
  nx_display_end_line();
  nx_display_string("Done!");
  nx_motors_stop(0, TRUE);
  nx_motors_stop(1, TRUE);
  nx_motors_stop(2, TRUE);

  nx_systick_wait_ms(10000);
}
