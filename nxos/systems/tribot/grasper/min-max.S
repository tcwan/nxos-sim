/** @file min-max.S
 *  @brief Min-Max Algorithm Module
 *
 * Finds the minimum and maximum values in an unsigned byte (char) array.
 *
 *	bool min_max(unsigned int n, unsigned char *array, unsigned char *min, unsigned char *max);
 *
 * This file must be processed using cpp before assembly.
 */

/* Copyright (C) 2007-2012 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#define __ASSEMBLY__
#include "base/interwork.h"
#include "armdebug/Debugger/debug_stub.h"
#include "systems/tribot/include/tribot.h"

	.equ	MIN_INITVAL, 255
	.equ	MAX_INITVAL, 0

.code 32
.text
.align 	4

/*	Min-Max Unsigned Byte Routine
 *    Parameters:
 *      R0: n, number of items in byte array
 *      R1: *array, pointer to unsigned byte array
 *      R2: *min, pointer to min value (byte)
 *      R3: *max, pointer to max value (byte)
 *
 *    Scratch Registers:
 *      R0: counter (array index)
 *      R4: Temporary value storage
 *      R5: Current Min value
 *      R6: Current Max value
 *
 *    Returns:
 *      R0: Boolean: TRUE if algorithm ran, FALSE otherwise (n == 0)
 *
 * R1: counter
 * R2: readings Array Pointer
 * R3: min value
 * R4: max value
 */

    arm_interwork min_max_ubyte
    push	{r4-r6, lr}
    teq		r0, #0               /* Sanity check, don't process n == 0 */
    beq		done_min_max         /* Leave things unchanged */
init_min_max:
    mov  	r5, #MIN_INITVAL     /* Initialize min to largest 8-bit value */
    mov  	r6, #MAX_INITVAL     /* Initialize max to smallest 8-bit value */

min_max_loop:
    sub  	r0, r0, #1    	     /* counter = counter - 1 */
    /* If */
    ldrb	r4, [r1, r0]   /* Retrieve array[counter] into r4 */
check_min:
    cmp		r4, r5         /* check array[counter] (in r4) < min */
    movlo	r5, r4         /* Min = array[counter] */
check_max:
    cmp		r4, r6         /* check array[counter] (in r4) > max */
    movhi	r6, r4         /* Max = array[counter] */
next_iter:
    teq		r0, #0         /* Compare counter/index r0 against zero */
    bne		min_max_loop   /* NE: r0 is non-zero */
exit_min_max_loop:
    strb	r5, [r2]       /* Store min into memory location */
    strb	r6, [r3]       /* Store max into memory location */
    mov		r0, #TRUE      /* Always activated */

done_min_max:
	pop		{r4-r6, pc}

.end
