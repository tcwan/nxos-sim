/** @file prng.c
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

#include "prng.h"

static unsigned int next = 1;

FUNCDEF int rand_r(unsigned int *seed)
{
       *seed = *seed * 1103515245 + 12345;
       return (*seed % ((unsigned int)RAND_MAX + 1));
}

FUNCDEF int rand(void)
{
       return (rand_r(&next));
}

FUNCDEF void srand(unsigned int seed)
{
       next = seed;
}
