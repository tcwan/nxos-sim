/** @file scaffolding.h
 *  @brief ARM Program Scaffolding Includes
 *   This header defines the various program
 *   init and shutdown support routines common
 *   to all NxOS applications
 *
 */

/* Copyright (C) 2007-2011 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __SCAFFOLDING_H__
#define __SCAFFOLDING_H__


#include "base/_c_arm_macros.h"

/** @name DE1 Button Enums
 *
 * Altera DE1-SoC Buttons
 * The enums must be consecutive, starting from 0
 * The values are taken from button.h but have different names to avoid clashing with the existing definitions
 */
/*@{*/
ENUM_BEGIN
ENUM_VALASSIGN(DE1_BTN_NONE, 0)  /**< Default button value. */
ENUM_VAL(DE1_BTN_0)              /**< Button 0. */
ENUM_VAL(DE1_BTN_1)              /**< Button 1. */
ENUM_VAL(DE1_BTN_2)       	     /**< Button 2. */
ENUM_VAL(DE1_BTN_3)       	     /**< Button 3. */
ENUM_END(nx_button_t)
/*@}*/

/* Assembly Language Defines */
#ifdef __ASSEMBLY__
  .extern       nx_proginit                    /* Program Initialization Routine */
  .extern       nx_progshutdown                /* Program Shutdown Routine */
  .extern       nx_progtitle                   /* Display Title string on LCD Screen */
  .extern       nx_progcontent                 /* Display Content string on LCD Screen */
  .extern		nx_getbutton				   /* Retrieve NXT button press */
#else

/**
 * Common Startup/Shutdown Routines for NxOS programs
 */

/**
 * Initialize NxOS subsystems
 */
FUNCDEF void nx_proginit(void);                /* Program Initialization Routine */

/**
 * Shut down NxOS subsystems
 */
FUNCDEF void nx_progshutdown(void);            /* Program Shutdown Routine */

/**
 * Display Title string on LCD
 *    @param string: Null-terminated string
 */
FUNCDEF void nx_progtitle(char *string);       /* Display Title string on LCD Screen */

/**
 * Display Content string on LCD (Row 2)
 *    @param string: Null-terminated string
 */
FUNCDEF void nx_progcontent(char *string);     /* Display Content string on LCD Screen */

/**
 * Display Content string on LCD (Row 4)
 *    @param string: Null-terminated string
 */
FUNCDEF void nx_progcontent2(char *string);     /* Display Content string on LCD Screen */

/**
 * Display Content string on LCD (Row row)
 *    @param string: Null-terminated string
 *    @param row int: Row Index
 */
FUNCDEF void nx_progcontentX(char *string, int row);     /* Display Content string on LCD Screen */

/**
 * Get Button value from NXT
 *    @return nx_button_t
 */
FUNCDEF  nx_button_t nx_getbutton(void);     /* Retrieve enum value of NXT Button press */

#endif

#endif /* __SCAFFOLDING_H__ */
