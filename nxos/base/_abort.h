/** @file _abort.h
 *  @brief Abort handler API.
 */

/* Copyright (c) 2007,2008 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE__ABORT_H__
#define __NXOS_BASE__ABORT_H__

/** @addtogroup coreinternal */
/*@{*/

/** Process a data or prefetch abort.
 *
 * @param data 2 if the abort is a spurious irq, 1 if the abort is a
 * data abort, 0 if it is a prefetch abort.
 * @param pc The address of the instruction that caused the abort.
 * @param cpsr The CPU state at the time of abort.
 *
 * @note This function never returns, and results in the brick locking
 * up completely.
 */
void nx__abort(U32 data, U32 pc, U32 cpsr);

/*@}*/

#endif /* __NXOS_BASE__ABORT_H__ */
