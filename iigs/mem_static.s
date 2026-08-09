*
* Static (inject) host memory map — fixed banks for GSSquared testing.
*   $01 SHR shadow   $02 code+work   $03 assets   $04/2000 BCK strip
* Put before equates.s from base_static_*.s / all_*.s.
*

BANK_CODE      equ $02
BANK_SHR       equ $01
BANK_ASSETS    equ $03
BANK_BCK       equ $04
* Bank $02 long base for >BANK2,x (legacy ghost work blit / old HUD).
BANK_WORK      equ $020000
BANK2          equ $020000
BUILD_GSOS     equ 0

SHR_PIXELS     equ $012000
SHR_SCB        equ $019D00
SHR_PALETTE    equ $019E00

* Playfield backing store — plain RAM, long refs (not bank $01).
BCK_PIXELS     equ $042000

AST_TILES      equ $030000
AST_SPR_EVEN   equ $031200
AST_MSK_EVEN   equ $032700
AST_SPR_ODD    equ $033C00
AST_MSK_ODD    equ $035100
AST_MAZE       equ $036600
AST_MAZE_CELLS equ $037000	; 868 × 18 stitched 6×6 cells

SPR_WORK16     equ $6000	; low 16 in bank $02 (legacy ghost work)

TILEMAP        equ $02A000
ACTORS         equ $02A400
* Actor indexing: >ACTORS+field,x with X = index×16 (not $A400+).
DIRTY_COUNT    equ $02A800
DIRTY_LIST     equ $02A802
FRAME_COUNT    equ $02A900
EAT_INDEX      equ $02A902
DEMO_FREEZE    equ $02A904
POWER_FLASH_CNT equ $02A906
SCORE_LO       equ $02A908
SCORE_MID      equ $02A909
SCORE_HI       equ $02A90A
HISCORE_LO     equ $02A90B
HISCORE_MID    equ $02A90C
HISCORE_HI     equ $02A90D
LIVES          equ $02A90E
LEVEL          equ $02A90F
ROW_ADDR       equ $02AB00
ROW_BCK        equ $02AD00

