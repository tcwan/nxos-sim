/** @file tribot.h
 *  @brief Tribot Program Includes
 *   [What does this component do?]
 *
 * [Optionally, more stuff about the component in general.]
 */

/* Copyright (C) 2007-2010 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __TRIBOT_H__  /* __${include_guard_symbol}__ */
#define __TRIBOT_H__  /* __${include_guard_symbol}__ */


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

#endif /* __${include_guard_symbol}__ */
