/** @file cpulator_stub.inc
 *  @brief Stub to support CPUlator execution
 */

/* Copyright (c) 2020 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#ifndef __CPULATOR_STUB_INC__
#define __CPULATOR_STUB_INC__

#ifdef __CPULATOR__

#ifdef __ASSEMBLY__
	// CPUlator defaults to start from main when loading a pre-compiled ELF executable, skipping the RESET handler call
	// This works around the problem by invoking nx_start() from main when program is started, and continuing with main_entry()
	b		nx_start

	.global main_entry
main_entry:

#else
	// CPUlator defaults to start from main when loading a pre-compiled ELF executable, skipping the RESET handler call
	// This works around the problem by invoking nx_start() from main when program is started, and continuing with main_entry()
	// WARNING: The stack may not preserved properly when doing this from C, depending on the number of registers used in main().
	//
	asm("  b		nx_start");

	asm("  .global main_entry");
	asm("main_entry:");
//	asm("  push		{r4, r5, r6, r7, lr}");
	asm("  push		{r4, lr}");

#endif /* __ASSEMBLY__ */ 

#endif /* __CPULATOR__ */

#endif /* __CPULATOR_STUB_INC__ */