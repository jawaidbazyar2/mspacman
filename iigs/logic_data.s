*
* Arcade tables for game build (from mspacmab boots / locked listing).
*
	mx	%00

* == #32FF tile delta table: words (dY, dX) per dir 0..3 (R,D,L,U)
DirDelta
	db	$00,$FF		; 0 right: dY=0, dX=-1 (arcade axes)
	db	$01,$00		; 1 down
	db	$00,$01		; 2 left
	db	$FF,$00		; 3 up

* Level-1 speed patterns after difficulty #0796 / j_0814 → #4D46..
Level1Speed
	db	$55,$55,$55,$55,$D5,$6A,$D5,$6A
	db	$AA,$6A,$55,$D5,$55,$55,$55,$55
	db	$AA,$2A,$55,$55,$92,$24,$92,$24
	db	$22,$22,$22,$22,$AA,$2A,$55,$55
	db	$92,$24,$92,$24,$22,$22,$22,$22
	db	$AA,$2A,$55,$55,$92,$24,$92,$24
	db	$22,$22,$22,$22,$AA,$2A,$55,$55
	db	$92,$24,$92,$24,$22,$22,$22,$22
	db	$A4,$01,$54,$06,$F8,$07,$A8,$0C
	db	$D4,$0D,$84,$12,$B0,$13

Level1SpeedLen equ 78

* Scatter corners == #8B2D maze1 (tile Y,X). Upright: low X = screen right.
ScatterRed	db	$1D,$22		; top right
ScatterPink	db	$1D,$39		; top left
ScatterBlue	db	$40,$20		; bottom right
ScatterOrange	db	$40,$3B		; bottom left

* Fruit release thresholds (Ms. Pac)
FruitDots1	equ	64
FruitDots2	equ	176
