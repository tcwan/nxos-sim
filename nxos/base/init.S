/* Copyright (C) 2007 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */


#include "asm_decls.h"

#ifdef __DE1SOC__
#include "base/boards/DE1-SoC/address_map_arm.h"
#include "base/boards/DE1-SoC/interrupt_ID.h"
#endif


#define ENABLE_STACK_GUARD 	/* Insert a stack guard value at top of selected stacks */
#define STACK_GUARD_VAL 0xDEADBEEF

/**********************************************************
 * Memory copy and setting macros. These refer to functions
 * defined at the end of the file.
 */
        .macro  mem_copy, source, source_end, dest
        ldr r0, =\source
        ldr r1, =\source_end
        ldr r2, =\dest
        bl mem_copy_func
        .endm

        .macro mem_initialise, dest, dest_end, val
        ldr r0,=\dest
        ldr r1,=\dest_end
        ldr r2,=\val
        bl mem_init_func
        .endm

#ifdef __DE1SOC__

.section .stack.supervisor, "aw", %nobits
        .space 0x400; /* 1 Kbyte supervisor stack. */

.code 32
.text
.align 0
        .global nx_start
        .extern nx__kernel_main


/* This variable is not really declared somewhere: the linker script
 * defines it. see system/appkernels.lds
 */
.extern __bottom_mapped__

/**********************************************************
 * Execution starts here after a reset.
 */
nx_start:
        /* Disable interrupts. They will be enabled if we are
         * rebooting.
         */
        msr cpsr_c, #(MODE_SVC | IRQ_FIQ_MASK)

		/* This section only initializes the Private Timer for CPUlator.
		 * Other devices are setup in nx__aic_init()
		 */

