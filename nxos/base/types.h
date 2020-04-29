/** @file types.h
 *  @brief Basic type definitions for the Arm7 platform.
 */

/* Copyright (c) 2007,2008 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_BASE_TYPES_H__
#define __NXOS_BASE_TYPES_H__

/** @addtogroup typesAndUtils */
/*@{*/

typedef unsigned char U8; /**< Unsigned 8-bit integer. */
typedef signed char S8; /**< Signed 8-bit integer. */
typedef unsigned short U16; /**< Unsigned 16-bit integer. */
typedef signed short S16; /**< Signed 16-bit integer. */
typedef unsigned long U32; /**< Unsigned 32-bit integer. */
typedef signed long S32; /**< Signed 32-bit integer. */

#ifndef __SIZE_TYPE__
#define __SIZE_TYPE__ U32 /**< Used to go conform with gcc, otherwise we are
                            risking an error because of conflicting types for size_t */
#endif
typedef __SIZE_TYPE__ size_t; /**< Abstract size type, needed by the memory allocator. */

typedef U8 bool; /**< Boolean data type. */
#define FALSE (0) /**< False boolean value. */
#define TRUE (!FALSE) /**< True boolean value. */

#ifndef NULL
/** Definition of the NULL pointer. */
#define NULL ((void*)0)
#endif

/** Hardware register definition for DE1-SoC support */
typedef volatile unsigned long HW_REG; 		/**< Volatile Hardware I/O 32-bit register. */
typedef volatile unsigned short HW_REG16;	/**< Volatile Hardware I/O 16-bit register. */
typedef volatile unsigned char HW_REG8;		/**< Volatile Hardware I/O  8-bit register. */

/** A function that takes no arguments and returns nothing. */
typedef void (*nx_closure_t)(void);

/*@}*/

#endif
