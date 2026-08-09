*
* Merlin32 link — game logic build → game.bin @ $02/0000
* Merlin 1.2 requires SNA (segment name) per ASM segment.
*
	dsk	game.bin
	org	$0000
	typ	$06
	asm	all_game.s
	sna	Main
