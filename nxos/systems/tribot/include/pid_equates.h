/** @file pid_equates.h
 *  @brief Definitions of PID Controller constants, etc.
 */

/* Copyright (C) 2007-2013 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __NXOS_SYSTEMS_PID_EQUATES_H__
#define __NXOS_SYSTEMS_PID_EQUATES_H__


/* 2s Complement macro	*/
    .macro   com  reg
    neg      \reg, \reg
#if 0
	// This is wrong, neg already convert it to the 2's complement since it is equivalent to rsbs \reg, \reg, #0
	add      \reg, \reg, #1
#endif
	.endm

/** @addtogroup pid */
/*@{*/

    .equ  MAX_LONG_PLUS1, 2147483648   @ 32 bit signed
    .equ  MAX_SHORT_PLUS1, 32768       @ 16 bit signed
    .equ  SCALING_SHIFT, 16            @ Scaling factor: 65536
    
/* PID Control data structure offsets */
    .equ    KP, 0                      @ Proportional Factor
    .equ    KI, 4                      @ Integral Factor
    .equ    KD, 8                      @ Derivative Factor
    .equ    ERR_Max, 12                @ Limit for ERR
    .equ    ERRSUM_Max, 16             @ Limit for ERR_Sum
    .equ    STEADY_STATE_Thresh, 20    @ Threshold for determining steady state
    /* State variables */
    .equ    ERR_Sum, 24                @ sum[e(k)]|(k=0..n)
    .equ    Y_Prev, 28                 @ y(n-1)
    .equ    STEADY_STATE_Count, 32     @ Count of error within STEADY_STATE_Thresh
    .equ    REF_Val, 36                @ Reference (Target / Set Point) value y0
    .equ    SIZEOF_PID_CONTROL, 40

/*@}*/

#endif /* __NXOS_SYSTEMS_PID_EQUATES_H__ */
