*
* Merlin32 link — GS/OS relocatable game → MSPACMAN.SYS16
*
	dsk	MSPACMAN.SYS16
	typ	$B3			; S16 application

* Segment 1 — code
	asm	all_gsos_main.s
	ds	0
	knd	#$1100			; static + bank-relative, code
	ali	None
	sna	Main

* Segment 2 — BCK strip (loader relocates >BCK_PIXELS refs)
	asm	seg_bck.s
	ds	0
	knd	#$1101			; static + bank-relative, data
	ali	None
	sna	Bck

* Segment 3 — graphics assets
	asm	seg_assets.s
	ds	0
	knd	#$1101
	ali	None
	sna	Assets

* Segment 4 — work RAM (tilemap, actors, arcade #4D/#4E mirror, HUD state)
	asm	seg_work.s
	ds	0
	knd	#$1101
	ali	None
	sna	Work
