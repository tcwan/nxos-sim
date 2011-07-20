/** @file armskel.S
 *  @brief ARM Skeleton Program
 *   [What does this component do?]
 *
 *
 * [Optionally, more stuff about the component in general.]
 * This file must be processed using cpp before assembly.
 */

/* Copyright (C) 2007-2011 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

#define __ASSEMBLY__
#include "armskel.h"
#include "base/interwork.h"
#include "armdebug/Debugger/debug_stub.h"

	.extern	nx_systick_wait_ms
	.equ	SYSTICK_1000MS, 1000

.data
.align 4

title:	 .asciz "First ARM Prog"
content: .asciz "Hello!"

.code 32
.text
.align 	4

/* main
 *    Main Program
 */
	.global	main
main:
	push	{lr}
	bl		nx_proginit

	mov		r7, #3
loop:
	ldr		r0, =title
	bl		nx_progtitle

	dbg__bkpt_arm

break:
	mov		r0, #SYSTICK_1000MS
	bl		nx_systick_wait_ms

	ldr		r0, =content
	bl		nx_progcontent

	mov		r0, #SYSTICK_1000MS
	bl		nx_systick_wait_ms

/*	subs	r7, r7, #1
	bne		loop
*/

exit_main:
	bl		nx_progshutdown
	pop		{pc}

.end
