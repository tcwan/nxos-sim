/* Copyright (c) 2009 the NxOS developers
 *
 * See AUTHORS for a full list of the developers.
 *
 * Redistribution of this file is permitted under
 * the terms of the GNU Public License (GPL) version 2.
 */

/*
   As described in nxt-native from Sivan Toledo:

   The NXT firmware recognizes a native file by the
   string "NXTBINARY" at the beginning of the file.
   To keep the changes in the NXT's firmware minimal,
   the file name must be .rxe (same as the stadard
   NXT binaries which are for a virtual machine).

   When the NXT's firmware recognizes a native file,
   it calls a function at offset X in the file, where
   X is the 32-bit number stored in offset 12 in the file.
   The firmware passes two arguments to the function: the
   address of the file in flash, and the length of the file.
*/

    .section .rxe_header, "ax"
	.code 32 /* Assemble in ARM mode, not Thumb mode */

    /* Marker for standard firmware. */
	.ascii "NXTBINARY\0\0\0"
    /*
     * The firmware expects to see at offset 12 in the
     * file the offset of the entry function from the
     * firmware. It evaluates to 16 (16-byte header)
     * This allows us to skip the runtime copier routine when copying.
     */
	.word  16
    .end

