/** @file prng.h
 *  @brief basic Pseudo Random Number Generator
 *
 *
 * Taken from Stack Overflow
 * http://stackoverflow.com/questions/5437351/random-number-generation-c-on-arm7
 */

/* Copyright (C) 2011 by Blindy (StackOverflow)
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */
#ifndef __PRNG_H__
#define __PRNG_H__

#include "base/_c_arm_macros.h"

/* Assembly Language Defines */
#ifdef __ASSEMBLY__
  .extern       srand		       	/* Initialize PRNG using seed */
  .extern		rand_r				/* Generate next PRNG using seed, and return the PRNG value */
  .extern		rand				/* Generate next PRNG value */
#else

/** @addtogroup lib */
/*@{*/

/** @defgroup prng Pseudo Random Number Generator
 *
 * Simple Pseudo Random Number Generator taken from Stackoverflow.
 */
/*@{*/


#define RAND_MAX 0x7fffffff			/**< Hardcoded 32-bit PRNG limit */

/** Initialize PRNG using seed.
 *
 * @param seed new initial value of PRNG. Must be non-zero
 */
FUNCDEF void srand(unsigned int seed);


/** Generate next PRNG using seed, and return the PRNG value.
 *
 * Internal Routine.
 *
 * @param seed previous value of PRNG.
 * @return PRNG value.
 */
FUNCDEF int rand_r(unsigned int *seed);

/** Generate next PRNG value.
 *
 * @return PRNG value.
 */
FUNCDEF int rand(void);


/*@}*/
/*@}*/

#endif

#endif /* __PRNG_H__ */
