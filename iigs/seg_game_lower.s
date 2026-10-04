*
* GS/OS OMF data segment: the lowered game's whole 64 KB game bank.
* The link aligns it to a bank, so arcade addresses are bank offsets:
*
*   $0000-$9FFF  build/mspac.bin (ROM at $0000-$3FFF and $8000-$9FFF;
*                LowerInit clears the RAM and I/O page at $4000-$50FF)
*   $A000-       lower.bin assembled at $A000 (lower_a000.bin), so its
*                code bank is the game bank
*   $F000        the host block
*
	rel
	ent	GAME

GAME
	putbin	mspac.bin
	putbin	lower_a000.bin
	ds	$10000-*
