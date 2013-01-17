/** @file helper-routines.S
 *  @brief Miscellaneous Algorithms Module
 *
 * This file must be processed using cpp before assembly.
 */

/* Copyright (C) 2007-2013 the NxOS developers
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
 *     Finds the minimum and maximum values in an unsigned byte (char) array.
 *
 *	   bool min_max(unsigned int n, unsigned char *array, unsigned char *min, unsigned char *max);
 *
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
	pop		{r4-r6, lr}
	bx		lr

#if 0
/*	MemMove Byte Copy Routine
 *     Finds the minimum and maximum values in an unsigned byte (char) array.
 *
 *	   void *memmove(void *s1, const void *s2, size_t n);
 *
 *    Parameters:
 *      R0: dest memory pointer s1
 *      R1: source memory pointer s2
 *      R2: number of bytes n
 *
 *    Scratch Registers:
 *      R0: Destination Buffer Pointer
 *      R1: Source Buffer Pointer
 *      R2: Number of Bytes Remaining
 *      R3: Pointer Increment/Decrement
 *      R4: Byte to be copied
 *
 *    Returns:
 *      R0: dest memory pointer s1
 *
 *
 *
 * Given Source Begin, Dest Begin, Block Size
 * Calculate Source End = Source Begin + Block Size
 * If (Source Begin < Dest Begin < Source End)
 *	Source Pointer = Source End - 1
 *  Calculate Dest End = Dest Begin + Block Size
 *	Dest Pointer = Dest End - 1
 *	Pointer Increment = Decreasing (negative)
 * Else // If (Dest Begin < Source Begin < Dest End) or Non overlap
 *	Source Pointer = Source Begin
 *	Dest Pointer = Dest Begin
 *	Pointer Increment = Increasing (positive)
 * Endif
 * Counter = Block Size
 * Repeat
 *	*Dest Pointer = *Source Pointer
 *	Source Pointer = Source Pointer + Pointer Increment
 *	Dest Pointer = Dest Pointer + Pointer Increment
 *	Counter = Counter - 1
 * Until (Counter == 0)
 *
 */


    arm_interwork memmove
    PUSH   {R0, R4, LR}    @ Keep s1, R4
    ADD    R3, R1, R2      @ R3: Source End := Source Begin (s2) + n
    CMP    R0, R1          @ Compare Dest Begin (s1) vs. Source Begin (s2)
    BLS    memmove_else    @ Source Begin >= Dest Begin, goto else
    CMP    R0, R3          @ Compare Dest Begin (s1) vs. Source End
    BHS    memmove_else    @ Dest Begin >= Source End, goto else
memmove_then:
    SUB    R1, R3, #1      @ Source Pointer := Source End - 1
    ADD    R0, R0, R2      @ R0 := Dest End := Dest Begin (s1) + n
    SUB    R0, R0, #1      @ Dest Pointer := Dest End - 1
    MOV    R3, #-1         @ R3: Negative Pointer Increament
    B      memmove_loop
memmove_else:
    MOV    R3, #1          @ R3: Positive Pointer Increment
    @ R0, R1 already contain Dest Begin and Source Begin Pointers

memmove_loop:
    LDRB   R4, [R1], R3    @ R4 = *Source Pointer, update Source Pointer
    STRB   R4, [R0], R3    @ *Dest Pointer = R4, update Dest Pointer
    SUBS   R2, R2, #1
    BNE    memmove_loop

memmove_exit:
    POP    {R0, R4, LR}    @ Restore R0, R4, retrieve LR to PC, exit
    BX     LR
#endif

/*	MemCmp Buffer Compare Routine
 *     Determines whether the two buffers have identical unsigned byte contents.
 *
 *	   int memcmp(void *s1, const void *s2, size_t n);
 *
 *    Parameters:
 *      R0: first buffer pointer s1
 *      R1: second buffer pointer s2
 *      R2: number of bytes n
 *
 *    Scratch Registers:
 *      R0: First Buffer Pointer
 *      R1: Second Buffer Pointer
 *      R2: Number of Bytes Remaining
 *      R3: Byte in First Buffer to be compared
 *      R4: Byte in Second Buffer to be compared
 *
 *    Returns:
 *      R0: 0 if identical, else difference between first non-identical byte in buffers
 *
 */


    arm_interwork memcmp
    PUSH   {R4, LR}        @ Keep R4, LR
    /* Sanity Checks */
    TEQ    R2, #0
    BEQ    memcmp_equal    @ Zero length comparisons are always equal
    CMP    R0, R1
    BEQ    memcmp_equal    @ Comparing buffer to itself will always be equal

memcmp_loop:
    LDRB   R3, [R0], #1    @ Load byte, increment First Buffer Pointer
    LDRB   R4, [R1], #1    @ Load byte, increment Second Buffer Pointer
    SUBS   R3, R3, R4      @ R3 = R3 - R4
    MOVNE  R0, R3          @ Move difference to R0 as return value
    BNE    memcmp_exit     @ Bytes not equal, exit
    SUBS   R2, R2, #1
    BNE    memcmp_loop     @ While bytes remain, keep going

memcmp_equal:
	MOV    R0, #0          @ Flag as equal
memcmp_exit:
    POP    {R4, LR}        @ Restore R4, Retrieve LR to PC, exit
    BX     LR

/* Jump Table Dispatcher
 *
 *   Internal routine used by various Dispatchers.
 *
 * On Entry:
 *     R0: Jump Table Start Address
 *     R1: Number of Jump Table entries
 *
 * Register Usage:
 *	   R4: Jump Table Start Address
 *	   R5: Jump Table index
 *
 *   In this implementation, we iterate from last entry to first entry
 */
    arm_interwork jumptable_dispatcher
	push	{r4, r5, lr}
	mov		r4, r0					/* Use R4 and R5 to keep input parameters since R0 & R1 will be destroyed */
	sub		r5, r1, #1				/* Convert jump table count to array index */
dispatcher_loop:
	ldr		r0, [r4, r5, lsl #2]	/* Load dispatch routine address from table */
    mov		lr, pc					/* LR = PC + 8 (pipeline) == done_dispatch */
    mov		pc, r0					/* Dispatch Behavior */
done_dispatch:
	subs	r5, r5, #1
	bge		dispatcher_loop			/* Continue if index is 0 or positive */
exit_jumptable_dispatcher:
	pop		{r4, r5, lr}
	bx		lr

.end
