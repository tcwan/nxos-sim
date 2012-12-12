/* Copyright (C) 2007 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

.data
.align
	.global irq_state
irq_state:
interrupts_count: .long 1
	.equ	IRQ_INTR_CNT, (interrupts_count - irq_state)
#if defined (__DBGENABLE__)
	.global irq_stack_frame_address

irq_nesting_level: .long -1		/* -1: Not in Interrupt; 0: Top Level Interrupt; 1+: Interrupt Nesting Level */
irq_stack_frame_address: .long 0
irq_spurious_count: .long 0
	.equ	IRQ_NEST_LVL, (irq_nesting_level - irq_state)
	.equ	IRQ_STK_FRAME, (irq_stack_frame_address - irq_state)
	.equ	IRQ_SPURIOUS, (irq_spurious_count - irq_state)
#endif

.text
.code 32
.align 0

#include "asm_decls.h"
#define __ASSEMBLY__
#include "at91sam7s256.h"

/**********************************************************
 * Default handlers for unknown IRQ and FIQ interrupts, and
 * unknown exception handler.
 */
        .global nx__default_irq
        .global nx__default_fiq
        .global nx__unhandled_exception
nx__default_irq:
nx__default_fiq:
nx__unhandled_exception:
        b nx__unhandled_exception

#if defined (__DBGENABLE__)
/* Enhanced NxOS Nested Interrupt Handler.
 * Based on notes from:
 * "Building Bare Metal ARM Systems with GNU," Miro Samek,
 * 2007, http://www.state-machine.com
 *
 * No context information is stored in IRQ mode.
 * Instead, the interrupt context will be stored
 * in the following priviledged modes:
 *
 * User/System Task (USR/SYS) -> System (SYS) Mode
 * NxOS Task (SVC) -> Supervisor (SVC) Mode
 * Debugger Task (ABT/UNDEF) -> Abort (ABT) Mode
 * All other reserved modes -> Abort (ABT) Mode
 *
 * The interrupt stack frame consists of the following
 * Registers: SPSR_irq, PC_irq, LR, R12, R3, R2, R1, R0
 * which is identical to the ARM v7-M hardware
 * interrupt stack frame (see ref: Miro Samek).
 *
 * This version also keeps track of the interrupt nesting
 * level and stores the top level interrupted instruction
 * address in order to let the Debugger know which instruction
 * should be breakpointed when invoking the Debugger from
 * Platform Operation Mode.
 */

        .global nx__irq_handler
nx__irq_handler:
		/* In IRQ Mode (IRQ Disabled, FIQ Enabled) */
		/* The IRQ stack is not used at all. Hence, SP is used as a temporary variable R13 */
		mrs		r13, spsr		/* Retrieve SPSR_irq */

        /* Compare the SPSR mode bits to both 0000 and 1111 (usr/sys mode). */
        ands 	r13, r13, #0x0F		/* eq (0) == User Mode */
        eornes 	r13, r13, #0x0F		/* ne (!0) && eor #0x0F => eq (0) == SYS mode) */
        msreq	cpsr_c, #(MODE_SYS | IRQ_MASK)	/* Match, so switch to SYS Mode */
		beq		_irq_save_stack_frame

		mrs		r13, spsr			/* Reload SPSR_irq */
		and		r13, r13, #MODE_MASK	/* check for other modes */
		teq		r13, #MODE_SVC		/* Supervisor Mode? */
        msreq	cpsr_c, #(MODE_SVC | IRQ_MASK)	/* Match, so switch to SVC Mode */
		beq		_irq_save_stack_frame

        msr		cpsr_c, #(MODE_ABT | IRQ_MASK)	/* Else, goto Abort Mode (catch all) */

