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

TILEMAP        equ $028000
ACTORS         equ $028400
* Actor indexing: >ACTORS+field,x with X = index×16 (not $8400+).
DIRTY_COUNT    equ $028800
DIRTY_LIST     equ $028802
FRAME_COUNT    equ $028900
EAT_INDEX      equ $028902
DEMO_FREEZE    equ $028904
POWER_FLASH_CNT equ $028906
SCORE_LO       equ $028908
SCORE_MID      equ $028909
SCORE_HI       equ $02890A
HISCORE_LO     equ $02890B
HISCORE_MID    equ $02890C
HISCORE_HI     equ $02890D
LIVES          equ $02890E
LEVEL          equ $02890F
ROW_ADDR       equ $028B00
ROW_BCK        equ $028D00

*============================================================
* Arcade RAM mirror (#4D00–#4E3F) in free actor pad.
* Offsets match locked src/ram.inc — comment anchors for listing.
*============================================================
RAM4D          equ $028460	; == #4D00
RAM4E          equ $028560	; == #4E00 (256 bytes after #4D00)
* #4Dxx actor physics (Y then X — arcade order)
RED_Y          equ $028460	; == #4D00
RED_X          equ $028461
PINK_Y         equ $028462
PINK_X         equ $028463
BLUE_Y         equ $028464
BLUE_X         equ $028465
ORANGE_Y       equ $028466
ORANGE_X       equ $028467
PAC_Y          equ $028468	; == #4D08
PAC_X          equ $028469	; == #4D09
RED_TILE_Y     equ $02846A	; == #4D0A
RED_TILE_X     equ $02846B
PINK_TILE_Y    equ $02846C
PINK_TILE_X    equ $02846D
BLUE_TILE_Y    equ $02846E
BLUE_TILE_X    equ $02846F
ORANGE_TILE_Y  equ $028470
ORANGE_TILE_X  equ $028471
PAC_TILE_Y     equ $028499	; == #4D39
PAC_TILE_X     equ $02849A	; == #4D3A
PAC_TILE_DY    equ $02847C	; == #4D1C (word Y,X deltas)
PAC_TILE_DX    equ $02847D
PAC_WANT_DY    equ $028486	; == #4D26
PAC_WANT_DX    equ $028487
PAC_DIR        equ $028490	; == #4D30
PAC_WANT_DIR   equ $02849C	; == #4D3C
RED_DIR        equ $02848C	; == #4D2C
PINK_DIR       equ $02848D
BLUE_DIR       equ $02848E
ORANGE_DIR     equ $02848F
RED_PREV_DIR   equ $028488	; == #4D28
PINK_PREV_DIR  equ $028489
BLUE_PREV_DIR  equ $02848A
ORANGE_PREV_DIR equ $02848B
RED_TILE_DY    equ $028474	; == #4D14
PINK_TILE_DY   equ $028476
BLUE_TILE_DY   equ $028478
ORANGE_TILE_DY equ $02847A
SPD_PAC_NORM   equ $0284A6	; == #4D46 (4 bytes rotating)
SPD_PAC_ENERG  equ $0284AA	; == #4D4A
SPD_RED_NORM   equ $0284B6	; == #4D56
PAC_MOVE_DELAY equ $0284FD	; == #4D9D
PILLS_SINCE_PAC_MOVE equ $0284FE	; == #4D9E
PILLS_AFTER_DEATH equ $0284FF	; == #4D9F
GHOST_HOME_MOVE equ $0284F4	; == #4D94 (RLCA half-rate house motion)
LEAVE_HOME_UNITS equ $0284F5	; == #4D95 word idle threshold
LEAVE_HOME_IDLE equ $0284F7	; == #4D97 word idle counter
POWER_PILL_ACT equ $028506	; == #4DA6
RED_FRIGHT     equ $028507	; == #4DA7
PINK_FRIGHT    equ $028508
BLUE_FRIGHT    equ $028509
ORANGE_FRIGHT  equ $02850A
RED_STATE      equ $02850B	; == #4DAB (0=alive,1=eyes,…)
PINK_STATE     equ $02850C
BLUE_STATE     equ $02850D
ORANGE_STATE   equ $02850E
RED_SUBSTATE   equ $028500	; == #4DA0 (0=home,1=out,2=door up,3=to door)
PINK_SUBSTATE  equ $028501
BLUE_SUBSTATE  equ $028502
ORANGE_SUBSTATE equ $028503
PINK_EXIT_LIMIT equ $028518	; == #4DB8
BLUE_EXIT_LIMIT equ $028519	; == #4DB9
ORANGE_EXIT_LIMIT equ $02851A	; == #4DBA
DOTS_EATEN     equ $02856E	; == #4E0E
PINK_EXIT_CNT  equ $02856F	; == #4E0F
BLUE_EXIT_CNT  equ $028570	; == #4E10
ORANGE_EXIT_CNT equ $028571	; == #4E11
DIED_THIS_LEVEL equ $028572	; == #4E12
GAME_MODE      equ $028560	; == #4E00
LEVEL_STATE    equ $028564	; == #4E04
LEVEL_NUMBER   equ $028573	; == #4E13
LIVES_REAL     equ $028575	; == #4E15
FRIGHT_FLASH_CNT equ $028528	; == #4DC8 (j_0ac3 period, reload #$0E)
FRIGHT_FLASH_PHASE equ $028529	; soft: 0=blue, 1=white when timer < $0100
FRIGHT_TIMER   equ $02852B	; == #4DCB word countdown
FRIGHT_TIME    equ $02851D	; == #4DBD word initial duration (level1 $02D0)
RED_REVERSE    equ $028511	; == #4DB1
PINK_REVERSE   equ $028512	; == #4DB2
BLUE_REVERSE   equ $028513	; == #4DB3
ORANGE_REVERSE equ $028514	; == #4DB4
* Level1Speed copy places reverse thresholds at #4D86 (== SPD_PAC_NORM+$40)
GHOST_ORIENT_TBL equ $0284E6	; == #4D86
GHOST_ORIENT_IDX equ $028521	; == #4DC1
GHOST_ORIENT_CNT equ $028522	; == #4DC2 word
PATH_BEST_DIR  equ $02849B	; == #4D3B
PATH_OPP_DIR   equ $02849D	; == #4D3D
PATH_CUR_Y     equ $02849E	; == #4D3E
PATH_CUR_X     equ $02849F
PATH_DST_Y     equ $0284A0	; == #4D40
PATH_DST_X     equ $0284A1
PATH_TMP_Y     equ $0284A2
PATH_TMP_X     equ $0284A3
PATH_MIN_LO    equ $0284A4	; == #4D44
PATH_TRY_DIR   equ $028527	; == #4DC7
STICK_IN0      equ $028590	; soft IN0 (active-low), game build
FRUIT_ACTIVE   equ $028591
FRUIT_PIXEL_Y  equ $028592	; == fruit_pos style
FRUIT_PIXEL_X  equ $028593
DEATH_TIMER    equ $028594
CLEAR_TIMER    equ $028595
FRUIT_TIMER    equ $028596
FRUIT_SPAWNED  equ $028597	; bit0=first, bit1=second
