*
* Merlin32 link — demo / rail harness → harness.bin @ $02/0000
* Merlin 1.2 requires SNA (segment name) per ASM segment.
*
	dsk	harness.bin
	org	$0000
	typ	$06
	asm	all_demo.s
	sna	Main
