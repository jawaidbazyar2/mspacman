*
* Merlin32 link: phase 3 IIgs host -> lower_host.bin @ $02/0000.
* make iigs-lower assembles this in a staging copy of iigs/ that also
* holds lower/entry_ids.s.
*
	dsk	lower_host.bin
	org	$0000
	typ	$06
	asm	all_lower.s
	sna	Main