*============================================================
* Arcade RAM mirror (#4D00–#4E3F) in free actor pad.
* Offsets match locked src/ram.inc — comment anchors for listing.
*============================================================
RAM4D          equ $02A460	; == #4D00
RAM4E          equ $02A560	; == #4E00 (256 bytes after #4D00)
* #4Dxx actor physics (Y then X — arcade order)
RED_Y          equ $02A460	; == #4D00
RED_X          equ $02A461
PINK_Y         equ $02A462
PINK_X         equ $02A463
BLUE_Y         equ $02A464
BLUE_X         equ $02A465
ORANGE_Y       equ $02A466
ORANGE_X       equ $02A467
PAC_Y          equ $02A468	; == #4D08
PAC_X          equ $02A469	; == #4D09
RED_TILE_Y     equ $02A46A	; == #4D0A
RED_TILE_X     equ $02A46B
PINK_TILE_Y    equ $02A46C
PINK_TILE_X    equ $02A46D
BLUE_TILE_Y    equ $02A46E
BLUE_TILE_X    equ $02A46F
ORANGE_TILE_Y  equ $02A470
ORANGE_TILE_X  equ $02A471
PAC_TILE_Y     equ $02A499	; == #4D39
PAC_TILE_X     equ $02A49A	; == #4D3A
PAC_TILE_DY    equ $02A47C	; == #4D1C (word Y,X deltas)
PAC_TILE_DX    equ $02A47D
PAC_WANT_DY    equ $02A486	; == #4D26
PAC_WANT_DX    equ $02A487
PAC_DIR        equ $02A490	; == #4D30
PAC_WANT_DIR   equ $02A49C	; == #4D3C
RED_DIR        equ $02A48C	; == #4D2C
PINK_DIR       equ $02A48D
BLUE_DIR       equ $02A48E
ORANGE_DIR     equ $02A48F
RED_PREV_DIR   equ $02A488	; == #4D28
PINK_PREV_DIR  equ $02A489
BLUE_PREV_DIR  equ $02A48A
ORANGE_PREV_DIR equ $02A48B
RED_TILE_DY    equ $02A474	; == #4D14
PINK_TILE_DY   equ $02A476
BLUE_TILE_DY   equ $02A478
ORANGE_TILE_DY equ $02A47A
SPD_PAC_NORM   equ $02A4A6	; == #4D46 (4 bytes rotating)
SPD_PAC_ENERG  equ $02A4AA	; == #4D4A
SPD_RED_NORM   equ $02A4B6	; == #4D56
SPD_RED_BLUE   equ $02A4BA	; == #4D5A (fright / "blue state" — slower)
PAC_MOVE_DELAY equ $02A4FD	; == #4D9D
PILLS_SINCE_PAC_MOVE equ $02A4FE	; == #4D9E
PILLS_AFTER_DEATH equ $02A4FF	; == #4D9F
GHOST_HOME_MOVE equ $02A4F4	; == #4D94 (RLCA half-rate house motion)
LEAVE_HOME_UNITS equ $02A4F5	; == #4D95 word idle threshold
LEAVE_HOME_IDLE equ $02A4F7	; == #4D97 word idle counter
RED_SUBSTATE   equ $02A500	; == #4DA0 (0=home,1=out,2=door up,3=to door)
PINK_SUBSTATE  equ $02A501
BLUE_SUBSTATE  equ $02A502
ORANGE_SUBSTATE equ $02A503
GHOSTS_KILLED_PENDING equ $02A504	; == #4DA4 (1..4 which ghost, 0=none)
EAT_FREEZE_TIMER equ $02A505	; soft: RST#30 $4A eat-pose countdown
POWER_PILL_ACT equ $02A506	; == #4DA6
RED_FRIGHT     equ $02A507	; == #4DA7
PINK_FRIGHT    equ $02A508
BLUE_FRIGHT    equ $02A509
ORANGE_FRIGHT  equ $02A50A
RED_STATE      equ $02A50B	; IIgs packed (arcade red_state=#4DAC; 0=alive,1=eyes)
PINK_STATE     equ $02A50C
BLUE_STATE     equ $02A50D
ORANGE_STATE   equ $02A50E
PINK_EXIT_LIMIT equ $02A518	; == #4DB8
BLUE_EXIT_LIMIT equ $02A519	; == #4DB9
ORANGE_EXIT_LIMIT equ $02A51A	; == #4DBA
DOTS_EATEN     equ $02A56E	; == #4E0E
PINK_EXIT_CNT  equ $02A56F	; == #4E0F
BLUE_EXIT_CNT  equ $02A570	; == #4E10
ORANGE_EXIT_CNT equ $02A571	; == #4E11
DIED_THIS_LEVEL equ $02A572	; == #4E12
GAME_MODE      equ $02A560	; == #4E00
LEVEL_STATE    equ $02A564	; == #4E04
LEVEL_NUMBER   equ $02A573	; == #4E13
LIVES_REAL     equ $02A575	; == #4E15
FRIGHT_FLASH_CNT equ $02A528	; == #4DC8 (j_0ac3 period, reload #$0E)
FRIGHT_FLASH_PHASE equ $02A529	; soft: 0=blue, 1=white when timer < $0100
KILL_GHOST_STATE equ $02A52A	; soft: which ghost → eyes after freeze (arcade #4DAB)
FRIGHT_TIMER   equ $02A52B	; == #4DCB word countdown
GHOSTS_KILLED_COUNT equ $02A530	; == #4DD0 (0..4 this energizer)
KILLED_GHOST_ANIM equ $02A531	; == #4DD1
FRIGHT_TIME    equ $02A51D	; == #4DBD word initial duration (level1 $02D0)
RED_REVERSE    equ $02A511	; == #4DB1
PINK_REVERSE   equ $02A512	; == #4DB2
BLUE_REVERSE   equ $02A513	; == #4DB3
ORANGE_REVERSE equ $02A514	; == #4DB4
* Level1Speed copy places reverse thresholds at #4D86 (== SPD_PAC_NORM+$40)
GHOST_ORIENT_TBL equ $02A4E6	; == #4D86
GHOST_ORIENT_IDX equ $02A521	; == #4DC1
GHOST_ORIENT_CNT equ $02A522	; == #4DC2 word
PATH_BEST_DIR  equ $02A49B	; == #4D3B
PATH_OPP_DIR   equ $02A49D	; == #4D3D
PATH_CUR_Y     equ $02A49E	; == #4D3E
PATH_CUR_X     equ $02A49F
PATH_DST_Y     equ $02A4A0	; == #4D40
PATH_DST_X     equ $02A4A1
PATH_TMP_Y     equ $02A4A2
PATH_TMP_X     equ $02A4A3
PATH_MIN_LO    equ $02A4A4	; == #4D44
PATH_TRY_DIR   equ $02A527	; == #4DC7
STICK_IN0      equ $02A590	; soft IN0 (active-low), game build
FRUIT_ACTIVE   equ $02A591
FRUIT_PIXEL_Y  equ $02A592	; == fruit_pos style
FRUIT_PIXEL_X  equ $02A593
DEATH_TIMER    equ $02A594
CLEAR_TIMER    equ $02A595
FRUIT_TIMER    equ $02A596
FRUIT_SPAWNED  equ $02A597	; bit0=first, bit1=second
