/** @file pid.S
 *  @brief Discrete PID Controller Algorithm
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

/* Discrete PID Controller Implementation
 * Based on Atmel Applicaiton Note AVR221
 * and libnxter (http://libnxter.sourceforge.net/)
 *
 *
 * The inputs and outputs have a resolution of 16 bits.
 * The PID Controller output is defined as:
 *
 * u(n) = KP x Err(n) + KI x sum[e(k)]|(k=0..n) + KD x [y(n) - y(n-1)]
 * Err(n) = RefVal - y(n)
 *
 * This Discrete PID uses 32-bit Integers to store the
 * parameters. However, to improve the accuracy of the
 * calculations, each P,I,D term is scaled using the
 * Scaling factor internally.
 */

#include "base/interwork.h"
#include "systems/tribot/include/pid_equates.h"
	.extern  ulongdiv
    

.text
.align 4
@===========================================================
@ InitPID
@ 
@ void InitPID(struct PID_Control *pid, ulong alphaKP, ulong alphaKI,
@              ulong alphaKD, ulong STEADY_STATE_Thresh);
@
@ ARM routine to initialize PID Controller
@ Call once at beginning of program
@ The P,I,D factors are multiplied
@ by the Scaling Factor to improve resolution
@ internally
@
@ On Entry:
@   R0: PID_Control Struct Pointer
@   R1: alphaKP
@   R2: alphaKI
@   R3: alphaKD
@   Stack: STEADY_STATE_Thresh
@
@ On Exit:
@   R0,R1,R2,R3: Destroyed
@
@===========================================================
    arm_interwork InitPID
    push    {r4, fp, lr}
    add     fp, sp, #8                 @ FP points to LR
 
