/* rup: toggle light sensor on port 1 */
/* the light is on by default, so using the CODR is best */
.print "Pin Toggle Code"
PIOPER: 	.word	0xFFFFF400
PIOOER: 	.word	0xFFFFF410
PIOCODR:	.word	0xFFFFF434
PIOSODR:	.word 	0xFFFFF430
LEDVALASM:	.word	(1 << 23)
ldr	r0, 		PIOPER
ldr	r1, 		LEDVALASM
str	r1, 		[r0]
ldr	r0, 		PIOOER
str	r1, 		[r0]
ldr	r0, 		PIOCODR 	/* use __PIOSODR (turn on) or __PIOCODR (turn off) */
str	r1, 		[r0]
nxtdebugloopforever:
MOV     R0, #0
B 	nxtdebugloopforever
