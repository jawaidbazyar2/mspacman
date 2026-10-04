*
* io.s: the input ports and the IRQ latch, harness version. The harness
* bus serves IN0/IN1 from the replay and DSW1 from the session, and the
* host block mirrors latch[0]. The IIgs build supplies iigs/lower_io.s
* in place of this file, with the same labels and contract: the value
* in A with N and Z set from it, X and Y kept.
*

read_in0
	lda	IN0
	rts

read_in1
	lda	IN1
	rts

read_dsw1
	lda	DSW1
	rts

* latch[0], the interrupt enable.
read_latch0
	lda	HB_LATCH
	rts