config_gic:
		/* taken from A9 Private Timer ISR example, Henry Wong, U of Toronto, Canada */

		// configure A9 Private Timer interrupt
		ldr	r0, =(MPCORE_GIC_DIST + ICDIPTR + 0x1c) // ICDIPTRn: processor targets register (IRQ 29)
		mov r1, #0x00000100		// set target to cpu0
		str r1, [r0]

		ldr r0, =(MPCORE_GIC_DIST + ICDISER + 0x0) // ICDISERn: set enable register
		mov r1, #0x20000000		// set interrupt enable for A9 private timer (! FIXME: make it general)
		str r1, [r0]

		// Configure GIC CPU interface
		ldr r0, =MPCORE_GIC_CPUIF
		ldr r1, =0xffff			// Enable interrupts of all priority levels
		str r1, [r0, #ICCPMR]

		mov r1, #1
		str r1, [r0, #ICCICR]	// Set enable bit in CPU Interface Control Register (ICCICR)

		ldr r0, =MPCORE_GIC_DIST
		str r1, [r0, #ICDDCR]	// Set enable bit in Distributor Control Register (ICDDCR)

init_mem:
        /* Copy and initialize memory region. */
        mem_copy __vectors_load_start__, __vectors_load_end__, __vectors_ram_start__
        mem_copy __data_load_start__, __data_load_end__, __data_ram_start__
        mem_copy __ramtext_load_start__, __ramtext_load_end__, __ramtext_ram_start__
        mem_initialise __bss_start__, __bss_end__, 0
        mem_initialise __stack_start__, __stack_end__, 0

        /* Set up stacks for the modes we're going to use.
         *
         * Note that the ATPCS specify that stacks must be 8-byte
         * aligned. We make sure they are here, but they are aligned
         * properly in the linker script.
         */

        ldr	r0, =__ram_userspace_end__
        bic r0, r0, #7
#ifdef ENABLE_STACK_GUARD
		/* setup stack guard value */
        ldr r1, =STACK_GUARD_VAL
#endif

		/* IRQ stack is not used. R13 (SP_irq) is used as a temporary variable
		 * during interrupt processing. Please see interrupt.S
		 * for more details.
		 */
#if 1
// Prevent CPUlator from triggering unnecessary SP OOB checks during startup
        /* Set up the IRQ stack (moved to top of RAM). */
        msr cpsr_c, #(MODE_IRQ | IRQ_FIQ_MASK)
        mov sp, r0
#endif

#if 0
// Not supported by CPUlator
        /* Set up the SYS/User stack (moved to top of RAM). */
        /* Note: Currently SYS/User Mode is not used.
         * If we enable user tasks scheduling, the stack initialization
         * for IRQ vs. User modes would have to be changed.
         */
        msr cpsr_c, #(MODE_SYS | IRQ_FIQ_MASK)
        mov sp, r0
#endif
        /* Set up the abort mode stack (Not used). */
        msr cpsr_c, #(MODE_ABT | IRQ_FIQ_MASK)
        mov sp, r0

        /* Set up the supervisor mode stack. */
        msr cpsr_c, #(MODE_SVC | IRQ_FIQ_MASK)
        ldr sp, =__supervisor_stack__
        bic sp, sp, #7
#ifdef ENABLE_STACK_GUARD
		/* store stack guard value */
        str r1, [sp]
#endif

        /* Set up initial frame pointers for C code in both Arm
         * and Thumb modes. */
        mov fp, #0
        mov r7, #0

        /* Start the main kernel code using an interworking branch. */
        ldr r5, =nx__kernel_main
        mov lr, pc
        bx  r5

main_returned:
        /* The kernel should never return, but if it does, freeze. */
        b main_returned

#endif /* __DE1SOC__ */

#ifdef __LEGONXT__
/*
 * Definition of a few constants, for readability.
 */
#define MC_RCR 0xFFFFFF00 /* Remap Control Register */
#define MC_FMR 0xFFFFFF60 /* Flash Mode Register */

#define WDTC_WDMR 0xFFFFFD44 /* Watchdog Control Register */

#define PMC_SR 0xFFFFFC68   /* PMC Status Register */
#define PMC_MOR 0xFFFFFC20  /* Main Oscillator Register */
#define PMC_PLLR 0xFFFFFC2C /* PLL Register */
#define PMC_MCKR 0xFFFFFC30 /* Master Clock Register */

/*---------------------------------------------------------
 *  Various debugger stacks.
 */
.section .stack.supervisor, "aw", %nobits
        .space 0x400; /* 1 Kbyte supervisor stack. */

#ifdef __DBGENABLE__
.section .stack.abort, "aw", %nobits
        .space 0x300; /* 768 byte abort mode stack. */
.section .stack.debugger, "aw", %nobits
        .space 0x48; /* 16 user mode registers + SPSR + UNDEF Next Instruction Address */
.section .breakpoints, "aw", %nobits
        .space 0x40; /* Single Stepping Breakpoint + 7 Breakpoints */
#endif


.code 32
.text
.align 0
        .global nx_start
        .extern nx__kernel_main


/* This variable is not really declared somewhere: the linker script
 * defines it. see system/appkernels.lds
 */
.extern __bottom_mapped__

/**********************************************************
 * Execution starts here after a reset.
 */
nx_start:
        /* Disable interrupts. They will be enabled if we are
         * rebooting.
         */
        msr cpsr_c, #(MODE_SVC | IRQ_FIQ_MASK)

        /* RAM needs to be remapped to the bottom of memory. If we are
         * booting from ram, this is already done, but if we're running
         * in rom, we need to do it now.
         */
        ldr r0, =MEM_START
        ldr r1, =RAM_START
        ldr r2, [r0]        /* Take the first initial word */
        ldr r4, [r1]        /* Take the first ram word */
        eor r3, r4, #0xFF   /* Modify the first initial word */
        str r3, [r1]        /* Store the modified version in ram */
        ldr r3, [r0]        /* Take again the first initial word */
        str r4, [r1]        /* Restore the original first ram word */

        /* Compare the values that were read before and after
         * flipping. If they are identical, ram is not mapped to the
         * bottom of memory, and we need to remap.
         * TODO: remove this hack and replace it with __bottom_mapped__
         *       variable reading.
         */
        cmp r2, r3

        /* This modifies the __bottom_mapped__ variable declared by the
         * linker script. Since we are remapping to ram, we need to set
         * this value as 1, otherwise we set it to 0.
         */
        moveq r1, #1
        movne r1, #0
        ldr r0, =__bottom_mapped__
        str r1, [r0];

        moveq r1, #1
        /* And this remaps if needed */
        ldreq r0, =MC_RCR
        streq r1, [r0]

        /* Break the instruction pipeline to make sure we're getting
         * stuff from the right place.
         */
        b continue_boot

continue_boot:
        /* Configure the flash controller with the correct values for
         * writing: FMCN is set to 72 (48 MHz * 1.5 us), the FWS is set
         * to 1 and the NEBP bit is cleared.
         */
        ldr r0, =MC_FMR
        ldr r1, =((72 << 16) | (1 << 8))
        str r1, [r0]

        /* Disable the watchdog. The watchdog is a sensitive beast:
         * its mode register is write-once, so we first check to see
         * if it has already been disabled, and only touch it if it
         * hasn't, assuming that this is a cold boot.
         */
        ldr r0, =WDTC_WDMR
        ldr r1, [r0]
        ldr r2, =(1 << 15)
        orr r2, r2, r1
        cmp r1, r2
        strne r2, [r0]

        /* Remember this address, we're going to use it a lot. */
        ldr r2, =PMC_SR

        /* Enable the internal main oscillator.
         *
         * The oscillator must be given a quartz-dependent time to start
         * up. For the NXT, this must be set to 6 cycles of the slow clock,
         * which at this stage controls the board.
         */
        ldr r0, =PMC_MOR
        ldr r1, =0x00000601
        str r1, [r0]

wait_mosc:
        /* Wait for the oscillator to stabilize. */
        ldr r1, [r2]
        ands r1, r1,#1
        beq wait_mosc

        /* Initialize the PLL clock.
         *
         * This clock will later provide the basis for the main board
         * clock. The quartz on the board runs at 18.432MHz, and we want a
         * main clock running at 48MHz. The best we can do is to set the PLL
         * to run at 96MHz, and then clock back down when configuring the
         * main clock.
         *
         * To do so, we divide the input signal by 14, then multiply the
         * output by 73 (72+1, as the datasheet says that the board adds 1
         * to the value written in the register), which clocks us to
         * 96.11MHz. Note that the USB clock requires an input signal of
         * 48MHz +/- 0.25% (-> 96/2). A frequency of 96.11MHz is a deviation of .11%,
         * therefore acceptable.
         *
         * The PLL clock is estimated to lock within 0.844ms (estimate
         * documented in the LEGO source code), which maps to ~28 slow clock
         * cycles.
         */
        ldr r0, =PMC_PLLR
        ldr r1, =0x10481C0E
        str r1, [r0]

wait_pll_lock:
        /* Wait for the PLL to lock. */
        ldr r1, [r2]
        ands r1, r1, #4
        beq wait_pll_lock

wait_mclk_1:
        /* Wait for master clock ready before fiddling with it, just as a
         * precaution. It should be running fine at this stage.
         */
        ldr r1, [r2]
        ands r1, r1, #8
        beq wait_mclk_1

        /* Set the master clock prescaler to divide by two, which sets the
         * master clock to 16KHz (half the slow clock frequency).
         *
         * Note that we stay on the slow clock, because of the procedure
         * explained in the specification: you must first set the prescaler,
         * wait for the newly scaled clock to stabilize, then switch to a
         * new clock source in a separate operation.
         */
        ldr r0, =PMC_MCKR
        ldr r1, =0x4
        str r1, [r0]

wait_mclk_2:
        /* Wait for the master clock to stabilize. */
        ldr r1, [r2]
        ands r1, r1, #8
        beq wait_mclk_2

        /* Switch the master clock source over to the PLL clock. */
        ldr r0, =PMC_MCKR
        ldr r1, =0x7
        str r1, [r0]

wait_mclk_3:
        /* Wait for the master clock to stabilize at 48MHz. */
        ldr r1, [r2]
        ands r1, r1, #8
        beq wait_mclk_3

init_mem:
        /* Copy and initialize memory region. */
        mem_copy __vectors_load_start__, __vectors_load_end__, __vectors_ram_start__
        mem_copy __data_load_start__, __data_load_end__, __data_ram_start__
        mem_copy __ramtext_load_start__, __ramtext_load_end__, __ramtext_ram_start__
        mem_initialise __bss_start__, __bss_end__, 0
        mem_initialise __stack_start__, __stack_end__, 0


        /* Set up stacks for the modes we're going to use.
         *
         * Note that the ATPCS specify that stacks must be 8-byte
         * aligned. We make sure they are here, but they are aligned
         * properly in the linker script.
         */

        ldr	r0, =__ram_userspace_end__
        bic r0, r0, #7
#ifdef ENABLE_STACK_GUARD
		/* setup stack guard value */
        ldr r1, =STACK_GUARD_VAL
#endif

#if !defined (__DBGENABLE__)
		/* IRQ stack is only used if Debugger is not enabled.
		 * Otherwise R13 (SP_irq) is used as a temporary variable
		 * during interrupt processing. Please see interrupt.S
		 * for more details.
		 */
        /* Set up the IRQ stack (moved to top of RAM). */
        msr cpsr_c, #(MODE_IRQ | IRQ_FIQ_MASK)
        mov sp, r0
#endif
        /* Set up the SYS/User stack (moved to top of RAM). */
        /* Note: Currently SYS/User Mode is not used.
         * If we enable user tasks scheduling, the stack initialization
         * for IRQ vs. User modes would have to be changed.
         */
        msr cpsr_c, #(MODE_SYS | IRQ_FIQ_MASK)
        mov sp, r0

        /* Set up the abort mode stack. */
        msr cpsr_c, #(MODE_ABT | IRQ_FIQ_MASK)
        ldr sp, =__abort_stack__
        bic sp, sp, #7
		/* There is no need to setup a stack guard value,
		 * since that slot contains part of the Debugger state
		 * and will be overwritten
		 */

        /* Set up the supervisor mode stack. */
        msr cpsr_c, #(MODE_SVC | IRQ_FIQ_MASK)
        ldr sp, =__supervisor_stack__
        bic sp, sp, #7
#ifdef ENABLE_STACK_GUARD
		/* store stack guard value */
        str r1, [sp]
#endif

        /* Set up initial frame pointers for C code in both Arm
         * and Thumb modes. */
        mov fp, #0
        mov r7, #0

        /* Start the main kernel code using an interworking branch. */
        ldr r5, =nx__kernel_main
        mov lr, pc
        bx  r5

main_returned:
        /* The kernel should never return, but if it does, freeze. */
        b main_returned

#endif /* __LEGONXT__ */

/**********************************************************
 * Helper functions used by the bootstrap code.
 */

/* Copy one region of memory to another.
 *  r0:        source start pointer
 *  r1:        source end pointer
 *  r2:        destination start pointer
 */
mem_copy_func:
        /* If the source and destination are the same, do nothing. */
        cmp r0, r2
        bxeq lr

mcf_loop:
        /* Otherwise, loop on through. */
        cmp r0, r1
        ldrlo r3, [r0], #4
        strlo r3, [r2], #4
        blo mcf_loop
        bx lr

/* Initialize a region of memory with a constant value.
 *  r0:        start pointer
 *  r1:        end pointer
 *  r2:        constant value to write
 */
mem_init_func:
        cmp r0, r1
        strlo r2, [r0], #4
        blo mem_init_func
        bx lr
