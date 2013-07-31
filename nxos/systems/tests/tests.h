/* Copyright (c) 2007,2008 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_TESTS_TESTS_H__
#define __NXOS_TESTS_TESTS_H__

void hello(void);
void goodbye(void);

void tests_util(void);
void tests_motor(void);
void tests_sound(void);
void tests_display(void);
void tests_sysinfo(void);
void tests_sensors(void);
void tests_tachy(void);
void tests_usb(void);
void tests_usb_hardcore(void);
void tests_radar(void);
void tests_ht_compass(void);
void tests_ht_accel(void);
bool ht_color_perform_calibration(U32 sensor, U8 mode);
void ht_color_calibrate(void);
void tests_ht_color(void);
void tests_ht_gyro(void);
void tests_ht_irlink(void);
void tests_digitemp(void);
void tests_bt(void);
void tests_bt2(void);
void tests_fs(void);
void tests_defrag(void);
void tests_fantom(void);
void tests_gdbdebug(void);

void tests_all(void);

#endif /* __NXOS_TESTS_TESTS_H__ */
