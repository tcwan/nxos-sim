/** @file division.S
 *  @brief Long Division Algorithm
 *
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

/* ulongdiv
 *
 * Unsigned Long Division Routine
 * Based on 'http://www.tofla.iconbar.com/tofla/arm/arm02/index.htm'
 * for Archive Magazine, algorithm written by Harriet Bazley
 *
 * On Entry:
 *   R0: Numerator
 *   R1: Divisor
 *
 * On Exit:
 *   R0: Quotient
 *   R1: Remainder
 *   R2,R3: Preserved (Needed by pid.S routines)
 */
#include "base/interwork.h"

/* The algorithm uses divides R1 by R2, so instead of
 * rewriting everything, we just move the inputs to
 * the right places
 */
    arm_interwork ulongdiv
    PUSH   {R2, R3}
    MOV    R2, R1
    MOV    R1, R0
    
@ Code from example follows (cleaned up)
    MOV    R0, #0            @ clear R0 to accumulate result
    CMP    R2, #0
    BEQ    ulongdiv_end      @ check for divide by zero!
                             @ R0: 0, R1: Numerator

    MOV    R3, #1            @ set bit 0 in R3, which will be shifted left then right

ulongdiv_start:
    CMP    R2, R1
    MOVLS  R2, R2, LSL #1    @ shift R2 left until it is about to be bigger than R1
    MOVLS  R3, R3, LSL #1    @ shift R3 left in parallel in order to flag how far we have to go
    BLS    ulongdiv_start

ulongdiv_next:
    CMP    R1, R2            @ carry set if R1>R2 (do not ask why) [CS == HS]
    SUBCS  R1, R1, R2        @ subtract R2 from R1 if this would give a positive answer
    ADDCS  R0, R0, R3        @ and add the current bit in R3 to the accumulating answer in R0

    MOVS   R3, R3, LSR #1    @ Shift R3 right into carry flag
    MOVCC  R2, R2, LSR #1    @ and if bit 0 of R3 was zero, also shift R2 right
    BCC    ulongdiv_next     @ If carry not clear, R3 has shifted back to where it started, 
                             @ and we can end
ulongdiv_end:
    POP    {R2, R3}
    BX     LR                @ exit routine, R0: quotient, R1: remainder

