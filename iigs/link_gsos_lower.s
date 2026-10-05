*
* Merlin32 link: GS/OS lowered game -> MSPACMAN.SYS16 (make iigs-lower-gsos)
*
	dsk	MSPACMAN.SYS16
	typ	$B3			; S16 application

* Segment 1: code (gsos_entry.s's Start is the entry at offset 0)
	asm	all_gsos_lower.s
	ds	0
	knd	#$1100			; static, bank-relative, code
	ali	None
	sna	Main

* Segment 2: the game bank. Merlin writes ALIGN as 2 for BANK; the
* Makefile sets it to $10000 with py/omf_fix_align.py.
	asm	seg_game_lower.s
	ds	0
	knd	#$1101
	ali	BANK
	sna	Game

* Segment 3: BCK strip
	asm	seg_bck.s
	ds	0
	knd	#$1101
	ali	None
	sna	Bck

* Segment 4: tile and sprite art
	asm	seg_assets_lower.s
	ds	0
	knd	#$1101
	ali	None
	sna	Assets

* Segment 5: renderer work RAM (tilemap, actors, dirty list, HUD state)
	asm	seg_work.s
	ds	0
	knd	#$1101
	ali	None
	sna	Work