@ The Scaling should be performed before calling InitPID 
@ Otherwise the less significant bits would be lost
@    mov     r4, #SCALING_SHIFT
@    lsl     r1, r1, r4
@    lsl     r2, r2, r4
@    lsl     r3, r3, r4
    
    mov     r4, r0                     @ Keep PID Control Struct Pointer in R4
    
    str     r1, [r4, #KP]
    str     r2, [r4, #KI]
    str     r3, [r4, #KD]
    ldr     r3, [fp, #4]               @ Retrieve Steady State Threshold
    str     r3, [r4, #STEADY_STATE_Thresh]
    
    
    mov     r3, #1
    add     r2, r2, r3                 @ R2 = KI + 1 (keep for later)
    add     r1, r1, r3                 @ R1 = KP + 1
    rsb     r0, r3, #MAX_SHORT_PLUS1   @ Max Signed Short is 32767
    bl      ulongdiv                   @ R0 = MAX_SHORT / (KP + 1)
    str     r0, [r4, #ERR_Max]         @ Limit for Error
    rsb     r0, r3, #MAX_LONG_PLUS1    @ Max Signed Long is 2147483647
    asr     r0, r0, #1                 @ MAX_LONG/2
    mov     r1, r2                     @ Retrieve R1 = KI + 1 
    bl      ulongdiv                   @ R0 = (MAX_LONG/2) / (KI + 1)
    str     r0, [r4, #ERRSUM_Max]      @ Limit for Error Sum

    @ Initialize State variables
    mov     r0, #0
    str     r0, [r4, #ERR_Sum]
    str     r0, [r4, #Y_Prev]
    str     r0, [r4, #STEADY_STATE_Count]
    str     r0, [r4, #REF_Val]
    pop     {r4, fp, lr}
    bx      lr
    
@===========================================================
@ SetPIDReferenceVal
@
@ void SetPIDReferenceVal(struct PID_Control *pid, ulong Reference);
@ 
@ ARM routine to set PID Controller output (y) reference (target) value
@ Call to initiate PID control
@
@ On Entry:
@   R0: PID_Control Struct Pointer
@   R1: Reference (target) Value
@
@ On Exit:
@   R1: Destroyed
@
@===========================================================
    arm_interwork SetPIDReferenceVal
    @ Initialize State variables
    str     r1, [r0, #REF_Val]
    mov     r1, #0
    str     r1, [r0, #ERR_Sum]
    str     r1, [r0, #Y_Prev]
    str     r1, [r0, #STEADY_STATE_Count]
    bx      lr

@===========================================================
@ CheckPIDEnd
@
@ Bool CheckPIDEnd(struct PID_Control *pid);
@ 
@ ARM routine to set PID Controller output (y) target value
@ Call to initiate PID control
@
@ On Entry:
@   R0: PID_Control Struct Pointer
@
@ On Exit:
@   R0: 0: False, !0: True
@   R1, R2: Destroyed
@
@===========================================================
    arm_interwork CheckPIDEnd
    ldr     r2, [r0, #STEADY_STATE_Thresh]
    ldr     r1, [r0, #STEADY_STATE_Count]
    mov     r0, #0                     @ Setup Return Value = False
    teq     r2, #0                     @ Zero threshold
    bxeq    lr						   @ return False
    cmp     r1, r2                     @ Is STEADY_STATE_Count > STEADY_STATE_Thresh?
    mvnhi   r0, #0                     @ Yes, Return True
    bx      lr

@===========================================================
@ PIDController
@
@ ulong PIDController(struct PID_Control *pid, ulong SystemStatus);
@ 
@ ARM routine to set PID Controller output (u) value
@ Call to initiate next step in PID control
@
@ On Entry:
@   R0: PID_Control Struct Pointer
@   R1: System Status (Feedback) Value y(n) 
@
@ On Exit:
@   R0: PID Controller Output: u(n) [16-bit resolution]
@       0 = Steady State reached, !0 = u(n)
@   R0,R1,R2,R3: Destroyed
@
@ R4: PID_Control Struct Pointer
@ R5: y(n) - y(n-1)
@===========================================================
    arm_interwork PIDController
    push    {r4,r5}
    mov     r3, #1                     @ Used for calculating LIMITS
    mov     r4, r0                     @ Use R4 for PID Control Struct Pointer
    ldr     r0, [r4, #REF_Val]         @ R0: Reference Value
    ldr     r5, [r4, #Y_Prev]          @ R5: y(n-1)
    sub     r5, r1, r5                 @ R5: y(n) - y(n-1)
    str     r1, [r4, #Y_Prev]          @ Update Y_Prev with y(n)
    sub     r0, r0, r1                 @ R0: Error = RefVal - y(n)

@ Check for Steady State
    teq     r0, #0
    bne     calc_pid                   @ Non-zero error, so not steady state
    ldr     r2, [r4, #STEADY_STATE_Thresh]
    teq     r2, #0                     @ Non-zero threshold, so increment count
    ldrne   r1, [r4, #STEADY_STATE_Count]
    addne   r1, r1, #1
    strne   r1, [r4, #STEADY_STATE_Count] @ Store updated Steady State Count
    cmp     r1, r2                     @ Is STEADY_STATE_Count > STEADY_STATE_Thresh?
    movhi   r0, #0                     @ Zero PID output
    bhi     done_pid
    
@ Calculate PTerm
calc_pid:
    ldr     r2, [r4, #ERR_Max]         @ R2: Err_Max
    cmp     r0, r2                     @ Error > Err_Max?
    rsbgt   r2, r3, #MAX_SHORT_PLUS1   @ Yes, Set R2: PTerm to MAX_SHORT
    bgt     exit_pterm_calc
    com     r2                         @ R2: -Err_Max
    cmp     r0, r2                     @ Error < -Err_Max?
    bge     pterm_calc                 @ No, so calculate PTerm
    mov     r2, #MAX_SHORT_PLUS1       @ R2: MAX_SHORT + 1
    com     r2                         @ R2: MIN_SHORT
    b       exit_pterm_calc            @ Else, Set R2: Pterm to MIN_SHORT
pterm_calc:
    ldr     r1, [r4, #KP]
    mul     r2, r0, r1                 @ R2 = KP x Error

exit_pterm_calc:    
@ R2 contains PTerm, Calculate ITerm
    ldr     r1, [r4, #ERR_Sum]
    add     r0, r1, r0                 @ R0: ERR_Sum + Error
    ldr     r1, [r4, #ERRSUM_Max]
    cmp     r0, r1                     @ (ERR_Sum + Error) > ERR_Sum_Max?
    strgt   r1, [r4, #ERR_Sum]         @ Yes, Set ERR_Sum = ERR_Sum_Max 
    rsbgt   r1, r3, #MAX_LONG_PLUS1    @ and Set R1: ITerm to MAX_LONG/2
    asrgt   r1, r1, #1
    bgt     exit_iterm_calc
    com     r1                         @ R1: -Err_Sum_Max
    cmp     r0, r1                     @ (ERR_Sum + Error) < -ERR_Sum_Max?
    bge     iterm_calc                 @ No, so calculate ITerm
    com     r1
    str     r1, [r4, #ERR_Sum]         @ Set ERR_Sum = -ERR_Sum_Max 
    mov     r1, #(MAX_LONG_PLUS1/2)    @ R1: (MAX_LONG + 1) / 2
    com     r1                         @ R1: MIN_LONG/2
    b       exit_iterm_calc            @ Else, set R1: ITerm to MIN_LONG/2
iterm_calc:
    str     r0, [r4, #ERR_Sum]         @ ERR_Sum = ERR_Sum + Error
    ldr     r1, [r4, #KI]
    mul     r1, r0, r1                 @ R1 = KI x ERR_Sum (new)

exit_iterm_calc:
@ R2 contains PTerm, R1 contains ITerm, calculate DTerm
    ldr     r3, [r4, #KD]
    mul     r0, r3, r5                 @ R0 = KD x [y(n) - y(n-1)]

@ R2 contains PTerm, R1 contains ITerm, R0 contains DTerm
    add     r0, r0, r1                 @ R0 = DTerm + ITerm
    add     r0, r2, r0                 @ R0 = PTerm + DTerm + ITerm
    asr     r0, r0, #SCALING_SHIFT

@ Limit to [MIN_SHORT,MAX_SHORT], which is done automatically by the ASR
@ if we are using SCALING_SHIFT of 16
done_pid:
    pop     {r4,r5}
    bx      lr


.end
