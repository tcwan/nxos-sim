/** @file _memcpy.h
 *  @brief Flash memory aware memory
 */

/* Copyright (c) 2009 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE__MEMCPY_H__
#define __NXOS_BASE__MEMCPY_H__

#include "base/types.h"

/** Native implementation of memory copy routine.
 * Note: The buffers should not overlap in memory
 *
 * @param dest The destination buffer start address.
 * @param src  The source buffer start address.
 * @param n    Number of bytes to copy
 *
 * @return Pointer to destination buffer.
 */
void *_memcpy(void *dest, const void *src, size_t n);

#endif /* __NXOS_BASE__MEMCPY_H__ */
