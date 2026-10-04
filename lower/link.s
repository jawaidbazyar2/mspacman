*
* Merlin32 link: phase 3 game logic -> lower.bin, loaded at $02/0000.
* The entry table (entries.s) must stay first: entry n is at $4*n.
*
	dsk	lower.bin
	org	$0000
	typ	$06
	asm	all.s
	sna	Main