_irq_save_stack_frame:
		/* In target privileged mode (IRQ Disabled, FIQ Enabled) */
		sub		sp, sp, #(2*4)			/* Reserve stack space for SPSR and PC of Interrupted instruction */
		stmfd	sp!, {r0-r3, r12, lr}	/* Save AAPCS clobbered registers to interrupt stack frame */
		add		r0, sp, #(8*4)			/* Pass top of current interrupt stack frame to IRQ mode */

		mrs		r1, cpsr				/* retrieve current privileged mode (for mode switchback) */
        msr		cpsr_c, #(MODE_IRQ | IRQ_MASK)	/* Switch to IRQ mode to save SPSR_irq and PC_irq */
		/* In IRQ Mode (IRQ Disabled, FIQ Enabled) */
		sub		r2, lr, #4				/* Adjust return address (interrupted instruction address), copy to R2 for stacking */
		mrs		r3, spsr				/* Retrieve SPSR_irq to R3 for stacking */
		stmfd	r0, {r2, r3}			/* completed saving interrupt stack frame (SPSR_irq, PC_irq, LR, R12, R3, R2, R1, R0) */

		/* Interrupt Handler Housekeeping */
		ldr		r3, =irq_state
		ldr		r2, [r3, #IRQ_NEST_LVL]
		adds	r2, r2, #1				/* Raise Nesting Level (0: Top Level Interrupt) */
		str		r2, [r3, #IRQ_NEST_LVL]
		movgt	r0, #0					/* Not Top Level Interrupt, clear Interrupted Stack Frame Address */
		str		r0, [r3, #IRQ_STK_FRAME] /* Else Save Top Level Interrupt Stack Frame Address (for Debugger) */

        /* Get the IVR value. */
        ldr 	r2, =AT91C_BASE_AIC
        ldr 	r3, [r2, #AIC_IVR]

        /* If we're in Protected mode (usually for JTAG debugging), we
         * need to write back to the IVR register to tell the AIC it
         * can dispatch other higher priority interrupts again.
         * In normal mode, this has no effect, so we can safely do it.
         */
        str 	r2, [r2, #AIC_IVR]

		and		r1, r1, #MODE_MASK		/* Enable IRQ (& FIQ) */
		msr		cpsr_c, r1				/* switch back to previous privileged mode */

_irq_dispatch_aic_ivr:
		/* In target privileged mode (IRQ & FIQ Enabled) */
        /* Dispatch the IRQ to the registered handler. */
        mov 	lr, pc
        bx 		r3						/* Use R3 to dispatch Interrupt Handler, so that it is not clobbered by
        								 * default exception handlers
        								 */

_irq_exit_handler:
		/* Clean up and exit */
		mrs		r1, cpsr
		orr		r1, #IRQ_FIQ_MASK			/* Mask IRQ and FIQ */
		msr		cpsr_c, r1					/* Disable interrupts to restore context */

		/* In target privileged mode (IRQ & FIQ Disabled) */
		mov		r0, sp						/* Pass privileged mode SP to IRQ Mode */
		ldr		lr, [r0, #(5*4)]			/* Restore LR to privileged mode */
		add		sp, sp, #(8*4)				/* unstack interrupt stack frame from current privileged mode */

        /* Switch back to IRQ mode and tell the AIC that the interrupt has been
         * handled.
         */
        msr 	cpsr_c, #(MODE_IRQ | IRQ_FIQ_MASK)

		/* In IRQ Mode (IRQ & FIQ Enabled) */
        ldr 	lr, =AT91C_BASE_AIC
        str 	lr, [lr, #AIC_EOICR]

		/* Interrupt Handler Housekeeping */
		ldr		r3, =irq_state
		ldr		r2, [r3, #IRQ_NEST_LVL]
		sub		r2, r2, #1					/* Decrease nesting level */
		str		r2, [r3, #IRQ_NEST_LVL]

		ldr		r1, [r0, #(7*4)]			/* Load SPSR to R1 */
		msr		spsr_csxf, r1				/* Restore SPSR_irq */

		ldmfd	r0, {r0-r3, r12, lr, pc}^	/* Return execution to interrupted instruction, restore CPSR from SPSR_irq */
		/* Note: SP_irq does not contain an actual IRQ stack pointer,
		 * whereas LR_irq is not used, so it does not matter what value they have on exit
		 */

#else
/* This is the original NxOS Nested Interrupt Handler.
 * It only knows about User/System and SVC (Supervisor)
 * modes, and does not handle ABT (Abort)  mode operation
 * used by the Debugger correctly.
 *
 * The main issue has to do with how context information
 * for the top level interrupted routine (presumably
 * a User Task) is stored completely in the System stack,
 * whereas SVC top level routines as well as routines that
 * were interrupted by nested interrupts are stored in the
 * SVC stack, with partial state kept in the IRQ stack.
 * Since the Debugger operates in Abort mode, the
 * multiple context switches causes the nested interrupt
 * handler to get confused as to which is the correct
 * previous state to return execution to.
 *
 * It would be much cleaner if all context information
 * were kept in one stack, and context switching eliminated
 * to avoid context restoration issues.
 *
 * Unfortunately, IRQ mode cannot be used for nested
 * interrupt processing since a second IRQ occuring
 * during the execution of the BL instruction will
 * corrupt LR_irq by overwriting the subroutine return
 * address with the IRQ return address.
 * http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.faqs/1456.html
 */

/**********************************************************
 * IRQ entry/exit routine. This gets called for all
 * interrupts, saves state, switches to Supervisor mode,
 * enables nested IRQ handling, and calls the service
 * routing that was registered with the AIC for the given
 * IRQ.
 */
        .global nx__irq_handler
nx__irq_handler:
        /* Save the return address and return processor mode registers
         * on the IRQ stack. This is needed to allow nested interrupts,
         * where a higher-priority interrupt halts execution of a lower
         * priority interrupt.
         */
        sub lr, lr, #4
        stmfd sp!, {lr}
        mrs lr, spsr
        stmfd sp!, {lr}

        /* If we were interrupted out of User or System mode, there is a
         * scheduler running, and we need to save the task state nicely.
         *
         * This code is beautiful. An ode of joy to everything ARM. Conditional
         * execution, status bit updates, the next few instructions
         * have it all.
         *
         * Note that each code path pushes one final value on the
         * stack. This value is 0 if this interrupt is nested, and !0 if
         * this interrupt is interrupting a user task. This value will be
         * used to figure out how to return from the interrupt later.
         */

        /* Compare the SPSR mode bits to both 0000 and 1111 (usr/sys mode). */
        ands lr, lr, #0x0F
        eornes lr, lr, #0x0F

        /* Switch to either sys or svc mode to save the state.
         * If usr/sys -> sys
         * Else (any other state) -> svc
         */
        msreq cpsr_c, #(MODE_SYS | IRQ_FIQ_MASK)
        msrne cpsr_c, #(MODE_SVC | IRQ_FIQ_MASK)

        /* Save the state. If we're saving a user task, also grab the task
         * CPSR and PC from the IRQ stack.
         */
        stmfd sp!, {r0-r12,lr}
        ldreq r0, =__irq_stack__
        ldmeqdb r0, {r1,r2}
        stmeqfd sp!, {r1,r2}
        movne r0, #0

        /* Get the IVR value. */
        ldr r1, =AT91C_BASE_AIC
        ldr r2, [r1, #AIC_IVR]

        /* If we're in Protected mode (usually for JTAG debugging), we
         * need to write back to the IVR register to tell the AIC it
         * can dispatch other higher priority interrupts again.
         * In normal mode, this has no effect, so we can safely do it.
         */
        str r1, [r1, #AIC_IVR]

        /* Switch to Supervisor mode if necessary, reenable IRQ and FIQ handling,
         * and stack either 0 (nested IRQ) or the address of the IRQ stack base (for
         * a task IRQ).
         */
        msr cpsr_c, #MODE_SVC
        stmfd sp!, {r0}

        /* Dispatch the IRQ to the registered handler. */
        mov lr, pc
        bx r2

        /* Restore the interrupted state. How this is done depends on the value at
         * the top of the stack, as explained above.
         *
         * Note that we inhibit IRQ and FIQ handling during task restoration only if
         * we're restoring a user task. Getting interrupted while we're tweaking around
         * in system mode would confuse the IRQ handler into breaking things.
         */
        ldmfd sp!, {r0}
        cmp r0, #0
        msrne cpsr_c, #(MODE_SYS | IRQ_FIQ_MASK)
        ldrne r0, =__irq_stack__
        ldmnefd sp!, {r1,r2}
        stmnedb r0, {r1,r2}
        ldmfd sp!, {r0-r12,lr}

        /* Switch back to IRQ mode and tell the AIC that the interrupt has been
         * handled.
         */
        msr cpsr_c, #(MODE_IRQ | IRQ_FIQ_MASK)
        ldr lr, =AT91C_BASE_AIC
        str lr, [lr, #AIC_EOICR]

        /* Restore the SPSR */
        ldmfd sp!, {lr}
        msr spsr_all, lr

        /* Restore execution to the main code. */
        ldmfd sp!, {pc}^
#endif

/**********************************************************
 * Abort entry points. These get run when the CPU enters
 * prefetch or data abort modes or if a spurious IRQ is received.
 * These handlers just set up the necessary arguments and invoke nx__abort().
 */
 /* Original NxOS code follows
  * The NxOS routine is aliased to default_XXX_handler
  * to share debugger code with other projects
  */
        .extern nx__abort
        .global default_prefetch_abort_handler
default_prefetch_abort_handler:
nx__prefetch_abort_handler:
        sub r1, lr, #4
        mov r0, #0
        mrs r2, spsr
        b nx__abort

        .global default_data_abort_handler
default_data_abort_handler:
nx__data_abort_handler:
        sub r1, lr, #8
        mov r0, #1
        mrs r2, spsr
        b nx__abort

        .global nx__spurious_irq
nx__spurious_irq:
#if defined (__DBGENABLE__)
		/* Spurious Count Housekeeping */
		ldr		r3, =irq_state
		ldr		r2, [r3, #IRQ_SPURIOUS]
		add		r2, r2, #1					/* Increment Spurious Count */
		str		r2, [r3, #IRQ_SPURIOUS]
		bx	lr
#else
        sub r1, lr, #4
        mov r0, #2
        mrs r2, spsr
        b nx__abort
#endif
        .global default_undef_handler
default_undef_handler:
nx__default_undef_handler:
        sub r1, lr, #4
        mov r0, #3
        mrs r2, spsr
        b nx__abort

/**********************************************************
 * Nested interrupt disable/enable routines. The
 * interrupts_disable routine disables IRQ/FIQ handling,
 * and increments a nesting counter. The interrupts_enable
 * routine decrements the counter, and reenables interrupts
 * when the counter reaches zero.
 *
 * When the system boots, the internal counter is set to
 * interrupts disabled with 1 level of nesting (ie. calling
 * interrupts_enable once will enable interrupts).
 */
        .global nx_interrupts_disable
        .global nx_interrupts_enable
nx_interrupts_disable:
        mrs r0, cpsr
        orr r0, r0, #IRQ_FIQ_MASK
        msr cpsr_c, r0

        ldr r1, =irq_state
        ldr r0, [r1, #IRQ_INTR_CNT]
        add r0, r0, #1
        str r0, [r1, #IRQ_INTR_CNT]

        bx lr

nx_interrupts_enable:
        ldr r1, =irq_state
        ldr r0, [r1, #IRQ_INTR_CNT]
        subs r0, r0, #1
        str r0, [r1, #IRQ_INTR_CNT]

        bxne lr

        mrs r0, cpsr
        bic r0, r0, #IRQ_FIQ_MASK
        msr cpsr_c, r0
        bx lr

