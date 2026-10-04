*
* Direct page and host block. The direct page is bank 0 $0000-$00FF.
*
*   $00-$0F  ARG0..: arguments past A, X and Y (see entries.s)
*   $10-$1F  T0-T15: scratch. Any JSR may change them
*   $20-     per-file locals, kept across calls into other files
*
* Calling convention: native mode, MX %10 (8-bit A, 16-bit X and Y) on
* entry and exit. DBR is the game bank, D is $0000. A byte result is in
* A, a word or Coord (y low, x high) in X.
*

ARG0	equ	$00
ARG1	equ	$01
ARG2	equ	$02
ARG3	equ	$03
ARG4	equ	$04
ARG5	equ	$05

T0	equ	$10
T1	equ	$11
T2	equ	$12
T3	equ	$13
T4	equ	$14
T5	equ	$15
T6	equ	$16
T7	equ	$17
T8	equ	$18
T9	equ	$19
T10	equ	$1A
T11	equ	$1B
T12	equ	$1C
T13	equ	$1D
T14	equ	$1E
T15	equ	$1F

* Host block: Board fields that are not arcade memory (lower/host/shadow.h).
HB_INT_ENABLED	equ	$F000
HB_RESTART	equ	$F001
HB_STARTED	equ	$F002
HB_STOP	equ	$F003
HB_RAND	equ	$F004	; 4 bytes, little-endian
HB_LATCH	equ	$F008	; 8 bytes, read-only

* Video change log, read and cleared by the IIgs host's LowerTiles once
* a frame. Stores to maze cells log their address (vid_log); routines
* that rewrite the maze set VID_FULL instead. VID_N is a byte offset
* into VID_LOG and wraps at 256 (128 entries); VID_N+1 stays 0.
VID_FULL	equ	$F200	; nonzero: LowerTiles walks every cell
VID_N	equ	$F202
VID_LOG	equ	$F204	; bus addresses of written cells, one word each

* Arcade I/O in the game bank.
IN0	equ	$5000
IN1	equ	$5040
DSW1	equ	$5080
WATCHDOG	equ	$50C0
COLOR_RAM	equ	$0400	; color cell = video cell + $400
TILE_BLANK	equ	$40

* Main task numbers (game.h TASK_*).
TASK_CLEAR_SCREEN	equ	$00
TASK_MAZE_COLORS	equ	$01
TASK_DRAW_MAZE	equ	$02
TASK_DRAW_PILLS	equ	$03
TASK_PLACE_ACTORS	equ	$04
TASK_HOUSE_TIMER	equ	$05
TASK_CLEAR_COLORS	equ	$06
TASK_DEMO_MODE	equ	$07
TASK_DIFFICULTY	equ	$10
TASK_CLEAR_ACTORS	equ	$11
TASK_RESET_PILLS	equ	$12
TASK_ERASE_PILLS	equ	$13
TASK_DIP_SWITCHES	equ	$14
TASK_DRAW_SCORES	equ	$18
TASK_LIVES_ROW	equ	$1A
TASK_FRUIT_ROW	equ	$1B
TASK_TEXT	equ	$1C
TASK_CREDITS	equ	$1D
TASK_CLEAR_SPRITES	equ	$1E
TASK_BONUS_DIGITS	equ	$1F

* QT task;param: queue_task with constant arguments.
QT	MAC
	lda	#]1
	ldx	#]2
	jsr	queue_task
	<<<

* VIDFULL: set VID_FULL. Keeps A (8-bit).
VIDFULL	MAC
	pha
	lda	#1
	sta	VID_FULL
	pla
	<<<

* Per-file direct-page locals ($20-$FF). Each file owns its range.
*   $20-$23 difficulty   $24-$25 draw   $26 hud   $28-$2F score

* sched.c fail(): WDM $02 with the reason in A and the detail in X.
FAIL_BAD_TASK	equ	1
FAIL_NOT_EMPTY	equ	2
