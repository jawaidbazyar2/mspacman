*
* GS/OS S16 entry — loader leaves native mode, UserID in A, D/S set.
* BCK + assets come from OMF data segments (no NewHandle).
*
	mx	%00

Start	ent
	phk				; DB = program bank
	plb

* A = UserID from GS/OS loader
	sta	|myID

* Preserve loader DP / stack (do not TCD #$0000 — that trashes system ZP).
	tsx
	stx	|mySP
	tdc
	sta	|myDP
	sec
	tsc
	sbc	|myDP
	sta	|myBank0Size

	sep	#$20
	lda	>KBDSTRB			; drop any boot/Finder keystroke
	rep	#$30
	jsr	GameEnter
* GameEnter returns only via ExitDemo → QuitGSOS
QuitGSOS
	jsl	$E100A8
	da	$0029			; P16/GSOS Quit
	adrl	quitPB
]q	bra	]q

quitPB	adrl	0			; null pathname → quit to launcher

myID	ds	2
mySP	ds	2
myDP	ds	2
myBank0Size ds	2
