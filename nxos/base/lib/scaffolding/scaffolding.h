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

/* Assembly Language Defines */
#ifdef __ASSEMBLY__
  .extern       nx_proginit                    /* Program Initialization Routine */
  .extern       nx_progshutdown                /* Program Shutdown Routine */
  .extern       nx_progtitle                   /* Display Title string on LCD Screen */
  .extern       nx_progcontent                 /* Display Content string on LCD Screen */
#else

FUNCDEF void nx_proginit(void);                /* Program Initialization Routine */
FUNCDEF void nx_progshutdown(void);            /* Program Shutdown Routine */
FUNCDEF void nx_progtitle(char *string);       /* Display Title string on LCD Screen */
FUNCDEF void nx_progcontent(char *string);     /* Display Content string on LCD Screen */

#endif

#endif /* __SCAFFOLDING_H__ */
