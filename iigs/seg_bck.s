*
* GS/OS OMF data segment — playfield backing store.
* Loader relocates all >BCK_PIXELS refs in the code segment.
*
	rel
	ent	BCK_PIXELS

* 200 rows × S_BCK (88) = 17600
BCK_PIXELS	ds	17600
