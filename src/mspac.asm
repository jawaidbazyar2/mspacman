;; Ms. Pac-Man documented disassembly
;;
;;  The copyright holders for the core program
;;  included within this file are:
;;	(c) 1980 NAMCO
;;	(c) 1980 Bally/Midway
;;	(c) 1981 General Computer Corporation (GCC)
;;
;;  Research and compilation of the documentation by
;;	Scott Lawrence
;;	pacman@umlautllama.com  @yorgle
;;
;;  Documentation and Hack Contributors:
;;      Don Hodges                 http://www.donhodges.com
;;      David Caldwell             http://www.porkrind.org
;;      Frederic Vecoven           http://www.vecoven.com (Music, Sound)
;;      Fred K "Juice"
;;      Marcel "The Sil" Silvius   http://home.kabelfoon.nl/~msilvius/
;;      Mark Spaeth                http://rgvac.978.org/asm
;;      Dave Widel                 http://www.widel.com/
;;      M.A.B. from Vigasoco

;;
;; DISCLAIMER:
;;	This project is a learning experience.  The goal is to try
;;	to figure out how the original programmers and subsequent
;;	GCC programmers wrote Pac-Man, Crazy Otto, and Ms. Pac-Man.
;;	This disassembly and comments are not sanctioned in any
;;	way by any of the copyright holders of these programs.
;;
;;  Over time, this document may transform from a documented disassembly
;;   of the bootleg ms-pacman roms into a re-assemblable source file.
;;
;;  This is also made to determine which spaces in the roms are available
;;   for patches and extra functionality for your own hacks.
;;
;;	NOTE:  This disassembly is based on the base "bootleg" 
;;		version of Ms. Pac-Man.   ("boot1" through "boot6")
;; 	rom images used:
;;		0x0000 - 0x0fff		boot1
;;		0x1000 - 0x1fff		boot2
;;		0x2000 - 0x2fff		boot3
;;		0x3000 - 0x3fff		boot4
;;		0x8000 - 0x8fff		boot5
;;		0x9000 - 0x9fff		boot6
;;
;;  More information about the actual Ms. Pac-Man aux board is below.
;;

;;
;;	IF YOU ARE AWARE OF ANY BITS OF CODE THAT ARE NOT DOCUMENTED
;;	HERE, OR KNOW OF MORE RAM ADDRESSES OR SUCH, PLEASE EMAIL
;;	ME SO THAT I MAY INTEGRATE YOUR INFORMATION INTO HERE.
;;
;;				THANKS!

;; 2014-01-18
;;	tried to document HACK2 (standard speedup hack) but it makes no sense
;;	added more info about f2 LOOP and ANIMATIONS in general
;;
;; 2014-01-16
;;	Completely documented DrawText (2c5e)
;;
;; 2014-01-12
;;	Text string decodings (0x3713, 0x3d00) for readibility
;;	Animation code engine at 0x34a9
;;	Animation code lists at 0x8251, Rosetta stone at 0x8395
;;
;; 2014-01-06
;;	Don Hodges' documentation work added
;;	bugfix section added.
;;		HACK8 -> BUGFIX01
;;		HACK9 -> BUGFIX02
;;		HACK10 -> HACK8
;;		HACK11 -> HACK9
;;
;; 2014-01-02
;;	Added "OTTOPATCH" information from Crazy Otto source
;;
;; 2009-12-16
;;	Added some Crazy Otto notes
;;
;; 2009-01-18
;;	Added content from Don Hodges for much of the undocumented code
;;
;; 2008-06-20
;;	Added content from Frederic Vecoven for all of the sound code
;;
;; 2007-09-03
;;	added more notes about mspac blocks in 8000/9000
;;	RAM layout, data tables from M.A.B. in the VIGASOCO project (pac)
;;
;; 2004-12-28
;;	added Interrupt Mode 1/2 documentation
;;
;; 2004-12-22
;;	added HACK12 - the C000 text mirror bug fix
;;
;; 2004-03-21
;;	added information for most of the reference tables for map-related-data
;;
;; 2004-03-15
;;	working on figuring out RST 28	
;;
;; 2004-03-09
;;	added comments about how the text rendering works (at 0x2c5e)
;;	added more details about the text string look up table
;;	added information about midway logo rendering at 0x964a
;;	changed all of the RST 28 calls to have data after them
;;
;; 2004-03-03
;;	mapped out most of the patches in 8000-81ef range
;;	(some are unused ff's, some I couldn't find...)
;;
;; 2004-03-02
;;	HACK10: Dave Widel's fast intermission fix (based on Dock Cutlip's code)
;;		(now HACK8)
;;	HACK11: Dave Widel's coin light blink with power pellets
;;		(now HACK9)
;;
;; 2004-02-18
;;	HACK8: Mark Spaeth's "20 byte" level 255 Pac-Man rom fix (BUGFIX01)
;;	HACK9: Mark Spaeth's Ms. Pac-Man level fix (BUGFIX02)
;;
;; 2004-01-10
;;	figured out some of the sound generation triggering
;;
;; 2004-01-09
;;	added notes about HACK7 : eliminating all of the startup tests
;;	figured out the easter egg routine as well as storage method for data
;;
;; 2004-01-05
;;	added notes about HACK6 : the standard "HARD" romset
;;	changed all of the HACK numbers
;;
;; 2004-01-04
;;	added notes from Fred K's roms about skipping the self test  HACK4
;;	added notes about the pause routine HACK5
;;	added notes from Fred K about 018c game loop
;;
;; 2004-01-03
;;	added note about 0068-008c being junk - INCORRECT! (ed.)
;;
;; 2004-01-02
;;	added in more information about controllers
;;	added info about the always-on fast upgrade  HACK2
;;	added info about the P1P2 cheat HACK3
;;
;; 2004-01-01
;;	integrated in Mark Spaeth's random fruit doc.
;;
;; 2003-07-16
;; 	added in red ghost AI code documentation (2730, 9561)
;;
;; 2003-03-26
;;	changed some 'kick the dog' text
;;	added a note about the checksum hack ; HACK1
;;
;; 2003-03
;;	cleaned up some notes, added the "Made By Namco" egg notes
;;
;; + 2001-07-13
;;       more notes from David Widel.  Ram variables, $2a23m $8768
;;
;; + 2001-06-25,26
;;      integrated in some notes from David Widel (THANKS!)
;;
;; 2001-03-06
;;      integrated in Fred K's pacman notes.
;;
;; 2001-03-04
;;      corrected text strings in the lookup table at 36a5
;;      commented some of the text string routines
;;
;; 2001-02-28
;;      added text string lookup tables
;;      added indirect lookup at 36a5
;;      added more commenting over from the pacman.asm file
;;  
;; 2001-02-27
;;      table data pulled out, and bogus opcodes removed.
;;      more score information found as well

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Documented Hacks
;;
;;	these are common hacks done to this codebase

;	HACK1
;		Skips the traditional bad-rom checksum routine.

;	HACK2
;		Traditional "Fast Chip" hack

;	HACK3
;		Dock Cutlip's Fast/Invincibility hack.
;		Press P1 start for super speed
;		Press P2 start for invincibility

;	HACK4
;		Self-Test skip
;		Reclaims rom space 3006 - 30c0 for custom code use

;	HACK5
;		Game pause routine
;		Press P1 start to pause
;		Press P2 start to unpause

;	HACK6
;		The standard "HARD" romset.
;		Unknown exactly what the changes are. (data table)

;	HACK7
;		Skips the Test startup display
;		(Alternate) just skips the grid.

;	HACK8 (formerly HACK10)
;		Dave Widel's faster intermission fix
;		Based on Dock Cutlip's code
;		Pac moves at normal speeds in intermissions
;		(this is a hack, not a fix, since it's based on a hack/mod

;	HACK9 (formerly HACK11)
;		Dave Widel's coin light blink with power pellets
;		Coin lights blink when power pellets blink now

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Documented bugfixes
;;
;;	these are bugfixes to the code base

;	BUGFIX01 - Level 255 Pac-Man kill screen killer
;		from: Mark Spaeth
;		notes: Mark Spaeth's level 255 Pac-Man fix
;			Mspac never gets to 255, so this fix is pac-only

;	BUGFIX02 - Level 141 Ms. Pac-Man kill screen killer
;		ref: http://www.funspotnh.com/discus/messages/10/508.html?1077146991
;		from: Mark Spaeth
;		notes: This fix is Ms. Pac only, but will work for pac as well.

;	BUGFIX03 - Blue Maze
;		from: Don Hodges
;		ref: http://donhodges.com/ms_pacman_bugs.htm
;		symptoms: Sometimes when starting Ms Pac, the first
;			board is blue.

;	BUGFIX04 - Marquee left side animation fix
;		from: Don Hodges
;		ref: http://donhodges.com/ms_pacman_bugs.htm
;		symptoms: incorrect character in the intro screen
;		causes the intro marquee to not work on the left side

;	BUGFIX05 - Map discoloration fix
;		from: Don Hodges
;		ref: http://donhodges.com/ms_pacman_bugs.htm
;		symptoms: The marquee doesn't light correctly,
;			Other characters glitch on gameplay maps


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Known Ms. Pac variants:
;
; Pac variants:
;	Puckman              Namco "original"
;	Hanglyman            Maze disappears sometimes, vertical tunnel?
;	Pac-Man              Namco/Midway
;	Pac-Man Hard         (table changes)
;	Pac-Man Plus         Midway upgrade - New ghosts, 
;                            harder gameplay, disappearing map
;
; (pre-release GCC versions:)
;   Crazy Otto           10/12/1981 (P1) Pac-man intro, legs, monsters, 
;                                        GENCOMP logo,
;                                        no eyes when ghosts return to jail
;   Crazy Otto           10/20/1981 (P2) Marquee (Mspac) intro, legs,
;                                        ghosts, Midway logo
;   Super Pac-Man        10/29/1981 (P3) Same as P2, with no legs, monsters
;   Super Pac-Man        10/29/1981 (P4) Same as P3, ghosts
;   Miss Pac-Man         11/12/1981 (P5) Marquee, "Pac-Woman" graphics, monsters
;   Ms. Pac-Man          11/25/1981 (P6) Same as P5, MsPac graphics, Bonnie
;
;' (Released versions)
;	Ms. Pac-Man          12/18/1981  Original GCC/Midway w/ aux board
;                                        (hardware protected)
;	Ms. Pac-Man          Bootleg (various) decoded aux board
;                                        (no hardware protection)
;	Ms. Pac-Man Attack   four new maps, broken fruit movement
;	Miss Pac Plus        four new maps (same as Attack, reversed)
; and of course, the "fast" and "cheat" versions of those above.
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; JUNK REGIONS OF ROMSPACE
;;

;	There are a few regions of rom space that are unused by
;	the ms-pac program.  These can be used for your own patches,
;	or for data, or whatever.

;	This list is most definitely incomplete.
;	Not all of these regions have been tested.
;	The list is inclusive of the start and end byte listed below.

;	Some routines (like the self-test) can be dropped to give
;	you more romspace to work with.  You should be careful
;	however in that some chunks of romspace might not be free
;	with some rom hacks.
;	(0f3c - 0f4b for example)

;	003b - 0041	  7 bytes	Tested
;	0f3c - 0fff	195 bytes	Untested, nops
;	1fa9 - 1fff	 87 bytes	Untested, nops, 48 used for HACK3 cheat
;	2fba - 2fff	 70 bytes	Untested, nops
;	3ce0 - 3cff	 32 bytes	Untested, nops
;	8000 - 81ef	1f0 bytes	Untested, bootleg hardware ONLY!
;	97c4 - 97cf	  c bytes	Untested, FF's
;	97d0 - 97f0	 30 bytes	Untested, message
;	9800 - 9fff     400 bytes	not available on "pure" mspac.
    
;    Similarly, there are chunks of code in the 0x0000-0x3fff area that are previously
;    used for Pac functionality that has been replaced by the aux roms, which can be
;    re-purposed.
    
;    If you're working with a bootleg romset, then the roms specific
;    to the Aux Board, namely "BOOT5" 0x8000-0x8fff, has a lot of space
;    previously used by the patching mechanism, in 0x8000-0x87ff, which 
;    can be re-used for other code/tables.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;  Ms Pacman Aux board information (GCC/Midway Pac-Man "Upgrade")

;ED note:  The U5, U6 and U7 notes below have yet to be confirmed.

;	It turns out the bootleg is the decrypted version with the
;	checksum check removed and interrupt mode changed to 1.

;	u7= boot 4($3000-$3fff) other than 4 bytes(checksum check
;	and interupt mode)

;	u6= boot 6($9000-$9fff). The second half of u6 gets mirrored
;	Renders to the second half of boot5($8800-$8fff) where it
;	is used.
;	u5= first half of boot5($8000-$87ff)

;	$8000-$81ef contain 8 byte patches that are overlayed on
;	locations in $0000-$2fff

;	The Ms Pacman aux board is not activated with the
;	mainboard.  As near as I can tell it requires a sequence
;	of bytes starting at around 3176 and ending with 3196. The
;	location of the bytes doesn't seem to matter, just that
;	those bytes are executed. That sequence of bytes includes
;	a write to 5006 so I'm using that to bankswitch, but that
;	is not accurate. The actual change is I believe at $317D.
;	The aux board can also be deactivated. A read to any
;	of the several 8 byte chunks listed will cause the Ms Pac
;	roms to disappear and Pacman to show up.  As a result I
;	couldn't verify what they contained. They should be the
;	same as the pacman roms, but I don't see how it could
;	matter. These areas can be accessed by the random number
;	generator at $2a23 and the board is deactivated but is
;	immediately reactivated. So the net result is no change.
;	The exact trigger for this is not yet known.

;	deactivation, 8 bytes starting at:
;	$38,$3b0,$1600,$2120,$3ff0,$8000

;	David Widel
;	d_widel@hotmail.com

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;Ghost names:

;            Pac-Man         Otto            Ms pre      Ms Release

;Red         Shadow/Blinky   Mad Dog/Plato   Blinky      Blinky
;Pink        Speedy/Pinky    Killer/Darwin   Pinky       Pinky
;Cyan        Bashful/Inky    Brute/Freud     Inky        Inky
;Orange      Pokey/Clyde     Sam/Newton      Bonnie      Sue

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; ram:
;	4c00	unknown
;	4c01	unknown
;
; Sprite variables
;
;	4c02	red ghost sprite number
;	4c03	red ghost color entry
;	4c04	pink ghost sprite number
;	4c05	pink ghost color entry
;	4c06	blue ghost sprite number
;	4c07	blue ghost color entry
;	4c08	orange ghost sprite number
;	4c09	orange ghost color entry
;	4c0a	pacman sprite number
;	4c0b	pacman color entry
;	4c0c	fruit sprite number
;	4c0d	fruit sprite entry
;
;	4c20	sprite data that goes to the hardware sprite system
;
;	4c22-4c2f sprite positions for spriteram2
;	4c32-4c3f sprite number and color for spriteram
;	
;	4C40-4C41 used for moving fruit positions
; 	4C42-4C43 used to hold address of the fruit path
;	4c44-4c7f unused/unknown
;
; Tasks and Timers
;
;	4c80	\ pointer to the end of the tasks list
;	4c81	/
;	4c82	\ pointer to the beginning of the tasks list
;	4c83	/
;	4c84	8 bit counter (0x00 to 0xff) used by sound routines
;	4c85	8 bit counter (0xff to 0x00) (unused)
;	4c86	counter 0: 0..5 10..15 20..25  ..  90..95 - hundreths
;	4c87	counter 1: 0..9 10..19 20..29  ..  50..59 - seconds
;	4c88	counter 2: 0..9 10..19 20..29  ..  50..59 - minutes
;	4c89	counter 3: 0..9 10..19 20..29  ..  90..99 - hours
;
;	4c8a	number of counter limits changes in this frame (to init time)
;		0x01	1 hundredth
;		0x02	10 hundredths
;		0x03	1 second
;		0x04	10 seconds
;		0x05	1 minute
;		0x06	10 minutes
;		0x07	1 hour
;		0x08	10 hours
;		0x09	100 hours
;	4c8b	random number generation (unused)
;	4c8c	random number generation (unused)
;
;	4c90-4cbf scheduled tasks list (run inside IRQ)
;		16 entries, 3 bytes per entry
;		Format:
;		byte 0: scheduled time
;                        7 6 5 4 3 2 1 0
;                        | | | | | | | |
;                        | | ------------ number of time units to wait
;                        | |
;                        ---------------- time units
;                                                0x40 -> 10 hundredths
;                                                0x80 -> 1 second
;                                                0xc0 -> 10 seconds
;		byte 1: index for the jump table
;		byte 2: parameter for b
;		these tasks are assigned using RST #30, with the three data bytes immediatly after the call used for the timer, index and parameter
;		these tasks are decoded at routine starting at #0221		
;
;	4cc0-4ccf tasks to execute outside of IRQ
;		0xFF fill for empty task
;		16 entries, 2 bytes per entry
;		Format:
;		byte 0: routine number
;		byte 1: parameter
;		these tasks are assigned using RST #28, with the two data bytes immedately after the call used for the routine number and parameter
;		alternately, tasks can be assigned by manually loading B and C with routine and parameter, and then executing call #0042
;		tasks are decoded at routine starting at #238D
;
; Game variables
; ** note - need to be sorted
;
;   4DD2    FRUITP  fruit position
;   4DD4    FVALUE  value of the current fruit (0=no fruit)
;   4C40    COUNT current place in fruit path
;   4E0C    FIRSTF  flag to indicate that first fruit has been released
;   4E0D    SECONDF flag to indicate that second fruit has been eaten
;   4C41    BCNT    current place within bounce
;   4C42    PATH    pointer to the path the fruit is currently following
;   4E0E    DOTSEAT how many dots the current player has eaten
;   4EBC    BNOISE  set bit 5 of BNOISE to make the bounce sound

;	4d00	red ghost Y position (bottom to top = decreases)
;	4d01	red ghost X position (left to right = decreases)
;	4d02	pink ghost Y position (bottom to top = decreases)
;	4d03	pink ghost X position (left to right = decreases)
;	4d04	blue ghost Y position (bottom to top = decreases)
;	4d05	blue ghost X position (left to right = decreases)
;	4d06	orange ghost Y position (bottom to top = decreases)
;	4d07	orange ghost X position (left to right = decreases)
;
;	4d08	pacman Y position
;	4d09	pacman X position
;
;	4d0a	red ghost Y tile pos (mid of tile) (bottom to top = decrease)
;	4d0b	red ghost X tile pos (mid of tile) (left to right = decrease)
;	4d0c	pink ghost Y tile pos (mid of tile) (bottom to top = decrease)
;	4d0d	pink ghost X tile pos (mid of tile) (left to right = decrease)
;	4d0e	blue ghost Y tile pos (mid of tile) (bottom to top = decrease)
;	4d0f	blue ghost X tile pos (mid of tile) (left to right = decrease)
;	4d10	orange ghost Y tile pos (mid of tile) (bottom to top = decrease)
;	4d11	orange ghost X tile pos (mid of tile) (left to right = decrease)
;	4d12	pacman tile pos in demo and cut scenes
;	4d13	pacman tile pos in demo and cut scenes
;
;	for the following, last move was 
;		(A) 0x00 = left/right, 0x01 = down, 0xff = up
;		(B) 0x00 = up/down, 0x01 = left, 0xff = right
;	4d14	red ghost Y tile changes (A)
;	4d15	red ghost X tile changes (B)
;	4d16	pink ghost Y tile changes (A)
;	4d17	pink ghost X tile changes (B)
;	4d18	blue ghost Y tile changes (A)
;	4d19	blue ghost X tile changes (B)
;	4d1a	orange ghost Y tile changes (A)
;	4d1b	orange ghost X tile changes (B)
;	4d1c	pacman Y tile changes (A)
;	4d1d	pacman X tile changes (B)
;
;	4d1e	red ghost y tile changes
;	4d1f	red ghost x tile changes
;	4d20	pink ghost y tile changes
;	4d21	pink ghost x tile changes
;	4d22	blue ghost y tile changes
;	4d23	blue ghost x tile changes
;	4d24	orange ghost y tile changes
;	4d25	orange ghost x tile changes
;	4d26	wanted pacman tile changes
;	4d27	wanted pacman tile changes
;
;		character orientations:
;		0 = right, 1 = down, 2 = left, 3 = up
;	4d28	previous red ghost orientation (stored middle of movement)
;	4d29	previous pink ghost orientation (stored middle of movement)
;	4d2a	previous blue ghost orientation (stored middle of movement)
;	4d2b	previous orange ghost orientation (stored middle of movement)
;	4d2c	red ghost orientation (stored middle of movement)
;	4d2d	pink ghost orientation (stored middle of movement)
;	4d2e	blue ghost orientation (stored middle of movement)
;	4d2f	orange ghost orientation (stored middle of movement)
;
;	4d30	pacman orientation
;
;		these are updated after a move
;	4d31	red ghost Y tile position 2 (See 4d0a)
;	4d32	red ghost X tile position 2 (See 4d0b)
;	4d33	pink ghost Y tile position 2
;	4d34	pink ghost X tile position 2
;	4d35	blue ghost Y tile position 2
;	4d36	blue ghost X tile position 2
;	4d37	orange ghost Y tile position 2
;	4d38	orange ghost X tile position 2
;
;	4d39	pacman Y tile position (0x22..0x3e) (bottom-top = decrease)
;	4d3a	pacman X tile position (0x1e..0x3d) (left-right = decrease)
;
;	4d3c	wanted pacman orientation
;
;	path finding algorithm:
;	4d3b		best orientation found 
;	4d3d		saves the opposite orientation
;	4d3e-4d3f 	saves the current tile position
;	4d40-4d41 	saves the destination tile position
;	4d42-4d43 	temp resulting position
;	4d44-4d45 	minimum distance^2 found
;
;	4dc7		current orientation we're trying
;	4d46-4d85 	speed bit patterns (difficulty dependant)
;	4D46-4D49       speed bit patterns for pacman in normal state
;	4D4A-4D4D       speed bit patterns for pacman in big pill state
;	4D4E-4D51       speed bit patterns for second difficulty flag
;	4D52-4D55       speed bit patterns for first difficulty flag
;	4D56-4D59       speed bit patterns for red ghost normal state
;	4D5A-4D5D       speed bit patterns for red ghost blue state
;	4D5E-4D61       speed bit patterns for red ghost tunnel areas
;	4D62-4D65       speed bit patterns for pink ghost normal state
;	4D66-4D69       speed bit patterns for pink ghost blue state
;	4D6A-4D6D       speed bit patterns for pink ghost tunnel areas
;	4D6E-4D71       speed bit patterns for blue ghost normal state
;	4D72-4D75       speed bit patterns for blue ghost blue state
;	4D76-4D79       speed bit patterns for blue ghost tunnel areas
;	4D7A-4D7D       speed bit patterns for orange ghost normal state
;	4D7E-4D81       speed bit patterns for orange ghost blue state
;	4D82-4D83       speed bit patterns for orange ghost tunnel areas
;
;	4d86-4d93
;	    Difficulty related table. Each entry is 2 bytes, and
;	    contains a counter value.  when the counter at 4DC2
;	    reaches each entry value, the ghosts changes their
;	    orientation and 4DC1 increments it's value to point to
;	    the next entry
;
;	4d94	counter related to ghost movement inside home
;	4d95-4d96 number of units before ghost leaves home (no change w/ pills)
;	4d97-4d98 inactivity counter for units of the above
;
;	4d99 - 4d9c
;	    These values are normally 0, but are changed to 1 when a ghost has
;	    entered a tunnel slowdown area
;	4d99	aux var used by red ghost to check positions
;	4d9a	aux var used by pink ghost to check positions
;	4d9b	aux var used by blue ghost to check positions
;	4d9c	aux var used by orange ghost to check positions
;
;	4d9d	delay to update pacman movement
;		not 0xff - the game doesn't move pacman, but decrements instead
;		0x01	when eating pill
;		0x06	when eating big pill
;		0xff	when not eating a pill
;	4d9e	related to number of pills eaten before last pacman move
;	4d9f	eaten pills counter after pacman has died in a level
;		used to make ghosts go out of home after # pills eaten
;
;		ghost substates:
;		0 = at home
;		1 = going for pac-man
;		2 = crossing the door
;		3 = going to the door
;
;	4da0	red ghost substate (if alive)
;	4da1	pink ghost substate (if alive)
;	4da2	blue ghost substate (if alive)
;	4da3	orange ghost substate (if alive)
;	4da4	# of ghost killed but no collision for yet [0..4]
;	4da5	pacman dead animation state (0 if not dead)
;	4da6	power pill effect (1=active, 0=no effect)
;
;	4da7	red ghost blue flag (0=not blue)
;	4da8	pink ghost blue flag (0=not blue)
;	4da9	blue ghost blue flag (0=not blue)
;	4daa	orange ghost blue flag (0=not blue)
;
;	4dab	killing ghost state
;		0 = nothing
;		1 = kill red ghost
;		2 = kill pink ghost
;		3 = kill blue ghost
;		4 = kill orange ghost
;
;		ghost states:
;		0 = alive
;		1 = dead
;		2 = entering home after being killed
;		3 = go left after entering home after dead (blue)
;		3 = go right after entering home after dead (orange)
;	4dac	red ghost state
;	4dad	pink ghost state
;	4dae	blue ghost state
;	4daf	orange ghost state
;
;	4db0	related to difficulty, appears to be unused 
;
;		with these, if they're set, ghosts change orientation
;	4db1	red ghost change orientation flag
;	4db2	pink ghost change orientation flag
;	4db3	blue ghost change orientation flag
;	4db4	orange ghost change orientation flag
;	4bd5	pacman change orientation flag
;
; Difficulty settings
;
;	4db6	1st difficulty flag (rel 4dbb) (cruise elroy 1)
;		0: red ghost goes to upper right corner on scatter
;		1: red ghost goes for pacman on scatter
;		1: red ghost goes faster
;	4db7	2nd difficulty flag (rel 4dbc) (cruise elroy 2)
;		when set, red uses a faster bit speed pattern
;		0: not set
;		1: faster movement
;	4db8	pink ghost counter to go out of home limit (rel 4e0f)
;	4db9	blue ghost counter to go out of home limit (rel 4e10)
;	4dba	orange ghost counter to go out of home limit (rel 4e11)
;	4dbb	remainder of pills when first diff. flag is set (cruise elroy 1)
;	4dbc	remainder of pills when second diff. flag is set (cruise elroy 2)
;	4dbd-4dbe Time the ghosts stay blue when pacman eats a big pill
;
;	4dbf	1=pacman about to enter a tunnel, otherwise 0
;
; Counters
;
;	4dc0	changes every 8 frames; used for ghost animations
;	4dc1	orientation changes index [0..7]. used to get value 4d86-4d93
;		0: random ghost movement, 1: normal movement (?)
;	4dc2-4dc3 counter related to ghost orientation changes
;	4dc4	counter 0..8 to handle things once every 8 times
;	4dc5-4dc6 counter started after pacman killed
; 	4dc7	counter for current orientation we're trying
;	4dc8	counter used to change ghost colors under big pill effects
;
;	4dc9-4dca pointer to pick a random value from the ROM (routine 2a23)
;
;	4dcb-4dcc counter while ghosts are blue. effect ceases at 0
;	4dce	counter started after insert coin (LED and 1UP/2UP blink)
;	4dcf	counter to handle power pill flashes
;	4dd0	current number of killed ghosts (0..4)	(rel 4da5)
;
;	4dd1	killed ghost animation state
;		if 4da4 != 0:
;			4dd1 = 0: killed, showing points per kill
;			4dd1 = 1: wating
;			4dd1 = 2: clearing killed ghost, changing state to 0
;	4dd2-4dd3 fruit position (sometimes for other sprite)
;
;	4dd4	entry to fruit points or 0 if no fruit
;	4dd6	used for LED state( 1: game waits for 1P/2P start button press)
;
; Main States
;
;	4e00	main routine number
;		0: init
;		1: demo
;		2: coin inserted
;		3: playing
;	4e01	main routine 0, subroutine #
;	4e02	main routine 1, subroutine # (related to blue maze bug)
;	4e03	main routine 2, subroutine #
;	4e04	level state subroutine #
;		3=ghost move, 2=ghost wait for start
;		(set to 2 to pause game)
;
;	4e06	state in first cutscene (pac-man only)
;	4e07	state in second cutscene (pac-man only)
;	4e08	state in third cutscene (pac-man only)
;
;	4e09	current player number:  0=P1, 1=P2
;
;	4e0a-4e0b pointer to current difficulty settings
;
;	4C40	COUNT current place in fruit path
;	4E0C	FIRSTF  flag to indicate that first fruit has been released
;	4E0D	SECONDF flag to indicate that second fruit has been eaten
;	4C41	BCNT	current place within bounce
;	4C42	PATH	pointer to the path the fruit is currently following
;	4E0E	DOTSEAT	how many dots the current player has eaten
;	4EBC	BNOISE	set bit 5 of BNOISE to make the bounce sound
;
;	4e0c	first fruit flag (1 if fruit has appeared)
;	4e0d	second fruit flag (1 if fruit has appeared)
;	4e0e	number of pills eaten in this level
;	4e0f	counter incremented if orange, blue and pink ghosts are home
;		and pacman is eating pills.
;		used to make pink ghost leave home (rel 4db8)
;	4e10	counter incremented if orange, blue and pink ghosts are home
;		and pacman is eating pills.
;		used to make blue ghost leave home (rel 4db9)
;	4e11	counter incremented if orange, blue and pink ghosts are home
;		and pacman is eating pills.
;		used to make orange ghost leave home (rel 4db9)
;	4e12	1 after dying in a level, reset to 0 if ghosts have left home
;		because of 4d9f
;
;	4e13	current level
;	4e14	real number of lives
;	4e15	number of lives displayed
;
;	4e16-4e33 0x13 pill data entries. each bit means if a pill is there
;		or not (1=yes 0=no)
;		the pills start at upper right corner, go down, then left.
;		first pill is bit 7 of 4e16
;	4e34-4e37 power pills data entries
;	4e38-4e65 copy of level data (430a-4e37)
;
; coins, credits
;
;	4e66	last 4 SERVICE1 to detect transitions
;	4e67	last 4 COIN2 to detect transitions
;	4e68	last 4 COIN1 to detect transitions
;
;	4e69	coin counter (coin->credts, this gets decremented)
;	4e6a	coin counter timeout, used to write coin counters
;
;		these are copied from the dipswitches
;	4e6b	number of coins per credit
;	4e6c	number of coins inserted
;	4e6d	number of credits per coin
;	4e6e	number of credits, 0xff for free play
;	4e6f	number of lives
;	4e70	number of players (0=1 player, 1=2 players)
;	4e71	bonus/life
;		0x10 = 10000	0x15 = 15000
;		0x20 = 20000	0xff = none
;	4e72	cocktail mode (0=no, 1=yes)
;	4e73-4e74 pointer to difficulty settings
;		4e73: 68=normal 7d=hard checked at start of game
;	4e75	ghost names mode (0 or 1)
;
;		SCORE AABBCC
;	4e80-4e82 score P1	80=CC 81=BB 82=CC
;	4e83	P1 got bonus life?  1=yes
;	4e84-4e86 score P2	84=CC 85=BB 86=CC
;	4e87	P2 got bonus life?  1=yes
;	4e88-4e8a high score	88=CC 89=BB 8A=CC
;
; Sound Registers

        ;; these 16 values are copied to the hardware every vblank interrupt.

;CH1_FREQ0       EQU     4e8c    ; 20 bits
;CH1_FREQ1       EQU     4e8d
;CH1_FREQ2       EQU     4e8e
;CH1_FREQ3       EQU     4e8f
;CH1_FREQ4       EQU     4e90
;CH1_VOL         EQU     4e91
;CH2_FREQ1       EQU     4e92    ; 16 bits
;CH2_FREQ2       EQU     4e93
;CH2_FREQ3       EQU     4e94
;CH2_FREQ4       EQU     4e95
;CH2_VOL         EQU     4e96
;CH3_FREQ1       EQU     4e97    ; 16 bits
;CH3_FREQ2       EQU     4e98
;CH3_FREQ3       EQU     4e99
;CH3_FREQ4       EQU     4e9a
;CH3_VOL         EQU     4e9b

;SOUND_COUNTER   EQU     4c84    ; counter, incremented each VBLANK
                                ; (used to adjust sound volume)

;EFFECT_TABLE_1  EQU     3b30    ; channel 1 effects. 8 bytes per effect
;EFFECT_TABLE_2  EQU     3b40    ; channel 2 effects. 8 bytes per effect
;EFFECT_TABLE_3  EQU     3b80    ; channel 3 effects. 8 bytes per effect

;if MSPACMAN
;SONG_TABLE_1    EQU     9685    ; channel 1 song table
;SONG_TABLE_2    EQU     967d    ; channel 2 song table
;SONG_TABLE_3    EQU     968d    ; channel 3 song table
;else
;SONG_TABLE_1    EQU     3bc8
;SONG_TABLE_2    EQU     3bcc
;SONG_TABLE_3    EQU     3bd0
;endif

;CH1_E_NUM       EQU     4e9c    ; effects to play sequentially (bitmask)
;CH1_E_1         EQU     4e9d    ; unused
;CH1_E_CUR_BIT   EQU     4e9e    ; current effect
;CH1_E_TABLE0    EQU     4e9f    ; table of parameters, initially copied from ROM
;CH1_E_TABLE1    EQU     4ea0
;CH1_E_TABLE2    EQU     4ea1
;CH1_E_TABLE3    EQU     4ea2
;CH1_E_TABLE4    EQU     4ea3
;CH1_E_TABLE5    EQU     4ea4
;CH1_E_TABLE6    EQU     4ea5
;CH1_E_TABLE7    EQU     4ea6
;CH1_E_TYPE      EQU     4ea7
;CH1_E_DURATION  EQU     4ea8
;CH1_E_DIR       EQU     4ea9
;CH1_E_BASE_FREQ EQU     4eaa
;CH1_E_VOL       EQU     4eab

; 4EAC repeats the above for channel 2
; 4EBC repeats the above for channel 3

;CH1_W_NUM       EQU     4ecc    ; wave to play (bitmask)
;CH1_W_1         EQU     4ecd    ; unused
;CH1_W_CUR_BIT   EQU     4ece    ; current wave
;CH1_W_SEL       EQU     4ecf
;CH1_W_4         EQU     4ed0
;CH1_W_5         EQU     4ed1
;CH1_W_OFFSET1   EQU     4ed2    ; address in ROM to find the next byte
;CH1_W_OFFSET2   EQU     4ed3    ; (16 bits)
;CH1_W_8         EQU     4ed4
;CH1_W_9         EQU     4ed5
;CH1_W_A         EQU     4ed6
;CH1_W_TYPE      EQU     4ed7
;CH1_W_DURATION  EQU     4ed8
;CH1_W_DIR       EQU     4ed9
;CH1_W_BASE_FREQ EQU     4eda
;CH1_W_VOL       EQU     4edb
;
; 4EDC repeats the above for channel 2
; 4EEC repeats the above for channel 3
;
;
; Runtime
;
;	4F00		Is set to 1 during intermissions and parts of the attract mode, otherwise 0
;	4F01-4FBF	Stack
;	4FC0-4FEF	Unused
;	4FF0-4FFF	Sprite RAM
;
;
;
;
; Memory mapped ports:
; Read ports:
;	port#	Name	; condition & change			Example value
;	----------------------------------------------------------------------
;	5000	IN0	; When Nothing pressed 			FF
;			; Joystick 1 UP clears bit 0		FE
;			; Joystick 1 LEFT clears bit 1		FD
;			; Joystick 1 RIGHT clears bit 2		FB
;			; Joystick 1 DOWN clears bit 3		F7
;			; Rack test clears bit 4		EF
;			; Coin 1 inserted clears bit 5		DF
;			; Coin 2 inserted clears bit 6		BF
;			; Service 1 pressed clears bit 7	#7F
;
;	5040	IN1	; When Nothing pressed			FF
;			; Joystick 2 UP clears bit 0		FE
;			; Joystick 2 LEFT clears bit 1		FD
;			; Joystick 2 RIGHT clears bit 2		FB
;			; Joystick 2 DOWN clears bit 3		F7
;			; service mode switch clears bit 4	EF
;			; Player 1 start button clears bit 5	DF
;			; Player 2 start button clears bit 6	BF
;			; Cocktail cabinet DIP clears bit 7	#7F
;
;	5080	DSW 1	; controls free play/coins per credit, # of lives per game, 
;			; points needed for bonus, rack test, game freeze
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       PAC-MAN SPRITE CODES
;
;       00-07   fruits
;       08-0D   naked ghosts for cutscenes
;       0E-0F   empty
;       10-1B   big pacman
;       1C-1D   ghost in panic mode
;       1E-1F   empty
;       20-27   ghosts
;       28-2B   points
;       2C-2F   pacmans
;       30      big pacman
;       31      explosion
;       32-33   broken ghost
;       34-3F   pacman dead
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	MS. PAC-MAN SPRITE CODES
;
;	00 	cherry
; 	01	strawberry
;	02	peach
;	03	pretzel
;	04 	apple
;	05 	pear
;	06	banana
;	07 	sack that is dropped from stork in act 3
;	08 	100
;	09	200
;	0A	500
;	0B	700
;	0C	1000
;	0D	2000
;	0E	5000
;	0F	junior pac-man seen in act 3
;	10-17	parts of ACT director's sign
;	18	stork
;	19-1B 	pac-man
;	1C-1D	ghost in panic mode
;	1E	heart
;	1F	empty
;	20-27	ghosts
;	28	200
;	29	400
;	2A	800
;	2B	1600
;	2C	stork
;	2D	ms pacman	
;	2E	pac-man
;	2F	ms pacman
;	30	stork head + beak
;	31	ms pacman
;	32	pac-man
;	33-3F	ms pacman (used during dying animation)
;	40-7F	same as 00-3F, but upside down
;	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;       PACMAN TILE CODES
;
;       00-0F   hex digits
;       10-15   pills
;       16-1F   empty
;       ...
;       40-5B   space + ASCII chars
;       5C      copyright
;       5D-5F   PTS
;       ...
;       C0-FF   map obstacles
;
;       SPECIAL COLOR ENTRIES
;
;       18      for ghost's door
;       1A      for pacman's and ghost's initial map positions
;       1B      for tunnel area
;
;       PACMAN TILE CONFIGURATION
;
;       tile position x can go from 0x1e to 0x3d.
;       0x1d == wraparound -> 0x3d
;       0x3e == wraparound -> 0x1e
;       tile position y can go from 0x22 to 0x3e.
;       Why?
;       Because of the graphics hardware.
;       With that configuration, you can convert directly between 
;	tile position to hardware sprite positions
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


	; rst 0 - initialization
	; init


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Symbols
	include "ram.inc"	; documented RAM / I/O (see py/ram_symbols.py)
;; Jump/call targets with no code listing (RAM/IO/etc.)
j_55ff	EQU	#55FF
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CPU memory map (mspacmab): 0000-3FFF, 8000-9FFF
	org	#0000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

j_0000:
	di		; @0000 F3  Disable interrupts
	ld      a,#00		; @0001 3E00  A := #00  
	ld      i,a		; @0003 ED47  Clear interrupt status register 
	jp      j_230b		; @0005 C30B23  jump to startup test 

;; PAC
;0001  3e3f      ld      a,#3f
;;
	
	; rst 8 - memset()
	; Fill HL to HL+B with A

j_0008:
	ld      (hl),a		; @0008 77  store A
	inc     hl		; @0009 23  next memory
	djnz    j_0008		; @000A 10FC  loop until B == #00
	ret		; @000C C9  return

	; arrive here from #23A7

	jp      j_070e		; @000D C30E07  sets up difficulty

	; rst 10  (for dereferencing pointers to bytes)
        ; HL = HL + A, , A := (HL)
	; HL = base address of table
	; A  = index
	; after the call, A gets the data in HL+A

	add     a,l		; @0010 85  Add L into A
	ld      l,a		; @0011 6F  copy result into L
	ld      a,#00		; @0012 3E00  A := #00
	adc     a,h		; @0014 8C  Add with carry into H
	ld      h,a		; @0015 67  copy result into H
	ld      a,(hl)		; @0016 7E  load A with value in HL
	ret		; @0017 C9  return

	; rst 18 (for dereferencing pointers to words)
        ; hl = hl + 2*b,  (hl) -> e, (++hl) -> d, de -> hl
        ; HL = base address of table
	; B  = index
	; after the call, HL gets the data in HL+(2*B).  DE becomes HL+2B
	; modified: DE, A

	ld	a,b		; @0018 78  load A with B
	add	a,a		; @0019 87  double it
	rst	#10		; @001A D7  A:= data in (HL + 2B), HL := HL + 2B
	ld	e,a		; @001B 5F  copy result into E
	inc	hl		; @001C 23  next HL
	ld	d,(hl)		; @001D 56  D := (HL+2B+1)
	ex	de,hl		; @001E EB  Exchange DE with HL.
	ret		; @001F C9  return


        ; rst 20 (jump table)
        ; Uses A as a vector to jump to the location indicated by 2*A after the call
	; For example, if A has #00 and the two bytes following the call are AB and CD, the program will jump to CDAB

	pop	hl		; @0020 E1  load HL with return address.  This is the next byte after the call.
	add	a,a		; @0021 87  A := 2*A
	rst	#10		; @0022 D7  HL += A,   A = (HL)
	ld	e,a		; @0023 5F  Copy first (low) byte to E
	inc	hl		; @0024 23  next Address
	ld	d,(hl)		; @0025 56  D = (HL+1) [high byte], so  DE = 16-bit address at 2*A after the call
	ex	de,hl		; @0026 EB  DE <-> HL
	jp	(hl)		; @0027 E9  jump to HL


	; rst 28
	; takes the 2 bytes after the call as data and inserts them into the task list

	pop     hl		; @0028 E1  HL = next byte after call, first data element
	ld      b,(hl)		; @0029 46  load B with first data byte
	inc     hl		; @002A 23  next data byte
	ld      c,(hl)		; @002B 4E  load C with second data byte
	inc     hl		; @002C 23  HL now has the proper return address
	push    hl		; @002D E5  push to stack so RET will return properly
	jr      j_0042		; @002E 1812  continue this sub below

; rst #30
; when rst #30 is called, the 3 data bytes following the call are inserted
; into the timed task list at the next available location.  Up to #10 (16 decimal)
; locations are searched before giving up.

	ld de,timed_task_list		; @0030 11904C  load DE with starting address of task table
	ld	b,#10		; @0033 0610  For B = 1 to #10
	jp	j_0051		; @0035 C35100  continue this sub below


	; rst 38 (vblank)
	; INTERRUPT MODE 1 handler

j_0038:
	jp      j_1f9b		; @0038 C39B1F  patched jump from pacman.
;	----50		; @003B  junk from pac-man
	; ;; gap-fill from golden boots $003B-$003B
	db	#50		; @003B
	ld      (coin_counter_out),a		; @003C 320750  junk from pac-man
	jp      j_0038		; @003F C33800  junk from pac-man

;; INTERRUPT MODE 2 (original hardware, non-bootlegs, puckman, pac plus)
;0038  af	xor	a
;0039  320050	ld	(#5000),a
;003c  320750	ld	(#5007),a   
;003f  c33800	jp	#0038
;;


	; continuation of rst 28 from #002E
	; this sub can be called with call #0042, if B and C are loaded manually

					; B and C have the data bytes
j_0042:
	ld      hl,(task_list_tail_ptr)		; @0042 2A804C  load HL with address pointing to the beginning of the task list
	ld      (hl),b		; @0045 70  store task 
	inc     l		; @0046 2C  next address
	ld      (hl),c		; @0047 71  store parameter
	inc     l		; @0048 2C  next address
	jr      nz,j_004d		; @0049 2002  If non zero, skip next step
	ld      l,#C0		; @004B 2EC0  else load L with C0 to cycle HL back to #4CC0 (spins C0-FF)
j_004d:
	ld      (task_list_tail_ptr),hl		; @004D 22804C  store new task pointer back (4c80, 4c81) = hl
	ret		; @0050 C9  return to program

	; continuation of rst 30 from #0035 (Task manager)

j_0051:
	ld	a,(de)		; @0051 1A  load A with task
	and	a		; @0052 A7  == #00 ?
	jr	z,j_005b		; @0053 2806  yes, skip ahead, we will insert the new task here

	inc	e		; @0055 1C  else inc E by 3
	inc	e		; @0056 1C
	inc	e		; @0057 1C  DE now at next task
	djnz	j_0051		; @0058 10F7  Next B, loops up to #10 times
	ret		; @005A C9  return

j_005b:
	pop	hl		; @005B E1  HL = data address of the 3 data bytes to be inserted
	ld	b,#03		; @005C 0603  For B = 1 to 3

j_005e:
	ld	a,(hl)		; @005E 7E  load A with table value
	ld 	(de),a		; @005F 12  store into task list
	inc	hl		; @0060 23  next HL
	inc	e		; @0061 1C  next DE
	djnz	j_005e		; @0062 10FA  next B
	jp	(hl)		; @0064 E9  return to program (HL now has return address following the 3 data bytes)

	; this is a common call
	; converts pac-mans sprite position into a grid position

j_0065:
	jp      j_202d		; @0065 C32D20

	; difficulty settings table data - normal #0068
	; these are assigned at a routine starting at #070E

	db	#00,#01,#02,#03,#04,#05,#06,#07	; @0068 0001020304050607
	db	#08,#09,#0A,#0B,#0C,#0D,#0E,#0F,#10,#11,#12,#13,#14	; @0070 08090A0B0C0D0E0F1011121314

	; difficulty settings table data - hard #007D
	; these are assigned at a routine starting at #070E

	db	#01,#03,#04	; @007D 010304
	db	#06,#07,#08,#09,#0A,#0B,#0C,#0D,#0E,#0F,#10,#11,#14	; @0080 060708090A0B0C0D0E0F101114

	;; part of the interrupt routine (non-test)
	;; continuation of RST 38 partially...  (vblank)
	;; (gets called from the #1f9b patch, from #0038)

j_008d:
	push    af		; @008D F5  save AF [restored at #01DA]
	ld      (watchdog),a		; @008E 32C050  kick the dog
	xor     a		; @0091 AF  0 -> a
	ld      (IN0),a		; @0092 320050  disable hardware interrupts
	di		; @0095 F3  disable cpu interrupts

; save registers. they are restored starting at #01BF

	push    bc		; @0096 C5  save BC
	push    de		; @0097 D5  save DE
	push    hl		; @0098 E5  save HL
	push    ix		; @0099 DDE5  save IX
	push    iy		; @009B FDE5  save IY

        ;;
        ;; VBLANK - 1 (SOUND)
        ;;
        ;; load the sound into the hardware
	;;

	ld      hl,CH1_FREQ0		; @009D  pointer to frequencies and volumes of the 3 voices
	ld      de,#5050		; @00A0  hardware address
	ld      bc,#0010		; @00A3  #10 (16 decimal) byte to copy
	ldir		; @00A6  copy

        ;; voice 1 wave select

	ld      a,(CH1_W_NUM)		; @00A8  if we play a wave
	and     a		; @00AB
	ld      a,(CH1_W_SEL)		; @00AC  then WaveSelect = CH1_W_SEL
	jr      nz,j_00b4		; @00AF

	ld      a,(CH1_E_TABLE0)		; @00B1  else WaveSelect = CH1_E_TABLE0

j_00b4:
	ld      (sound_voice1),a		; @00B4  write WaveSelect to hardware

        ;; voice 2 wave select

	ld      a,(CH2_W_NUM)		; @00B7
	and     a		; @00BA
	ld      a,(CH2_W_SEL)		; @00BB
	jr      nz,j_00c3		; @00BE

	ld      a,(CH2_E_TABLE0)		; @00C0
j_00c3:
	ld      (#504a),a		; @00C3

        ;; voice 3 wave select

	ld      a,(CH3_W_NUM)		; @00C6
	and     a		; @00C9
	ld      a,(CH3_W_SEL)		; @00CA
	jr      nz,j_00d2		; @00CD

	ld      a,(CH3_E_TABLE0)		; @00CF
j_00d2:
	ld      (#504f),a		; @00D2


	; copy last frame calculated sprite data into sprite buffer

	ld hl,spr_red_code		; @00D5 21024C  load HL with source address (calculated sprite data)
	ld de,spr_pos_base		; @00D8 11224C  load DE with destination (sprite buffer)
	ld      bc,#001c		; @00DB 011C00  load counter with #1C bytes to copy
	ldir		; @00DE EDB0  copy

	; update sprite data, adjusting to hardware

	ld ix,spr_hw_data		; @00E0 DD21204C  load IX with start of sprite buffer	
	ld      a,(ix+#02)		; @00E4 DD7E02  load A with red ghost sprite
	rlca		; @00E7 07
	rlca		; @00E8 07  rotate 2 bits up 
	ld      (ix+#02),a		; @00E9 DD7702  store
	ld      a,(ix+#04)		; @00EC DD7E04  load A with pink ghost sprite
	rlca		; @00EF 07
	rlca		; @00F0 07  rotate 2 bits up
	ld      (ix+#04),a		; @00F1 DD7704  store
	ld      a,(ix+#06)		; @00F4 DD7E06  load A with blue (inky) ghost sprite
	rlca		; @00F7 07
	rlca		; @00F8 07  rotate 2 bits up
	ld      (ix+#06),a		; @00F9 DD7706  store
	ld      a,(ix+#08)		; @00FC DD7E08  load A with orange ghost sprite
	rlca		; @00FF 07
	rlca		; @0100 07  rotate 2 bits up
	ld      (ix+#08),a		; @0101 DD7708  store
	ld      a,(ix+#0a)		; @0104 DD7E0A  load A with ms pac sprite
	rlca		; @0107 07
	rlca		; @0108 07  rotate 2 bits up
	ld      (ix+#0a),a		; @0109 DD770A  store
	ld      a,(ix+#0c)		; @010C DD7E0C  load A with fruit sprite
	rlca		; @010F 07
	rlca		; @0110 07  rotate 2 bits up
	ld      (ix+#0c),a		; @0111 DD770C  store

	ld      a,(killed_ghost_anim)		; @0114 3AD14D  load A with killed ghost animation state
	cp      #01		; @0117 FE01  is there a ghost being eaten ?
	jr      nz,j_0153		; @0119 2038  no , skip ahead

	ld ix,spr_hw_data		; @011B DD21204C  else load IX with sprite data buffer start
	ld      a,(ghosts_killed_pending)		; @011F 3AA44D  load A with the unhandled killed ghost #
	add     a,a		; @0122 87  A := A * 2
	ld      e,a		; @0123 5F  copy to E
	ld      d,#00		; @0124 1600  D := #00
	add     ix,de		; @0126 DD19  add to index.  now has the eaten ghost sprite
	ld      hl,(#4c24)		; @0128 2A244C  load HL with start of ghost sprite address
	ld      de,(#4c34)		; @012B ED5B344C  load DE with sprite number and color for spriteram
	ld      a,(ix+#00)		; @012F DD7E00  load A with eaten ghost sprite
	ld      (#4c24),a		; @0132 32244C  store
	ld      a,(ix+#01)		; @0135 DD7E01  load A with next ghost sprite
	ld      (#4c25),a		; @0138 32254C  store
	ld      a,(ix+#10)		; @013B DD7E10  load A with eaten ghost spriteram
	ld      (#4c34),a		; @013E 32344C  store
	ld      a,(ix+#11)		; @0141 DD7E11  load A with next ghost spriteram
	ld      (#4c35),a		; @0144 32354C  store
	ld      (ix+#00),l		; @0147 DD7500
	ld      (ix+#01),h		; @014A DD7401
	ld      (ix+#10),e		; @014D DD7310
	ld      (ix+#11),d		; @0150 DD7211  store L, H, E, and D

j_0153:
	ld      a,(power_pill_active)		; @0153 3AA64D  load A with power pill effect (1=active, 0=no effect)
	and     a		; @0156 A7  is a power pill active ?
	jp      z,j_0176		; @0157 CA7601  no, skip ahead

; power pill active

	ld      bc,(spr_pos_base)		; @015A ED4B224C  else swap pac for first ghost.  load BC with red ghost sprite
	ld      de,(spr_code_base)		; @015E ED5B324C  load DE with highest sprite for spriteram
	ld      hl,(#4c2a)		; @0162 2A2A4C  load HL with fruit sprite
	ld      (spr_pos_base),hl		; @0165 22224C  store into highest priority sprite
	ld      hl,(#4c3a)		; @0168 2A3A4C  load HL with ms pac spriteram
	ld      (spr_code_base),hl		; @016B 22324C  store into highest priority spriteram
	ld      (#4c2a),bc		; @016E ED432A4C  store first ghost sprite
	ld      (#4c3a),de		; @0172 ED533A4C  store first ghost spriteram

;

j_0176:
	ld hl,spr_pos_base		; @0176 21224C  load source address with start of sprites
	ld      de,#4ff2		; @0179 11F24F  load destiantion address with spriteram2
	ld      bc,#000c		; @017C 010C00  set counter at #0C bytes

; green eyed ghost bug encountered here
; 4FF2,3 - 
; 4FF2,3 - red ghost (8x,11)
; 4FF4,5 - pink ghost (8x,11)
; 4FF6,7 - blue ghost (8x,11)
; 4FF8,9 - orange ghost (8x,11)


	ldir		; @017F EDB0  copy

	ld hl,spr_code_base		; @0181 21324C  load source address with start of spriteram	
	ld      de,#5062		; @0184 116250  load destination address with hardware sprite
	ld      bc,#000c		; @0187 010C00  set counter at #0C bytes
	ldir		; @018A EDB0  copy [write updated sprites to spriteram]

	;
	; Core game loop
	;

	call    j_01dc		; @018C CDDC01  update all timers
	call    j_0221		; @018F CD2102  check timed tasks and execute them if it is time to do so
	call    j_03c8		; @0192 CDC803  runs subprograms based on game mode, power-on stuff, attract mode, push start screen, and core loops for game playing
	ld      a,(game_mode)		; @0195 3A004E  load A with game mode
	and     a		; @0198 A7  is the game still in power-on mode ?
	jr      z,j_01ad		; @0199 2812  yes, skip over next calls

	call    j_039d		; @019B CD9D03  check for double size pacman in intermission (pac-man only)
	call    j_1490		; @019E CD9014  when player 1 or 2 is played without cockatil mode, update all sprites
	call    j_141f		; @01A1 CD1F14  when player 2 is played on cockatil mode, update all sprites
	call    j_0267		; @01A4 CD6702  debounce rack input / add credits
	call    j_02ad		; @01A7 CDAD02  debounce coin input / add credits
	call    j_02fd		; @01AA CDFD02  blink coin lights
					; print player 1 and player two
					; check for game mode 3
					; draw cprt stuff

j_01ad:
	ld      a,(game_mode)		; @01AD 3A004E  load A with game mode
	dec     a		; @01B0 3D  are we in the demo mode ?
	jr      nz,j_01b9        ; no, skip next 2 steps		; @01B1 2006  set to jr #01b9 to enable sound in demo
	ld	(CH2_E_NUM),a		; @01B3 32AC4E  yes, clear sound channel 2
	ld	(CH3_E_NUM),a		; @01B6 32BC4E  clear sound channel 3

        ;; VBLANK - 2 (SOUND)
        ;;
        ;; Process sound

j_01b9:
	call    j_2d0c		; @01B9  process effects
	call    j_2cc1		; @01BC  process waves

; restore registers.  they were saved at #0096

	pop     iy		; @01BF FDE1  restore IY
	pop     ix		; @01C1 DDE1  restore IX
	pop     hl		; @01C3 E1  restore HL
	pop     de		; @01C4 D1  restore DE
	pop     bc		; @01C5 C1  restore BC

;

	ld      a,(game_mode)		; @01C6 3A004E  load A with game mode
	and     a		; @01C9 A7  is this the initialization?
	jr      z,j_01d4		; @01CA 2808  yes, skip ahead

	ld      a,(IN1)		; @01CC 3A4050  else load A with IN1
	and     #10		; @01CF E610  is the service mode switch set ?

	; elimiate test mode ; HACK7
	;01d1  00        nop
	;01d2  00        nop
	;01d3  00        nop
	;

	jp      z,j_0000		; @01D1 CA0000  yes, reset

j_01d4:
	ld      a,#01		; @01D4 3E01  else A := #01
	ld      (IN0),a		; @01D6 320050  reenable hardware interrupts
	ei		; @01D9 FB  enable cpu interrupts
	pop     af		; @01DA F1  restore AF [was saved at #008D]
	ret		; @01DB C9  return

	; called from #018C
	; this sub increments the timers and random numbers from #4C84 to #4C8C

j_01dc:
	ld hl,SOUND_COUNTER		; @01DC 21844C  load HL with sound counter address
	inc     (hl)		; @01DF 34  increment
	inc     hl		; @01E0 23  load HL with 2nd sound counter address
	dec     (hl)		; @01E1 35  decrement
	inc     hl		; @01E2 23  next address.  HL now has #4C86
	ld      de,#0219		; @01E3 111902  load DE with start of table data
	ld      bc,#0401		; @01E6 010104  C := #01,  For B = 1 to 4, 

j_01e9:
	inc     (hl)		; @01E9 34  increase memory
	ld      a,(hl)		; @01EA 7E  load A with this value
	and     #0f		; @01EB E60F  mask bits, now between #00 and #0F
	ex      de,hl		; @01ED EB  DE <-> HL
	cp      (hl)		; @01EE BE  compare with value in table
	jr      nz,j_0204		; @01EF 2013  if not equal, break out of loop
	inc     c		; @01F1 0C  else C := C + 1
	ld      a,(de)		; @01F2 1A  load A with the value
	add     a,#10		; @01F3 C610  add #10
	and     #F0		; @01F5 E6F0  mask bits
	ld      (de),a		; @01F7 12  store result
	inc     hl		; @01F8 23  next table value
	cp      (hl)		; @01F9 BE  compare with value in table
	jr      nz,j_0204		; @01FA 2008  if not equal, break out of loop
	inc     c		; @01FC 0C  else C := C + 1
	ex      de,hl		; @01FD EB  DE <-> HL
	ld      (hl),#00		; @01FE 3600  clear the value in HL
	inc     hl		; @0200 23  next HL
	inc     de		; @0201 13  next table value
	djnz    j_01e9		; @0202 10E5  loop

; set up psuedo random number generator values, #4C8A, #4C8B, #4C8C

j_0204:
	ld hl,clock_limit_changes		; @0204 218A4C  load HL with timer address
	ld      (hl),c		; @0207 71  store C which was computed above
	inc     l		; @0208 2C  next address.  HL now has #4C8B
	ld      a,(hl)		; @0209 7E  load A with the value from this timer
	add     a,a		; @020A 87  A := A * 2
	add     a,a		; @020B 87  A := A * 2
	add     a,(hl)		; @020C 86  A := A + (HL) (A is now 5 times what it was)
	inc     a		; @020D 3C  increment.   (A is now 5 times plus 1 what it was)
	ld      (hl),a		; @020E 77  store new value
	inc     l		; @020F 2C  next address.  HL now has #4C8C
	ld      a,(hl)		; @0210 7E  load A with the value from this timer
	add     a,a		; @0211 87  A := A * 2
	add     a,(hl)		; @0212 86  A := A + (HL) (A is now 3 times what it was)  
	add     a,a		; @0213 87  A := A * 2
	add     a,a		; @0214 87  A := A * 2
	add     a,(hl)		; @0215 86  A := A + (HL) (A is now 13 times what it was)
	inc     a		; @0216 3C  increment.  (A is now 13 times plus 1 what it was)
	ld      (hl),a		; @0217 77  store result
	ret		; @0218 C9  return

; data used in subrotine above, loaded at #01E3

	db	#06,#A0,#0A,#60,#0A,#60,#0A,#A0	; @0219 06A00A600A600AA0

; checks timed tasks
; counts down timer and executes the task if the timer has expired
; called from #018F

j_0221:
	ld hl,timed_task_list		; @0221 21904C  load HL with task list address
	ld	a,(clock_limit_changes)		; @0224 3A8A4C  load A with number of counter limits changes in this frame
	ld	c,a		; @0227 4F  save to C for testing in line #0232
	ld	b,#10		; @0228 0610  for B = 1 to #10

j_022a:
	ld	a,(hl)		; @022A 7E  load A with task list first value (timer)
	and	a		; @022B A7  == #00 ?  (is this task empty?)
	jr	z,j_025d		; @022C 282F  Yes, jump ahead and loop for next task

	and	#C0		; @022E E6C0  else mask bits with binary 1100 0000 - the left 2 bits (6 and 7) are the time units
	rlca		; @0230 07
	rlca		; @0231 07  rotate twice left.  The time unit bits are now rightmost, in bits 0 and 1.  EG #02 for seconds
	cp	c		; @0232 B9  compare to counter.  is it time to count down the timer?
	jr	nc,j_025d		; @0233 3028  if no, jump ahead and loop for next task

	dec	(hl)		; @0235 35  else decrease the task timer
	ld	a,(hl)		; @0236 7E  load A with new task timer
	and	#3F		; @0237 E63F  mask bits with binary 0011 1111. This will erase the units in the left 2 bits. is the timer counted all the way down?
	jr	nz,j_025d		; @0239 2022  no, jump ahead and loop for next task

	ld	(hl),a		; @023B 77  yes, store A into task timer.  this should be zero and effectively clears the task
	push	bc		; @023C C5  save BC
	push	hl		; @023D E5  save HL
	inc	l		; @023E 2C  HL now has the coded task number address
	ld	a,(hl)		; @023F 7E  load A with task number, used for jump table below
	inc	l		; @0240 2C  HL now has the coded task parameter address
	ld	b,(hl)		; @0241 46  load B with task parameter
	ld	hl,#025B		; @0242 215B02  load HL with return address
	push	hl		; @0245 E5  push to stack so a RET call will return to #025B
	rst	#20		; @0246 E7  jump based on A

	db	#94,#08	; @0247 9408  A==0, #0894  	; increases main subroutine number (level_state) and returns 
	db	#A3,#06	; @0249 A306  A==1, #06A3	; increments main routine 2, subroutine # (game_mode_sub2)
	db	#8E,#05	; @024B 8E05  A==2, #058E 	; increases the main routine # (game_mode_sub1)
	db	#72,#12	; @024D 7212  A==3, #1272 	; increases killed ghost animation state when a ghost is eaten
	db	#00,#10	; @024F 0010  A==4, #1000 	; clears the fruit sprite
	db	#0B,#10	; @0251 0B10  A==5, #100B 	; clears the fruit score sprite
	db	#63,#02	; @0253 6302  A==6, #0263 	; clears the "READY!" message
	db	#2B,#21	; @0255 2B21  A==7, #212B 	; to increase state in 1st cutscene (cutscene1_state) (pac-man only)
	db	#F0,#21	; @0257 F021  A==8, #21F0 	; to increase state in 2nd cutscene (cutscene2_state) (pac-man only)
	db	#B9,#22	; @0259 B922  A==9, #22B9 	; to increase state in 3rd cutscene (cutscene3_state) (pac-man only)

	pop  hl		; @025B E1  restore HL
	pop  bc		; @025C C1  restore BC

j_025d:
	inc  l		; @025D 2C
	inc  l		; @025E 2C
	inc  l		; @025F 2C  next task
	djnz j_022a		; @0260 10C8  next B
	ret		; @0262 C9  return    

	; timed task #06 - clears ready message

	rst     #28		; @0263 EF  insert task #1C, parameter 86 to clear the "READY!" message
	db	#1C,#86	; @0264 1C86  task data
	ret		; @0266 C9  return

	;; debounce rack input / add credits (if 99 or over, return)
	; called from #01A4

j_0267:
	ld      a,(credits)		; @0267 3A6E4E  load A with number of  current credits in BCD
	cp      #99		; @026A FE99  == #99 ? (99 is max number of credits avail)
	rla		; @026C 17  rotate left A
	ld      (coin_lockout),a		; @026D 320650  store into #5006 (coin lockout, not used ?)
	rra		; @0270 1F  rotate right A
	ret     nc		; @0271 D0  return if 99 credits

	ld      a,(IN0)		; @0272 3A0050  load A with IN0 input (joystick, credits, service mode button)
	ld      b,a		; @0275 47  copy to B
	rlc     b		; @0276 CB00  rotate left
	ld      a,(in_service_hist)		; @0278 3A664E  load A with service mode indicator
	rla		; @027B 17  rotate left with carry
	and     #0f		; @027C E60F  and it with #0F
	ld      (in_service_hist),a		; @027E 32664E  put it back
	sub     #0c		; @0281 D60C  subtract #0C.  is the service mode being used to add a credit?
	call    z,j_02df		; @0283 CCDF02  If yes, call #02df  ; add credit
	rlc     b		; @0286 CB00  rotate left B
	ld      a,(in_coin2_hist)		; @0288 3A674E  load A with coin input #1
	rla		; @028B 17  rotate left
	and     #0f		; @028C E60F  mask bits
	ld      (in_coin2_hist),a		; @028E 32674E  put back
	sub     #0c		; @0291 D60C  subtract C.  is a coin being inserted?
	jp      nz,j_029a		; @0293 C29A02  no, skip ahead
	ld hl,coin_counter		; @0296 21694E  yes, load HL with coin counter
	inc     (hl)		; @0299 34  increase counter
j_029a:
	rlc     b		; @029A CB00  rotaate left B
	ld      a,(in_coin1_hist)		; @029C 3A684E  load A with coint input #2
	rla		; @029F 17  rotate left
	and     #0f		; @02A0 E60F  maks bits
	ld      (in_coin1_hist),a		; @02A2 32684E  put back
	sub     #0c		; @02A5 D60C  subtract #0C.  is a coin being inserted?
	ret     nz		; @02A7 C0  no, return

	ld hl,coin_counter		; @02A8 21694E  else load HL with coin counter
	inc     (hl)		; @02AB 34  increase
	ret		; @02AC C9  return

	;; debounce coin input / add credits
	; called from #01A7

j_02ad:
	ld      a,(coin_counter)		; @02AD 3A694E  load A with coin counter
	and     a		; @02B0 A7  == #00 ?
	ret     z		; @02B1 C8  yes, return

	ld      b,a		; @02B2 47  else copy coin counter to B
	ld      a,(coin_counter_timeout)		; @02B3 3A6A4E  load A with coin counter timeout
	ld      e,a		; @02B6 5F  copy timeout to E
	cp      #00		; @02B7 FE00  is the timeout == #00?
	jp      nz,j_02c4		; @02B9 C2C402  no, skip ahead

	ld      a,#01		; @02BC 3E01  else A := #01
	ld      (coin_counter_out),a		; @02BE 320750  store into coin counter
	call    j_02df		; @02C1 CDDF02  call coins -> credits routine

j_02c4:
	ld      a,e		; @02C4 7B  load A with timeout
	cp      #08		; @02C5 FE08  is the timeout == #08 ?
	jp      nz,j_02ce		; @02C7 C2CE02  no, skip next 2 steps

	xor     a		; @02CA AF  A := #00
	ld      (coin_counter_out),a		; @02CB 320750  clear coin counter

j_02ce:
	inc     e		; @02CE 1C  increment timeout
	ld      a,e		; @02CF 7B  copy to A
	ld      (coin_counter_timeout),a		; @02D0 326A4E  store into coin counter timeout
	sub     #10		; @02D3 D610  subtract #10.  did the timeout end?
	ret     nz		; @02D5 C0  no, return

	ld      (coin_counter_timeout),a		; @02D6 326A4E  else clear the counter timeout [A now has #00]
	dec     b		; @02D9 05  decrement B, this was a copy of the coin counter
	ld      a,b		; @02DA 78  copy to A
	ld      (coin_counter),a		; @02DB 32694E  store into coin counter
	ret		; @02DE C9  return

	;; coins -> credits routine

j_02df:
	ld      a,(dip_coins_per_credit)		; @02DF 3A6B4E  load A with coins per credits
	ld hl,coins_inserted		; @02E2 216C4E  load HL with # of leftover coins
	inc     (hl)		; @02E5 34  add 1
	sub     (hl)		; @02E6 96  subract this value from A
	ret     nz		; @02E7 C0  if not zero, then not enough coins for credits.  return

	ld      (hl),a		; @02E8 77  else store A into leftover coins
	ld      a,(dip_credits_per_coin)		; @02E9 3A6D4E  load A with credits per coins
	ld hl,credits		; @02EC 216E4E  load HL with credits
	add     a,(hl)		; @02EF 86  add # credits
	daa		; @02F0 27  decimal adjust
	jp      nc,j_02f6		; @02F1 D2F602  if no carry, skip ahead
	ld      a,#99		; @02F4 3E99  else load a with #99
j_02f6:
	ld      (hl),a		; @02F6 77  store credits, max #99
	ld hl,CH1_E_NUM		; @02F7 219C4E  load HL with sound register
	set     1,(hl)		; @02FA CBCE  play credit sound
	ret		; @02FC C9  return

	;; blink coin lights, print player 1 and player 2, check for mode 3
	; called from #01AA

j_02fd:
	ld hl,coin_blink_counter		; @02FD 21CE4D  load HL with counter started after insert coin (LED and 1UP/2UP blink)
	inc     (hl)		; @0300 34  increment counter
	ld      a,(hl)		; @0301 7E  load A with counter
	and     #0f		; @0302 E60F  mask 4 left bits to zero
	jr      nz,j_0325		; @0304 201F  skip ahead if result is not zero

	ld      a,(hl)		; @0306 7E  load A with counter
	rrca		; @0307 0F
	rrca		; @0308 0F
	rrca		; @0309 0F
	rrca		; @030A 0F  shift right 4 times
	ld      b,a		; @030B 47  copy A to B

	;; blink coin lights to pellets ; HACK9
	;;
	;; 030c  3aa74d	ld	a,(#4da7) 
	;; 030f  4f	ld	c,a
	;; 0310  180b	jr	#0317
	;;

	ld      a,(start_button_wait)		; @030C 3AD64D  load A with LED state (1: game waits for 1P/2P start button press)	 
	cpl		; @030F 2F  1's complement of A
	or      b		; @0310 B0  or with B
	ld      c,a		; @0311 4F  load C with result
	ld      a,(credits)		; @0312 3A6E4E  load A with number of credits
	sub     #01		; @0315 D601  subtract one from it.

	jr      nc,j_031b		; @0317 3002  if no carry then skip next 2 steps
	xor     a		; @0319 AF  A := #00
	ld      c,a		; @031A 4F  c := #00

j_031b:
	jr      z,j_031e		; @031B 2801  If zero then skip next step

	ld      a,c		; @031D 79  else load A with C

j_031e:
	ld      (lamp_p2),a		; @031E 320550  Store A into player 2 start lamp
	ld      a,c		; @0321 79  load A with C
	ld      (lamp_p1),a		; @0322 320450  store A into player 1 start lamp

j_0325:
	ld      ix,#43d8		; @0325 DD21D843  load IX with start address where the screen shows "1UP"
	ld      iy,#43c5		; @0329 FD21C543  load IY with start address where the screen shows "1UP"
	ld      a,(game_mode)		; @032D 3A004E  load A with game mode
	cp      #03		; @0330 FE03  is a game being played ?
	jp      z,j_0344		; @0332 CA4403  Yes, Jump ahead

	ld      a,(game_mode_sub2)		; @0335 3A034E  else load A with main routine 2, subroutine #
	cp      #02		; @0338 FE02  <= 2 ?
	jp      nc,j_0344		; @033A D24403  yes, skip ahead

	call    j_0369		; @033D CD6903  else draw "1UP"
	call    j_0376		; @0340 CD7603  draw "2UP"
	ret		; @0343 C9  return

	;; display and blink 1UP/2UP depending on player up

j_0344:
	ld      a,(player_number)		; @0344 3A094E  load A with current player number:  0=P1, 1=P2
	and     a		; @0347 A7  is this player 1 ?
	ld      a,(coin_blink_counter)		; @0348 3ACE4D  load A with counter started after insert coin (LED and 1UP/2UP blink)
	jp      nz,j_0359		; @034B C25903

	bit     4,a		; @034E CB67  test bit 4 of the counter.  is it on?
	call    z,j_0369		; @0350 CC6903  no, draw  "1UP"
	call    nz,j_0383		; @0353 C48303  yes, clear "1UP"
	jp      j_0361		; @0356 C36103  skip ahead

j_0359:
	bit     4,a		; @0359 CB67  test bit 4 of the counter.  is it on?
	call    z,j_0376		; @035B CC7603  no, draw  "2UP"
	call    nz,j_0390		; @035E C49003  yes, clear "2UP"

j_0361:
	ld      a,(num_players)		; @0361 3A704E  load A with player# (0=player1, 1=player2)
	and     a		; @0364 A7  is this player 1 ?
	call    z,j_0390		; @0365 CC9003  yes, clear "2UP"
	ret		; @0368 C9  return     

	; draw "1UP"

j_0369:
	ld      (ix+#00),#50		; @0369 DD360050  'P'
	ld      (ix+#01),#55		; @036D DD360155  'U'
	ld      (ix+#02),#31		; @0371 DD360231  '1'
	ret		; @0375 C9

	; draw "2UP"

j_0376:
	ld      (iy+#00),#50		; @0376 FD360050  'P'
	ld      (iy+#01),#55		; @037A FD360155  'U'
	ld      (iy+#02),#32		; @037E FD360232  '2'
	ret		; @0382 C9

	; clear "1UP"

j_0383:
	ld      (ix+#00),#40		; @0383 DD360040  ' '
	ld      (ix+#01),#40		; @0387 DD360140  ' '
	ld      (ix+#02),#40		; @038B DD360240  ' '
	ret		; @038F C9

	; clear "2UP"

j_0390:
	ld      (iy+#00),#40		; @0390 FD360040  ' '
	ld      (iy+#01),#40		; @0394 FD360140  ' '
	ld      (iy+#02),#40		; @0398 FD360240  ' '
	ret		; @039C C9

	; draws big pacman in intermission. used for pac-man only, not ms.pac
	; called from #019b

j_039d:
	ld      a,(cutscene1_state)		; @039D 3A064E  load A with 1st intermission counter
	sub     #05		; @03A0 D605  is big-pac onscreen ?
	ret     c		; @03A2 D8  no, return.  (always returns in ms. pacman)

	; draw big pac (pac-man only, during 1st cutscene)

	ld      hl,(pac_y)		; @03A3 2A084D
	ld      b,#08		; @03A6 0608
	ld      c,#10		; @03A8 0E10
	ld      a,l		; @03AA 7D
	ld      (orange_y),a		; @03AB 32064D
	ld      (fruit_pos_lo),a		; @03AE 32D24D
	sub     c		; @03B1 91
	ld      (pink_y),a		; @03B2 32024D
	ld      (blue_y),a		; @03B5 32044D
	ld      a,h		; @03B8 7C
	add     a,b		; @03B9 80
	ld      (pink_x),a		; @03BA 32034D
	ld      (orange_x),a		; @03BD 32074D
	sub     c		; @03C0 91
	ld      (blue_x),a		; @03C1 32054D
	ld      (fruit_pos_hi),a		; @03C4 32D34D
	ret		; @03C7 C9

	;; enable sound out and other stuff
	; called from #0192

j_03c8:
	ld      a,(game_mode)		; @03C8 3A004E  load A with game mode
	rst     #20		; @03CB E7  jump based on A

	db	#D4,#03	; @03CC D403  #03D4		;#4E00 = 0	;GAME POWER ON
	db	#FE,#03	; @03CE FE03  #03FE		;#4E00 = 1      ;ALL ATTRACT MODES.  this runs until a credit is inserted
	db	#E5,#05	; @03D0 E505  #05E5		;#4E00 = 2      ;PLAYER 1 OR 2 SCREEN.  draw screen and wait for start to be pressed
	db	#BE,#06	; @03D2 BE06  #06BE		;#4E00 = 3      ;PLAYER 1 OR 2 PLAYING.  runs core game loop

; arrive here after power on

	ld	a,(game_mode_sub0)		; @03D4 3A014E  load A with main routine 0, subroutine #
;	rst     #20		; @03D5 E7  jump based on A

	; ;; gap-fill from golden boots $03D7-$03D7
	db	#E7		; @03D7
	db	#DC,#03	; @03D8 DC03  #03DC
	db	#0C,#00	; @03DA 0C00  #000C.  returns immediately (to #0195)

; arrive here after powering on
; this sets up the following tasks

	rst	#28		; @03DC EF  insert task to clear the whole screen
	db	#00,#00	; @03DD 0000  data for above, task #00         
	rst	#28		; @03DF EF  insert task to clear the color RAM
	db	#06,#00	; @03E0 0600  data for above, task #06
	rst     #28		; @03E2 EF  insert task color the maze
	db	#01,#00	; @03E3 0100  data for above, task #01
	rst     #28		; @03E5 EF  insert task to check all dip switches and assign memories to the settings indicated
	db	#14,#00	; @03E6 1400  data for above, task #14
	rst     #28		; @03E8 EF  insert task - draws "high score" and scores.  clears player 1 and 2 scores to zero.
	db	#18,#00	; @03E9 1800  data for above, task #18
	rst     #28		; @03EB EF  insert task - resets a bunch of memories
	db	#04,#00	; @03EC 0400  data for above, task #04
	rst     #28		; @03EE EF  insert task - clear fruit, pacman, and all ghosts
	db	#1E,#00	; @03EF 1E00  data for above, task #1E
	rst     #28		; @03F1 EF  insert task - set game to demo mode
	db	#07,#00	; @03F2 0700  data for above, task #07

	ld hl,game_mode_sub0		; @03F4 21014E  load HL with main routine 0, subroutine #
	inc	(hl)		; @03F7 34  increase so this sub doesn't run again.
	ld hl,irq_enable		; @03F8 210150  load HL with sound address
	ld      (hl),#01		; @03FB 3601  enable sound
	ret		; @03FD C9  return

	; attract mode main routine

	call    j_2ba1		; @03FE CDA12B  write # of credits on screen
	ld      a,(credits)		; @0401 3A6E4E  load A with # of credits
	and     a		; @0404 A7  == #00 ?
	jr      z,j_0413		; @0405 280C  yes, skip ahead

	xor     a		; @0407 AF  else A := #00
	ld      (level_state),a		; @0408 32044E  clear level state subroutine #
	ld      (game_mode_sub1),a		; @040B 32024E  clear main routine 1, subroutine #
	ld hl,game_mode		; @040E 21004E  load HL with game mode
	inc     (hl)		; @0411 34  increase game mode to press start screen
	ret		; @0412 C9  return (to #0195)

	; table lookup
; OTTOPATCH
;PATCH FOR NEW ATTRACT MODE
;ORG 0413H
;JP ATTRACT
j_0413:
	jp      j_3e5c		; @0413 C35C3E  jump to mspac patch when there are no credits - controls the demo mode
					; code resumes at #045F

; Pac-man code:
; 0413  3a024e	ld	a,(#4e02)	; load A with main routine 1, subroutine #
; end Pac-man code

	rst	#20		; @0416 E7  jump based on A (pac-man only)

	; jump table based from value in #4E02
	; task routine to draw out the attract screen, only used in pac-man, not ms. pac

	db	#5F,#04	; @0417 5F04  #045F	;(game_mode_sub1)=#00    ; clear screen, reset memories, clear sprites          
	db	#0C,#00	; @0419 0C00  #000C	;(game_mode_sub1)=#01	; returns immediately
	db	#71,#04	; @041B 7104  #0471 ;(game_mode_sub1)=#02	; draw red ghost
	db	#0C,#00	; @041D 0C00  #000C ;(game_mode_sub1)=#03	; returns immediately
	db	#7F,#04	; @041F 7F04  #047F ;(game_mode_sub1)=#04  	; draw "-SHADOW"
	db	#0C,#00	; @0421 0C00  #000C ;(game_mode_sub1)=#05	; returns immediately
	db	#85,#04	; @0423 8504  #0485 ;(game_mode_sub1)=#06	; draw ""BLINKY""
	db	#0C,#00	; @0425 0C00  #000C ;(game_mode_sub1)=#07	; returns immediately
	db	#8B,#04	; @0427 8B04  #048B ;(game_mode_sub1)=#08	; draw pink ghost
	db	#0C,#00	; @0429 0C00  #000C ;(game_mode_sub1)=#09	; returns immediately
	db	#99,#04	; @042B 9904  #0499 ;(game_mode_sub1)=#0A	; draw "-SPEEDY"
	db	#0C,#00	; @042D 0C00  #000C ;(game_mode_sub1)=#0B	; returns immediately
	db	#9F,#04	; @042F 9F04  #049F ;(game_mode_sub1)=#0C	; draw ""PINKY""
	db	#0C,#00	; @0431 0C00  #000C ;(game_mode_sub1)=#0D	; returns immediately
	db	#A5,#04	; @0433 A504  #04A5 ;(game_mode_sub1)=#0E	; draw blue ghost (inky)
	db	#0C,#00	; @0435 0C00  #000C ;(game_mode_sub1)=#0F	; returns immediately
	db	#B3,#04	; @0437 B304  #04B3 ;(game_mode_sub1)=#10	; draw "-BASHFUL"
	db	#0C,#00	; @0439 0C00  #000C ;(game_mode_sub1)=#11	; returns immediately
	db	#B9,#04	; @043B B904  #04B9 ;(game_mode_sub1)=#12	; draw ""INKY""
	db	#0C,#00	; @043D 0C00  #000C ;(game_mode_sub1)=#13	; returns immediately
	db	#BF,#04	; @043F BF04  #04BF ;(game_mode_sub1)=#14	; draw orange ghost
	db	#0C,#00	; @0441 0C00  #000C ;(game_mode_sub1)=#15	; returns immediately
	db	#CD,#04	; @0443 CD04  #04CD ;(game_mode_sub1)=#16	; draw "-POKEY"
	db	#0C,#00	; @0445 0C00  #000C ;(game_mode_sub1)=#17	; returns immediately
	db	#D3,#04	; @0447 D304  #04D3 ;(game_mode_sub1)=#18	; draw ""CLYDE""
	db	#0C,#00	; @0449 0C00  #000C ;(game_mode_sub1)=#19	; returns immediately
	db	#D8,#04	; @044B D804  #04D8 ;(game_mode_sub1)=#1A	; draw ". 10 Pts" and "o 50pts"
	db	#0C,#00	; @044D 0C00  #000C ;(game_mode_sub1)=#1B	; returns immediately
	db	#E0,#04	; @044F E004  #04E0 ;(game_mode_sub1)=#1C	; get demo ready and draw invisible maze
	db	#0C,#00	; @0451 0C00  #000C ;(game_mode_sub1)=#1D	; returns immediately
	db	#1C,#05	; @0453 1C05  #051C ;(game_mode_sub1)=#1E	; start and run demo
	db	#4B,#05	; @0455 4B05  #054B ;(game_mode_sub1)=#1F	; check to release pink ghost
	db	#56,#05	; @0457 5605  #0556 ;(game_mode_sub1)=#20	; check to release inky
	db	#61,#05	; @0459 6105  #0561 ;(game_mode_sub1)=#21	; check to release orange ghost
	db	#6C,#05	; @045B 6C05  #056C ;(game_mode_sub1)=#22	; check for completion of demo
	db	#7C,#05	; @045D 7C05  #057C ;(game_mode_sub1)=#23	; end demo and return to program


	; ms. pac code resumes here
	; arrive here from #3E67 when subroutine # = 00
	; sets up the attract mode

	rst     #28		; @045F EF  insert task #00 - clears the maze
	db	#00,#01	; @0460 0001
	rst     #28		; @0462 EF  insert task #01 - colors the screen
	; ;; gap-fill from golden boots $0463-$0463
	db	#01		; @0463
	db	#00,#EF		; @0464 0100
;	rst     #28		; @0465 EF  insert task #04 - resets a bunch of memories
	db	#04,#00	; @0466 0400
	rst     #28		; @0468 EF  insert task #1E - clear fruit, pacman and all ghosts
	db	#1E,#00	; @0469 1E00
	ld      c,#0c		; @046B 0E0C  load C with text code for "Ms Pac Man"
	call    j_0585		; @046D CD8505  draw text to screen, increase subroutine #
	ret		; @0470 C9  return (to #0195)

; pac-man only attract mode code from #0471 to #0579

	ld      hl,#4304		; @0471 210443  load HL with starting screen address of stationary red ghost
	ld      a,#01		; @0474 3E01  load A with the color code for red
	call    j_05bf		; @0476 CDBF05  draw stationary red ghost on screen
	ld      c,#0c		; @0479 0E0C  load C with text code for "CHARACTER / NICKNAME"
	call    j_0585		; @047B CD8505  insert task to write text to screen
	ret		; @047E C9  return

	ld      c,#14		; @047F 0E14  load C with text code for "-SHADOW"
	call    j_0593		; @0481 CD9305  draw text to screen
	ret		; @0484 C9  return

	ld      c,#0d		; @0485 0E0D  load C with text code for ""BLINKY""
	call    j_0593		; @0487 CD9305  draw text to screen
	ret		; @048A C9  return

	ld      hl,#4307		; @048B 210743  load HL with starting screen address of stationary pink ghost
	ld      a,#03		; @048E 3E03  load A with color code for pink
	call    j_05bf		; @0490 CDBF05  draw stationary pink ghost on screen
	ld      c,#0c		; @0493 0E0C  load C with text code for "CHARACTER / NICKNAME"
	call    j_0585		; @0495 CD8505  insert task to write text to screen
	ret		; @0498 C9  return

	ld      c,#16		; @0499 0E16  load C with text code for "-SPEEDY"
	call    j_0593		; @049B CD9305  draw text to screen
	ret		; @049E C9  return

	ld      c,#0f		; @049F 0E0F  load C with text code for ""PINKY""
	call    j_0593		; @04A1 CD9305  draw text to screen
	ret		; @04A4 C9  return

	ld      hl,#430a		; @04A5 210A43  load HL with starting screen address of stationary blue ghost (inky)
	ld      a,#05		; @04A8 3E05  load A with color code for light blue
	call    j_05bf		; @04AA CDBF05  draw stationary inky on screen
	ld      c,#0c		; @04AD 0E0C  load C with text code for "CHARACTER / NICKNAME"
	call    j_0585		; @04AF CD8505  insert task to write text to screen
	ret		; @04B2 C9  return

	ld      c,#33		; @04B3 0E33  load C with text code for "-BASHFUL"
	call    j_0593		; @04B5 CD9305  draw text to screen
	ret		; @04B8 C9  return

	ld      c,#2f		; @04B9 0E2F  load C with text code for ""INKY""
	call    j_0593		; @04BB CD9305  draw text to screen
	ret		; @04BE C9  return

	ld      hl,#430d		; @04BF 210D43  load HL with starting screen address of staionary orange ghost
	ld      a,#07		; @04C2 3E07  load A with color code for orange
	call    j_05bf		; @04C4 CDBF05  draw stationary orange ghost on screen
	ld      c,#0c		; @04C7 0E0C  load C with text code for "CHARACTER / NICKNAME"
	call    j_0585		; @04C9 CD8505  insert task to write text to screen
	ret		; @04CC C9  return

	ld      c,#35		; @04CD 0E35  load C with text code for "-POKEY"
	call    j_0593		; @04CF CD9305  draw text on screen
	ret		; @04D2 C9  return

	ld      c,#31		; @04D3 0E31  load C with text code for ""CLYDE""
	jp      j_0580		; @04D5 C38005  draw text and increase game mode

	rst     #28		; @04D8 EF  insert task to write text ". 10 Pts"
	db	#1C,#11	; @04D9 1C11
;	ld      c,#12		; @04DA 0E12
	; ;; gap-fill from golden boots $04DB-$04DC
	db	#0E,#12		; @04DB
	jp      j_0585		; @04DD C38505  insert task to write text "o 50 Pts"

	ld      c,#13		; @04E0 0E13  load C with text code for "(C) MIDWAY MFG CO"
	call    j_0585		; @04E2 CD8505  insert task to write text to screen
	call    j_0879		; @04E5 CD7908  setup game start variables
	dec     (hl)		; @04E8 35
	rst     #28		; @04E9 EF  set task #11 to clear memories #4d00 through #4dff
	db	#11,#00	; @04EA 1100
	rst     #28		; @04EC EF  set task #05 to reset ghost home counter
	db	#05,#01	; @04ED 0501
	rst	#28		; @04EF EF  set task #10 to set up difficulty
	db	#10,#14	; @04F0 1014
	rst     #28		; @04F2 EF  set task #04 to reset a bunch of memories and set up sprite locations for demo mode
	db	#04,#01	; @04F3 0401
;	ld      a,#01		; @04F4 3E01  A := #01
	; ;; gap-fill from golden boots $04F5-$04F6
	db	#3E,#01		; @04F5
	ld      (lives_real),a		; @04F7 32144E  store into number of lives left 
	xor     a		; @04FA AF  A := #00
	ld      (num_players),a		; @04FB 32704E  store into number of players ( 0=1 1=2 )
	ld      (lives_displayed),a		; @04FE 32154E  store into number of lives displayed
	ld      hl,#4332		; @0501 213243  load HL with screen address where energizer is in attract mode
	ld      (hl),#14		; @0504 3614  draw energizer
j_0506:
	ld      a,#FC		; @0506 3EFC  load A with code for invisible maze block
	ld      de,#0020		; @0508 112000  load DE with offset for columns
	ld      b,#1c		; @050B 061C  For B = 1 to #1C
	ld      ix,#4040		; @050D DD214040  load IX with start address of video memory for playfield

j_0511:
	ld      (ix+#11),a		; @0511 DD7711  draw invisible maze block
	ld      (ix+#13),a		; @0514 DD7713  draw invisible maze block
	add     ix,de		; @0517 DD19  add offset for next column
	djnz    j_0511		; @0519 10F6  Next B
	ret		; @051B C9  return

	; called during attract mode, pac-man only, not ms. pac

	ld hl,red_substate		; @051C 21A04D  load HL with red ghost substate address
	ld      b,#21		; @051F 0621  B := #21
	ld      a,(pac_tile_x)		; @0521 3A3A4D  load A with pacman X tile position

j_0524:
	sub     b		; @0524 90  has pacman/ghost reached the far right side of the screen?
	jr      nz,j_052c		; @0525 2005  no, skip ahead and do a core loop
	ld      (hl),#01		; @0527 3601  yes, change ghost substate to going for pac-man
	jp      j_058e		; @0529 C38E05  jump ahead, increase game state and return

	; a core game loop used in pac-man demo mode only, not used in ms. pac

j_052c:
	call    j_1017		; @052C CD1710  another core game loop which does many things
	call    j_1017		; @052F CD1710  another core game loop which does many things
	call    j_0e23		; @0532 CD230E  change animation of ghosts every 8th frame
	call    j_0c0d		; @0535 CD0D0C  handle power pill flashes
	call    j_0bd6		; @0538 CDD60B  set ghost colors
	call    j_05a5		; @053B CDA505  check for direction reversal after eating power pill
	call    j_1efe		; @053E CDFE1E  check for red ghost direction reversal
	call    j_1f25		; @0541 CD251F  check for pink ghost direction reversal
	call    j_1f4c		; @0544 CD4C1F  check for blue ghost (inky) direction reversal
	call    j_1f73		; @0547 CD731F  check for orange ghost direction reversal
	ret		; @054A C9

	ld hl,pink_substate		; @054B 21A14D  load HL with pink ghost substate
	ld      b,#20		; @054E 0620  B := #20
	ld      a,(red_tile_x2)		; @0550 3A324D  load A with red ghost X tile position 2
	jp      j_0524		; @0553 C32405  check for reaching position to release next ghost

	ld hl,blue_substate		; @0556 21A24D  load HL with blue ghost (inky) substate
	ld      b,#22		; @0559 0622  B := #22
	ld      a,(red_tile_x2)		; @055B 3A324D  load A with red ghost X tile position 2
	jp      j_0524		; @055E C32405  check for reaching position to release next ghost

	ld hl,orange_substate		; @0561 21A34D  load HL with orange ghost substate
	ld      b,#24		; @0564 0624  B := #24
	ld      a,(red_tile_x2)		; @0566 3A324D  load A with red ghost X tile position 2
	jp      j_0524		; @0569 C32405  check for reaching position to release next ghost

	ld      a,(ghosts_killed_count)		; @056C 3AD04D  load A with current number of killed ghosts
	ld      b,a		; @056F 47  copy to B
	ld      a,(killed_ghost_anim)		; @0570 3AD14D  load A with killed ghost animation state
	add     a,b		; @0573 80  add to number of killed ghosts
	cp      #06		; @0574 FE06  == #06?  (are we done ?)
	jp      z,j_058e		; @0576 CA8E05  yes, skip ahead and increase subroutine number

	jp      j_052c		; @0579 C32C05  no, loop back again to core loop

; arrive here in demo mode from #3ECD

j_057c:
	call    j_06be		; @057C CDBE06  jump to new subroutine based on game state
	ret		; @057F C9  returns to #0195  

; pac-man only ???
; arrive here from #04D5

j_0580:
	ld      a,(ghost_names_mode)		; @0580 3A754E  load A with ghost name mode (0 or 1)
	add     a,c		; @0583 81
	ld      c,a		; @0584 4F

; called from #046D and other places.  C is preloaded with the text code to display

j_0585:
	ld      b,#1c		; @0585 061C  load B with task code for text display
	call    j_0042		; @0587 CD4200  insert task to display text, parameter = variable text
	rst     #30		; @058A F7  insert timed task to increase the main routine # (game_mode_sub1)
	db	#4A,#02,#00	; @058B 4A0200  timer = #4A, task = 2, parameter = 0

; BUGFIX03 - Blue maze - Don Hodges
;	db	#41,#02,#00	; @058B 410200  41 is 1/10 second rather than 1 second


; called from # 0246 from jump table based on game state
; or, timed task number #02 has been encountered, arrive from #0246
; also arrive from #3E93 during marquee mode in demo

j_058e:
	ld hl,game_mode_sub1		; @058E 21024E  load HL with main routine 1, subroutine #
	inc     (hl)		; @0591 34  increase
	ret		; @0592 C9  return

; pac-man only - used in demo mode for introducing ghost names
; called from several places after C has been preloaded with ghost name code

j_0593:
	ld      a,(ghost_names_mode)		; @0593 3A754E  Load A with ghost name mode (0 or 1)
	add     a,c		; @0596 81  add to C
	ld      c,a		; @0597 4F  load result into C
	ld      b,#1c		; @0598 061C  load B with task code for text display
	call    j_0042		; @059A CD4200  set task to display ghost name
	rst     #30		; @059D F7  set timed task to increase the main routine # (game_mode_sub1)
	db	#45,#02,#00	; @059E 450200  data for rst #30 above.  timer=45, task=2, param=0
	call    j_058e		; @05A1 CD8E05  increase main routine 1, subroutine # (game_mode_sub1)
	ret		; @05A4 C9  return

; pac-man only, used during attract mode when pac-man moves toward energizer followed by the 4 ghosts

j_05a5:
	ld      a,(pac_reverse_flag)		; @05A5 3AB54D  load A with pacman change orientation flag
	and     a		; @05A8 A7  == #00 ?
	ret     z		; @05A9 C8  yes, return

; pac-man only, used during attract mode when pac-man reaches the energizer

	xor     a		; @05AA AF  no, A := #00
	ld      (pac_reverse_flag),a		; @05AB 32B54D  store into pacman change orientation flag
	ld      a,(pac_dir)		; @05AE 3A304D  load A with pacman orientation
	xor     #02		; @05B1 EE02  flip bit = change direction
	ld      (pac_wanted_dir),a		; @05B3 323C4D  store into wanted pacman orientation
	ld      b,a		; @05B6 47  store into B
	ld      hl,#32ff		; @05B7 21FF32  load HL with tile direction table
	rst     #18		; @05BA DF  load HL with tile direction based on direction
	ld      (pac_wanted_tile_dy),hl		; @05BB 22264D  store into wanted pacman tile changes
	ret		; @05BE C9  return

; pac-man only, used during attract mode to draw the stationary ghosts during introductions
; HL is preloaded with starting screen address,
; A is preloaded with the ghost color code

j_05bf:
	ld      (hl),#B1		; @05BF 36B1  draw first part of ghost
	inc     l		; @05C1 2C
	ld      (hl),#B3		; @05C2 36B3  draw 2nd part of ghost
	inc     l		; @05C4 2C
	ld      (hl),#B5		; @05C5 36B5  draw 3rd part of ghost
	ld      bc,#001e		; @05C7 011E00  load BC with offset for next column
	add     hl,bc		; @05CA 09  add offset
	ld      (hl),#B0		; @05CB 36B0  draw 4th part of ghost
	inc     l		; @05CD 2C
	ld      (hl),#B2		; @05CE 36B2  draw 5th part of ghost
	inc     l		; @05D0 2C
	ld      (hl),#B4		; @05D1 36B4  draw last part of ghost
	ld      de,#0400		; @05D3 110004
	add     hl,de		; @05D6 19  add offset for color
	ld      (hl),a		; @05D7 77  color last part of ghost
	dec     l		; @05D8 2D
	ld      (hl),a		; @05D9 77  color 5th part of ghost
	dec     l		; @05DA 2D
	ld      (hl),a		; @05DB 77  color 4th part of ghost
	and     a		; @05DC A7  clear carry flag
	sbc     hl,bc		; @05DD ED42  subtract offset for previous column
	ld      (hl),a		; @05DF 77  color 3rd part of ghost
	dec     l		; @05E0 2D
	ld      (hl),a		; @05E1 77  color 2nd part of ghost
	dec     l		; @05E2 2D
	ld      (hl),a		; @05E3 77  color first part of ghost
	ret		; @05E4 C9  return


; arrive from #03CB
; arrive here when credit has been inserted and game is waiting for start button to be pressed

	ld	a,(game_mode_sub2)		; @05E5 3A034E  load A with main routine 2, subroutine #
	rst	#20		; @05E8 E7  jump based on A

	db	#F3,#05	; @05E9 F305  #05F3		; inserts tasks to draw info on screen
	db	#1B,#06	; @05EB 1B06  #061B		; display 1/2 player and check start buttons
	db	#74,#06	; @05ED 7406  #0674		; run when start button pressed, gets game ready to be played
	db	#0C,#00	; @05EF 0C00  #000C		; returns immediately
	db	#A8,#06	; @05F1 A806  #06A8		; draw remaining lives at bottom of screen and start game

	call	j_2ba1		; @05F3 CDA12B  write # of credits on screen

	rst	#28		; @05F6 EF  insert task to clear the maze
	db	#00,#01	; @05F7 0001  task #00, parameter #01
	rst	#28		; @05F9 EF  insert task to color the maze
	; ;; gap-fill from golden boots $05FA-$05FA
	db	#01		; @05FA
	db	#00,#EF		; @05FB 0100  task #01
;	rst	#28		; @05FC EF  insert task to display "PUSH START BUTTON"
	db	#1C,#07	; @05FD 1C07  task #1c, parameter #07.  
	rst	#28		; @05FF EF  insert task to display "ADDITIONAL    AT   000"
	db	#1C,#0B	; @0600 1C0B  task #1C, parameter #0B. 
	rst	#28		; @0602 EF  insert task to clear fruit, pacman, and all ghosts
	db	#1E,#00	; @0603 1E00  task #1E

	ld hl,game_mode_sub2		; @0605 21034E  load HL with main routine 2, subroutine #
	inc	(hl)		; @0608 34  increase
	ld	a,#01		; @0609 3E01  A := #01
	ld	(start_button_wait),a		; @060B 32D64D  store in LED state ( 1: game waits for 1P/2P start button press)
	ld	a,(dip_bonus_life)		; @060E 3A714E  load A with setting for bonus life
	cp	#FF		; @0611 FEFF  does this game award any bonus lives?
	ret	z		; @0613 C8  no, return

	rst	#28		; @0614 EF  else insert task to draw the MS PAC MAN graphic which appears between "ADDITIONAL" and "AT 10,000 pts"
	db	#1C,#0A	; @0615 1C0A  task data
	rst	#28		; @0617 EF  insert task to write points needed for extra life digits to screen
	db	#1F,#00	; @0618 1F00  task data
	ret		; @061A C9  return

	;; jump here from #05E8
	;; display 1/2 player and check start buttons

	call    j_2ba1		; @061B CDA12B  write # of credits on screen
	ld      a,(credits)		; @061E 3A6E4E  load A with # of credits
	cp      #01		; @0621 FE01  is it 1?
	ld      b,#09		; @0623 0609  load B with message #9:  "1 OR 2 PLAYERS"
	jr      nz,j_0629		; @0625 2002  if >= 2 credits, skip next step
	ld      b,#08		; @0627 0608  load B with message #8:  "1 PLAYER ONLY"
j_0629:
	call    j_2c5e		; @0629 CD5E2C  print message
	ld      a,(credits)		; @062C 3A6E4E  load A with # of credits
	cp      #01		; @062F FE01  1 credit?
	ld      a,(IN1)		; @0631 3A4050  load A with IN1 (player start buttons)
	jr      z,j_0642		; @0634 280C  don't check p2 with 1 credit
	bit     6,a		; @0636 CB77  check for player 2 start button
	jr      nz,j_0642		; @0638 2008  if not, pressed, skip ahead to check for player 1 start
	ld      a,#01		; @063A 3E01  else set 2 players
	ld      (num_players),a		; @063C 32704E  store into # of players (0=1 player, 1=2 players)
	jp      j_0649		; @063F C34906  jump ahead
j_0642:
	bit     5,a		; @0642 CB6F  player 1 start being pressed ?
	ret     nz		; @0644 C0  no, return

	xor     a		; @0645 AF  A := #00
	ld      (num_players),a		; @0646 32704E  store into # of players (0=1 player, 1=2 players)
j_0649:
	ld      a,(dip_coins_per_credit)		; @0649 3A6B4E  load A with number of coins per credit
	and     a		; @064C A7  Is free play activated?
	jr      z,j_0664		; @064D 2815  Yes, skip ahead
	ld      a,(num_players)		; @064F 3A704E  else load A with # of players
	and     a		; @0652 A7  Is this a 1 player game?
	ld      a,(credits)		; @0653 3A6E4E  load A with number of credits
	jr      z,j_065b		; @0656 2803  If 1 player game, skip ahead and only subtract 1 credit
	add     a,#99		; @0658 C699  else subtract 2 credits.  one here...
	daa		; @065A 27  decimal adjust

j_065b:
	add     a,#99		; @065B C699  subtract a credit
	daa		; @065D 27  decimal adjust
	ld      (credits),a		; @065E 326E4E  save result in credits counter
	call    j_2ba1		; @0661 CDA12B  write # of credits on screen

j_0664:
	ld hl,game_mode_sub2		; @0664 21034E  load HL with main routine 2, subroutine #
	inc     (hl)		; @0667 34  increase
	xor     a		; @0668 AF  A := #00
	ld      (start_button_wait),a		; @0669 32D64D  store in LED state ( 1: game waits for 1P/2P start button press)
	inc     a		; @066C 3C  A := #01
	ld      (CH1_W_NUM),a		; @066D 32CC4E  store in wave to play (begins intro music tune)
	ld      (CH2_W_NUM),a		; @0670 32DC4E  store in wave to play (beigns intro music tune)
	ret		; @0673 C9  return (to #0195)

	; arrive from #05E8 when start button has been pressed

	rst     #28		; @0674 EF  set task #00, parameter #01 - clears the maze
	db	#00,#01	; @0675 0001
	rst     #28		; @0677 EF  set task #01, parameter #01 - colors the maze
	db	#01,#01	; @0678 0101
	rst     #28		; @067A EF  set task #02, parameter #00 - draws the maze
	db	#02,#00	; @067B 0200
	rst     #28		; @067D EF  set task #12, parameter #00 - sets up coded pill and power pill memories
	db	#12,#00	; @067E 1200
	rst     #28		; @0680 EF  set task #03, parameter #00 - draws the pellets
	db	#03,#00	; @0681 0300
	rst     #28		; @0683 EF  set task #1C, parameter #03 - draws text on screen "PLAYER 1"
	db	#1C,#03	; @0684 1C03
	rst     #28		; @0686 EF  set task #1C, parameter #06 - draws text on screen "READY!" and clears the intermission indicator
	db	#1C,#06	; @0687 1C06
	rst     #28		; @0689 EF  set task #18, parameter #00 - draws "high score" and scores.  clears player 1 and 2 scores to zero.
	db	#18,#00	; @068A 1800
	rst     #28		; @068C EF  set task #1B, parameter #00 - draws fruit at bottom right of screen
	db	#1B,#00	; @068D 1B00

	xor     a		; @068F AF  A := #00
	ld      (level_number),a		; @0690 32134E  current board level = 0
	ld      a,(dip_lives)		; @0693 3A6F4E  load number of lives to start
	ld      (lives_real),a		; @0696 32144E  set number of lives
	ld      (lives_displayed),a		; @0699 32154E  set number of lives displayed
	rst     #28		; @069C EF  set task #1A, parameter #00 - draws remaining lives at bottom of screen
	db	#1A,#00	; @069D 1A00
	rst     #30		; @069F F7  set timed task to increment main routine 2, subroutine # (game_mode_sub2)
	db	#57,#01,#00	; @06A0 570100  task data: timer=#57, task=01, parameter=0.

; also arrive here from #0246.   This is timed task #01

	ld hl,game_mode_sub2		; @06A3 21034E  load HL with main routine 2, subroutine #
	inc     (hl)		; @06A6 34  increase
	ret		; @06A7 C9  return

	;; draw lives displayed onto the screen

	ld hl,lives_displayed		; @06A8 21154E  load HL with lives displayed on screen loc
	dec     (hl)		; @06AB 35  decrement
	call    j_2b6a		; @06AC CD6A2B  draw remaining lives at bottom of screen 
	xor     a		; @06AF AF  A := #00
	ld      (game_mode_sub2),a		; @06B0 32034E  clear main routine 2, subroutine #
	ld      (game_mode_sub1),a		; @06B3 32024E  clear main routine 1, subroutine #
	ld      (level_state),a		; @06B6 32044E  clear level state subroutine #
	ld hl,game_mode		; @06B9 21004E  load HL with game mode address
	inc     (hl)		; @06BC 34  inc game mode.  game mode is now 3 = game is just now starting
	ret		; @06BD C9  return

; arrive here from #03CB or from #057C, when someone or demo is playing

j_06be:
	ld   a,(level_state)		; @06BE 3A044E  load A with level state
	rst  #20		; @06C1 E7  jump based on A

	db	#79,#08	; @06C2 7908  #0879		; set up game initialization
	db	#99,#08	; @06C4 9908  #0899		; set up tasks for beginning of game
	db	#0C,#00	; @06C6 0C00  #000C		; returns immediately
	db	#CD,#08	; @06C8 CD08  #08CD		; demo mode or player is playing
	db	#0D,#09	; @06CA 0D09  #090D		; when player has collided with hostile ghost (died)
	db	#0C,#00	; @06CC 0C00  #000C		; returns immediately
	db	#40,#09	; @06CE 4009  #0940		; check for game over, do things if true
	db	#0C,#00	; @06D0 0C00  #000C		; returns immediately
	db	#72,#09	; @06D2 7209  #0972		; end of demo mode when ms pac dies in demo.  clears a bunch of memories.
	db	#88,#09	; @06D4 8809  #0988		; sets a bunch of tasks and displays "ready" or "game over"
	db	#0C,#00	; @06D6 0C00  #000C		; returns immediately
	db	#D2,#09	; @06D8 D209  #09D2		; begin start of maze demo after marquee
	db	#D8,#09	; @06DA D809  #09D8		; clears sounds and sets a small delay.  run at end of each level
	db	#0C,#00	; @06DC 0C00  #000C		; returns immediately
	db	#E8,#09	; @06DE E809  #09E8		; flash screen
	db	#0C,#00	; @06E0 0C00  #000C		; returns immediately
	db	#FE,#09	; @06E2 FE09  #09FE		; flash screen
	db	#0C,#00	; @06E4 0C00  #000C		; returns immediately
	db	#02,#0A	; @06E6 020A  #0A02		; flash screen
	db	#0C,#00	; @06E8 0C00  #000C		; returns immediately
	db	#04,#0A	; @06EA 040A  #0A04		; flash screen
	db	#0C,#00	; @06EC 0C00  #000C		; returns immediately
	db	#06,#0A	; @06EE 060A  #0A06		; flash screen
	db	#0C,#00	; @06F0 0C00  #000C		; returns immediately
	db	#08,#0A	; @06F2 080A  #0A08		; flash screen
	db	#0C,#00	; @06F4 0C00  #000C		; returns immediately
	db	#0A,#0A	; @06F6 0A0A  #0A0A		; flash screen
	db	#0C,#00	; @06F8 0C00  #000C		; returns immediately
	db	#0C,#0A	; @06FA 0C0A  #0A0C		; flash screen
	db	#0C,#00	; @06FC 0C00  #000C		; returns immediately
	db	#0E,#0A	; @06FE 0E0A  #0A0E		; set a bunch of tasks
	db	#0C,#00	; @0700 0C00  #000C		; returns immediately
	db	#2C,#0A	; @0702 2C0A  #0A2C		; clears all sounds and runs intermissions when needed
	db	#0C,#00	; @0704 0C00  #000C		; returns immediately
	db	#7C,#0A	; @0706 7C0A  #0A7C		; clears sounds, increases level, increases difficulty if needed, resets pill maps
	db	#A0,#0A	; @0708 A00A  #0AA0		; get game ready to play and set this sub back to #03
	db	#0C,#00	; @070A 0C00  #000C		; returns immediately
	db	#A3,#0A	; @070C A30A  #0AA3		; sets sub # back to #03

; arrive here from #000D
; sets up game difficulty

j_070e:
	ld      a,b		; @070E 78  load A with parameter from task
	and     a		; @070F A7  == #00 ?
	jr      nz,j_0716		; @0710 2004  no, skip ahead
	ld      hl,(difficulty_ptr_lo)		; @0712 2A0A4E  else load HL with difficulty setting pointer.  EG #0068
	ld      a,(hl)		; @0715 7E  load A with difficulty, EG #00

j_0716:
	ld      ix,#0796		; @0716 DD219607  load IX with difficulty table start
	ld      b,a		; @071A 47
	add     a,a		; @071B 87
	add     a,a		; @071C 87
	add     a,b		; @071D 80
	add     a,b		; @071E 80  A is now 6 times what it was
	ld      e,a		; @071F 5F
	ld      d,#00		; @0720 1600
	add     ix,de		; @0722 DD19  adjust IX based on current difficulty
	ld      a,(ix+#00)		; @0724 DD7E00  load A with first value from table
	add     a,a		; @0727 87
	ld      b,a		; @0728 47
	add     a,a		; @0729 87
	add     a,a		; @072A 87
	ld      c,a		; @072B 4F
	add     a,a		; @072C 87
	add     a,a		; @072D 87
	add     a,c		; @072E 81
	add     a,b		; @072F 80
	ld      e,a		; @0730 5F
	ld      d,#00		; @0731 1600
	ld      hl,#330f		; @0733 210F33  load HL with start of data table - speeds of ghosts and pacman
	add     hl,de		; @0736 19  add offset computed above
	call    j_0814		; @0737 CD1408  copy data into #4d46 through #4d94
	ld      a,(ix+#01)		; @073A DD7E01  load A with second value from table
	ld      (diff_unused_4db0),a		; @073D 32B04D  store.  appears to be unused
	ld      a,(ix+#02)		; @0740 DD7E02  load A with third value from table
	ld      b,a		; @0743 47  copy to B
	add     a,a		; @0744 87  A := A*2
	add     a,b		; @0745 80  A is now 3 times value in table
	ld      e,a		; @0746 5F  store in E
	ld      d,#00		; @0747 1600  D := #00
	ld      hl,#0843		; @0749 214308  load HL with hard/easy data table check 
	add     hl,de		; @074C 19  add offset computed above
	call    j_083a		; @074D CD3A08  copy difficulty info to #4DB8 to #4DBA
	ld      a,(ix+#03)		; @0750 DD7E03  load A with fourth value from table
	add     a,a		; @0753 87  A := A * 2
	ld      e,a		; @0754 5F  copy to E
	ld      d,#00		; @0755 1600  D := #00
	ld      iy,#084f		; @0757 FD214F08  load IY with data table start
	add     iy,de		; @075B FD19  add offset
	ld      l,(iy+#00)		; @075D FD6E00
	ld      h,(iy+#01)		; @0760 FD6601  load HL with table data
	ld      (elroy1_pill_threshold),hl		; @0763 22BB4D  store into remainder of pills when first diff. flag is set
	ld      a,(ix+#04)		; @0766 DD7E04  load A with fifth value from table
	add     a,a		; @0769 87  A := A * 2
	ld      e,a		; @076A 5F  store into E
	ld      d,#00		; @076B 1600  clear D
	ld      iy,#0861		; @076D FD216108  load IY with start of table that controls time that ghosts stay blue
	add     iy,de		; @0771 FD19  add offset
	ld      l,(iy+#00)		; @0773 FD6E00
	ld      h,(iy+#01)		; @0776 FD6601  load HL with data from table
	ld      (frightened_time_lo),hl		; @0779 22BD4D  store into time the ghosts stay blue when pacman eats a power pill
	ld      a,(ix+#05)		; @077C DD7E05  load A with sixth value from table
	add     a,a		; @077F 87  A := A * 2
	ld      e,a		; @0780 5F  copy to E
	ld      d,#00		; @0781 1600  clear D
	ld      iy,#0873		; @0783 FD217308  load IY with start of difficulty table - number of units before ghosts leaves home
	add     iy,de		; @0787 FD19  add offset
	ld      l,(iy+#00)		; @0789 FD6E00
	ld      h,(iy+#01)		; @078C FD6601  load HL with data from table
	ld      (ghost_leave_home_units_lo),hl		; @078F 22954D  store
	call    j_2bea		; @0792 CDEA2B  draw fruit at bottom of screen
	ret		; @0795 C9  return (to # 238D ?) 

;	-- difficulty related table
;	each entry is 6 bytes
;	byte 0: (0..6) speed bit patterns and orientation changes (table at #330F)
;	byte 1: (00, 01, 02) stored at #4DB0 - seems to be unused
;	byte 2: (0..3) ghost counter table to exit home (table at #0843)
;	byte 3: (0..7) remaining number of pills to set difficulty flags (table at #084F)
;	byte 4: (0..8) ghost time to stay blue when pacman eats the big pill (table at #0861)
;	byte 5: (0..2) number of units before a ghost goes out of home (table at #0873)

	
	db	#03,#01,#01,#00,#02,#00	; @0796 030101000200
	db	#04,#01,#02,#01,#03,#00	; @079C 040102010300
	db	#04,#01,#03,#02,#04,#01	; @07A2 040103020401
	db	#04,#02,#03,#02,#05,#01	; @07A8 040203020501
	db	#05,#00,#03,#02,#06,#02	; @07AE 050003020602
	db	#05,#01,#03,#03,#03,#02	; @07B4 050103030302
	db	#05,#02,#03,#03,#06,#02	; @07BA 050203030602
	db	#05,#02,#03,#03,#06,#02	; @07C0 050203030602
	db	#05,#00,#03,#04,#07,#02	; @07C6 050003040702
	db	#05,#01,#03,#04,#03,#02	; @07CC 050103040302
	db	#05,#02,#03,#04,#06,#02	; @07D2 050203040602
	db	#05,#02,#03,#05,#07,#02	; @07D8 050203050702
	db	#05,#00,#03,#05,#07,#02	; @07DE 050003050702
	db	#05,#02,#03,#05,#05,#02	; @07E4 050203050502
	db	#05,#01,#03,#06,#07,#02	; @07EA 050103060702
	db	#05,#02,#03,#06,#07,#02	; @07F0 050203060702
	db	#05,#02,#03,#06,#08,#02	; @07F6 050203060802
	db	#05,#02,#03,#06,#07,#02	; @07FC 050203060702
	db	#05,#02,#03,#07,#08,#02	; @0802 050203070802
	db	#05,#02,#03,#07,#08,#02	; @0808 050203070802
	db	#06,#02,#03,#07,#08,#02	; @080E 060203070802


; called from #0737
; copies difficulty-related data into #4d46 through #4d94
; includes 4d58 which is blinky's normal speed
; include 4d86 which controls timing of reversals


j_0814:
	ld de,speed_pat_pac_normal		; @0814 11464D  set destination
	ld      bc,#001c		; @0817 011C00  set counter
	ldir		; @081A EDB0  copy
	ld      bc,#000c		; @081C 010C00  set counter
	and     a		; @081F A7  clear carry flag
	sbc     hl,bc		; @0820 ED42  subtract from source
	ldir		; @0822 EDB0  copy
	ld      bc,#000c		; @0824 010C00  set counter
	and     a		; @0827 A7  clear carry flag
	sbc     hl,bc		; @0828 ED42  subtract from source
	ldir		; @082A EDB0  copy
	ld      bc,#000c		; @082C 010C00  set counter
	and     a		; @082F A7  clear carry flag
	sbc     hl,bc		; @0830 ED42  subtract source
	ldir		; @0832 EDB0  copy
	ld      bc,#000e		; @0834 010E00  set counter
	ldir		; @0837 EDB0  copy
	ret		; @0839 C9  return

; called from #0749

j_083a:
	ld de,pink_exit_limit		; @083A 11B84D  load destination with #4DB8
	ld      bc,#0003		; @083D 010300  set bytes to copy at 3
	ldir		; @0840 EDB0  copy
	ret		; @0842 C9  return

;-- table related to difficulty - each entry is 3 bytes
; b0: when counter at 4E0F reaches this value, pink ghost goes out of home
; b1: when counter at 4E10 reaches this value, blue ghost goes out of home
; b2: when counter at 4E11 reaches this value, orange ghost goes out of home

    ; these don't seem to be used in ms-pac at all.

	db	#14,#1E,#46,#00,#1E,#3C,#00,#00,#32,#00,#00,#00	; @0843 141E46001E3C000032000000

	; hard hack: HACK6
	; 0843  0f 14 37 04  18 34  02 06 28   00 04 08
	;

; -- difficulty table --
; each entry is 2 bytes
; b1: remaining number of pills when first difficulty flag is set (cruise elroy 1)
; b2: remaining number of pills when second difficulty flag is set (cruise elroy 2)


	db	#14,#0A	; @084F 140A
	db	#1E,#0F	; @0851 1E0F
	db	#28,#14	; @0853 2814
	db	#32,#19	; @0855 3219
	db	#3C,#1E	; @0857 3C1E
	db	#50,#28	; @0859 5028
	db	#64,#32	; @085B 6432
	db	#78,#3C	; @085D 783C
	db	#8C,#46	; @085F 8C46


; difficulty table - Time the ghosts stay blue when pacman eats a big pill
;		-- do not use with l set up at #076D 

	db	#C0,#03	; @0861 C003  03c0 (960) 8 seconds (not used)
	db	#48,#03	; @0863 4803  0348 (840) 7 seconds (not used)
	db	#D0,#02	; @0865 D002  02d0 (720) 6 seconds
	db	#58,#02	; @0867 5802  0258 (600) 5 seconds
	db	#E0,#01	; @0869 E001  01e0 (480) 4 seconds
	db	#68,#01	; @086B 6801  0168 (360) 3 seconds
	db	#F0,#00	; @086D F000  00f0 (240) 2 seconds
	db	#78,#00	; @086F 7800  0078 (120) 1 second
	db	#01,#00	; @0871 0100  0001 (1)   0 seconds

; difficulty table - number of units before ghosts leaves home
; set up at #0783

	db	#F0,#00	; @0873 F000  00f0 (240) 2 seconds
	db	#F0,#00	; @0875 F000  00f0 (240) 2 seconds
	db	#B4,#00	; @0877 B400  00b4 (180) 1.5 seconds

; main routine #3.  arrive here at the start of the game when a new game is started
; arrive from #04E5 or #06C1

j_0879:
	ld hl,player_number		; @0879 21094E  load HL with player # address
	xor     a		; @087C AF  A := #00
	ld      b,#0b		; @087D 060B  set counter to #0B
	rst     #8		; @087F CF  clear memories from #4E09 through #4E09 + #0B
	call    j_24c9		; @0880 CDC924  set up pills and power pills in RAM
	ld      hl,(dip_difficulty_ptr_lo)		; @0883 2A734E  load HL with difficulty
	ld      (difficulty_ptr_lo),hl		; @0886 220A4E  store difficulty
	ld hl,difficulty_ptr_lo		; @0889 210A4E  load source with difficulty
	ld de,level_data_copy		; @088C 11384E  load destination with difficulty
	ld      bc,#002e		; @088F 012E00  set byte counter at #2E
	ldir		; @0892 EDB0  copy

; arrive here from #09CF
; this is also timed task #00, arrive from #0246

j_0894:
	ld hl,level_state		; @0894 21044E  load HL with main subroutine number
	inc     (hl)		; @0897 34  increment
	ret		; @0898 C9  return

; arrive from #06C1

	ld      a,(game_mode)		; @0899 3A004E  load A with game mode
	dec     a		; @089C 3D  are we in the demo mode ?
	jr      nz,j_08a5		; @089D 2006  no, skip ahead

	ld      a,#09		; @089F 3E09  yes, load A with #09
	ld      (level_state),a		; @08A1 32044E  store in main subroutine
	ret		; @08A4 C9  return 

j_08a5:
	rst     #28		; @08A5 EF  insert task #11 - clears memories from #4D00 through #4DFF
	db	#11,#00	; @08A6 1100
	rst     #28		; @08A8 EF  insert task #1C, parameter #83 - displays or clears text
	db	#1C,#83	; @08A9 1C83
	rst     #28		; @08AB EF  insert task #04 - resets a bunch of memories and
	db	#04,#00	; @08AC 0400
	rst     #28		; @08AE EF  insert task #05 - resets ghost home counter
	db	#05,#00	; @08AF 0500
	rst     #28		; @08B1 EF  insert task #10 - sets up difficulty
	db	#10,#00	; @08B2 1000
	rst     #28		; @08B4 EF  insert task #1A - draws remaining lives at bottom of screen
	db	#1A,#00	; @08B5 1A00
	rst     #30		; @08B7 F7  set timed task to increase the main subroutine number (level_state)
	db	#54,#00,#00	; @08B8 540000  task timer=#54, task=0, param=0    
	rst     #30		; @08BB F7  set timed task to clear the "READY!" message
	db	#54,#06,#00	; @08BC 540600  task timer=#54, task=6, param=0
	ld      a,(dip_cocktail)		; @08BF 3A724E  load A with cocktail or upright
	ld      b,a		; @08C2 47  copy to B
	ld      a,(player_number)		; @08C3 3A094E  load A with current player #
	and     b		; @08C6 A0  is this game cockatil mode and player # 2 ? If so , this value becomes 1
	ld      (flip_screen),a		; @08C7 320350  store into flip screen register
	jp      j_0894		; @08CA C39408  loop back to increment level complete register and return

; demo or game is playing

	ld      a,(IN0)		; @08CD 3A0050  load A with IN0
	bit     4,a		; @08D0 CB67  is rack test on?
	jp      nz,j_08de		; @08D2 C2DE08  no, skip ahead

	ld hl,level_state		; @08D5 21044E  else rack switch on, so advance.  load HL with game state
	ld      (hl),#0e		; @08D8 360E  store value of #0E.  this signals end of level
	rst     #28		; @08DA EF  insert task #13 with parameter #00 - clears the sprites
	db	#13,#00	; @08DB 1300
	ret		; @08DD C9  return  

	;; routine to determine the number of pellets which must be eaten

j_08de:
	ld      a,(dots_eaten)		; @08DE 3A0E4E  load A with number of pellets eaten

; OTTOPATCH
;PATCH TO ADJUST THE TOTAL DOT NUMBER
;ORG 08E1H
;JP MOREDOTS
;NOP
	jp      j_94a1		; @08E1 C3A194  jump to ms pac man new check for end of level routine
	nop		; @08E4 00  junk
    
	; returns here if the level is complete

j_08e5:
	ld hl,level_state		; @08E5 21044E  load HL with game state
	ld      (hl),#0c		; @08E8 360C  store value of #0C, signals end of level
	ret		; @08EA C9  return

;; pacman original:
; 08de  3a0e4e	ld	a,(#4e0e)	; load A with number of pellets eaten
; 08e1  fef4	cp	f4		; == 244 ?
; 08e3  2006	jr	nz,#08eb	; No, jump ahead
; 08e5  21044e	ld	hl,#4e04	; Yes, then end of level.  Load HL with main subroutine #
; 08e8  360c	ld	(hl),#0c	; store #0C into main sub to signal end of level
; 08ea  c9	ret			; return
;;

	; returns here if level is not complete
	; core game loop

j_08eb:
	call    j_1017		; @08EB CD1710  another core game loop that does many things
	call    j_1017		; @08EE CD1710  another core game loop that does many things
	call    j_13dd		; @08F1 CDDD13  check for release of ghosts from ghost house
	call    j_0c42		; @08F4 CD420C  adjust movement of ghosts if moving out of ghost house
	call    j_0e23		; @08F7 CD230E  change animation of ghosts every 8th frame
	call    j_0e36		; @08FA CD360E  periodically reverse ghost direction based on difficulty (only when energizer not active)
	call    j_0ac3		; @08FD CDC30A  handle ghost flashing and colors when power pills are eaten
	call    j_0bd6		; @0900 CDD60B  color dead ghosts the correct colors
	call    j_0c0d		; @0903 CD0D0C  handle power pill (dot) flashes
	call    j_0e6c		; @0906 CD6C0E  change the background sound based on # of pills eaten
	call	j_0ead		; @0909 CDAD0E  check for fruit to come out.  (new ms. pac sub actually at #86EE.)
	ret		; @090C C9  return ( to #0195 )


; arrive here from #06C1 when player has died

	ld      a,#01		; @090D 3E01  A := #01
	ld      (died_this_level),a		; @090F 32124E  store into player dead flag

;	4e12	1 after dying in a level, reset to 0 if ghosts have left home
;		because of 4d9f

	call    j_2487		; @0912 CD8724  save pellet info to memory
	ld hl,level_state		; @0915 21044E  load HL with main subroutine number
	inc     (hl)		; @0918 34  increase it
	ld      a,(lives_real)		; @0919 3A144E  load A with number of lives left
	and     a		; @091C A7  == #00 ?
	jr      nz,j_093e		; @091D 201F  no, skip ahead

	ld      a,(num_players)		; @091F 3A704E  else game over.  load A with number of players (0=1 player, 1=2 players)
	and     a		; @0922 A7  is this a one player game?
	jr      z,j_093e		; @0923 2819  yes, skip ahead
	ld      a,(#4e42)		; @0925 3A424E  else load A with game state
	and     a		; @0928 A7  is this the demo mode ?
	jr      z,j_093e		; @0929 2813  yes, skip ahead
	ld      a,(player_number)		; @092B 3A094E  else load A with current player number:  0=P1, 1=P2
	add     a,#03		; @092E C603  add #03, result is either #03 or #04
	ld      c,a		; @0930 4F  store into C for call below
	ld      b,#1c		; @0931 061C  load B with #1C for task call below
	call    j_0042		; @0933 CD4200  insert task to draw to screen either "PLAYER ONE" or "PLAYER TWO"
	rst     #28		; @0936 EF  insert task to draw "GAME OVER"
	db	#1C,#05	; @0937 1C05
	rst     #30		; @0939 F7  set timed task to increase the main subroutine number (level_state)
	db	#54,#00,#00	; @093A 540000  task timer=#54, task=0, param=0    
	ret		; @093D C9  return

j_093e:
	inc     (hl)		; @093E 34  increase game state
	ret		; @093F C9  return

; arrive from #06C1

	ld      a,(num_players)		; @0940 3A704E  load A with number of players
	and     a		; @0943 A7  == #00 ?
	jr      z,j_094c		; @0944 2806  yes, skip ahead if 1 player
	ld      a,(#4e42)		; @0946 3A424E  else load A with game state 
	and     a		; @0949 A7  is a game being played ?
	jr      nz,j_0961		; @094A 2015  yes, skip ahead and switch from player 1 to player 2 or vice versa
j_094c:
	ld      a,(lives_real)		; @094C 3A144E  else load A with number of lives left
	and     a		; @094F A7  are there any lives left ?
	jr      nz,j_096c		; @0950 201A  yes, jump ahead

	; change 0950 to 
	; 0950  18 1a		jr	#096C 	; always jump ahead 
	; for never-ending pac goodness


	call    j_2ba1		; @0952 CDA12B  else draw # credits or free play on bottom of screen
	rst     #28		; @0955 EF  insert task #1C , parameter #05 .  Draws text on screen "GAME OVER"
	db	#1C,#05	; @0956 1C05  task data
	rst     #30		; @0958 F7  set timed task to increase main subroutine number (level_state)
	db	#54,#00,#00	; @0959 540000  task timer=#54, task=0, param=0
	ld hl,level_state		; @095C 21044E  Load HL with level state subroutine #
	inc     (hl)		; @095F 34  increment
	ret		; @0960 C9  return

; arrive here from #094a when there 2 players, when a player dies

j_0961:
	call    j_0aa6		; @0961 CDA60A  transposes data from #4e0a through #4e37 into #4e38 through #4e66
	ld      a,(player_number)		; @0964 3A094E  load A with current player number:  0=P1, 1=P2
	xor     #01		; @0967 EE01  flip bit 0
	ld      (player_number),a		; @0969 32094E  store result.  toggles between player 1 and 2

j_096c:
	ld      a,#09		; @096C 3E09  A := #09
	ld      (level_state),a		; @096E 32044E  store into level state subroutine #
	ret		; @0971 C9  return


	; arrive from #06C1 when subroutine# (#4E04)= #08
	; zeros some important variables
	; arrive here after demo mode finishes (ms pac man dies in demo)

	xor     a		; @0972 AF  A := #00
	ld      (game_mode_sub1),a		; @0973 32024E  clear main routine 1, subroutine #
	ld      (level_state),a		; @0976 32044E  clear level state subroutine #
	ld      (num_players),a		; @0979 32704E  clear number of players
	ld      (player_number),a		; @097C 32094E  clear current player number
	ld      (flip_screen),a		; @097F 320350  clear flip screen register
	ld      a,#01		; @0982 3E01  A := #01
	ld      (game_mode),a		; @0984 32004E  set game mode to demo
	ret		; @0987 C9  return (to #057F)


; arrive from #06C1 when (#4E04==#09)  when marquee mode ends or after player has been killed
; or from #06C1 when (#4E04 == #20) when a level has ended and a new one is about to begin


j_0988:
	rst     #28		; @0988 EF  set task #00, parameter = #01. - clears the maze
	db	#00,#01	; @0989 0001
	rst     #28		; @098B EF  set task #01, parameter = #01. - colors the maze
	db	#01,#01	; @098C 0101
	rst     #28		; @098E EF  set task #02, parameter = #00. - draws the maze
	db	#02,#00	; @098F 0200
	rst     #28		; @0991 EF  set task #11, parameter = #00. - clears memories from #4D00 through #4DFF
	db	#11,#00	; @0992 1100
	rst     #28		; @0994 EF  set task #13, parameter = #00. - clears the sprites
	db	#13,#00	; @0995 1300
	rst     #28		; @0997 EF  set task #03, parameter = #00. - draws the pellets
	db	#03,#00	; @0998 0300
	rst     #28		; @099A EF  set task #04, parameter = #00. - resets a bunch of memories
	db	#04,#00	; @099B 0400
	rst     #28		; @099D EF  set task #05, parameter = #00. - resets ghost home counter
	db	#05,#00	; @099E 0500
	rst     #28		; @09A0 EF  set task #10, parameter = #00. - sets up difficulty
	db	#10,#00	; @09A1 1000
	rst     #28		; @09A3 EF  set task #1A, parameter = #00. - draws remaining lives at bottom of screen
	db	#1A,#00	; @09A4 1A00
	rst     #28		; @09A6 EF  set task #1C, parameter = #06. Draws text on screen "READY!" and clears the intermission indicator
	db	#1C,#06	; @09A7 1C06
;	ld      a,(game_mode)		; @09A8 3A004E  load A with game state
	; ;; gap-fill from golden boots $09A9-$09AB
	db	#3A,#00,#4E		; @09A9
	cp      #03		; @09AC FE03  is someone playing ?
	jr      z,j_09b6		; @09AE 2806  Yes, skip ahead

	rst     #28		; @09B0 EF  set task #1C, parameter = #05.  Draws text on screeen "GAME OVER"
	db	#1C,#05	; @09B1 1C05
	rst     #28		; @09B3 EF  set task #1D - write # of credits on screen
	db	#1D,#00	; @09B4 1D00

j_09b6:
	rst     #30		; @09B6 F7  set timed task to increase main subroutine number (level_state)
	db	#54,#00,#00	; @09B7 540000  taks timer = #54, task = 00, parameter = 00    
	ld      a,(game_mode)		; @09BA 3A004E  load A with game sate
	dec     a		; @09BD 3D  is this the demo mode ?
	jr      z,j_09c4		; @09BE 2804  yes, skip next step

	rst     #30		; @09C0 F7  set timed task to clear the "READY!" text from the screen
	db	#54,#06,#00	; @09C1 540600  timer = #54, task = 6, parameter = 00

j_09c4:
	ld      a,(dip_cocktail)		; @09C4 3A724E  load A with cocktail mode (0=no, 1=yes)
	ld      b,a		; @09C7 47  copy to B
	ld      a,(player_number)		; @09C8 3A094E  load A with current player #
	and     b		; @09CB A0  mix together
	ld      (flip_screen),a		; @09CC 320350  flip screens if player 2 in cocktail mode, else screen is set upright
	jp      j_0894		; @09CF C39408  increase main routine # and return from sub

; called after marquee mode is done during demo
; called from #06C1 when (#4E04 == #0B)

j_09d2:
	ld      a,#03		; @09D2 3E03  A := #03
	ld      (level_state),a		; @09D4 32044E  store into main routine #.  signals the maze part of game is on
	ret		; @09D7 C9  return

; called from #06C1 when (#4E04 == #0C)
; arrive here at end of level

	rst     #30		; @09D8 F7  set timed task to increase main subroutine number (level_state)
	db	#54,#00,#00	; @09D9 540000  timer = #54, task = #00, parameter = #00
	ld hl,level_state		; @09DC 21044E  load HL with game subroutine #
	inc	(hl)		; @09DF 34  increase 
	xor	a		; @09E0 AF  A := #00
	ld	(CH2_E_NUM),a		; @09E1 32AC4E  clear sound channel 2
	ld	(CH3_E_NUM),a		; @09E4 32BC4E  clear sound channel 3
	ret		; @09E7 C9  return   

; Called from #06C1 when (#4E04 == #0E)

j_09e8:
	ld      c,#02		; @09E8 0E02  C := #02

j_09ea:
	ld      b,#01		; @09EA 0601  B := #01
	call    j_0042		; @09EC CD4200  set task #01 with parameter #02, or task #01 with parameter #00
	rst     #30		; @09EF F7  set timed task to increase main subroutine number (level_state)
	db	#42,#00,#00	; @09F0 420000  timer = #42, task = #00, parameter = #00
	ld      hl,#0000		; @09F3 210000  clear HL
	call    j_267e		; @09F6 CD7E26  clears all ghosts from screen
	ld hl,level_state		; @09F9 21044E  load HL with game subroutine #
	inc     (hl)		; @09FC 34  increase
	ret		; @09FD C9  return

; the following calls are made at end of level to flash the screen

j_09fe:
	ld      c,#00		; @09FE 0E00  set code to flash screen
	jr      j_09ea		; @0A00 18E8  flash screen

	jr      j_09e8		; @0A02 18E4  flash screen

	jr      j_09fe		; @0A04 18F8  flash screen

	jr      j_09e8		; @0A06 18E0  flash screen

	jr      j_09fe		; @0A08 18F4  flash screen

	jr      j_09e8		; @0A0A 18DC  flash screen

	jr      j_09fe		; @0A0C 18F0  flash screen

; arrive here at end of level after screen has flashed several times
; called from #06C1 when (#4E04 == #14)

	rst     #28		; @0A0E EF  insert task #00, parameter #01 - clears the maze
	db	#00,#01	; @0A0F 0001
	rst     #28		; @0A11 EF  insert task #06, parameter #00 - clears the color RAM
	db	#06,#00	; @0A12 0600
	rst     #28		; @0A14 EF  insert task #11, parameter #00 - clears memories from #4D00 through #4DFF
	db	#11,#00	; @0A15 1100
	rst     #28		; @0A17 EF  insert task #13, parameter #00 - clears the sprites
	db	#13,#00	; @0A18 1300
	rst     #28		; @0A1A EF  insert task #04, parameter #01 - resets a bunch of memories
	db	#04,#01	; @0A1B 0401
	rst     #28		; @0A1D EF  insert task #05, parameter #01 - resets ghost home counter
	db	#05,#01	; @0A1E 0501
	rst     #28		; @0A20 EF  insert task #10, parameter #13 - sets up difficulty
	db	#10,#13	; @0A21 1013
	rst     #30		; @0A23 F7  set timed task to increase main subroutine number (level_state)
	db	#43,#00,#00	; @0A24 430000  task timer = #43, task #00, parameter #00
	ld hl,level_state		; @0A27 21044E  load HL with main subroutine number
	inc     (hl)		; @0A2A 34  increase subroutine number
	ret		; @0A2B C9  return

; arrive here at end of level
; called from #06C1 when (#4E04 == #16)
; clear sounds and run intermissions when needed

	xor  a		; @0A2C AF  A := #00
	ld   (CH2_E_NUM),a		; @0A2D 32AC4E  clear sound channel #2
	ld   (CH3_E_NUM),a		; @0A30 32BC4E  clear sound channel #3
	jr   j_0a3b		; @0A33 1806  skip next 2 steps

; junk from pac-man

	ld	(CH1_W_NUM),a		; @0A35 32CC4E
	ld	(CH2_W_NUM),a		; @0A38 32DC4E

j_0a3b:
	ld      a,(level_number)		; @0A3B 3A134E  load A with current board level
	cp      #14		; @0A3E FE14  > #14 ?
	jr      c,j_0a44		; @0A40 3802  no, skip next step
	ld      a,#14		; @0A42 3E14  else load A with #14
j_0a44:
	rst     #20		; @0A44 E7  jump based on A

	; jump table to control when cutscenes occur

	db	#6F,#0A	; @0A45 6F0A  #0A6F ; increment level state and stop sound
	db	#08,#21	; @0A47 0821  #2108 ; cut scene 1
	db	#6F,#0A	; @0A49 6F0A  #0A6F ; increment level state and stop sound
	db	#6F,#0A	; @0A4B 6F0A  #0A6F ; increment level state and stop sound
	db	#9E,#21	; @0A4D 9E21  #219E ; cut scene 2
	db	#6F,#0A	; @0A4F 6F0A  #0A6F ; increment level state and stop sound
	db	#6F,#0A	; @0A51 6F0A  #0A6F ; increment level state and stop sound
	db	#6F,#0A	; @0A53 6F0A  #0A6F ; increment level state and stop sound
	db	#97,#22	; @0A55 9722  #2297 ; cut scene 3
	db	#6F,#0A	; @0A57 6F0A  #0A6F ; increment level state and stop sound
	db	#6F,#0A	; @0A59 6F0A  #0A6F ; increment level state and stop sound
	db	#6F,#0A	; @0A5B 6F0A  #0A6F ; increment level state and stop sound
	db	#97,#22	; @0A5D 9722  #2297 ; cut scene 3
	db	#6F,#0A	; @0A5F 6F0A  #0A6F ; increment level state and stop sound
	db	#6F,#0A	; @0A61 6F0A  #0A6F ; increment level state and stop sound
	db	#6F,#0A	; @0A63 6F0A  #0A6F ; increment level state and stop sound
	db	#97,#22	; @0A65 9722  #2297 ; cut scene 3
	db	#6F,#0A	; @0A67 6F0A  #0A6F ; increment level state and stop sound
	db	#6F,#0A	; @0A69 6F0A  #0A6F ; increment level state and stop sound
	db	#6F,#0A	; @0A6B 6F0A  #0A6F ; increment level state and stop sound
	db	#6F,#0A	; @0A6D 6F0A  #0A6F ; increment level state and stop sound

	; increment level state and stop sound

	ld hl,level_state		; @0A6F 21044E  load HL with level state subroutine #
	inc     (hl)		; @0A72 34
	inc     (hl)		; @0A73 34  increase twice
	xor     a		; @0A74 AF  A := #00
	ld      (CH1_W_NUM),a		; @0A75 32CC4E  clear sound
	ld      (CH2_W_NUM),a		; @0A78 32DC4E  clear sound
	ret		; @0A7B C9  return

	;; we're about to start the next board, (it's about to be drawn)
	; called from #06C1 when (#4E04 == #18)

	xor     a		; @0A7C AF  A := #00
	ld      (CH1_W_NUM),a		; @0A7D 32CC4E  clear sound
	ld      (CH2_W_NUM),a		; @0A80 32DC4E  clear sound
	ld      b,#07		; @0A83 0607  B := #07
	ld hl,fruit1_released		; @0A85 210C4E  load HL with start address to clear
	rst     #8		; @0A88 CF  clear #4e0c through #4e0c+7.  these flags are reset at beginning of each level
	call    j_24c9		; @0A89 CDC924  set addresses #4E16 through #4E39 with FF and #14 (pill map???)
	ld hl,level_state		; @0A8C 21044E  load HL with subroutine #
	inc     (hl)		; @0A8F 34  increase


	; level 255 pac fix ; BUGFIX01 (1 of 2)
	; 0a90  c3800f	jp	#0f88      
	; 0a93  00	nop
	;


	; level 141 mspac fix ; BUGFIX02 (1 of 2)
	; 0a90  c3960f	jp	#0f96
	; 0a93  00	nop
 	;


	ld hl,level_number		; @0A90 21134E  load HL with current board level
	inc     (hl)		; @0A93 34  increment board level
	ld      hl,(difficulty_ptr_lo)		; @0A94 2A0A4E  load HL with pointer to current difficulty settings (#0068 for easy, #007D for hard)
	ld      a,(hl)		; @0A97 7E  load A with the result
	cp      #14		; @0A98 FE14  == #14 (is this already the highest difficulty?)
	ret     z		; @0A9A C8  yes, return

	inc     hl		; @0A9B 23  else increase difficulty
	ld      (difficulty_ptr_lo),hl		; @0A9C 220A4E  store result
	ret		; @0A9F C9  return

; called from #06C1 when (#4E04 == #20)

	jp      j_0988		; @0AA0 C38809

; ; called from #06C1 when (#4E04 == #22)

	jp      j_09d2		; @0AA3 C3D209

; called from #0961
; transposes data from #4e0a through #4e37 into #4e38 through #4e66
; used to copy data in and out for 2 player games

j_0aa6:
	ld      b,#2e		; @0AA6 062E  For B = 1 to #2E
	ld ix,difficulty_ptr_lo		; @0AA8 DD210A4E  load IX with group 1 start address
	ld iy,level_data_copy		; @0AAC FD21384E  load IY with group 2 start address

j_0ab0:
	ld      d,(ix+#00)		; @0AB0 DD5600  load D with data from group 1
	ld      e,(iy+#00)		; @0AB3 FD5E00  load E with data from group 2
	ld      (iy+#00),d		; @0AB6 FD7200  store D into group 2
	ld      (ix+#00),e		; @0AB9 DD7300  store E into group 1
	inc     ix		; @0ABC DD23  next address
	inc     iy		; @0ABE FD23  next address
	djnz    j_0ab0		; @0AC0 10EE  next B
	ret		; @0AC2 C9  return

; called from #08FD

j_0ac3:
	ld      a,(ghosts_killed_pending)		; @0AC3 3AA44D  load A with # of ghost killed but no collision for yet [0..4]
	and     a		; @0AC6 A7  is there a collision ?
	ret     nz		; @0AC7 C0  yes, return

; this subroutine never gets called when the green-eyed ghost bug occurs

	ld ix,spr_unk_4c00		; @0AC8 DD21004C  else load IX with start of sprites address
	ld iy,frightened_flash_counter		; @0ACC FD21C84D  load IY with (counter used to change ghost colors under big pill effects?)
	ld      de,#0100		; @0AD0 110001  load DE with offset value of #0100.  [used at #0AE7]
	cp      (iy+#00)		; @0AD3 FDBE00  compare.  is it time to flash?
	jp      nz,j_0bd2		; @0AD6 C2D20B  no, decrement (IY) and return

	ld      (iy+#00),#0e		; @0AD9 FD36000E  else reset counter to #0E
	ld      a,(power_pill_active)		; @0ADD 3AA64D  load A with power pill effect (1=active, 0=no effect)
	and     a		; @0AE0 A7  is a power pill still active ?
	jr      z,j_0afe		; @0AE1 281B  no, skip ahead

	ld      hl,(frightened_timer_lo)		; @0AE3 2ACB4D  yes, load HL with counter while ghosts are blue
	and     a		; @0AE6 A7  clear carry flag
	sbc     hl,de		; @0AE7 ED52  subtract offset of #0100.  has this counter gone under?
	jr      nc,j_0afe		; @0AE9 3013  no, skip ahead

; arrive here when ghosts start flashing after being blue
; this sub controls the flashing and the return

	ld hl,CH2_E_NUM		; @0AEB 21AC4E  yes, load HL with sound 2 channel
	set	7,(hl)		; @0AEE CBFE  play sound = high frequency
	ld	a,#09		; @0AF0 3E09  A := #09
	cp	(ix+#0b)		; @0AF2 DDBE0B  compare with #4C0b = pacman color entry.  is a ghost being eaten?
	jr	nz,j_0afb		; @0AF5 2004  no, skip ahead

	res	7,(hl)		; @0AF7 CBBE  clear sound
	ld	a,#09		; @0AF9 3E09  A := #09

j_0afb:
	ld      (spr_pac_color),a		; @0AFB 320B4C  set pacman color to yellow




j_0afe:
	ld      a,(red_frightened)		; @0AFE 3AA74D  load A with red ghost blue flag (0=not blue)
	and     a		; @0B01 A7  is red ghost blue (edible) ?
	jr      z,j_0b21		; @0B02 281D  no, skip ahead and set red ghost to red

	ld      hl,(frightened_timer_lo)		; @0B04 2ACB4D  else load HL with counter while ghosts are blue
	and     a		; @0B07 A7  clear carry flag
	sbc     hl,de		; @0B08 ED52  subtract offset (#0100).  has this counter gone under?
	jr      nc,j_0b33		; @0B0A 3027  no, jump ahead and check next ghost

	ld      a,#11		; @0B0C 3E11  yes, A := #11
	cp      (ix+#03)		; @0B0E DDBE03  compare with red ghost color. is red ghost blue ?
	jr      z,j_0b1a		; @0B11 2807  yes, skip ahead and change his color to white

	ld      (ix+#03),#11		; @0B13 DD360311  no, set red ghost to blue color
	jp      j_0b33		; @0B17 C3330B  skip ahead and check next ghost

j_0b1a:
	ld      (ix+#03),#12		; @0B1A DD360312  set red ghost color to white
	jp      j_0b33		; @0B1E C3330B  skip ahead and check next ghost

j_0b21:
	ld      a,#01		; @0B21 3E01  A := #01
	cp      (ix+#03)		; @0B23 DDBE03  compare with red ghost color.  is the red ghost red?
	jr      z,j_0b2f		; @0B26 2807  yes, then jump ahead

	ld      (ix+#03),#01		; @0B28 DD360301  set red ghost back to red
	jp      j_0b33		; @0B2C C3330B  skip ahead

j_0b2f:
	ld      (ix+#03),#01		; @0B2F DD360301  set red ghost back to red

j_0b33:
	ld      a,(pink_frightened)		; @0B33 3AA84D  load A with pink ghost blue flag
	and     a		; @0B36 A7  is pink ghost blue (edible) ?
	jr      z,j_0b56		; @0B37 281D  no, skip ahead and set pink ghost to pink

	ld      hl,(frightened_timer_lo)		; @0B39 2ACB4D  else load HL with counter while ghosts are blue 
	and     a		; @0B3C A7  clear carry flag
	sbc     hl,de		; @0B3D ED52  subtract offset (#0100).  has this counter gone under?
	jr      nc,j_0b68		; @0B3F 3027  no, jump ahead and check next ghost

	ld      a,#11		; @0B41 3E11  A := #11
	cp      (ix+#05)		; @0B43 DDBE05  compare with pink ghost color.  is the pink ghost blue?
	jr      z,j_0b4f		; @0B46 2807  yes, jump ahead and change his color to white

	ld      (ix+#05),#11		; @0B48 DD360511  no, set pink ghost back to blue
	jp      j_0b68		; @0B4C C3680B  skip ahead

j_0b4f:
	ld      (ix+#05),#12		; @0B4F DD360512  set pink ghost color to white
	jp      j_0b68		; @0B53 C3680B  skip ahead

j_0b56:
	ld      a,#03		; @0B56 3E03  A := #03
	cp      (ix+#05)		; @0B58 DDBE05  is the pink ghost pink ?
	jr      z,j_0b64		; @0B5B 2807  yes, skip ahead

	ld      (ix+#05),#03		; @0B5D DD360503  set pink ghost to pink
	jp      j_0b68		; @0B61 C3680B  jump ahead

j_0b64:
	ld      (ix+#05),#03		; @0B64 DD360503  set pink ghost to pink

j_0b68:
	ld      a,(blue_frightened)		; @0B68 3AA94D  load A with blue ghost (inky) blue flag
	and     a		; @0B6B A7  is inky blue (edible) ?
	jr      z,j_0b8b		; @0B6C 281D  no, skip ahead

	ld      hl,(frightened_timer_lo)		; @0B6E 2ACB4D  else load HL with counter while ghosts are blue
	and     a		; @0B71 A7  clear carry flag
	sbc     hl,de		; @0B72 ED52  subtract offset (#0100).  has this counter gone under?
	jr      nc,j_0b9d		; @0B74 3027  no, jump ahead and check next ghost

	ld      a,#11		; @0B76 3E11  A := #11
	cp      (ix+#07)		; @0B78 DDBE07  is inky blue (edible) ?
	jr      z,j_0b84		; @0B7B 2807  yes, jump ahead and change his color to white

	ld      (ix+#07),#11		; @0B7D DD360711  no, set inky to blue color
	jp      j_0b9d		; @0B81 C39D0B  skip ahead

j_0b84:
	ld      (ix+#07),#12		; @0B84 DD360712  set inky to white color
	jp      j_0b9d		; @0B88 C39D0B  skip ahead

j_0b8b:
	ld      a,#05		; @0B8B 3E05  A := #05
	cp      (ix+#07)		; @0B8D DDBE07  is inky his regular color ?
	jr      z,j_0b99		; @0B90 2807  yes, skip ahead

	ld      (ix+#07),#05		; @0B92 DD360705  set inky to his regular color
	jp      j_0b9d		; @0B96 C39D0B  skip ahead

j_0b99:
	ld      (ix+#07),#05		; @0B99 DD360705  set inky to his regular color

j_0b9d:
	ld      a,(orange_frightened)		; @0B9D 3AAA4D  load A with orange ghost blue flag
	and     a		; @0BA0 A7  is orange ghost blue (edible) ?
	jr      z,j_0bc0		; @0BA1 281D  no, skip ahead

	ld      hl,(frightened_timer_lo)		; @0BA3 2ACB4D  else load HL with counter while ghosts are blue 
	and     a		; @0BA6 A7  clear carry flag
	sbc     hl,de		; @0BA7 ED52  subtract offset (#0100).  has this counter gone under?
	jr      nc,j_0bd2		; @0BA9 3027  no, jump ahead

	ld      a,#11		; @0BAB 3E11  A := #11
	cp      (ix+#09)		; @0BAD DDBE09  is orange ghost blue (edible) ?
	jr      z,j_0bb9		; @0BB0 2807  yes, skip ahead and change to white

	ld      (ix+#09),#11		; @0BB2 DD360911  no, set orange ghost color to blue
	jp      j_0bd2		; @0BB6 C3D20B  skip ahead

j_0bb9:
	ld      (ix+#09),#12		; @0BB9 DD360912  set orange ghost color to white
	jp      j_0bd2		; @0BBD C3D20B  skip ahead

j_0bc0:
	ld      a,#07		; @0BC0 3E07  A := #07
	cp      (ix+#09)		; @0BC2 DDBE09  is orange ghost orange ?
	jr      z,j_0bce		; @0BC5 2807  yes, skip ahead

	ld      (ix+#09),#07		; @0BC7 DD360907  set orange ghost to orange
	jp      j_0bd2		; @0BCB C3D20B  skip ahead

j_0bce:
	ld      (ix+#09),#07		; @0BCE DD360907  set orange ghost to orange

j_0bd2:
	dec     (iy+#00)		; @0BD2 FD3500  decrease the flash counter
	ret		; @0BD5 C9  return

; called from #0900

    ; set the color for a dead ghost
j_0bd6:
	ld      b,#19		; @0BD6 0619  B := #19 - floating death eyes (good band name!)
	ld      a,(game_mode_sub1)		; @0BD8 3A024E  load A with main routine 1, subroutine #
	cp      #22		; @0BDB FE22  == #22 ? is code is used in pac-man only, not ms. pac.  its checking for the routine where pacman heads towards the energizer followed by 4 ghosts
	jp      nz,j_0be2		; @0BDD C2E20B  no, skip next step

	ld      b,#00		; @0BE0 0600  B := #00.  code used to clear ghosts after they get eaten in the pac-man attract

j_0be2:
	ld ix,spr_unk_4c00		; @0BE2 DD21004C  load IX with start of offset for ghost sprites and colors
	ld      a,(red_state)		; @0BE6 3AAC4D  load A with red ghost state

	and     a		; @0BE9 A7  is red ghost alive ?
	jp      z,j_0bf0		; @0BEA CAF00B  yes, skip next step. only set color if not alive

	ld      (ix+#03),b		; @0BED DD7003  store B into red ghost color entry

j_0bf0:
	ld      a,(pink_state)		; @0BF0 3AAD4D  load A wtih pink ghost state
	and     a		; @0BF3 A7  is pink ghost alive ?
	jp      z,j_0bfa		; @0BF4 CAFA0B  yes, skip next step

	ld      (ix+#05),b		; @0BF7 DD7005  store B into pink ghost color entry

j_0bfa:
	ld      a,(blue_state)		; @0BFA 3AAE4D  load A with blue ghost (inky) state
	and     a		; @0BFD A7  is inky alive ?
	jp      z,j_0c04		; @0BFE CA040C  yes, skip next step

	ld      (ix+#07),b		; @0C01 DD7007  store B into blue ghost (inky) color entry

j_0c04:
	ld      a,(orange_state)		; @0C04 3AAF4D  load A with orange ghost state
	and     a		; @0C07 A7  is orange ghost alive ? 
	ret     z		; @0C08 C8  yes, return

	ld      (ix+#09),b		; @0C09 DD7009  store B into orange ghost color entry
	ret		; @0C0C C9  return  

; called from #0903
; routine to handle power pill flashes

j_0c0d:
	ld hl,power_pill_flash_counter		; @0C0D 21CF4D  load HL with power pill counter
	inc     (hl)		; @0C10 34  increment
	ld      a,#0a		; @0C11 3E0A  A := #0A
	cp      (hl)		; @0C13 BE  is it time to flash the power pellets ?
	ret     nz		; @0C14 C0  no, return

	ld      (hl),#00		; @0C15 3600  else we will flash the pellets.  reset counter to #00
	ld      a,(level_state)		; @0C17 3A044E  load A with game state indicator.  this is #03 when game or demo is in play
	cp      #03		; @0C1A FE03  == #03 ?  Is a game being played ?
	jr      nz,j_0c33		; @0C1C 2015  no, skip ahead and flash the pellets in the demo screen where pac is chased by 4 ghosts and then eats a power pill and eats them all

; BUGFIX05 - Map discoloration fix - Don Hodges
;	jr 	nz,j_0c1e		; @0C1C 2000  no, do nothing

j_0c1e:
	ld      hl,#4464		; @0C1E 216444  else load HL with first power pellet address (legacy from pac-man.  new routine loads new value)

; OTTOPATCH
;PATCH TO MAKE THE ENERGIZERS FLASH IN NEW AND EXCITING COLORS
;ORG 0C21H
;JP FLASHEN
	jp      j_9524		; @0C21 C32495  jump to new ms pac routine to flash power pellets

;; Pac-man code:
; 0c21  3e10      ld      a,#10		; load A with code for power pellet
; 0c23  be        cp      (hl)		; is there already a power pellet there?
;; end pac-man code

; junk from pac-man, flashes power pellets for non-changing maze

	jr      nz,j_0c28		; @0C24 2002  no, skip ahead
	ld      a,#00		; @0C26 3E00  yes, change code to empty graphic
j_0c28:
	ld      (hl),a		; @0C28 77  flash power pellet
	ld      (#4478),a		; @0C29 327844  flash power pellet
	ld      (#4784),a		; @0C2C 328447  flash power pellet
	ld      (#4798),a		; @0C2F 329847  flash power pellet
	ret		; @0C32 C9  return

; arrive from #0C1C
; flash the pellets in the demo screen where pac is chased by 4 ghosts and then eats a power pill and eats them all
; this causes a very minor bug in pac-man and ms. pac man.  
; potentially 2 screen elements can sometimes get colored wrong when player dies.
; in pac-man, a dot may disappear at #4678

j_0c33:
	ld      hl,#4732		; @0C33 213247  load HL with screen color address (?)
	ld      a,#10		; @0C36 3E10  A := #10
	cp      (hl)		; @0C38 BE  is the screen color in this address == #10 ?
	jr      nz,j_0c3d		; @0C39 2002  no, skip next step

	ld      a,#00		; @0C3B 3E00  A := #00

j_0c3d:
	ld      (hl),a		; @0C3D 77  store #10 or #00 into this color location to flash the power pill in the demo
	ld      (#4678),a		; @0C3E 327846  store into #4678 to flash the other power pill
	ret		; @0C41 C9  return (to #0906)

; called from #08f4
; handles ghost movements when they are moving around in or coming out of the ghost home

; red ghost

j_0c42:
	ld      a,(ghosts_killed_pending)		; @0C42 3AA44D  load A with # of ghost killed but no collision for yet [0..4]
	and     a		; @0C45 A7  == #00 ?
	ret     nz		; @0C46 C0  return if no collision

	ld      a,(ghost_home_move_counter)		; @0C47 3A944D  else load A with counter related to ghost movement inside home
	rlca		; @0C4A 07  rotate left
	ld      (ghost_home_move_counter),a		; @0C4B 32944D  store result
	ret     nc		; @0C4E D0  return if no carry

	ld      a,(red_substate)		; @0C4F 3AA04D  else load A with red ghost substate
	and     a		; @0C52 A7  is red ghost out of the ghost house ?
	jp      nz,j_0c90		; @0C53 C2900C  yes, skip ahead and check next ghost

	ld      ix,#3305		; @0C56 DD210533  no, load IX with address for offsets to move up
	ld iy,red_y		; @0C5A FD21004D  load IY with red ghost position
	call    j_2000		; @0C5E CD0020  load HL with IY + IX = new position by moving up
	ld      (red_y),hl		; @0C61 22004D  store into red ghost position
	ld      a,#03		; @0C64 3E03  A := #03
	ld      (red_prev_dir),a		; @0C66 32284D  set previous red ghost orientation as moving up
	ld      (red_dir),a		; @0C69 322C4D  set red ghost orientation as moving up
	ld      a,(red_y)		; @0C6C 3A004D  load A with red ghost Y position
	cp      #64		; @0C6F FE64  is the red ghost out of the ghost house ?
	jp      nz,j_0c90		; @0C71 C2900C  no, skip ahead and check next ghost

	ld      hl,#2e2c		; @0C74 212C2E  yes, HL := #2E, 2C
	ld      (red_tile_y),hl		; @0C77 220A4D  store into red ghost position
	ld      hl,#0100		; @0C7A 210001  HL := #01 00 (code for moving to left)
	ld      (red_tile_dy),hl		; @0C7D 22144D  store into red ghost tile changes
	ld      (red_tile_dy2),hl		; @0C80 221E4D  store into red ghost tile changes
	ld      a,#02		; @0C83 3E02  A := #02
	ld      (red_prev_dir),a		; @0C85 32284D  set previous red ghost orientation as moving left
	ld      (red_dir),a		; @0C88 322C4D  set red ghost orientation as moving left
	ld      a,#01		; @0C8B 3E01  A := #01
	ld      (red_substate),a		; @0C8D 32A04D  set red ghost indicator to outside the ghost house

; pink ghost

j_0c90:
	ld      a,(pink_substate)		; @0C90 3AA14D  load A with pink ghost substate
	cp      #01		; @0C93 FE01  is pink ghost out of the ghost house ?
	jp      z,j_0cfb		; @0C95 CAFB0C  yes, skip ahead and check next ghost

	cp      #00		; @0C98 FE00  is pink ghost waiting to leave the ghost house?
	jp      nz,j_0cc1		; @0C9A C2C10C  no, skip ahead

; pink ghost is moving up and down in the ghost house

	ld      a,(pink_y)		; @0C9D 3A024D  yes, load A with pink ghost Y position
	cp      #78		; @0CA0 FE78  is pink ghost at the upper limit of the ghost house?
	call    z,j_1f2e		; @0CA2 CC2E1F  yes, reverse direction of pink ghost

	cp      #80		; @0CA5 FE80  is pink ghost at bottom of the ghost house?
	call    z,j_1f2e		; @0CA7 CC2E1F  yes, reverse direction of pink ghost

	ld      a,(pink_dir)		; @0CAA 3A2D4D  load A with pink ghost orientation
	ld      (pink_prev_dir),a		; @0CAD 32294D  store into previous pink ghost orienation
	ld ix,pink_tile_dy2		; @0CB0 DD21204D  load IX with pink ghost tile changes
	ld iy,pink_y		; @0CB4 FD21024D  load IY with pink ghost position
	call    j_2000		; @0CB8 CD0020  load HL with IX + IY = new pink ghost position
	ld      (pink_y),hl		; @0CBB 22024D  store into pink ghost position
	jp      j_0cfb		; @0CBE C3FB0C  skip ahead and check next ghost

; pink ghost is moving up out of the ghost house

j_0cc1:
	ld      ix,#3305		; @0CC1 DD210533  load IX with address for offsets to move up
	ld iy,pink_y		; @0CC5 FD21024D  load IY with pink ghost position
	call    j_2000		; @0CC9 CD0020  load HL with IY + IX = new pink ghost position
	ld      (pink_y),hl		; @0CCC 22024D  store result into pink ghost position
	ld      a,#03		; @0CCF 3E03  A := #03
	ld      (pink_dir),a		; @0CD1 322D4D  set previous pink ghost orientation as moving up
	ld      (pink_prev_dir),a		; @0CD4 32294D  set pink ghost orientation as moving up
	ld      a,(pink_y)		; @0CD7 3A024D  load A with pink ghost Y position
	cp      #64		; @0CDA FE64  is pink ghost out of the ghost house ?
	jp      nz,j_0cfb		; @0CDC C2FB0C  no, skip ahead and check next ghost

; pink ghost has made it out of the ghost house

	ld      hl,#2e2c		; @0CDF 212C2E  HL := 2E, 2C
	ld      (pink_tile_y),hl		; @0CE2 220C4D  store into pink ghost position
	ld      hl,#0100		; @0CE5 210001  HL := #01 00 (code for moving left)
	ld      (pink_tile_dy),hl		; @0CE8 22164D  store into pink ghost tile changes
	ld      (pink_tile_dy2),hl		; @0CEB 22204D  store into pink ghost tile changes
	ld      a,#02		; @0CEE 3E02  A := #02
	ld      (pink_prev_dir),a		; @0CF0 32294D  set previous pink ghost orientation as moving left
	ld      (pink_dir),a		; @0CF3 322D4D  set pink ghost orientation as moving left
	ld      a,#01		; @0CF6 3E01  A := #01
	ld      (pink_substate),a		; @0CF8 32A14D  set pink ghost indicator to outside the ghost house

; blue ghost (inky)

j_0cfb:
	ld      a,(blue_substate)		; @0CFB 3AA24D  load A with blue ghost (inky) substate
	cp      #01		; @0CFE FE01  is inky out of the ghost house ?
	jp      z,j_0d93		; @0D00 CA930D  yes, skip ahead and check next ghost

	cp      #00		; @0D03 FE00  is inky waiting to leave the ghost house ?
	jp      nz,j_0d2c		; @0D05 C22C0D  no, skip ahead

; inky is moving up and down in the ghost house

	ld      a,(blue_y)		; @0D08 3A044D  load A with inky Y position
	cp      #78		; @0D0B FE78  is inky at the upper limit of ghost house ?
	call    z,j_1f55		; @0D0D CC551F  yes, reverse direction of inky
	cp      #80		; @0D10 FE80  is inky at the bottom of the ghost house ?
	call    z,j_1f55		; @0D12 CC551F  yes, reverse direction of inky

	ld      a,(blue_dir)		; @0D15 3A2E4D  load A with inky orientation
	ld      (blue_prev_dir),a		; @0D18 322A4D  store into previous inky orientation
	ld ix,blue_tile_dy2		; @0D1B DD21224D  load IX with inky tile changes
	ld iy,blue_y		; @0D1F FD21044D  load IY with inky position
	call    j_2000		; @0D23 CD0020  load HL with IX + IY = new inky position
	ld      (blue_y),hl		; @0D26 22044D  store into inky position
	jp      j_0d93		; @0D29 C3930D  skip ahead and check next ghost

j_0d2c:
	ld      a,(blue_substate)		; @0D2C 3AA24D  load A with inky substate
	cp      #03		; @0D2F FE03  is inky moving to his right, on his way out of the ghost house?
	jp      nz,j_0d59		; @0D31 C2590D  no, skip ahead

; inky is on his way out of ghost house to right

	ld      ix,#32ff		; @0D34 DD21FF32  yes, load IX with tile movement for moving right
	ld iy,blue_y		; @0D38 FD21044D  load IY with inky position
	call    j_2000		; @0D3C CD0020  load HL with IX + IY = new inky position
	ld      (blue_y),hl		; @0D3F 22044D  store new position for inky
	xor     a		; @0D42 AF  A := #00
	ld      (blue_prev_dir),a		; @0D43 322A4D  set previous inky orientation as moving right
	ld      (blue_dir),a		; @0D46 322E4D  set inky orientation as moving right
	ld      a,(blue_x)		; @0D49 3A054D  load A with inky X position
	cp      #80		; @0D4C FE80  is inky exactly under the ghost house door ?
	jp      nz,j_0d93		; @0D4E C2930D  no, skip ahead and check next ghost

	ld      a,#02		; @0D51 3E02  yes, A := #02
	ld      (blue_substate),a		; @0D53 32A24D  store into inky substate to indicate moving up and out of ghost house
	jp      j_0d93		; @0D56 C3930D  skip ahead and check next ghost

; inky is moving up out of the ghost house

j_0d59:
	ld      ix,#3305		; @0D59 DD210533  load IX with address for offsets to move up
	ld iy,blue_y		; @0D5D FD21044D  load IY with inky position
	call    j_2000		; @0D61 CD0020  load HL with IX + IY = new inky position
	ld      (blue_y),hl		; @0D64 22044D  store into inky position
	ld      a,#03		; @0D67 3E03  A := #03
	ld      (blue_prev_dir),a		; @0D69 322A4D  set previous inky orientation as moving up
	ld      (blue_dir),a		; @0D6C 322E4D  set inky orientation as moving up
	ld      a,(blue_y)		; @0D6F 3A044D  load A with inky's Y position
	cp      #64		; @0D72 FE64  is inky out of the ghost house ?
	jp      nz,j_0d93		; @0D74 C2930D  no, skip ahead and check next ghost

; inky has made it out of the ghost house

	ld      hl,#2e2c		; @0D77 212C2E  load HL with 2E, 2C
	ld      (blue_tile_y),hl		; @0D7A 220E4D  store into inky tile position
	ld      hl,#0100		; @0D7D 210001  load HL with code for moving left
	ld      (blue_tile_dy),hl		; @0D80 22184D  store into inky tile changes
	ld      (blue_tile_dy2),hl		; @0D83 22224D  store into inky tile changes
	ld      a,#02		; @0D86 3E02  A := #02
	ld      (blue_prev_dir),a		; @0D88 322A4D  set previous inky orientation as moving left
	ld      (blue_dir),a		; @0D8B 322E4D  set inky orientation as moving left
	ld      a,#01		; @0D8E 3E01  A := #01	
	ld      (blue_substate),a		; @0D90 32A24D  set inky ghost indicator to outside the ghost house

; orange ghost

j_0d93:
	ld      a,(orange_substate)		; @0D93 3AA34D  load A with orange ghost substate
	cp      #01		; @0D96 FE01  is orange ghost out of the ghost house ?
	ret     z		; @0D98 C8  yes, return

	cp      #00		; @0D99 FE00  is orange ghost waiting to leave the ghost house ?
	jp      nz,j_0dc0		; @0D9B C2C00D  no, skip ahead

; orange ghost is moving up and down in the ghost house

	ld      a,(orange_y)		; @0D9E 3A064D  yes, load A with orange ghost Y position
	cp      #78		; @0DA1 FE78  is orange ghost at upper limit of ghost house ?
	call    z,j_1f7c		; @0DA3 CC7C1F  yes, reverse orange ghost direction

	cp      #80		; @0DA6 FE80  is orange ghost at bottom of ghost house ?
	call    z,j_1f7c		; @0DA8 CC7C1F  yes, reverse orange ghost direction

	ld      a,(orange_dir)		; @0DAB 3A2F4D  load A with orange ghost orientation
	ld      (orange_prev_dir),a		; @0DAE 322B4D  store into previous orange ghost orientation
	ld ix,orange_tile_dy2		; @0DB1 DD21244D  load IX with orange ghost tile changes
	ld iy,orange_y		; @0DB5 FD21064D  load IY with orange ghost position
	call    j_2000		; @0DB9 CD0020  load HL with IX + IY = new orange ghost position
	ld      (orange_y),hl		; @0DBC 22064D  store into orange ghost position
	ret		; @0DBF C9  return

j_0dc0:
	ld      a,(orange_substate)		; @0DC0 3AA34D  load A with orange ghost substate
	cp      #03		; @0DC3 FE03  is orange ghost moving to his left, on his way out of the ghost house ?
	jp      nz,j_0dea		; @0DC5 C2EA0D  no, skip ahead

; orange ghost is moving left, on his way out of ghost house

	ld      ix,#3303		; @0DC8 DD210333  load IX with address for offsets to move left
	ld iy,orange_y		; @0DCC FD21064D  load IY with orange ghost position 
	call    j_2000		; @0DD0 CD0020  load HL with IX + IY = new orange ghost position
	ld      (orange_y),hl		; @0DD3 22064D  store new orange ghost position
	ld      a,#02		; @0DD6 3E02  A := #02
	ld      (orange_prev_dir),a		; @0DD8 322B4D  set previous orange ghost orientation as moving left
	ld      (orange_dir),a		; @0DDB 322F4D  set orange ghost orientation as moving left
	ld      a,(orange_x)		; @0DDE 3A074D  load A with orange ghost X position
	cp      #80		; @0DE1 FE80  is orange ghost exactly under the ghost house door ?
	ret     nz		; @0DE3 C0  no, return

	ld      a,#02		; @0DE4 3E02  yes, A := #02
	ld      (orange_substate),a		; @0DE6 32A34D  store into orange ghost substate to indicate moving up and out of ghost house
	ret		; @0DE9 C9  return

; orange ghost is moving up and out of ghost house

j_0dea:
	ld      ix,#3305		; @0DEA DD210533  load IX with address for offsets to move up
	ld iy,orange_y		; @0DEE FD21064D  load IY with orange ghost position
	call    j_2000		; @0DF2 CD0020  load HL with IX + IY = new orange ghost position
	ld      (orange_y),hl		; @0DF5 22064D  store into orange ghost position
	ld      a,#03		; @0DF8 3E03  A := #03
	ld      (orange_prev_dir),a		; @0DFA 322B4D  set previous orange ghost orientation as moving up
	ld      (orange_dir),a		; @0DFD 322F4D  set orange ghost orientation as moving up
	ld      a,(orange_y)		; @0E00 3A064D  load A with orange ghost Y position
	cp      #64		; @0E03 FE64  is orange ghost out of the ghost house ?
	ret     nz		; @0E05 C0  no, return

; orange ghost has made it out of the ghost house

	ld      hl,#2e2c		; @0E06 212C2E  load HL with 2E, 2C
	ld      (orange_tile_y),hl		; @0E09 22104D  store into orange ghost tile position
	ld      hl,#0100		; @0E0C 210001  load HL with code for moving left
	ld      (orange_tile_dy),hl		; @0E0F 221A4D  store into oragne ghost tile changes
	ld      (orange_tile_dy2),hl		; @0E12 22244D  store into orange ghost tile changes
	ld      a,#02		; @0E15 3E02  A := #02
	ld      (orange_prev_dir),a		; @0E17 322B4D  set previous orange ghost orientation as moving left
	ld      (orange_dir),a		; @0E1A 322F4D  set orange ghost orientation as moving left
	ld      a,#01		; @0E1D 3E01  A := #01
	ld      (orange_substate),a		; @0E1F 32A34D  set orange ghost indicator to outside the ghost house
	ret		; @0E22 C9  return

; called from #08f7

j_0e23:
	ld hl,frame_div8_counter		; @0E23 21C44D  load HL with counter
	inc     (hl)		; @0E26 34  increment
	ld      a,#08		; @0E27 3E08  A := #08
	cp      (hl)		; @0E29 BE  is the counter == #08 ?
	ret     nz		; @0E2A C0  no, return

	ld      (hl),#00		; @0E2B 3600  else clear counter
	ld      a,(ghost_anim_phase)		; @0E2D 3AC04D  load A with address used for ghost animations
	xor     #01		; @0E30 EE01  flip bit 0
	ld      (ghost_anim_phase),a		; @0E32 32C04D  store result
	ret		; @0E35 C9  return

; called from #08fa

j_0e36:
	ld      a,(power_pill_active)		; @0E36 3AA64D  load A with power pill effect (1=active, 0=no effect)
	and     a		; @0E39 A7  is a power pill active ?
	ret     nz		; @0E3A C0  yes, return, we never reverse dir. when power pill is on

	ld      a,(ghost_orient_index)		; @0E3B 3AC14D  no, load A with ghost orientation index
	cp      #07		; @0E3E FE07  == #07 ?
	ret     z		; @0E40 C8  yes, return, we never reverse dir. more than 7 times (pac-man only)

	add     a,a		; @0E41 87  Double the index, this is used below for offset in the table
	ld      hl,(ghost_orient_counter_lo)		; @0E42 2AC24D  load HL with counter for ghost reversals
	inc     hl		; @0E45 23  increment
	ld      (ghost_orient_counter_lo),hl		; @0E46 22C24D  store result
	ld      e,a		; @0E49 5F  E := A
	ld      d,#00		; @0E4A 1600  D := #00
	ld ix,ghost_orient_table		; @0E4C DD21864D  load IX with start of difficulty table
	add     ix,de		; @0E50 DD19  add offset based on which reversal this is
	ld      e,(ix+#00)		; @0E52 DD5E00
	ld      d,(ix+#01)		; @0E55 DD5601  load DE with result from table.  for first reverse this is #01A4
	and     a		; @0E58 A7  clear carry flag
	sbc     hl,de		; @0E59 ED52  subtract.  are they equal ? = time to reverse direction of ghosts
	ret     nz		; @0E5B C0  if not, return

; arrive here when ghosts reverse direction
; this differs from the pac-man code

; OTTOPATCH
;PATCH TO MAKE RED MONSTER GO AFTER OTTO TO AVOID PARKING
	xor     a		; @0E5C AF  else A := #00
	nop		; @0E5D 00


;; Pac-Man code follows
	; 0E5C CB 3F SRL A		; this undoes the double from line #0E41
;; end pac-man code

	inc     a		; @0E5E 3C  increment
	ld      (ghost_orient_index),a		; @0E5F 32C14D  store into orientation index
	ld      hl,#0101		; @0E62 210101
	ld      (red_reverse_flag),hl		; @0E65 22B14D
	ld      (blue_reverse_flag),hl		; @0E68 22B34D  load #01 ghost orientations - reverses ghosts direction
	ret		; @0E6B C9  return

; called from #0906
; changes the background sound based on # of pills eaten

j_0e6c:
	ld      a,(pac_death_anim)		; @0E6C 3AA54D  load A with pacman dead animation state (0 if not dead)
	and     a		; @0E6F A7  is pacman dead ?
	jr      z,j_0e77		; @0E70 2805  no, skip ahead
	xor     a		; @0E72 AF  else A := #00
	ld      (CH2_E_NUM),a		; @0E73 32AC4E  clear sound channel 2
	ret		; @0E76 C9  return

j_0e77:
	ld hl,CH2_E_NUM		; @0E77 21AC4E  else pacman is alive.  load HL with sound 2 channel
	ld	b,#E0		; @0E7A 06E0  B := E0.  this is a binary bitmask of 11100000 applied later
	ld	a,(dots_eaten)		; @0E7C 3A0E4E  load A with number of pills eaten in this level
	cp	#E4		; @0E7F FEE4  > E4 ?
	jr	c,j_0e89		; @0E81 3806  no, skip ahead

	ld	a,b		; @0E83 78  else load A with bitmask
	and	(hl)		; @0E84 A6  apply bitmask to sound 2 channel. this turns off bits 0 through 4
	set	4,a		; @0E85 CBE7  turn on bit 4
	ld	(hl),a		; @0E87 77  play sound
	ret		; @0E88 C9  return

j_0e89:
	cp      #D4		; @0E89 FED4  is the number of pills eaten in this level > D4 ? 
	jr      c,j_0e93		; @0E8B 3806  no, skip ahead

	ld      a,b		; @0E8D 78  else load A with bitmask
	and     (hl)		; @0E8E A6  turn off bits 0 through 4 on sound channel
	set     3,a		; @0E8F CBDF  turn on bit 3
	ld      (hl),a		; @0E91 77  play sound
	ret		; @0E92 C9  return

j_0e93:
	cp      #B4		; @0E93 FEB4  is the number of pills eaten in this level > B4 ?
	jr      c,j_0e9d		; @0E95 3806  no, skip ahead
	ld      a,b		; @0E97 78  else load A with bitmask
	and     (hl)		; @0E98 A6  turn off bits 0 through 4 on sound channel
	set     2,a		; @0E99 CBD7  turn on bit 2
	ld      (hl),a		; @0E9B 77  play sound
	ret		; @0E9C C9  return

j_0e9d:
	cp      #74		; @0E9D FE74  is the number of pills eaten in this level > #74 ?
	jr      c,j_0ea7		; @0E9F 3806  no, skip ahead
	ld      a,b		; @0EA1 78  load A with bitmask
	and     (hl)		; @0EA2 A6  turn off bits 0 through 4 on sound channel
	set     1,a		; @0EA3 CBCF  turn on bit 1
	ld      (hl),a		; @0EA5 77  play sound
	ret		; @0EA6 C9  return

j_0ea7:
	ld      a,b		; @0EA7 78  else load A with bitmask
	and     (hl)		; @0EA8 A6  turn off bits 0 through 4 on sound channel
	set     0,a		; @0EA9 CBC7  turn on bit 0
	ld      (hl),a		; @0EAB 77  play sound
	ret		; @0EAC C9  return

; called from #0909

; OTTOPATCH
;PATCH TO THE PRIMARY FRUIT ROUTINE, THIS ROUTINE IS CALLED ONCE PER
;GAME STEP (THE MINIMUM TIME IT TAKES A MONSTER TO MOVE A PIXEL)
;ORG 0EADH
;JP DOFRUIT
j_0ead:
	jp      j_86ee		; @0EAD C3EE86  jump to Ms. Pac patch for fruit release OTTO DOFRUIT

; original pac man code:
; 0EAD  3aa54d	ld	a,(#4da5)	; load A with pacman dead animation state (0 if not dead)
; end original pac man code

; junk from pac-man, used for fruit release

	and     a		; @0EB0 A7  is pac man dead ?
	ret     nz		; @0EB1 C0  yes, return

	ld      a,(fruit_points)		; @0EB2 3AD44D  load A with entry to fruit points (0 if no fruit)
	and     a		; @0EB5 A7  is a fruit already onscreen?
	ret     nz		; @0EB6 C0  yes, return

	ld      a,(dots_eaten)		; @0EB7 3A0E4E  load A with # of pills eaten this level
	cp      #46		; @0EBA FE46  == #46 ?
	jr      z,j_0ecc		; @0EBC 280E  yes, skip ahead to check for launch of first fruit
	cp      #AA		; @0EBE FEAA  == AA ?
	ret     nz		; @0EC0 C0  no, return

	ld      a,(fruit2_released)		; @0EC1 3A0D4E  load A with second fruit flag (1 if fruit has appeared)
	and     a		; @0EC4 A7  has the second fruit already appeared ?
	ret     nz		; @0EC5 C0  yes, return

	ld hl,fruit2_released		; @0EC6 210D4E  else load HL with second fruit flag
	inc     (hl)		; @0EC9 34  set the flag
	jr      j_0ed5		; @0ECA 1809  skip ahead to release fruit

j_0ecc:
	ld      a,(fruit1_released)		; @0ECC 3A0C4E  load A with first fruit flag (1 if fruit has appeared)
	and     a		; @0ECF A7  has the first fruit already appeared ?
	ret     nz		; @0ED0 C0  yes, return

	ld hl,fruit1_released		; @0ED1 210C4E  else load HL with first fruit flag
	inc     (hl)		; @0ED4 34  set the flag
j_0ed5:
	ld      hl,#8094		; @0ED5 219480  load H with #80, L with #94
	ld      (fruit_pos_lo),hl		; @0ED8 22D24D  store #80 into #4dd2, #94 into #4dd3.  sets fruit position to #80,#94 onscreen
	ld      hl,#0efd		; @0EDB 21FD0E  load HL with start of fruit data table below
	ld      a,(level_number)		; @0EDE 3A134E  load A with board level
	cp      #14		; @0EE1 FE14  > #14 ? (20 decimal)
	jr      c,j_0ee7		; @0EE3 3802  yes, skip ahead

	ld      a,#14		; @0EE5 3E14  else load A with #14
j_0ee7:
	ld      b,a		; @0EE7 47  copy to B
	add     a,a		; @0EE8 87  A := A*2
	add     a,b		; @0EE9 80  A := A + B.  A now has 3 times the board level
	rst     #10		; @0EEA D7  A: = (HL + A), HL := HL + A
	ld      (spr_fruit_code),a		; @0EEB 320C4C  Store fruit shape code
	inc     hl		; @0EEE 23  next address for color
	ld      a,(hl)		; @0EEF 7E  load A with fruit color
	ld      (spr_fruit_color),a		; @0EF0 320D4C  Store fruit color code
	inc     hl		; @0EF3 23  next address for point value
	ld      a,(hl)		; @0EF4 7E  Load A with point value
	ld      (fruit_points),a		; @0EF5 32D44D  Store fruit point value
	rst     #30		; @0EF8 F7  set timed task to clear the fruit sprite.
	db	#8A,#04,#00	; @0EF9 8A0400  timer=8a, task=4, param=0.  clears fruit after timer runs out (10 seconds)
	ret		; @0EFC C9  return
 
	; table for fruit sprites, colors, point value.  pac-man only, not used in ms. pac
	; (the 3 bytes are stored in the above order)
	; [the corresponding ms pac fruit table is at #879D]

	db	#00,#14,#06	; @0EFD 001406  cherry
	db	#01,#0F,#07	; @0F00 010F07  strawberry
	db	#02,#15,#08	; @0F03 021508  1st peach
	db	#02,#15,#08	; @0F06 021508  2nd peach
	db	#04,#14,#09	; @0F09 041409  1st apple
	db	#04,#14,#09	; @0F0C 041409  2nd apple
	db	#05,#17,#0A	; @0F0F 05170A  1st grape
	db	#05,#17,#0A	; @0F12 05170A  2nd grape
	db	#06,#09,#0B	; @0F15 06090B  1st galaxian
	db	#06,#09,#0B	; @0F18 06090B  2nd galaxian
	db	#03,#16,#0C	; @0F1B 03160C  1st bell
	db	#03,#16,#0C	; @0F1E 03160C  2nd bell
	db	#07,#16,#0D	; @0F21 07160D  1st key
	db	#07,#16,#0D	; @0F24 07160D  2nd key
	db	#07,#16,#0D	; @0F27 07160D  3rd key
	db	#07,#16,#0D	; @0F2A 07160D  4th key
	db	#07,#16,#0D	; @0F2D 07160D  5th key
	db	#07,#16,#0D	; @0F30 07160D  6th key
	db	#07,#16,#0D	; @0F33 07160D  7th key
	db	#07,#16,#0D	; @0F36 07160D  8th key
	db	#07,#16,#0D	; @0F39 07160D  9th key

; end pac-man code for fruit release


	db	#00,#00,#00,#00	; @0F3C 00000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @0F40 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @0F50 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @0F60 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @0F70 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @0F80 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @0F90 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @0FA0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @0FB0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @0FC0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @0FD0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @0FE0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#0A,#ED,#0C,#14,#0A,#00,#08		; @0FF0 0000000000000000000000000000

	db	#48,#36		; @0FFE 81CE  checksum bytes for this rom bank #0000 through #0FFF
    
    
	; hacks start at 0f5c since 0f3c-0f5b is used in other romsets.

	;; Pause toggle ; HACK5
        ; start 1 enters pause, start 2 leaves pause

	; 0f5c  3a4050    ld      a,(#5040)       ; IN1
	; 0f5f  e620      and     #20             ; start 1
	; 0f61  c2db1f    jp      nz,#1fdb        ; nope. jump away
	; 1fd0 for HACK3

        ; pause 
   
	;0f64  f5        push    af
	;0f65  af        xor     a		; a=0
	;0f66  320150    ld      (#5001),a	; disable sound
	;0f69  32c050    ld      (#50c0),a	; kick dog
	;0f6c  320050    ld      (#5000),a	; disable interrupts
	;0f6f  f3        di			; disable interrupts
	;0f70  af        xor     a		; a=0
	;0f71  32c050    ld      (#50c0),a	; kick dog
	;0f74  3a4050    ld      a,(#5040)	; IN1
	;0f77  cb77      bit     6,a		; start 2
	;0f79  20f5      jr      nz,#0f70	; not pressed, loop back

        ; turn it back on

	;0f7b  3e01      ld	a,#01		; a=1
	;0f7d  320050    ld	(#5000),a	; enable interrupts
	;0f80  320150    ld	(#5001),a	; enable sound
	;0f83  fb        ei			; enable interrupts
	;0f84  f1        pop	af		; retore a
	;0f85  c3db1f    jp	#1fdb		; jump back


	; level 255 pac fix ; BUGFIX01 (2 of 2)

	;0f88  3a134e    ld      a,(#4e13)  	; board number
	;0f8b  3c        inc     a
	;0f8c  feff      cp      ff
	;0f8e  2803      jr      z,#0f93	; don't store level if == 255
	;0f90  32134e    ld      (#4e13),a	; store new board number
	;0f93  c3940a    jp      #0a94		; jump back

	; level 141 mspac fix ; BUGFIX02 (2 of 2)

	;0f96  3a134e    ld      a,(#4e13)	; board number
	;0f99  3c        inc     a
	;0f9a  f37b      cp      #7b		; compare to bad board point
	;0f9c  2002      jr      nz,#0fa0	; don't store if out of range
	;0f9e  d608      sub     #08		; loop around for all 8 boards
	;0fa0  32134e    ld      (#4e13),a	; store the level number
	;0fa3  c3940a    jp      #0a94		; return


	;; blink coin lights to pellets ; HACK9

	; 0ffe  e089				; checksum patch



	; clear fruit
	; arrive from #0246 as timed task #04

j_1000:
	xor     a		; @1000 AF  A := #00
	ld      (fruit_points),a		; @1001 32D44D  clear fruit
j_1004:
	ret		; @1004 C9  return

; pac-man code:
; 1004 210000	ld	hl,#0000	; clear HL
; end pac-man code

; junk from pac-man
     
	; ;; gap-fill from golden boots $1005-$1006
	db	#00,#00		; @1005
	ld      (fruit_pos_lo),hl		; @1007 22D24D  clear fruit position 
	ret		; @100A C9  return

; this is timed task #05, arrive from #0246

	jp	j_3678		; @100B C37836  ms pac patch to erase the fruit score

; pac-man code:
; 100b  ef        rst     #28		; insert task to display text code #9B
; 100c  1C 9B
; end pac-man code

; junk from pac-man

	ld      a,(game_mode)		; @100E 3A004E  load A with main routine number
	dec     a		; @1011 3D  decrease.  are we in the demo?
	ret     z		; @1012 C8  yes, return
	rst     #28		; @1013 EF  no, insert task to display text code A2
	db	#1C,#A2	; @1014 1CA2  task data
	ret		; @1016 C9  return

; called from #052C, #052F, #08EB and #08EE 

j_1017:
	call    j_1291		; @1017 CD9112  do things if pacman is dead
	ld      a,(pac_death_anim)		; @101A 3AA54D  load A with pacman dead animation state (0 if pac is alive)
	and     a		; @101D A7  is pacman alive?
	ret     nz		; @101E C0  no, return (to #08F1)

	call    j_1066		; @101F CD6610  check for ghosts being eaten and set ghost states accordingly
	call    j_1094		; @1022 CD9410  check for red ghost state and do things if not alive
	call    j_109e		; @1025 CD9E10  check for pink ghost state and do things if not alive
	call    j_10a8		; @1028 CDA810  check for blue ghost (inky) state and do things if not alive
	call    j_10b4		; @102B CDB410  check for orange ghost state and do things if not alive
	ld      a,(ghosts_killed_pending)		; @102E 3AA44D  load A with # of ghost killed but no collision for yet [0..4]
	and     a		; @1031 A7  == #00 ?
	jp      z,j_1039		; @1032 CA3910  yes, skip ahead

	call    j_1235		; @1035 CD3512  no, call this sub
	ret		; @1038 C9  and return

j_1039:
	call    j_171d		; @1039 CD1D17  check for collision with regular ghosts
	call    j_1789		; @103C CD8917  check for collision with blue ghosts
	ld      a,(ghosts_killed_pending)		; @103F 3AA44D  load A with # of ghost killed but no collision for yet [0..4]
	and     a		; @1042 A7  is there a collsion ?
	ret     nz		; @1043 C0  yes, return

	call    j_1806		; @1044 CD0618  handle all pac-man movement
	call    j_1b36		; @1047 CD361B  control movement for red ghost
	call    j_1c4b		; @104A CD4B1C  control movement for pink ghost
	call    j_1d22		; @104D CD221D  control movement for blue ghost (inky)
	call    j_1df9		; @1050 CDF91D  control movement for orange ghost
	ld      a,(level_state)		; @1053 3A044E  load A with level state subroutine #
	cp      #03		; @1056 FE03  is a game being played ?
	ret     nz		; @1058 C0  no, return

	call    j_1376		; @1059 CD7613  control blue ghost timer and reset ghosts when it is over or when pac eats all blue ghosts
	call    j_2069		; @105C CD6920  check for pink ghost to leave the ghost house
	call    j_208c		; @105F CD8C20  check for blue ghost (inky) to leave the ghost house
	call    j_20af		; @1062 CDAF20  check for orange ghost to leave the ghost house
	ret		; @1065 C9  return

; called from #101F

j_1066:
	ld      a,(kill_ghost_state)		; @1066 3AAB4D  load A with killing ghost state
	and     a		; @1069 A7  is a ghost being eaten ?
	ret     z		; @106A C8  no, return

	dec     a		; @106B 3D  is the red ghost being eaten?
	jr      nz,j_1076		; @106C 2008  no, skip ahead and check next ghost
	ld      (kill_ghost_state),a		; @106E 32AB4D  yes, store A (#00) into the killing ghost state
	inc     a		; @1071 3C  A := A + 1 [ A is now #01, code for dead ghost]
	ld      (red_state),a		; @1072 32AC4D  store into red ghost state
	ret		; @1075 C9  return

j_1076:
	dec     a		; @1076 3D  is the pink ghost being eaten?
	jr      nz,j_1081		; @1077 2008  no, skip ahead and check next ghost
	ld      (kill_ghost_state),a		; @1079 32AB4D  yes, store A (#00) into the killing ghost state
	inc     a		; @107C 3C  A := #01
	ld      (pink_state),a		; @107D 32AD4D  set pink ghost state to dead
	ret		; @1080 C9  return

j_1081:
	dec     a		; @1081 3D  is the blue ghost (inky) being eaten?
	jr      nz,j_108c		; @1082 2008  no, skip ahead
	ld      (kill_ghost_state),a		; @1084 32AB4D  yes, store A (#00) into the killing ghost state
	inc     a		; @1087 3C  A := #01
	ld      (blue_state),a		; @1088 32AE4D  set inky ghost state to dead
	ret		; @108B C9  return

j_108c:
	ld      (orange_state),a		; @108C 32AF4D  else orange ghost is being eaten.   set orange ghost state to dead
	dec     a		; @108F 3D  A := #00
	ld      (kill_ghost_state),a		; @1090 32AB4D  clear killing ghost state 
	ret		; @1093 C9  return

; called from #1022

j_1094:
	ld	a,(red_state)		; @1094 3AAC4D  load A with red ghost state
	rst	#20		; @1097 E7  jump based on A
	db	#0C,#00	; @1098 0C00  #000C	; return immediately when ghost is alive
	db	#C0,#10	; @109A C010  #10C0	; when ghost is dead
	db	#D2,#10	; @109C D210  #10D2	; when ghost eyes are above and entering the ghost house when returning home

; called from #1025

j_109e:
	ld	a,(pink_state)		; @109E 3AAD4D  load A with pink ghost state
	rst	#20		; @10A1 E7  jump based on A
	db	#0C,#00	; @10A2 0C00  #000C	; return immediately when ghost is alive
	db	#18,#11	; @10A4 1811  #1118	; when ghost is dead
	db	#2A,#11	; @10A6 2A11  #112A	; when ghost eyes are above and entering the ghost house when returning home

; called from #1028

j_10a8:
	ld	a,(blue_state)		; @10A8 3AAE4D  load A with blue ghost (Inky) state
	rst	#20		; @10AB E7  jump based on A
	db	#0C,#00	; @10AC 0C00  #000C	; return immediately when ghost is alive
	db	#5C,#11	; @10AE 5C11  #115C	; when ghost is dead
	db	#6E,#11	; @10B0 6E11  #116E	; when ghost eyes are above and entering the ghost house when returning home
	db	#8F,#11	; @10B2 8F11  #118F	; when ghost eyes have arrived in ghost house and when moving to left side of ghost house

; called from #102B

j_10b4:
	ld	a,(orange_state)		; @10B4 3AAF4D  load A with orange ghost state
	rst	#20		; @10B7 E7  jump based on A
	db	#0C,#00	; @10B8 0C00  #000C	; return immediately when ghost is alive
	db	#C9,#11	; @10BA C911  #11C9	; when ghost is dead
	db	#DB,#11	; @10BC DB11  #11DB	; when ghost eyes are above and entering the ghost house when returning home
	db	#FC,#11	; @10BE FC11  #11FC	; when ghost eyes have arrived in ghost house and when moving to right side of ghost house

; arrive here from #1097 when red ghost is dead (eyes)

	call	j_1bd8		; @10C0 CDD81B  handle red ghost movement
	ld	hl,(red_y)		; @10C3 2A004D  load HL with red ghost (Y,X) position
	ld      de,#8064		; @10C6 116480  load DE with X=80, Y=64 position which is right above the ghost house
	and     a		; @10C9 A7  clear carry flag
	sbc     hl,de		; @10CA ED52  is red ghost eyes right above the ghost house?
	ret     nz		; @10CC C0  no, return

	ld hl,red_state		; @10CD 21AC4D  yes, load HL with red ghost state
	inc     (hl)		; @10D0 34  increase
	ret		; @10D1 C9  return

; arrive here from #1097 when red ghost eyes are above and entering the ghost house when returning home

	ld      ix,#3301		; @10D2 DD210133  load IX with direction address tiles for moving down
	ld iy,red_y		; @10D6 FD21004D  load IY with red ghost position
	call    j_2000		; @10DA CD0020  HL := (IX) + (IY)
	ld      (red_y),hl		; @10DD 22004D  store new position for red ghost
	ld      a,#01		; @10E0 3E01  A := #01
	ld      (red_prev_dir),a		; @10E2 32284D  set previous red ghost orientation as moving down
	ld      (red_dir),a		; @10E5 322C4D  set red ghost orientation as moving down
	ld      a,(red_y)		; @10E8 3A004D  load A with red ghost Y position
	cp      #80		; @10EB FE80  has the red ghost eyes fully entered the ghost house?
	ret     nz		; @10ED C0  no, return

	ld      hl,#2e2f		; @10EE 212F2E  yes, load HL with 2E, 2F location which is the center of the ghost house
	ld      (red_tile_y),hl		; @10F1 220A4D  store into red ghost tile position
	ld      (red_tile_y2),hl		; @10F4 22314D  store into red ghost tile position 2
	xor     a		; @10F7 AF  A := #00
	ld      (red_substate),a		; @10F8 32A04D  set red ghost substate as at home
	ld      (red_state),a		; @10FB 32AC4D  set red ghost state as alive
	ld      (red_frightened),a		; @10FE 32A74D  set red ghost blue flag as not edible

; the other ghost subroutines arrive here after the ghost has arrived at home

j_1101:
	ld ix,red_state		; @1101 DD21AC4D  load IX with ghost state starting address
	or      (ix+#00)		; @1105 DDB600  is red ghost dead?
	or      (ix+#01)		; @1108 DDB601  or the pink ghost dead?
	or      (ix+#02)		; @110B DDB602  or the blue ghost dead?
	or      (ix+#03)		; @110E DDB603  or the orange ghost dead
	ret     nz		; @1111 C0  yes, return

; arrive here when ghost eyes return to ghost home and there are no other ghost eyes still moving around

	ld hl,CH2_E_NUM		; @1112 21AC4E  load HL with sound channel 2
	res	6,(hl)		; @1115 CBB6  clear sound on bit 6
	ret		; @1117 C9  return

; arrive here from #10A1 when pink ghost is dead (eyes)

	call    j_1caf		; @1118 CDAF1C  handle pink ghost movement
	ld      hl,(pink_y)		; @111B 2A024D  load HL with pink ghost position
	ld      de,#8064		; @111E 116480  load DE with Y,X position above ghost house 
	and     a		; @1121 A7  clear carry flag
	sbc     hl,de		; @1122 ED52  subtract. is the pink ghost eyes right above the ghost home?
	ret     nz		; @1124 C0  no, return

	ld hl,pink_state		; @1125 21AD4D  yes, load HL with pink ghost state
	inc     (hl)		; @1128 34  increase
	ret		; @1129 C9  return

; arrive here from #10A1 when pink ghost eyes are above and entering the ghost house when returning home

	ld      ix,#3301		; @112A DD210133  load IX with direction address tiles for moving down
	ld iy,pink_y		; @112E FD21024D  load IY with pink ghost position
	call    j_2000		; @1132 CD0020  HL := (IX) + (IY)
	ld      (pink_y),hl		; @1135 22024D  store new position for pink ghost
	ld      a,#01		; @1138 3E01  A := #01
	ld      (pink_prev_dir),a		; @113A 32294D  set previous pink ghost orientation as moving down
	ld      (pink_dir),a		; @113D 322D4D  set pink ghost orientation as moving down
	ld      a,(pink_y)		; @1140 3A024D  load A with pink ghost Y position
	cp      #80		; @1143 FE80  has the pink ghost eyes fully entered the ghost house?
	ret     nz		; @1145 C0  no, return

	ld      hl,#2e2f		; @1146 212F2E  yes, load HL with 2E, 2F location which is the center of the ghost house
	ld      (pink_tile_y),hl		; @1149 220C4D  store into pink ghost tile position
	ld      (pink_tile_y2),hl		; @114C 22334D  store into pink ghost tile position 2
	xor     a		; @114F AF  A := #00
	ld      (pink_substate),a		; @1150 32A14D  set pink ghost substate as at home
	ld      (pink_state),a		; @1153 32AD4D  set pink ghost state as alive
	ld      (pink_frightened),a		; @1156 32A84D  set pink ghost blue flag as not edible
	jp      j_1101		; @1159 C30111  jump to check for clearing eyes sound

; arrive here from #10AB when blue ghost (inky) is dead (eyes)

	call    j_1d86		; @115C CD861D  handle inky movement
	ld      hl,(blue_y)		; @115F 2A044D  load HL with blue ghost (inky) position
	ld      de,#8064		; @1162 116480  load DE with Y,X position above ghost house
	and     a		; @1165 A7  clear carry flag
	sbc     hl,de		; @1166 ED52  subtract.  are inky's eyes right above the ghost home?
	ret     nz		; @1168 C0  no, return

	ld hl,blue_state		; @1169 21AE4D  yes, load HL with blue ghost (inky) state
	inc     (hl)		; @116C 34  increase
	ret		; @116D C9  return

; arrive here from #10AB when blue ghost (inky) eyes are above and entering the ghost house when returning home

	ld      ix,#3301		; @116E DD210133  load IX with direction address tiles for moving down
	ld iy,blue_y		; @1172 FD21044D  load IY with inky position
	call    j_2000		; @1176 CD0020  HL := (IX) + (IY)
	ld      (blue_y),hl		; @1179 22044D  store new position for inky
	ld      a,#01		; @117C 3E01  A := #01
	ld      (blue_prev_dir),a		; @117E 322A4D  set previous inky orientation as moving down
	ld      (blue_dir),a		; @1181 322E4D  set inky orientation as moving down
	ld      a,(blue_y)		; @1184 3A044D  load A with inky Y position
	cp      #80		; @1187 FE80  have the inky eyes fully entered the ghost house?
	ret     nz		; @1189 C0  no, return

	ld hl,blue_state		; @118A 21AE4D  yes, load HL with blue ghost (inky) state 
	inc     (hl)		; @118D 34  increase
	ret		; @118E C9  return

; arrive here from #10AB when inky ghost eyes have arrived in ghost house and when moving to left side of ghost house

	ld      ix,#3303		; @118F DD210333  load IX with direction address tiles for moving left
	ld iy,blue_y		; @1193 FD21044D  load IY with inky position
	call    j_2000		; @1197 CD0020  HL := (IX) + (IY)
	ld      (blue_y),hl		; @119A 22044D  store new position for inky
	ld      a,#02		; @119D 3E02  A := #02
	ld      (blue_prev_dir),a		; @119F 322A4D  set previous inky orientation as moving left
	ld      (blue_dir),a		; @11A2 322E4D  set inky orientation as moving left
	ld      a,(blue_x)		; @11A5 3A054D  load A with inky X position
	cp      #90		; @11A8 FE90  has inky reached the left side of the ghost house?
	ret     nz		; @11AA C0  no, return

	ld      hl,#302f		; @11AB 212F30  yes, load HL with #30, #2F for tile position inside ghost house
	ld      (blue_tile_y),hl		; @11AE 220E4D  store into inky tile position
	ld      (blue_tile_y2),hl		; @11B1 22354D  store into inky tile position 2
	ld      a,#01		; @11B4 3E01  A := #01
	ld      (blue_prev_dir),a		; @11B6 322A4D  set previous inky orientation as moving down
	ld      (blue_dir),a		; @11B9 322E4D  set inky orientation as moving down
	xor     a		; @11BC AF  A := #00
	ld      (blue_substate),a		; @11BD 32A24D  set inky substate as at home
	ld      (blue_state),a		; @11C0 32AE4D  set inky state as alive
	ld      (blue_frightened),a		; @11C3 32A94D  set inky blue flag as not edible
	jp      j_1101		; @11C6 C30111  jump to check for clearing eyes sound

; arrive here from #10B7 when orange ghost is dead (eyes)

	call    j_1e5d		; @11C9 CD5D1E  handle orange ghost movement
	ld      hl,(orange_y)		; @11CC 2A064D  load HL with orange ghost position
	ld      de,#8064		; @11CF 116480  load DE with Y,X position above ghost home
	and     a		; @11D2 A7  clear carry flag
	sbc     hl,de		; @11D3 ED52  subtract.  is orange ghost eyes right above ghost home?
	ret     nz		; @11D5 C0  no, return

	ld hl,orange_state		; @11D6 21AF4D  yes, load HL with orange ghost state
	inc     (hl)		; @11D9 34  increase
	ret		; @11DA C9  return

; arrive here from #10B7 when orange ghost eyes are above and entering the ghost house when returning home

	ld      ix,#3301		; @11DB DD210133  load IX with direction address tiles for moving down
	ld iy,orange_y		; @11DF FD21064D  load IY with orange ghost position 
	call    j_2000		; @11E3 CD0020  HL := (IX) + (IY)
	ld      (orange_y),hl		; @11E6 22064D  store new position for orange ghost
	ld      a,#01		; @11E9 3E01  A := #01
	ld      (orange_prev_dir),a		; @11EB 322B4D  set previous orange ghost orientation as moving down
	ld      (orange_dir),a		; @11EE 322F4D  set orange orientation as moving down
	ld      a,(orange_y)		; @11F1 3A064D  load A with orange ghost Y position
	cp      #80		; @11F4 FE80  has the orange ghost eyes fully entered the ghost house?
	ret     nz		; @11F6 C0  no, return

	ld hl,orange_state		; @11F7 21AF4D  yes, load HL with orange ghost state
	inc     (hl)		; @11FA 34  increase
	ret		; @11FB C9  return

; arrive here from #10B7 when orange ghost eyes have arrived in ghost house and when moving to right side of ghost house

	ld      ix,#32ff		; @11FC DD21FF32  load IX with direction address tiles for moving right
	ld iy,orange_y		; @1200 FD21064D  load IY with orange ghost position 
	call    j_2000		; @1204 CD0020  HL := (IX) + (IY)
	ld      (orange_y),hl		; @1207 22064D  store new position for orange ghost
	xor     a		; @120A AF  A := #00
	ld      (orange_prev_dir),a		; @120B 322B4D  set previous orange ghost orientation as moving right
	ld      (orange_dir),a		; @120E 322F4D  set orange orientation as moving right
	ld      a,(orange_x)		; @1211 3A074D  load A with orange ghost X position
	cp      #70		; @1214 FE70  has the orange ghost reached the right side of the ghost house?
	ret     nz		; @1216 C0  no, return

	ld      hl,#2c2f		; @1217 212F2C  yes, load HL with tile position of the right side of ghost house
	ld      (orange_tile_y),hl		; @121A 22104D  store into orange ghost tile position
	ld      (orange_tile_y2),hl		; @121D 22374D  store into orange ghost tile position 2
	ld      a,#01		; @1220 3E01  A := #01
	ld      (orange_prev_dir),a		; @1222 322B4D  set previous orange ghost orientation as moving down
	ld      (orange_dir),a		; @1225 322F4D  set orange ghost orientation as moving down
	xor     a		; @1228 AF  A := #00
	ld      (orange_substate),a		; @1229 32A34D  set orange ghost substate as at home
	ld      (orange_state),a		; @122C 32AF4D  set orange ghost state as alive
	ld      (orange_frightened),a		; @122F 32AA4D  set orange ghost blue flag as not edible
	jp      j_1101		; @1232 C30111  jump to check for clearing eyes sound

; called from #1035
; arrive here when a ghost is eaten, or after the point score for eating a ghost is set to vanish

j_1235:
	ld	a,(killed_ghost_anim)		; @1235 3AD14D  load A with killed ghost animation state
	rst  #20		; @1238 E7  jump based on A

	db	#3F,#12	; @1239 3F12  #123F	; a ghost is being eaten
	db	#0C,#00	; @123B 0C00  #000C	; return immediately
	db	#3F,#12	; @123D 3F12  #123F	; point score is set to vanish

	ld hl,spr_unk_4c00		; @123F 21004C  load HL with starting address for ghost sprites and colors
	ld      a,(ghosts_killed_pending)		; @1242 3AA44D  load A with # of ghost killed but no collision for yet
	add     a,a		; @1245 87  A := A * 2
	ld      e,a		; @1246 5F  store into E
	ld      d,#00		; @1247 1600  clear D
	add     hl,de		; @1249 19  add.  now HL has the sprite address of the ghost killed
	ld      a,(killed_ghost_anim)		; @124A 3AD14D  load A with killed ghost animation state
	and     a		; @124D A7  is this ghost killed, showing points per kill ?
	jr      nz,j_1277		; @124E 2027  no, skip ahead

	ld      a,(ghosts_killed_count)		; @1250 3AD04D  yes, load A with current number of killed ghosts
	ld      b,#27		; @1253 0627  B := #27
	add     a,b		; @1255 80  add together to choose correct sprite (200, 400, 800 or 1600)
	ld      b,a		; @1256 47  store result into B
	ld      a,(dip_cocktail)		; @1257 3A724E  load A with cocktail mode (0=no, 1=yes)
	ld      c,a		; @125A 4F  copy to C
	ld      a,(player_number)		; @125B 3A094E  load A with current player number (0=P1, 1=P2)
	and     c		; @125E A1  is this player 2 and cocktail mode ?
	jr      z,j_1265		; @125F 2804  no, skip next 2 steps

	set     6,b		; @1261 CBF0  set bit 6 of B
	set     7,b		; @1263 CBF8  set bit 7 of B

j_1265:
	ld      (hl),b		; @1265 70  store B into ghost sprite score
	inc     hl		; @1266 23  HL now has ghost sprite color
	ld      (hl),#18		; @1267 3618  store color #18
	ld      a,#00		; @1269 3E00  A := #00
	ld      (spr_pac_color),a		; @126B 320B4C  store into pacman sprite color
	rst     #30		; @126E F7  set timed task to increase killed ghost animation state when a ghost is eaten
	db	#4A,#03,#00	; @126F 4A0300  task timer=#4A, task=3, param=0.  

; arrive here from task table when a ghost has been eaten.  Task #03, arrive from #0246

	ld hl,killed_ghost_anim		; @1272 21D14D  load HL with killed ghost animation state
	inc     (hl)		; @1275 34  increase to next type
	ret		; @1276 C9  return

; arrive here when score for eating a ghost is set to dissapear

j_1277:
	ld	(hl),#20		; @1277 3620  set ghost sprite to eyes
	ld	a,#09		; @1279 3E09  load A with #09
	ld	(spr_pac_color),a		; @127B 320B4C  store into pacman sprite color to restore pacman to screen
	ld	a,(ghosts_killed_pending)		; @127E 3AA44D  load A with # of ghost killed but no collision for yet
	ld	(kill_ghost_state),a		; @1281 32AB4D  store into killing ghost state
	xor	a		; @1284 AF  A := #00
	ld	(ghosts_killed_pending),a		; @1285 32A44D  store into # of ghost killed but no collision for yet
	ld	(killed_ghost_anim),a		; @1288 32D14D  store into killed ghost animation state
	ld hl,CH2_E_NUM		; @128B 21AC4E  load HL with sound channel 2
	set	6,(hl)		; @128E CBF6  play sound for ghost eyes
	ret		; @1290 C9  return

; called from #1017

j_1291:
	ld	a,(pac_death_anim)		; @1291 3AA54D  load A with pacman dead animation state (0 if alive)
	rst	#20		; @1294 E7  jump based on A

	db	#0C,#00	; @1295 0C00  #000C	; alive returns immediately
	db	#B7,#12	; @1297 B712  #12B7	; increase counter
	db	#B7,#12	; @1299 B712  #12B7	; increase counter
	db	#B7,#12	; @129B B712  #12B7	; increase counter
	db	#B7,#12	; @129D B712  #12B7	; increase counter
	db	#CB,#12	; @129F CB12  #12CB	; animate dead mspac
	db	#F9,#12	; @12A1 F912  #12F9	; animate dead mspac + start dying sound
	db	#06,#13	; @12A3 0613  #1306	; animate dead mspac
	db	#0E,#13	; @12A5 0E13  #130E	; animate dead mspac
	db	#16,#13	; @12A7 1613  #1316	; animate dead mspac
	db	#1E,#13	; @12A9 1E13  #131E	; animate dead mspac
	db	#26,#13	; @12AB 2613  #1326	; animate dead mspac
	db	#2E,#13	; @12AD 2E13  #132E	; animate dead mspac
	db	#36,#13	; @12AF 3613  #1336	; animate dead mspac
	db	#3E,#13	; @12B1 3E13  #133E	; animate dead mspac
	db	#46,#13	; @12B3 4613  #1346	; animate dead mspac + clear sound
	db	#53,#13	; @12B5 5313  #1353	; animate last time, decrease lives, clear ghosts, increase game state


	ld      hl,(death_counter_lo)		; @12B7 2AC54D  load HL with counter started after pacman killed
	inc     hl		; @12BA 23  increase counter
	ld      (death_counter_lo),hl		; @12BB 22C54D  store counter
	ld      de,#0078		; @12BE 117800  load DE with counter timer result 
	and     a		; @12C1 A7  clear carry flag
	sbc     hl,de		; @12C2 ED52  is the counter == #78 ?
	ret     nz		; @12C4 C0  no, return

	ld      a,#05		; @12C5 3E05  yes, A := #05
	ld      (pac_death_anim),a		; @12C7 32A54D  store into pacman dead animation state (0 if not dead)
	ret		; @12CA C9  return (to #101A)

	; adjust mspac sprite animation while dying

	ld      hl,#0000		; @12CB 210000  HL := #0000
	call    j_267e		; @12CE CD7E26  clears #4d00 through #4d07
	ld      a,#34		; @12D1 3E34  A := #34
	ld      de,#00b4		; @12D3 11B400  DE := #00B4

j_12d6:
	ld      c,a		; @12D6 4F  Copy A into C
	ld      a,(dip_cocktail)		; @12D7 3A724E  load A with cocktail mode (0=no, 1=yes)
	ld      b,a		; @12DA 47  copy cocktail mode into B
	ld      a,(player_number)		; @12DB 3A094E  load A with current player number
	and     b		; @12DE A0  mix with cocktail mode.  Is this player 2 and cocktail mode ?
	jr      z,j_12e5		; @12DF 2804  no, skip ahead

	ld      a,#C0		; @12E1 3EC0  yes, A := C0
	or      c		; @12E3 B1  OR with C which has mspac sprite # in it
	ld      c,a		; @12E4 4F  store result into C

; death animation display
j_12e5:
	ld      a,c		; @12E5 79  A := C
	ld      (spr_pac_code),a		; @12E6 320A4C  store into mspac sprite number
	ld      hl,(death_counter_lo)		; @12E9 2AC54D  load HL with counter started after pacman killed
	inc     hl		; @12EC 23  increase counter
	ld      (death_counter_lo),hl		; @12ED 22C54D  store counter
	and     a		; @12F0 A7  clear carry flag
	sbc     hl,de		; @12F1 ED52  is the counter == DE ?
	ret     nz		; @12F3 C0  no, return

	ld hl,pac_death_anim		; @12F4 21A54D  yes, load HL with pacman dead animation state
	inc     (hl)		; @12F7 34  increase pacman dead animation state
	ret		; @12F8 C9  return

	ld hl,CH3_E_NUM		; @12F9 21BC4E  load HL with sound channel 3
	set	4,(hl)		; @12FC CBE6  set dying sound
	ld      a,#35		; @12FE 3E35  mspac sprite := #35  Frame 1
	ld      de,#00c3		; @1300 11C300  timer := C3
	jp      j_12d6		; @1303 C3D612  animate dead mspac

	ld      a,#36		; @1306 3E36  mspac sprite := #36  Frame 2
	ld      de,#00d2		; @1308 11D200  timer := D2
	jp      j_12d6		; @130B C3D612  animate dead mspac

	ld      a,#37		; @130E 3E37  mspac sprite := #37  Frame 3
	ld      de,#00e1		; @1310 11E100  timer := E1
	jp      j_12d6		; @1313 C3D612  animate dead mspac

	ld      a,#38		; @1316 3E38  mspac sprite := #38  Frame 4
	ld      de,#00f0		; @1318 11F000  timer := F0
	jp      j_12d6		; @131B C3D612  animate dead mspac

	ld      a,#39		; @131E 3E39  mspac sprite := #39  Frame 5
	ld      de,#00ff		; @1320 11FF00  timer := FF
	jp      j_12d6		; @1323 C3D612  animate dead mspac

	ld      a,#3a		; @1326 3E3A  mspac sprite := #3A  Frame 6
	ld      de,#010e		; @1328 110E01  timer := #10E
	jp      j_12d6		; @132B C3D612  animate dead mspac

	ld      a,#3b		; @132E 3E3B  mspac sprite := #3B  Frame 7
	ld      de,#011d		; @1330 111D01  timer := #11D
	jp      j_12d6		; @1333 C3D612  animate dead mspac

	ld      a,#3c		; @1336 3E3C  mspac sprite := #3C  Frame 8
	ld      de,#012c		; @1338 112C01  timer := #12C
	jp      j_12d6		; @133B C3D612  animate dead mspac

	ld      a,#3d		; @133E 3E3D  mspac sprite := #3D  Frame 9
	ld      de,#013b		; @1340 113B01  timer := #13B
	jp      j_12d6		; @1343 C3D612  animate dead mspac

	ld hl,CH3_E_NUM		; @1346 21BC4E  load HL with sound channel 3
	ld	(hl),#00		; @1349 3600  clear sound
	ld      a,#3e		; @134B 3E3E  mspac sprite = #3E  Frame 10
	ld      de,#0159		; @134D 115901  timer := #159
	jp      j_12d6		; @1350 C3D612  animate dead mspac

	ld      a,#3f		; @1353 3E3F  A := #3F
	ld      (spr_pac_code),a		; @1355 320A4C  store into mspac sprite number
	ld      hl,(death_counter_lo)		; @1358 2AC54D  load HL with counter started after pacman killed
	inc     hl		; @135B 23  increase timer
	ld      (death_counter_lo),hl		; @135C 22C54D  store timer
	ld      de,#01b8		; @135F 11B801  load timer check with #01B8
	and     a		; @1362 A7  clear carry flag
	sbc     hl,de		; @1363 ED52  is timer == #01B8 ?
	ret     nz		; @1365 C0  no, return

	; decrement lives
	; this gets called after the death animation, but before the screen gets redrawn.
	; -- probably a good hook point for 'insert coin to contunue' --

	ld hl,lives_real		; @1366 21144E  load HL with number of lives left
	dec     (hl)		; @1369 35  subtract 1
	ld hl,lives_displayed		; @136A 21154E  load HL with number of lives on screen
	dec     (hl)		; @136D 35  subtract 1
	call    j_2675		; @136E CD7526  clears all ghosts
	ld hl,level_state		; @1371 21044E  load HL with game state.  
	inc     (hl)		; @1374 34  increase game state
	ret		; @1375 C9  return


	;; routine to control blue time
	;; ret immediately to make ghosts stay blue till eaten 

j_1376:
	ld      a,(power_pill_active)		; @1376 3AA64D  load A with power pill effect (1=active, 0=no effect)
	and     a		; @1379 A7  is a power pill active ?
	ret     z		; @137A C8  no, return

	ld ix,red_frightened		; @137B DD21A74D  yes, load IX with ghost blue flag starting address
	ld      a,(ix+#00)		; @137F DD7E00  load A with red ghost blue flag
	or      (ix+#01)		; @1382 DDB601  OR with pink ghost blue flag
	or      (ix+#02)		; @1385 DDB602  OR with blue ghost (inky) blue flag
	or      (ix+#03)		; @1388 DDB603  OR with oragne ghost blue flag
	jp      z,j_1398		; @138B CA9813  if all ghosts are not blue, then skip ahead and reset power pill effect

	ld      hl,(frightened_timer_lo)		; @138E 2ACB4D  else load HL with blue ghost counter
	dec     hl		; @1391 2B  count down
	ld      (frightened_timer_lo),hl		; @1392 22CB4D  store result
	ld      a,h		; @1395 7C  load A with counter high byte
	or      l		; @1396 B5  or with counter low byte.  are both counters at #00 ?
	ret     nz		; @1397 C0  no, return

; arrive here when power pill effect is over, either by timer or by eating all ghosts

j_1398:
	ld hl,spr_pac_color		; @1398 210B4C  load HL with pacman color entry
	ld      (hl),#09		; @139B 3609  store #09 into pacman color entry
	ld      a,(red_state)		; @139D 3AAC4D  load A with red ghost state
	and     a		; @13A0 A7  is red ghost alive ?
	jp      nz,j_13a7		; @13A1 C2A713  yes, skip next step

	ld      (red_frightened),a		; @13A4 32A74D  clear red ghost blue state

j_13a7:
	ld      a,(pink_state)		; @13A7 3AAD4D  load A with pink ghost state
	and     a		; @13AA A7  is pink ghost alive ?
	jp      nz,j_13b1		; @13AB C2B113  yes, skip next step

	ld      (pink_frightened),a		; @13AE 32A84D  clear pink ghost blue state

j_13b1:
	ld      a,(blue_state)		; @13B1 3AAE4D  load A with blue ghost (inky) state
	and     a		; @13B4 A7  is inky alive ?
	jp      nz,j_13bb		; @13B5 C2BB13  yes, skip next step

	ld      (blue_frightened),a		; @13B8 32A94D  clear inky blue state

j_13bb:
	ld      a,(orange_state)		; @13BB 3AAF4D  load A with orange ghost state
	and     a		; @13BE A7  is orange ghost alive ?
	jp      nz,j_13c5		; @13BF C2C513  yes, skip next step

	ld	(orange_frightened),a		; @13C2 32AA4D  clear orange ghost blue state

j_13c5:
	xor	a		; @13C5 AF  A := #00
	ld	(frightened_timer_lo),a		; @13C6 32CB4D  clear counter while ghosts are blue
	ld	(frightened_timer_hi),a		; @13C9 32CC4D  clear counter while ghosts are blue
	ld	(power_pill_active),a		; @13CC 32A64D  clear pill effect
	ld	(frightened_flash_counter),a		; @13CF 32C84D  clear counter used to change ghost colors under big pill effects
	ld	(ghosts_killed_count),a		; @13D2 32D04D  clear current number of killed ghosts
	ld hl,CH2_E_NUM		; @13D5 21AC4E  load HL with sound channel 2
	res	5,(hl)		; @13D8 CBAE  clear sound bit 5
	res	7,(hl)		; @13DA CBBE  clear sound bit 7
	ret		; @13DC C9  return

; arrive here from call at #08F1

j_13dd:
	ld hl,pills_since_pac_move		; @13DD 219E4D  load HL with address related to number of pills eaten before last pacman move
	ld      a,(dots_eaten)		; @13E0 3A0E4E  load A with # of pills eaten
	cp      (hl)		; @13E3 BE  are they equal ?
	jp      z,j_13ee		; @13E4 CAEE13  yes, skip ahead

	ld      hl,#0000		; @13E7 210000  else HL := #0000
	ld      (ghost_leave_home_idle_lo),hl		; @13EA 22974D  clear inactivity counter
	ret		; @13ED C9  return

j_13ee:
	ld      hl,(ghost_leave_home_idle_lo)		; @13EE 2A974D  load HL with inactivity counter
	inc     hl		; @13F1 23  increment
	ld      (ghost_leave_home_idle_lo),hl		; @13F2 22974D  store
	ld      de,(ghost_leave_home_units_lo)		; @13F5 ED5B954D  load DE with number of units before ghost leaves home (no change w/ pills)
	and     a		; @13F9 A7  clear carry flag
	sbc     hl,de		; @13FA ED52  subtract.  are they equal ?
	ret     nz		; @13FC C0  no, return

	ld      hl,#0000		; @13FD 210000  else HL := #0000
	ld      (ghost_leave_home_idle_lo),hl		; @1400 22974D  clear inactivity counter
	ld      a,(pink_substate)		; @1403 3AA14D  load A with pink ghost substate
	and     a		; @1406 A7  is pink ghost in the ghost house ?
	push    af		; @1407 F5  save AF
	call    z,j_2086		; @1408 CC8620  yes, then call this sub which will release the pink ghost
	pop     af		; @140B F1  restore AF
	ret     z		; @140C C8  yes, then return

	ld      a,(blue_substate)		; @140D 3AA24D  else load A with blue (inky) ghost state
	and     a		; @1410 A7  is inky in the ghost house ?
	push    af		; @1411 F5  save AF
	call    z,j_20a9		; @1412 CCA920  yes, then call this sub which will release Inky
	pop     af		; @1415 F1  restore AF
	ret     z		; @1416 C8  yes, then return

	ld      a,(orange_substate)		; @1417 3AA34D  else load A with orange ghost state
	and     a		; @141A A7  is orange ghost in the ghost house?
	call    z,j_20d1		; @141B CCD120  yes, then call this sub which will release orange ghost
	ret		; @141E C9  return

; arrive here from #01A1
; during core game loop

j_141f:
	ld      a,(dip_cocktail)		; @141F 3A724E  load A with cocktail mode (0=no, 1=yes)
	ld      b,a		; @1422 47  copy to B
	ld      a,(player_number)		; @1423 3A094E  load A with player #
	and     b		; @1426 A0  is cocktail mode on and and player 2 playing?
	ret     z		; @1427 C8  no, return

; yes, handle sprite flips

	ld      b,a		; @1428 47  B := #01
	ld ix,spr_unk_4c00		; @1429 DD21004C  load IX with start of sprite address
	ld      e,#08		; @142D 1E08  E := #08
	ld      c,#08		; @142F 0E08  C := #08
	ld      d,#07		; @1431 1607  D := #07
	ld      a,(red_y)		; @1433 3A004D  load A with red ghost Y position
	add     a,e		; @1436 83  add #08
	ld      (ix+#13),a		; @1437 DD7713  store into #4C13 (?)
	ld      a,(red_x)		; @143A 3A014D  load A with red ghost X position
	cpl		; @143D 2F  invert
	add     a,d		; @143E 82  add #07
	ld      (ix+#12),a		; @143F DD7712  store into #4C12 (?)
	ld      a,(pink_y)		; @1442 3A024D  load A with pink ghost Y position
	add     a,e		; @1445 83  add #08
	ld      (ix+#15),a		; @1446 DD7715  store into #4C15 (?)
	ld      a,(pink_x)		; @1449 3A034D  load A with pink ghost X position
	cpl		; @144C 2F  invert
	add     a,d		; @144D 82  add #07
	ld      (ix+#14),a		; @144E DD7714  store into #4C14 (?)
	ld      a,(blue_y)		; @1451 3A044D  load A with inky Y position
	add     a,e		; @1454 83  add #08
	ld      (ix+#17),a		; @1455 DD7717  store into #4C17 (?)
	ld      a,(blue_x)		; @1458 3A054D  load A with inky X position
	cpl		; @145B 2F  invert
	add     a,c		; @145C 81  add #08
	ld      (ix+#16),a		; @145D DD7716  store into #4C16 (?)
	ld      a,(orange_y)		; @1460 3A064D  load A with orange ghost Y position
	add     a,e		; @1463 83  add #08
	ld      (ix+#19),a		; @1464 DD7719  store into #4C19 (?)
	ld      a,(orange_x)		; @1467 3A074D  load A with orange ghost X position
	cpl		; @146A 2F  invert
	add     a,c		; @146B 81  add #08
	ld      (ix+#18),a		; @146C DD7718  store into #4C18 (?)
	ld      a,(pac_y)		; @146F 3A084D  load A with pacman Y position
	add     a,e		; @1472 83  add #08
	ld      (ix+#1b),a		; @1473 DD771B  store into #4C1B (?)
	ld      a,(pac_x)		; @1476 3A094D  load A with pacman X position
	cpl		; @1479 2F  invert
	add     a,c		; @147A 81  add #08
	ld      (ix+#1a),a		; @147B DD771A  store into #4C1A (?)
	ld      a,(fruit_pos_lo)		; @147E 3AD24D  load A with fruit Y position
	add     a,e		; @1481 83  add #08
	ld      (ix+#1d),a		; @1482 DD771D  store into #4C1D (?)
	ld      a,(fruit_pos_hi)		; @1485 3AD34D  load A with fruit X position
	cpl		; @1488 2F  invert
	add     a,c		; @1489 81  add #08
	ld      (ix+#1c),a		; @148A DD771C  store into #4C1C (?)
	jp      j_14fe		; @148D C3FE14  jump ahead

; called from #019E during core game loop
; display the sprites in the intro and game and cutscenes

j_1490:
	ld      a,(dip_cocktail)		; @1490 3A724E  load A with cocktail mode
	ld      b,a		; @1493 47  store into B
	ld      a,(player_number)		; @1494 3A094E  load A with player number
	and     b		; @1497 A0  is this player 2 and cocktail mode ?
	ret     nz		; @1498 C0  yes, return

	ld      b,a		; @1499 47  B := #00
	ld      e,#09		; @149A 1E09  E := #09
	ld      c,#07		; @149C 0E07  C := #07
	ld      d,#06		; @149E 1606  D := #06
	ld ix,spr_unk_4c00		; @14A0 DD21004C  load IX with starting address of sprite values

	ld      a,(red_y)		; @14A4 3A004D  load A with red ghost Y position
	cpl		; @14A7 2F  invert A
	add     a,e		; @14A8 83  Add #09
	ld      (ix+#13),a		; @14A9 DD7713  store into #4C13 (?)

	ld      a,(red_x)		; @14AC 3A014D  load A with red ghost X position
	add     a,d		; @14AF 82  add #06
	ld      (ix+#12),a		; @14B0 DD7712  store into #4C12 (?)

	ld      a,(pink_y)		; @14B3 3A024D  load A with pink ghost Y position
	cpl		; @14B6 2F  invert
	add     a,e		; @14B7 83  add #09
	ld      (ix+#15),a		; @14B8 DD7715  store into #4C15 (?)

	ld      a,(pink_x)		; @14BB 3A034D  load A with pink ghost X position
	add     a,d		; @14BE 82  add #06
	ld      (ix+#14),a		; @14BF DD7714  store into #4C14 (?)

	ld      a,(blue_y)		; @14C2 3A044D  load A with inky Y position
	cpl		; @14C5 2F  invert
	add     a,e		; @14C6 83  add #06
	ld      (ix+#17),a		; @14C7 DD7717  store into #4C17 (?)

	ld      a,(blue_x)		; @14CA 3A054D  load A with inky X position
	add     a,c		; @14CD 81  add #07
	ld      (ix+#16),a		; @14CE DD7716  store into #4C16 (?)

	ld      a,(orange_y)		; @14D1 3A064D  load A with orange ghost Y position
	cpl		; @14D4 2F  invert
	add     a,e		; @14D5 83  add #09
	ld      (ix+#19),a		; @14D6 DD7719  store into #4C19 (?)

	ld      a,(orange_x)		; @14D9 3A074D  load A with orange ghost X position
	add     a,c		; @14DC 81  add #07
	ld      (ix+#18),a		; @14DD DD7718  store into #4C18 (?)

	ld      a,(pac_y)		; @14E0 3A084D  load A with pacman Y position
	cpl		; @14E3 2F  invert
	add     a,e		; @14E4 83  add #09
	ld      (ix+#1b),a		; @14E5 DD771B  store into #4C1B (?)

	ld      a,(pac_x)		; @14E8 3A094D  load A with pacman X position
	add     a,c		; @14EB 81  add #07
	ld      (ix+#1a),a		; @14EC DD771A  store into #4C1A (?)

	ld      a,(fruit_pos_lo)		; @14EF 3AD24D  load A with fruit Y position
	cpl		; @14F2 2F  invert
	add     a,e		; @14F3 83  add #09
	ld      (ix+#1d),a		; @14F4 DD771D  store into #4C1D (?)

	ld      a,(fruit_pos_hi)		; @14F7 3AD34D  load A with fruit X position
	add     a,c		; @14FA 81  add #07
	ld      (ix+#1c),a		; @14FB DD771C  store into #4C1C (?)

; also arrive here if player 2 and cocktail mode from #148D

j_14fe:
	ld      a,(pac_death_anim)		; @14FE 3AA54D  load A with pacman dead animation state (0 if not dead)
	and     a		; @1501 A7  is pacman dead ?
	jp      nz,j_154b		; @1502 C24B15  yes, jump ahead

	ld      a,(ghosts_killed_pending)		; @1505 3AA44D  no, load A with # of ghost killed but no collision for yet
	and     a		; @1508 A7  are we currently eating a ghost ?
	jp      nz,j_15b4		; @1509 C2B415  yes, jump ahead

	ld      hl,#151c		; @150C 211C15  no, load HL with return address
	push    hl		; @150F E5  push return address to stack so RET comes back to #151C

	ld	a,(pac_dir)		; @1510 3A304D  load A with pacman orientation
	rst	#20		; @1513 E7  jump based on which way pac man is facing - for drawing sprite frames to the screen

	db	#8C,#16	; @1514 8C16  #168C	; right
	db	#B1,#16	; @1516 B116  #16B1	; down
	db	#D6,#16	; @1518 D616  #16D6	; left
	db	#F7,#16	; @151A F716  #16F7	; up

	ld	a,b		; @151C 78  load A with B which was created earlier to indicate 2 player and cocktail
	and	a		; @151D A7  is this player 2 and cocktail mode ?
	jr      z,j_154b		; @151E 282B  no, skip ahead

	ld      c,#C0		; @1520 0EC0  yes, C := C0
	ld      a,(spr_pac_code)		; @1522 3A0A4C  load A with mspac sprite number
	ld      d,a		; @1525 57  copy into D
	and     c		; @1526 A1  apply mask of #1100 0000 = C0
	jr      nz,j_152e		; @1527 2005  not zero, skip ahead

	ld      a,d		; @1529 7A  zero, load A with original value
	or      c		; @152A B1  turn on bits 7 and 6
	jp      j_1548		; @152B C34815  skip ahead

j_152e:
	ld      a,(pac_dir)		; @152E 3A304D  load A with pacman orientation
	cp      #02		; @1531 FE02  pacman facing left ?
	jr      nz,j_153e		; @1533 2009  no, skip ahead

	bit     7,d		; @1535 CB7A  yes, turn on bit 7 of D
	jr      z,j_154b		; @1537 2812  if zero, skip ahead

	ld      a,d		; @1539 7A  else A := D
	xor     c		; @153A A9  flip bits 6 and 7
	jp      j_1548		; @153B C34815  skip ahead

j_153e:
	cp      #03		; @153E FE03  pacman facing up ?
	jr      nz,j_154b		; @1540 2009  no, skip ahead

	bit     6,d		; @1542 CB72  yes, turn on bit 6 of D
	jr      z,j_154b		; @1544 2805  if zero, skip ahead

	ld      a,d		; @1546 7A  else A := D
	xor     c		; @1547 A9  flip bits 6 and 7

j_1548:
	ld      (spr_pac_code),a		; @1548 320A4C  store result into mspac sprite number

; the next section of code toggles the sprites for the ghosts based on the counter that flips every 8 frames

j_154b:
	ld hl,ghost_anim_phase		; @154B 21C04D  load HL with counter that changes from 0 to 1 and back every 8 frames; used for ghost animations
	ld      d,(hl)		; @154E 56  load D with the counter
	ld      a,#1c		; @154F 3E1C  A := #1C
	add     a,d		; @1551 82  add to counter

; toggle between #1C and #1D (edible ghost sprites) for all ghosts ... those that are not edible are changed again later

	ld      (ix+#02),a		; @1552 DD7702  store into red ghost sprite
	ld      (ix+#04),a		; @1555 DD7704  store into pink ghost sprite
	ld      (ix+#06),a		; @1558 DD7706  store into inky sprite
	ld      (ix+#08),a		; @155B DD7708  store into orange ghost sprite
	ld      c,#20		; @155E 0E20  C := #20

	ld      a,(red_state)		; @1560 3AAC4D  load A with red ghost state
	and     a		; @1563 A7  is red ghost alive ?
	jr      nz,j_156c		; @1564 2006  no, skip next 3 steps

	ld      a,(red_frightened)		; @1566 3AA74D  yes, load A with red ghost blue flag (0=not blue)
	and     a		; @1569 A7  is red ghost blue (edible) ?
	jr      nz,j_1575		; @156A 2009  yes, skip ahead and check next ghost

j_156c:
	ld      a,(red_dir)		; @156C 3A2C4D  no, load A with red ghost orientation
	add     a,a		; @156F 87  A := A * 2
	add     a,d		; @1570 82  A := A + D
	add     a,c		; @1571 81  A := A + #20
	ld      (ix+#02),a		; @1572 DD7702  store into red ghost sprite

j_1575:
	ld      a,(pink_state)		; @1575 3AAD4D  load A with pink ghost state
	and     a		; @1578 A7  is pink ghost alive ?
	jr      nz,j_1581		; @1579 2006  no, skip next 3 steps

	ld      a,(pink_frightened)		; @157B 3AA84D  load A with pink ghost blue flag
	and     a		; @157E A7  is pink ghost blue (edible) ?
	jr      nz,j_158a		; @157F 2009  yes, skip ahead and check next ghost

j_1581:
	ld      a,(pink_dir)		; @1581 3A2D4D  no, load A with pink ghost orientation
	add     a,a		; @1584 87  A := A * 2
	add     a,d		; @1585 82  A := A + D
	add     a,c		; @1586 81  A := A + #20
	ld      (ix+#04),a		; @1587 DD7704  store into pink ghost sprite

j_158a:
	ld      a,(blue_state)		; @158A 3AAE4D  load A with inky state
	and     a		; @158D A7  is inky alive ?
	jr      nz,j_1596		; @158E 2006  no, skip next 3 steps

	ld      a,(blue_frightened)		; @1590 3AA94D  load A with inky blue flag
	and     a		; @1593 A7  is inky edible ?
	jr      nz,j_159f		; @1594 2009  yes, skip ahead and check next ghost

j_1596:
	ld      a,(blue_dir)		; @1596 3A2E4D  no, load A with inky orientation
	add     a,a		; @1599 87  A := A * 2
	add     a,d		; @159A 82  A := A + D
	add     a,c		; @159B 81  A := A + #20
	ld      (ix+#06),a		; @159C DD7706  store into inky sprite

j_159f:
	ld      a,(orange_state)		; @159F 3AAF4D  load A with orange ghost state
	and     a		; @15A2 A7  is orange ghost alive ?
	jr      nz,j_15ab		; @15A3 2006  no, skip next 3 steps

	ld      a,(orange_frightened)		; @15A5 3AAA4D  load A with orange ghost blue flag
	and     a		; @15A8 A7  is orange ghost blue (edible) ?
	jr      nz,j_15b4		; @15A9 2009  yes, skip ahead

j_15ab:
	ld      a,(orange_dir)		; @15AB 3A2F4D  load A with orange ghost orienation
	add     a,a		; @15AE 87  A = A * 2
	add     a,d		; @15AF 82  A = A + D
	add     a,c		; @15B0 81  A = A + #20
	ld      (ix+#08),a		; @15B1 DD7708  store into orange ghost sprite

j_15b4:
	call    j_15e6		; @15B4 CDE615  check for and handle big pac-man sprites in 1st cutscene (pac-man only)
	call    j_162d		; @15B7 CD2D16  check for and handle sprites in 2nd cutscene (pac-man only)
	call    j_1652		; @15BA CD5216  check for and handle sprites in 3rd cutscene (pac-man only)
	ld      a,b		; @15BD 78  A := B
	and     a		; @15BE A7  is this player 2 and cocktail mode ?
	ret     z		; @15BF C8  no, return

; 2 player and cocktail

	ld      c,#C0		; @15C0 0EC0  C := C0 (binary 1100 0000)

	ld      a,(spr_red_code)		; @15C2 3A024C  load A with red ghost sprite
	or      c		; @15C5 B1  make upside down
	ld      (spr_red_code),a		; @15C6 32024C  store

	ld      a,(spr_pink_code)		; @15C9 3A044C  load A with pink ghost sprite
	or      c		; @15CC B1  make upside down
	ld      (spr_pink_code),a		; @15CD 32044C  store

	ld      a,(spr_blue_code)		; @15D0 3A064C  load A with inky sprite
	or      c		; @15D3 B1  make upside down
	ld      (spr_blue_code),a		; @15D4 32064C  store

	ld      a,(spr_orange_code)		; @15D7 3A084C  load A with orange ghost sprite
	or      c		; @15DA B1  make upside down
	ld      (spr_orange_code),a		; @15DB 32084C  store

	ld      a,(spr_fruit_code)		; @15DE 3A0C4C  load A with pacman sprite
	or      c		; @15E1 B1  make upside down
	ld      (spr_fruit_code),a		; @15E2 320C4C  store
	ret		; @15E5 C9  return

; called from #15B4

j_15e6:
	ld      a,(cutscene1_state)		; @15E6 3A064E  load A with state in first cutscene
	sub     #05		; @15E9 D605  is this cutscene state <= 5 ?
	ret     c		; @15EB D8  yes, return

; pac-man only, not used in ms. pac
; arrive here when the big pac-man needs to be animated in the 1st cutscene

	ld      a,(pac_x)		; @15EC 3A094D
	and     #0f		; @15EF E60F
	cp      #0c		; @15F1 FE0C
	jr      c,j_15f9		; @15F3 3804  (4)

	ld      d,#18		; @15F5 1618
	jr      j_160b		; @15F7 1812  (18)

j_15f9:
	cp      #08		; @15F9 FE08
	jr      c,j_1601		; @15FB 3804  (4)

	ld      d,#14		; @15FD 1614
	jr      j_160b		; @15FF 180A  (10)

j_1601:
	cp      #04		; @1601 FE04
	jr      c,j_1609		; @1603 3804  (4)

	ld      d,#10		; @1605 1610
	jr      j_160b		; @1607 1802  (2)

j_1609:
	ld      d,#14		; @1609 1614
j_160b:
	ld      (ix+#04),d		; @160B DD7204
	inc     d		; @160E 14
	ld      (ix+#06),d		; @160F DD7206
	inc     d		; @1612 14
	ld      (ix+#08),d		; @1613 DD7208
	inc     d		; @1616 14
	ld      (ix+#0c),d		; @1617 DD720C
	ld      (ix+#0a),#3f		; @161A DD360A3F
	ld      d,#16		; @161E 1616
	ld      (ix+#05),d		; @1620 DD7205
	ld      (ix+#07),d		; @1623 DD7207
	ld      (ix+#09),d		; @1626 DD7209
	ld      (ix+#0d),d		; @1629 DD720D
	ret		; @162C C9

; called from #15B7

j_162d:
	ld      a,(cutscene2_state)		; @162D 3A074E  load A with state in second cutscene
	and     a		; @1630 A7  == #00 ?
	ret     z		; @1631 C8  yes, return

; pac-man only, not used in ms. pac
; arrive here during 2nd cutscene

	ld      d,a		; @1632 57
	ld      a,(pac_tile_x)		; @1633 3A3A4D
	sub     #3d		; @1636 D63D
	jr      nz,j_163e		; @1638 2004

	ld      (ix+#0b),#00		; @163A DD360B00
j_163e:
	ld      a,d		; @163E 7A
	cp      #0a		; @163F FE0A
	ret     c		; @1641 D8

	ld      (ix+#02),#32		; @1642 DD360232
	ld      (ix+#03),#1d		; @1646 DD36031D
	cp      #0c		; @164A FE0C
	ret     c		; @164C D8

	ld      (ix+#02),#33		; @164D DD360233
	ret		; @1651 C9

; called from #15BA

j_1652:
	ld      a,(cutscene3_state)		; @1652 3A084E  load A with state in third cutscene
	and     a		; @1655 A7  == #00 ?
	ret     z		; @1656 C8  yes, return

; pac-man only, not used is ms. pac
; arrive here during 3rd cutscene

	ld      d,a		; @1657 57
	ld      a,(pac_tile_x)		; @1658 3A3A4D
	sub     #3d		; @165B D63D
	jr      nz,j_1663		; @165D 2004  (4)

	ld      (ix+#0b),#00		; @165F DD360B00
j_1663:
	ld      a,d		; @1663 7A
	cp      #01		; @1664 FE01
	ret     c		; @1666 D8

	ld      a,(ghost_anim_phase)		; @1667 3AC04D
	ld      e,#08		; @166A 1E08
	add     a,e		; @166C 83
	ld      (ix+#02),a		; @166D DD7702
	ld      a,d		; @1670 7A
	cp      #03		; @1671 FE03
	ret     c		; @1673 D8

	ld      a,(red_x)		; @1674 3A014D
	and     #08		; @1677 E608
	rrca		; @1679 0F
	rrca		; @167A 0F
	rrca		; @167B 0F
	ld      e,#0a		; @167C 1E0A
	add     a,e		; @167E 83
	ld      (ix+#0c),a		; @167F DD770C
	inc     a		; @1682 3C
	inc     a		; @1683 3C
	ld      (ix+#02),a		; @1684 DD7702
	ld      (ix+#0d),#1e		; @1687 DD360D1E
	ret		; @168B C9


; arrive here when pac man is facing right from #1513

; MOVING EAST
	jp      j_869c		; @168C C39C86  jump to ms. pacman patch to animate ms pac
	ret		; @168F C9

	db	#07	; @1690 07  junk from pac-man    
	cp      #06		; @1691 FE06
	jr      c,j_169a		; @1693 3805
	ld      (ix+#0a),#30		; @1695 DD360A30
	ret		; @1699 C9

j_169a:
	cp      #04		; @169A FE04
	jr      c,j_16a3		; @169C 3805
	ld      (ix+#0a),#2e		; @169E DD360A2E
	ret		; @16A2 C9

j_16a3:
	cp      #02		; @16A3 FE02
	jr      c,j_16ac		; @16A5 3805
	ld      (ix+#0a),#2c		; @16A7 DD360A2C
	ret		; @16AB C9

j_16ac:
	ld      (ix+#0a),#2e		; @16AC DD360A2E
	ret		; @16B0 C9

; arrive here when pac man is facing down from #1513
; MOVING SOUTH
	jp      j_86b1		; @16B1 C3B186  jump to ms. pacman patch to animate ms pac
	ret		; @16B4 C9

	db	#07	; @16B5 07  junk from pac-man    
	cp      #06		; @16B6 FE06
	jr      c,j_16bf		; @16B8 3805
	ld      (ix+#0a),#2f		; @16BA DD360A2F
	ret		; @16BE C9

j_16bf:
	cp      #04		; @16BF FE04
	jr      c,j_16c8		; @16C1 3805
	ld      (ix+#0a),#2d		; @16C3 DD360A2D
	ret		; @16C7 C9

j_16c8:
	cp      #02		; @16C8 FE02
	jr      c,j_16d1		; @16CA 3805
	ld      (ix+#0a),#2f		; @16CC DD360A2F
	ret		; @16D0 C9

j_16d1:
	ld      (ix+#0a),#30		; @16D1 DD360A30
	ret		; @16D5 C9

; arrive here when pac man is facing left from #1513
; MOVING WEST
	ld      a,(pac_x)		; @16D6 3A094D
	jp      j_86c5		; @16D9 C3C586  jump to ms. pacman patch to animate ms pac
	ret		; @16DC C9

	jr      c,j_16e7		; @16DD 3808
j_16df:
	ld      e,#2e		; @16DF 1E2E
j_16e1:
	set     7,e		; @16E1 CBFB
	ld      (ix+#0a),e		; @16E3 DD730A
	ret		; @16E6 C9

j_16e7:
	cp      #04		; @16E7 FE04
	jr      c,j_16ef		; @16E9 3804
	ld      e,#2c		; @16EB 1E2C
	jr      j_16e1		; @16ED 18F2
j_16ef:
	cp      #02		; @16EF FE02

	jr      nc,j_16df		; @16F1 30EC
	ld      e,#30		; @16F3 1E30
	jr      j_16e1		; @16F5 18EA

; arrive here when pac man is facing up from #1513
; MOVING NORTH
	ld      a,(pac_y)		; @16F7 3A084D
	jp      j_86d9		; @16FA C3D986  jump to ms. pacman patch to animate ms pac

	ret		; @16FD C9

	jr      c,j_1705		; @16FE 3805
	ld      (ix+#0a),#30		; @1700 DD360A30
	ret		; @1704 C9

j_1705:
	cp      #04		; @1705 FE04
	jr      c,j_1711		; @1707 3808  (8)
	ld      e,#2f		; @1709 1E2F
j_170b:
	set     6,e		; @170B CBF3
	ld      (ix+#0a),e		; @170D DD730A
	ret		; @1710 C9

j_1711:
	cp      #02		; @1711 FE02
	jr      c,j_1719		; @1713 3804  (4)

	ld      e,#2d		; @1715 1E2D
	jr      j_170b		; @1717 18F2  (-14)

j_1719:
	ld      e,#2f		; @1719 1E2F
	jr      j_170b		; @171B 18EE  (-18)


	;; normal ghost collision detect
	;; called from #1039

j_171d:
	ld      b,#04		; @171D 0604  B := #04
	ld      de,(pac_tile_y)		; @171F ED5B394D  load DE with pacman Y and X tile positions
	ld      a,(orange_state)		; @1723 3AAF4D  load A with orange ghost state
	and     a		; @1726 A7  is orange ghost alive ?
	jr      nz,j_1732		; @1727 2009  no, skip ahead for next ghost

	ld      hl,(orange_tile_y2)		; @1729 2A374D  else load HL with orange ghost Y and X tile positions
	and     a		; @172C A7  clear the carry flag
	sbc     hl,de		; @172D ED52  is pacman colliding with orange ghost?
	jp      z,j_1763		; @172F CA6317  yes, jump ahead and continue checks

j_1732:
	dec     b		; @1732 05  B := #03
	ld      a,(blue_state)		; @1733 3AAE4D  load A with blue ghost (inky) state
	and     a		; @1736 A7  is inky alive ?
	jr      nz,j_1742		; @1737 2009  no, skip ahead for next ghost

	ld      hl,(blue_tile_y2)		; @1739 2A354D  else load HL with inky's Y and X tile positions
	and     a		; @173C A7  clear carry flag
	sbc     hl,de		; @173D ED52  is pacman colliding with inky ?
	jp      z,j_1763		; @173F CA6317  yes, jump ahead and continue checks

j_1742:
	dec     b		; @1742 05  B := #02
	ld      a,(pink_state)		; @1743 3AAD4D  load A with pink ghost state
	and     a		; @1746 A7  is pink ghost alive ?
	jr      nz,j_1752		; @1747 2009  no, skip ahead

	ld      hl,(pink_tile_y2)		; @1749 2A334D  else load HL with pink ghost Y and X tile positions
	and     a		; @174C A7  clear carry flag
	sbc     hl,de		; @174D ED52  is pacman colliding with pink ghost?
	jp      z,j_1763		; @174F CA6317  yes, jump ahead and continue checks

j_1752:
	dec     b		; @1752 05  B := #01
	ld      a,(red_state)		; @1753 3AAC4D  load A with red ghost state
	and     a		; @1756 A7  is red ghost alive ?
	jr      nz,j_1762		; @1757 2009  no, skip ahead

	ld      hl,(red_tile_y2)		; @1759 2A314D  else load HL with red ghost Y and X tile positions
	and     a		; @175C A7  clear carry flag
	sbc     hl,de		; @175D ED52  is pacman colliding with red ghost?
	jp      z,j_1763		; @175F CA6317  yes, jump ahead and continue checks

j_1762:
	dec     b		; @1762 05  B := #00 , no collision occurred

j_1763:
	ld      a,b		; @1763 78  load A with ghost # that collided with pacman
	ld      (ghosts_killed_pending),a		; @1764 32A44D  store

	; invincibility check ; HACK3
	; 1764 c3b01f    jp      #1fb0
	;

	ld      (pac_death_anim),a		; @1767 32A54D  store into pacman dead animation state (0 if not dead)
	and     a		; @176A A7  was there a collision?
	ret     z		; @176B C8  no, return

	ld hl,power_pill_active		; @176C 21A64D  else load HL with start of ghost flags
	ld      e,a		; @176F 5F  load E with ghost # that collided
	ld      d,#00		; @1770 1600  D := #00
	add     hl,de		; @1772 19  add.  HL now has the ghost blue flag (0 if not blue)
	ld      a,(hl)		; @1773 7E  load A with the ghost's status
	and     a		; @1774 A7  is this ghost blue (eatable) ?
	ret     z		; @1775 C8  no, return

; else arrive here when eating a blue ghost

	xor     a		; @1776 AF  A := #00
	ld      (pac_death_anim),a		; @1777 32A54D  store into pacman dead animation state (0 if not dead)
	ld hl,ghosts_killed_count		; @177A 21D04D  load HL with # of ghosts killed
	inc     (hl)		; @177D 34  increase
	ld      b,(hl)		; @177E 46  load B with this # of ghosts killed
	inc     b		; @177F 04  increase by one, used for scoring routine
	call    j_2a5a		; @1780 CD5A2A  update score.  B has code for items scored. draws score on screen, checks for high score and extra lives

	ld hl,CH3_E_NUM		; @1783 21BC4E  load HL with sound channel 3
	set	3,(hl)		; @1786 CBDE  set sound for eating a ghost
	ret		; @1788 C9  return

	;; end normal ghost collision detect


	;; blue (edible) ghost collision detect

; called from #103C

j_1789:
	ld      a,(ghosts_killed_pending)		; @1789 3AA44D  load A with ghost # that collided with pacman (0=no collision)
	and     a		; @178C A7  was there a collision ?
	ret     nz		; @178D C0  yes, return

	ld      a,(power_pill_active)		; @178E 3AA64D  no, load A with power pill status
	and     a		; @1791 A7  is a power pill active ?
	ret     z		; @1792 C8  no, return

	ld      c,#04		; @1793 0E04  else C := #04
	ld      b,#04		; @1795 0604  B := #04
	ld ix,pac_y		; @1797 DD21084D  load IX with pacman Y position
	ld      a,(orange_state)		; @179B 3AAF4D  load A with orange ghost state
	and     a		; @179E A7  is ghost alive ?
	jr      nz,j_17b4		; @179F 2013  no, skip ahead for next ghost

	ld      a,(orange_y)		; @17A1 3A064D  yes, load A with orange ghost Y position
	sub     (ix+#00)		; @17A4 DD9600  subtract pacman's Y position
	cp      c		; @17A7 B9  <= #04 ?
	jr      nc,j_17b4		; @17A8 300A  no, skip ahead for next ghost

	ld      a,(orange_x)		; @17AA 3A074D  yes, load A with orange ghost X position
	sub     (ix+#01)		; @17AD DD9601  subtract pacman's X position
	cp      c		; @17B0 B9  <= #04 ?
	jp      c,j_1763		; @17B1 DA6317  yes, jump back and set collision

j_17b4:
	dec     b		; @17B4 05  B := #03
	ld      a,(blue_state)		; @17B5 3AAE4D  load A with blue ghost (inky) state
	and     a		; @17B8 A7  is inky alive ?
	jr      nz,j_17ce		; @17B9 2013  no, skip ahead for next ghost

	ld      a,(blue_y)		; @17BB 3A044D  load A with inky's Y position
	sub     (ix+#00)		; @17BE DD9600  subtract pacman's Y position
	cp      c		; @17C1 B9  <= #04 ?
	jr      nc,j_17ce		; @17C2 300A  no, skip ahead for next ghost

	ld      a,(blue_x)		; @17C4 3A054D  yes, load A with inky's X position
	sub     (ix+#01)		; @17C7 DD9601  subtract pacman's X position
	cp      c		; @17CA B9  <= #04 ?
	jp      c,j_1763		; @17CB DA6317  yes, jump back and set collision

j_17ce:
	dec     b		; @17CE 05  B := #02
	ld      a,(pink_state)		; @17CF 3AAD4D  load A with pink ghost state
	and     a		; @17D2 A7  is pink ghost alive ?
	jr      nz,j_17e8		; @17D3 2013  no, skip ahead for next ghost

	ld      a,(pink_y)		; @17D5 3A024D  load A with pink ghost Y position
	sub     (ix+#00)		; @17D8 DD9600  subtract pacman's Y position
	cp      c		; @17DB B9  <= #04 ?
	jr      nc,j_17e8		; @17DC 300A  no, skip ahead for next ghost

	ld      a,(pink_x)		; @17DE 3A034D  yes, load A with pink ghost X position
	sub     (ix+#01)		; @17E1 DD9601  subtract pacman's X position
	cp      c		; @17E4 B9  <= #04 ?
	jp      c,j_1763		; @17E5 DA6317  yes, jump back and set collision

j_17e8:
	dec     b		; @17E8 05  B := #01
	ld      a,(red_state)		; @17E9 3AAC4D  load A with red ghost state
	and     a		; @17EC A7  is red ghost alive ?
	jr      nz,j_1802		; @17ED 2013  no, skip ahead

	ld      a,(red_y)		; @17EF 3A004D  yes, load A with red ghost Y position
	sub     (ix+#00)		; @17F2 DD9600  subtract pacman's Y position
	cp      c		; @17F5 B9  <= #04 ?
	jr      nc,j_1802		; @17F6 300A  no, skip ahead

	ld      a,(red_x)		; @17F8 3A014D  yes, load A with red ghost X position
	sub     (ix+#01)		; @17FB DD9601  subtract pacman's X position
	cp      c		; @17FE B9  <= #04 ?
	jp      c,j_1763		; @17FF DA6317  yes, jump back and set collision

j_1802:
	dec     b		; @1802 05  else no collision ; B := #00
	jp      j_1763		; @1803 C36317  jump back and set collision

	; end of blue ghost collision detection


; called from #1044

j_1806:
	ld hl,pac_move_delay		; @1806 219D4D  load HL with address of delay to update pacman movement
	ld      a,#FF		; @1809 3EFF  A := FF = code for no delay


	; Hack code:
	; 1809  c3c01f	jp	#1fc0		; Intermission fast fix ; HACK8 (1 of 3)
	; 1809  c3d01f	jp	#1fd0		; P1P2 cheat  ; HACK3
	; 1809  c34c0f	jp	#0f4c		; pause cheat ; HACK5
	; end hack code


	cp      (hl)		; @180B BE  is pacman slow due to the eating of a pill ?

	; Hack code
	; set 0xbe to 0x01 for fast cheat.	; HACK2 (1 of 2)
	; 180b  01
	;		i'm not entirely sure how this works.  it mangles
	;		the opcodes starting at 180b to be:
	;
	;	    080b 01ca11    ld      bc,11cah
	;	    080e 1835      jr      1845h
	;	    0810 c9        ret     
	;
	;	which makes little to no sense, but it works


	; end hack code

	jp      z,j_1811		; @180C CA1118  no, skip ahead
	dec     (hl)		; @180F 35  yes, decrement the counter to delay pacman movement
	ret		; @1810 C9  return without movement

j_1811:
	ld      a,(power_pill_active)		; @1811 3AA64D  load A with power pill effect (1=active, 0=no effect)
	and     a		; @1814 A7  is a power pill active ?
	jp      z,j_182f		; @1815 CA2F18  no, skip ahead

; movement when power pill active

	ld      hl,(#4d4c)		; @1818 2A4C4D  yes, load HL with speed bit patterns for pacman in power pill state (low bytes)
	add     hl,hl		; @181B 29  double
	ld      (#4d4c),hl		; @181C 224C4D  store result
	ld      hl,(speed_pat_pac_energized)		; @181F 2A4A4D  load HL with speed bit patterns for pacman in power pill state (high bytes)
	adc     hl,hl		; @1822 ED6A  double, with the carry = we have doubled the speed
	ld      (speed_pat_pac_energized),hl		; @1824 224A4D  store result. have we reached the threshold ?
	ret     nc		; @1827 D0  no, return

	ld      hl,#4d4c		; @1828 214C4D  yes, load HL with speed bit patterns for pacman in power pill state (low bytes)
	inc     (hl)		; @182B 34  increase
	jp      j_1843		; @182C C34318  skip ahead to move pacman

; movement when power pill not active

j_182f:
	ld      hl,(#4d48)		; @182F 2A484D  load HL with speed for pacman in normal state (low bytes)
	add     hl,hl		; @1832 29  double
	ld      (#4d48),hl		; @1833 22484D  store result
	ld      hl,(speed_pat_pac_normal)		; @1836 2A464D  load HL with speed for pacman in normal state (high bytes)
	adc     hl,hl		; @1839 ED6A  double with carry
	ld      (speed_pat_pac_normal),hl		; @183B 22464D  store result.  is it time for pacman to move?
	ret     nc		; @183E D0  no, return.  pacman will be idle this time.

	ld      hl,#4d48		; @183F 21484D  yes, load HL with speed for pacman in normal state (low byte)
	inc     (hl)		; @1842 34  increase by one

; all pacman movement

j_1843:
	ld      a,(dots_eaten)		; @1843 3A0E4E  load A with number of pills eaten in this level
	ld      (pills_since_pac_move),a		; @1846 329E4D  store into counter related to number of pills eaten before last pacman move
	ld      a,(dip_cocktail)		; @1849 3A724E  load A with cocktail mode (0=no, 1=yes)
	ld      c,a		; @184C 4F  copy to C
	ld      a,(player_number)		; @184D 3A094E  load A with current player number:  0=P1, 1=P2
	and     c		; @1850 A1  mix together
	ld      c,a		; @1851 4F  copy to C.  This is checked at #1879 and #18BB
	ld hl,pac_tile_x		; @1852 213A4D  load HL with address of pacman X tile position 
	ld      a,(hl)		; @1855 7E  load A with pacman X tile position
	ld      b,#21		; @1856 0621  B := #21
	sub     b		; @1858 90  subtract.  is pacman past the right edge of the screen?
	jr      c,j_1864		; @1859 3809  yes, skip ahead to handle tunnel movement

	ld      a,(hl)		; @185B 7E  load A with pacman X tile position
	ld      b,#3b		; @185C 063B  B := #3B
	sub     b		; @185E 90  subtract. is pacman pas the left edge of the screen?
	jr      nc,j_1864		; @185F 3003  yes, skip ahead to handle tunnel movement

	jp      j_18ab		; @1861 C3AB18  no tunnel movement.  jump ahead to handle normal movement

; this sub is only called while player is in a tunnel

j_1864:
	ld      a,#01		; @1864 3E01  A := #01
	ld      (pac_entering_tunnel),a		; @1866 32BF4D  store into pacman about to enter a tunnel flag
	ld      a,(game_mode)		; @1869 3A004E  load A with game state
	cp      #01		; @186C FE01  are we in demo mode ?
	jp      z,j_1a19		; @186E CA191A  yes, skip ahead [ zero this instruction to NOP's to enable playing in demo mode (part 1/2) ] 

	ld      a,(level_state)		; @1871 3A044E  else load A with subroutine #
	cp      #10		; @1874 FE10  <=#10 ?
	jp      nc,j_1a19		; @1876 D2191A  no, skip ahead

	ld      a,c		; @1879 79  load A with mix of cocktail mode and player number, created above at #1849-#1851
	and     a		; @187A A7  is this player 2 and cocktail mode ?
	jr      z,j_1883		; @187B 2806  No, skip ahead and check IN0

; check player 1 or player 2 input
; the program jumps to one of two locations to check
; player input based on whether it's player 1 or player 2 currently playing, and cocktail mode is enabled
; if player 2 is playing and cocktail mode enabled, 187b will fall through to 187d.
; if player 1 is playing or cocktail mode is disabled, 187b will jump to 1883 

	ld      a,(IN1)		; @187D 3A4050  else load A with IN1 (player 2)
	jp      j_1886		; @1880 C38618  skip ahead

j_1883:
	ld      a,(IN0)		; @1883 3A0050  load A with IN0 (player 1)

j_1886:
	bit     1,a		; @1886 CB4F  is joystick pushed to left?
	jp      nz,j_1899		; @1888 C29918  no, skip ahead

	ld      hl,(#3303)		; @188B 2A0333  yes, load HL with move left tile change
	ld      a,#02		; @188E 3E02  A := #02
	ld      (pac_dir),a		; @1890 32304D  store into pac orientation
	ld      (pac_tile_dy),hl		; @1893 221C4D  store HL into pacman Y tile changes (A)
	jp      j_1950		; @1896 C35019  jump back to program

j_1899:
	bit     2,a		; @1899 CB57  is joystick pushed to right?
	jp      nz,j_1950		; @189B C25019  no, skip ahead

	ld      hl,(#32ff)		; @189E 2AFF32  load HL with move right tile change
	xor     a		; @18A1 AF  A := #00
	ld      (pac_dir),a		; @18A2 32304D  store into pac orientation
	ld      (pac_tile_dy),hl		; @18A5 221C4D  store HL into pacman Y tile changes (A)
	jp      j_1950		; @18A8 C35019  jump back to program

; arrive here via #1861, this handles normal (not tunnel) movement

j_18ab:
	ld      a,(game_mode)		; @18AB 3A004E  load A with game state
	cp      #01		; @18AE FE01  are we in demo mode ?
	jp      z,j_1a19		; @18B0 CA191A  yes, skip ahead [ zero this instruction into NOP's to enable playable demo mode, (part 2/2) ]

	ld      a,(level_state)		; @18B3 3A044E  else load A with subroutine #
	cp      #10		; @18B6 FE10  <= #10 ?
	jp      nc,j_1a19		; @18B8 D2191A  no, skip ahead

	ld      a,c		; @18BB 79  A := C
	and     a		; @18BC A7  is this player 2 and cocktail mode ?
	jr      z,j_18c5		; @18BD 2806  yes, skip next 2 steps

; p1/p2 check.  see 187b above for info.

	; p2 movement check

	ld      a,(IN1)		; @18BF 3A4050  load A with IN1
	jp      j_18c8		; @18C2 C3C818  skip next step

	; p1 movement check

j_18c5:
	ld      a,(IN0)		; @18C5 3A0050  load A with IN0

j_18c8:
	bit     1,a		; @18C8 CB4F  joystick pressed left?
	jp      z,j_1ac9		; @18CA CAC91A  yes, jump to process

	bit     2,a		; @18CD CB57  joystick pressed right?
	jp      z,j_1ad9		; @18CF CAD91A  yes, jump to process

	bit     0,a		; @18D2 CB47  joystick pressed up?
	jp      z,j_1ae8		; @18D4 CAE81A  yes, jump to process

	bit     3,a		; @18D7 CB5F  joystick pressed down?
	jp      z,j_1af8		; @18D9 CAF81A  yes, jump to process

	; no change in movement - joystick is centered

	ld      hl,(pac_tile_dy)		; @18DC 2A1C4D  load HL with pacman tile change
	ld      (pac_wanted_tile_dy),hl		; @18DF 22264D  store into wanted pacman tile changes
	ld      b,#01		; @18E2 0601  B := #01 - this codes that the joystick was not moved

	; movement checks return to here

j_18e4:
	ld ix,pac_wanted_tile_dy		; @18E4 DD21264D  load IX with wanted pacman tile changes
	ld iy,pac_tile_y		; @18E8 FD21394D  load IY with pacman tile position
	call    j_200f		; @18EC CD0F20  load A with screen value of position computed in (IX) + (IY)
	and     #C0		; @18EF E6C0  mask bits
	sub     #C0		; @18F1 D6C0  subtract.  is the maze blocking pacman from moving this way?
	jr      nz,j_1940		; @18F3 204B  no, skip ahead

	dec     b		; @18F5 05  yes, was the joystick moved ?
	jp      nz,j_1916		; @18F6 C21619  yes, skip ahead

	ld      a,(pac_dir)		; @18F9 3A304D  no, load A with pacman orientation
	rrca		; @18FC 0F  roll right with carry.  is pacman moving either up or down?
	jp      c,j_190b		; @18FD DA0B19  yes, skip next 5 steps

	ld      a,(pac_x)		; @1900 3A094D  no, load A with pacman X position
	and     #07		; @1903 E607  mask bits, now between 0 and 7
	cp      #04		; @1905 FE04  == #04 ?  (In center of tile ?)
	ret     z		; @1907 C8  yes, return

	jp      j_1940		; @1908 C34019  else skip ahead

j_190b:
	ld      a,(pac_y)		; @190B 3A084D  load A with pacman Y position
	and     #07		; @190E E607  mask bits, now between 0 and 7
	cp      #04		; @1910 FE04  == #04 ? (In center of tile ?)
	ret     z		; @1912 C8  yes, return

	jp      j_1940		; @1913 C34019  no, skip ahead

j_1916:
	ld ix,pac_tile_dy		; @1916 DD211C4D  load IX with pacman Y,X tile changes 
	call    j_200f		; @191A CD0F20  load A with screen value of position computed in (IX) + (IY)
	and     #C0		; @191D E6C0  mask bits
	sub     #C0		; @191F D6C0  subtract.  is the maze blocking pacman from moving this way?
	jr      nz,j_1950		; @1921 202D  no, skip ahead

; code seems to be why pacman turns corners fast.  it gives an extra boost to the new direction

	ld      a,(pac_dir)		; @1923 3A304D  yes, load A with pacman orientation
	rrca		; @1926 0F  roll right with carry.  is pacman moving either up or down ?
	jp      c,j_1935		; @1927 DA3519  yes, skip next 5 steps

	ld      a,(pac_x)		; @192A 3A094D  no, load A with pacman X position
	and     #07		; @192D E607  mask bits, now between 0 and 7
	cp      #04		; @192F FE04  == #04 ? ( In center of tile ? )
	ret     z		; @1931 C8  yes, return

	jp      j_1950		; @1932 C35019  no, skip ahead

j_1935:
	ld      a,(pac_y)		; @1935 3A084D  load A with pacman Y position
	and     #07		; @1938 E607  mask bits, now between 0 and 7
	cp      #04		; @193A FE04  == #04 ( In center of tile?)
	ret     z		; @193C C8  yes, return

	jp      j_1950		; @193D C35019  no, jump ahead

; arrive when changing direction (???)

j_1940:
	ld      hl,(pac_wanted_tile_dy)		; @1940 2A264D  load HL with wanted pacman tile changes
	ld      (pac_tile_dy),hl		; @1943 221C4D  store into pacman tile changes
	dec     b		; @1946 05  was the joystick moved?
	jp      z,j_1950		; @1947 CA5019  no, skip ahead

	ld      a,(pac_wanted_dir)		; @194A 3A3C4D  yes, load A with wanted pacman orientation
	ld      (pac_dir),a		; @194D 32304D  store into pacman orientation

j_1950:
	ld ix,pac_tile_dy		; @1950 DD211C4D  load IX with pacman Y,X tile changes
	ld iy,pac_y		; @1954 FD21084D  load IY with pacman position
	call    j_2000		; @1958 CD0020  HL := (IX) + (IY)
	ld      a,(pac_dir)		; @195B 3A304D  load A with pacman orientation
	rrca		; @195E 0F  roll right, is pacman moving either up or down ?
	jp      c,j_1975		; @195F DA7519  yes, skip ahead

	ld      a,l		; @1962 7D  load A with X position of new location
	and     #07		; @1963 E607  mask bits, now between 0 and 7
	cp      #04		; @1965 FE04  == #04 ( in center of tile ?)
	jp      z,j_1985		; @1967 CA8519  yes, skip ahead

	jp      c,j_1971		; @196A DA7119  was the last comparison less than #04 ?, if yes, skip next 2 steps

; cornering up to the left or up to the right

	dec     l		; @196D 2D  lower the X position
	jp      j_1985		; @196E C38519  skip ahead

; cornering right from down , cornering left from down

j_1971:
	inc     l		; @1971 2C  else increase the X position
	jp      j_1985		; @1972 C38519  skip ahead

; handle up/down movement turns

j_1975:
	ld      a,h		; @1975 7C  load A with Y position of new loctaion
	and     #07		; @1976 E607  mask bits, now between 0 and 7
	cp      #04		; @1978 FE04  == #04 ( in center of tile ?)
	jp      z,j_1985		; @197A CA8519  yes, skip ahead

	jp      c,j_1984		; @197D DA8419  was the last comparison less than #04 ?, if yes, skip next 2 steps

; cornering up from the left side, or down from the left side

	dec     h		; @1980 25  else lower the Y position 
	jp      j_1985		; @1981 C38519  skip ahead

; arrive here when cornering up from the right side
; or when cornering down from the right side

j_1984:
	inc     h		; @1984 24  increase the Y position

; arrive here from several locations
; HL has the expected new position of a sprite

j_1985:
	ld      (pac_y),hl		; @1985 22084D  store the new sprite position into pacman position
	call    j_2018		; @1988 CD1820  convert sprite position into a tile position
	ld      (pac_tile_y),hl		; @198B 22394D  store tile position into pacman's tile position
	ld ix,pac_entering_tunnel		; @198E DD21BF4D  load IX with tunnel indicator address
	ld      a,(ix+#00)		; @1992 DD7E00  load A with tunnel indiacator.  1=pacman in a tunnel
	ld      (ix+#00),#00		; @1995 DD360000  clear the tunnel indicator
	and     a		; @1999 A7  is pacman in a tunnel ?
	ret     nz		; @199A C0  yes, return

; check for items eaten

	ld	a,(fruit_pos_lo)		; @199B 3AD24D  load A with fruit position
	and	a		; @199E A7  == #00 ?
	jr	z,j_19cd		; @199F 282C  yes, skip ahead

	ld	a,(fruit_points)		; @19A1 3AD44D  else load A with entry to fruit points, or 0 if no fruit
	and	a		; @19A4 A7  == #00 ?
	jr	z,j_19cd		; @19A5 2826  yes, skip ahead

; else check for fruit to be eaten

	ld	hl,(pac_y)		; @19A7 2A084D  load HL with pacman Y position
	ld	de,#8094		; @19AA 119480  load DE with #8094 (why?  on jump DE is loaded with new values.  this is junk from pac-man)

; OTTOPATCH
;PATCH TO MAKE THE PACMAN AWARE OF THE CHANGING POSITION OF THE FRUIT
;ORG 19ADH
;JP EATFRUIT
	jp	j_8818		; @19AD C31888  MS Pac-man patch. jump to check for fruit being eaten

	jr	nz,j_19cd		; @19B0 201B  junk from pac-man

; arrive here when fruit is eaten

j_19b2:
	ld	b,#19		; @19B2 0619  else a fruit is eaten.  load B with task #19
	ld	c,a		; @19B4 4F  load C with task from A register
	call	j_0042		; @19B5 CD4200  set task #19 with parameter variable A.  updates score.  B has code for items scored, draw score on screen, check for high score and extra lives
	call	j_1000		; @19B8 CD0010  clear fruit.  clears #4DD4 and returns
	jr	j_19c4		; @19BB 1807  skip ahead.  a fruit has been eaten

; Pac man code:
; 19b8  0e15      ld      c,#15
; 19ba  81        add     a,c
; 19bb  4f        ld      c,a
; 19bc  061c      ld      b,#1c
; end pac-man code


	db	#1C	; @19BD 1C  junk from pac-man
	call	j_0042		; @19BE CD4200  pac-man only
	call	j_1004		; @19C1 CD0410  pac-man only

j_19c4:
	rst	#30		; @19C4 F7  set timed task to clear the fruit score sprite
	db	#54,#05,#00	; @19C5 540500  timer=54, task=5, param=0

	ld hl,CH3_E_NUM		; @19C8 21BC4E  load HL with voice 3 address
	set	2,(hl)		; @19CB CBD6  set up fruit eating sound.

; arrive here when no fruit eaten from fruit eating check subroutine

j_19cd:
	ld	a,#FF		; @19CD 3EFF  load A with FF
	ld	(pac_move_delay),a		; @19CF 329D4D  store into delay to update pacman movement
	ld	hl,(pac_tile_y)		; @19D2 2A394D  load HL with pacman's position
	call	j_0065		; @19D5 CD6500  load HL with pacman's grid position
	ld	a,(hl)		; @19D8 7E  load A with item on grid
	cp	#10		; @19D9 FE10  is a dot being eaten ?
	jr	z,j_19e0		; @19DB 2803  yes, skip ahead

	cp	#14		; @19DD FE14  else is an energizer being eaten?
	ret	nz		; @19DF C0  no, return

; arrive here when a dot or energizer has been eaten
; A has either #10 or #14 loaded

j_19e0:
	ld ix,dots_eaten		; @19E0 DD210E4E  else load number of pills eaten in this level
	inc	(ix+#00)		; @19E4 DD3400  increase
	and	#0F		; @19E7 E60F  mask bits.  If a dot is eaten, A is now #00.  Energizer, A is now #04
	srl	a		; @19E9 CB3F  shift right (div by 2)
	ld	b,#40		; @19EB 0640  load B with #40 (clear graphic)
	ld	(hl),b		; @19ED 70  update maze to clear the dot that has been eaten
	ld	b,#19		; @19EE 0619  load B with #19 for task call below
	ld	c,a		; @19F0 4F  load C with A (either #00 or #02)
	srl	c		; @19F1 CB39  shift right (div by 2).  now C is either #00 or #01
	call	j_0042		; @19F3 CD4200  set task #19 with variable parameter

; task #19 will update score.  B has code for items scored, draw score on screen, check for high score and extra lives

	inc	a		; @19F6 3C  A := A + 1.  A is now either 1 or 3
	cp	#01		; @19F7 FE01  was a dot just eaten?
	jp	z,j_19fd		; @19F9 CAFD19  yes, skip next step

	add  a,a		; @19FC 87  else it was an energizer. double A to 6

j_19fd:
	ld	(pac_move_delay),a		; @19FD 329D4D  store A to delay update pacman movement
	call	j_1b08		; @1A00 CD081B  update timers for ghosts to leave ghost house
	call	j_1a6a		; @1A03 CD6A1A  check for energizer eaten
	ld hl,CH3_E_NUM		; @1A06 21BC4E  load HL with sound #3
	ld	a,(dots_eaten)		; @1A09 3A0E4E  load A with number of pills eaten in this level
	rrca		; @1A0C 0F  roll right
	jr	c,j_1a14		; @1A0D 3805  if carry then use other sound pattern

	set	0,(hl)		; @1A0F CBC6  else set sound bit 0
	res	1,(hl)		; @1A11 CB8E  clear sound bit 1
	ret		; @1A13 C9  return

j_1a14:
	res	0,(hl)		; @1A14 CB86  clear sound bit 0
	set	1,(hl)		; @1A16 CBCE  set sound bit 1
	ret		; @1A18 C9  return     

; arrive here from #18b0 when game is in demo mode

j_1a19:
	ld hl,pac_tile_dy		; @1A19 211C4D  load HL with pacman Y tile changes (A) location
	ld      a,(hl)		; @1A1C 7E  load A pacman Y tile changes (A)
	and     a		; @1A1D A7  == #00 ?  is pacman moving left-right ?
	jp      z,j_1a2e		; @1A1E CA2E1A  yes, skip ahead

	ld      a,(pac_y)		; @1A21 3A084D  else load A with pacman Y position
	and     #07		; @1A24 E607  mask bits, now between 0 and 7
	cp      #04		; @1A26 FE04  == #04?
	jp      z,j_1a38		; @1A28 CA381A  yes, skip ahead
	jp      j_1a5c		; @1A2B C35C1A  else jump ahead

j_1a2e:
	ld      a,(pac_x)		; @1A2E 3A094D  load A with pacman X position
	and     #07		; @1A31 E607  mask bits, now between 0 and 7
	cp      #04		; @1A33 FE04  == #04 ?
	jp      nz,j_1a5c		; @1A35 C25C1A  no, skip ahead

j_1a38:
	ld      a,#05		; @1A38 3E05  yes, A := #05. sets up call below to check if pacman is using tunnel in demo
	call    j_1ed0		; @1A3A CDD01E  if using tunnel, set carry flag
	jr      c,j_1a42		; @1A3D 3803  is pacman in tunnel?  no, skip next 2 steps
	rst     #28		; @1A3F EF  insert task to control pacman AI during demo mode.
	db	#17,#00	; @1A40 1700  task #17, parameter #00

j_1a42:
	ld ix,pac_wanted_tile_dy		; @1A42 DD21264D  load IX with wanted pacman tile changes
	ld iy,pac_demo_tile_y		; @1A46 FD21124D  load IY with pacman tile pos in demo and cut scenes
	call    j_2000		; @1A4A CD0020  load HL with new position of pacman
	ld      (pac_demo_tile_y),hl		; @1A4D 22124D  store new position into pacman tile position in demo and cut scenes
	ld      hl,(pac_wanted_tile_dy)		; @1A50 2A264D  load HL with wanted pacman tile changes
	ld      (pac_tile_dy),hl		; @1A53 221C4D  store into pacman tile changes (Y,X)
	ld      a,(pac_wanted_dir)		; @1A56 3A3C4D  load A with wanted pacman orientation
	ld      (pac_dir),a		; @1A59 32304D  store into pacman orientation

j_1a5c:
	ld ix,pac_tile_dy		; @1A5C DD211C4D  load IX with pacman tile changes (Y,X)
	ld iy,pac_y		; @1A60 FD21084D  load IY with pacman position (Y,X) address
	call    j_2000		; @1A64 CD0020  load HL with new position of pacman
	jp      j_1985		; @1A67 C38519  jump to movement check

; called from #1A03 after a dot has been eaten

j_1a6a:
	ld      a,(pac_move_delay)		; @1A6A 3A9D4D  load A with dot just eaten
	cp      #06		; @1A6D FE06  was it an energizer?
	ret     nz		; @1A6F C0  no, return

; else an engergizer has been eaten
; this is also called even on boards where energizers have "no effect"

j_1a70:
	ld	hl,(frightened_time_lo)		; @1A70 2ABD4D  load HL with time the ghosts stay blue when pacman eats a big pill
	ld      (frightened_timer_lo),hl		; @1A73 22CB4D  store into counter used while ghosts are blue
	ld      a,#01		; @1A76 3E01  A := #01
	ld      (power_pill_active),a		; @1A78 32A64D  set power pill to active
	ld      (red_frightened),a		; @1A7B 32A74D  set red ghost blue flag
	ld      (pink_frightened),a		; @1A7E 32A84D  set pink ghost blue flag
	ld      (blue_frightened),a		; @1A81 32A94D  set inky blue flag
	ld      (orange_frightened),a		; @1A84 32AA4D  set orange ghost blue flag
	ld      (red_reverse_flag),a		; @1A87 32B14D  set red ghost change orientation flag
	ld      (pink_reverse_flag),a		; @1A8A 32B24D  set pink ghost change orientation flag
	ld      (blue_reverse_flag),a		; @1A8D 32B34D  set blue ghost (inky) change orientation flag
	ld      (orange_reverse_flag),a		; @1A90 32B44D  set orange ghost change orientation flag
	ld      (pac_reverse_flag),a		; @1A93 32B54D  set pacman change orientation flag (?)
	xor     a		; @1A96 AF  A := #00
	ld      (frightened_flash_counter),a		; @1A97 32C84D  clear counter used to change ghost colors under big pill effects
	ld      (ghosts_killed_count),a		; @1A9A 32D04D  clear current number of killed ghosts (used for scoring)
	ld ix,spr_unk_4c00		; @1A9D DD21004C  load IX with start of sprites address
	ld      (ix+#02),#1c		; @1AA1 DD36021C  set red ghost sprite to edible
	ld      (ix+#04),#1c		; @1AA5 DD36041C  set pink ghost sprite to edible
	ld      (ix+#06),#1c		; @1AA9 DD36061C  set inky sprite to edible
	ld      (ix+#08),#1c		; @1AAD DD36081C  set orange ghost sprite to edible

	ld      (ix+#03),#11		; @1AB1 DD360311  set red ghost color to blue

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Patch to fix the green-eye bug
; by Don Hodges 1/19/2009
; part 1/2 (rest at #1FB0):
;
; 1AB1 C3B01F	JP	#1FB0		; jump to new sub to only color ghosts when enough time
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


	ld      (ix+#05),#11		; @1AB5 DD360511  set pink ghost color to blue
	ld      (ix+#07),#11		; @1AB9 DD360711  set inky color to blue
	ld      (ix+#09),#11		; @1ABD DD360911  set orange ghost color to blue

	ld hl,CH2_E_NUM		; @1AC1 21AC4E  load HL with sound channel 2
	set	5,(hl)		; @1AC4 CBEE  play sound bit 5
	res	7,(hl)		; @1AC6 CBBE  clear sound bit 7
	ret		; @1AC8 C9  return

	; Player move Left

j_1ac9:
	ld      hl,(#3303)		; @1AC9 2A0333  load HL with tile movement left
	ld      a,#02		; @1ACC 3E02  load A with code for moving left
	ld      (pac_wanted_dir),a		; @1ACE 323C4D  store into wanted pacman orientation
	ld      (pac_wanted_tile_dy),hl		; @1AD1 22264D  store into wanted pacman tile changes
	ld      b,#00		; @1AD4 0600  B := #00
	jp      j_18e4		; @1AD6 C3E418  return to program

	; player move Right

j_1ad9:
	ld      hl,(#32ff)		; @1AD9 2AFF32  load HL with tile movement right
	xor     a		; @1ADC AF  A := #00, code for moving right
	ld      (pac_wanted_dir),a		; @1ADD 323C4D  store into wanted pacman orientation
	ld      (pac_wanted_tile_dy),hl		; @1AE0 22264D  store into wanted pacman tile changes 
	ld      b,#00		; @1AE3 0600  B := #00
	jp      j_18e4		; @1AE5 C3E418  return to program

	; player move Up

j_1ae8:
	ld      hl,(#3305)		; @1AE8 2A0533  load HL with tile movement up
	ld      a,#03		; @1AEB 3E03  load A with code for moving up
	ld      (pac_wanted_dir),a		; @1AED 323C4D  store into wanted pacman orientation
	ld      (pac_wanted_tile_dy),hl		; @1AF0 22264D  store into wanted pacman tile changes
	ld      b,#00		; @1AF3 0600  B := #00
	jp      j_18e4		; @1AF5 C3E418  return to program

	; player move Down

j_1af8:
	ld      hl,(#3301)		; @1AF8 2A0133  load HL with tile movement down
	ld      a,#01		; @1AFB 3E01  load A with code for moving down
	ld      (pac_wanted_dir),a		; @1AFD 323C4D  store into wanted pacman orientation
	ld      (pac_wanted_tile_dy),hl		; @1B00 22264D  store into wanted pacman tile changes
	ld      b,#00		; @1B03 0600  B := #00
	jp      j_18e4		; @1B05 C3E418  return to program

; called from #1A00

j_1b08:
	ld      a,(died_this_level)		; @1B08 3A124E  load A with flag set to 1 after dying in a level, reset to 0 if ghosts have left home
	and     a		; @1B0B A7  has pacman died this level?  (or has this flag been reset after eating enough dots after death) ?
	jp      z,j_1b14		; @1B0C CA141B  no, skip ahead

	ld hl,pills_after_death		; @1B0F 219F4D  no, load HL with eaten pills counter after pacman has died in a level
	inc     (hl)		; @1B12 34  increase
	ret		; @1B13 C9  return

j_1b14:
	ld      a,(orange_substate)		; @1B14 3AA34D  load A with orange ghost substate
	and     a		; @1B17 A7  is orange ghost at home ?
	ret     nz		; @1B18 C0  no, return

	ld      a,(blue_substate)		; @1B19 3AA24D  yes, load A with inky substate
	and     a		; @1B1C A7  is inky at home ?
	jp      z,j_1b25		; @1B1D CA251B  yes, skip ahead

	ld hl,orange_exit_counter		; @1B20 21114E  no, load HL with counter incremented if orange ghost is home but inky is not
	inc     (hl)		; @1B23 34  increase counter
	ret		; @1B24 C9  return

j_1b25:
	ld      a,(pink_substate)		; @1B25 3AA14D  load A with pink ghost substate
	and     a		; @1B28 A7  is pink ghost at home ?
	jp      z,j_1b31		; @1B29 CA311B  yes, skip ahead

	ld hl,blue_exit_counter		; @1B2C 21104E  no, load HL with counter incremented if inky and orange ghost are home but pinky is not
	inc     (hl)		; @1B2F 34  increase counter
	ret		; @1B30 C9  return

j_1b31:
	ld hl,pink_exit_counter		; @1B31 210F4E  load HL with counter incremented if pink ghost is home
	inc     (hl)		; @1B34 34  increase counter
	ret		; @1B35 C9  return

; called from several locations

j_1b36:
	ld      a,(red_substate)		; @1B36 3AA04D  load A with red ghost substate
	and     a		; @1B39 A7  is red ghost at home ?
	ret     z		; @1B3A C8  yes, return

	ld      a,(red_state)		; @1B3B 3AAC4D  else load A with red ghost state
	and     a		; @1B3E A7  is red ghost alive ?
	ret     nz		; @1B3F C0  no, return

	call    j_20d7		; @1B40 CDD720  checks for and sets the difficulty flags based on number of pellets eaten
	ld      hl,(red_tile_y2)		; @1B43 2A314D  load HL with red ghost Y, X tile position 2
	ld bc,red_tunnel_slow		; @1B46 01994D  load BC with address of aux var used by red ghost to check positions
	call    j_205a		; @1B49 CD5A20  check to see if red ghost has entered a tunnel slowdown area
	ld      a,(red_tunnel_slow)		; @1B4C 3A994D  load A with aux var used by red ghost to check positions
	and     a		; @1B4F A7  is the red ghost in a tunnel slowdown area ?
	jp      z,j_1b6a		; @1B50 CA6A1B  no, skip ahead

	ld      hl,(#4d60)		; @1B53 2A604D  else load HL with red ghost speed bit patterns for tunnel areas
	add     hl,hl		; @1B56 29  double it
	ld      (#4d60),hl		; @1B57 22604D  store result
	ld      hl,(speed_pat_red_tunnel)		; @1B5A 2A5E4D  load HL with red ghost speed bit patterns for tunnel areas
	adc     hl,hl		; @1B5D ED6A  double it
	ld      (speed_pat_red_tunnel),hl		; @1B5F 225E4D  store result.  have we exceeded the threshold ?
	ret     nc		; @1B62 D0  no, return

	ld      hl,#4d60		; @1B63 21604D  else load HL with red ghost speed bit patterns for tunnel areas
	inc     (hl)		; @1B66 34  increase
	jp      j_1bd8		; @1B67 C3D81B  skip ahead

j_1b6a:
	ld      a,(red_frightened)		; @1B6A 3AA74D  load A with red ghost blue flag (0=not blue)
	and     a		; @1B6D A7  is red ghost blue ?
	jp      z,j_1b88		; @1B6E CA881B  no, skip ahead

	ld      hl,(#4d5c)		; @1B71 2A5C4D  yes, load HL with red ghost speed bit patterns for blue state
	add     hl,hl		; @1B74 29  double it
	ld      (#4d5c),hl		; @1B75 225C4D  store result
	ld      hl,(speed_pat_red_blue)		; @1B78 2A5A4D  load HL with red ghost speed bit patterns for blue state
	adc     hl,hl		; @1B7B ED6A  double it
	ld      (speed_pat_red_blue),hl		; @1B7D 225A4D  store result.  have we exceeded the threshold ?
	ret     nc		; @1B80 D0  no, return

	ld      hl,#4d5c		; @1B81 215C4D  yes, load HL with red ghost speed bit patterns for blue state
	inc     (hl)		; @1B84 34  increase
	jp      j_1bd8		; @1B85 C3D81B  skip ahead

j_1b88:
	ld      a,(cruise_elroy_2)		; @1B88 3AB74D  load A with 2nd difficulty flag
	and     a		; @1B8B A7  is cruise elroy 2 active ?
	jp      z,j_1ba6		; @1B8C CAA61B  no, skip ahead

	ld      hl,(#4d50)		; @1B8F 2A504D  yes, load HL with speed bit patterns for second difficulty flag
	add     hl,hl		; @1B92 29  double
	ld      (#4d50),hl		; @1B93 22504D  store result
	ld      hl,(speed_pat_diff2)		; @1B96 2A4E4D  load HL with speed bit patterns for second difficulty flag
	adc     hl,hl		; @1B99 ED6A  double
	ld      (speed_pat_diff2),hl		; @1B9B 224E4D  store result.  have we exceeded the threshold ?
	ret     nc		; @1B9E D0  no, return

	ld      hl,#4d50		; @1B9F 21504D  yes, load HL with movement bit patterns for second difficulty flag
	inc     (hl)		; @1BA2 34  increase
	jp      j_1bd8		; @1BA3 C3D81B  skip ahead

j_1ba6:
	ld      a,(cruise_elroy_1)		; @1BA6 3AB64D  load A with 1st difficulty flag
	and     a		; @1BA9 A7  is cruise elroy 1 active?
	jp      z,j_1bc4		; @1BAA CAC41B  no, skip ahead

	ld      hl,(#4d54)		; @1BAD 2A544D  yes, load HL with speed bit patterns for first difficulty flag
	add     hl,hl		; @1BB0 29  double
	ld      (#4d54),hl		; @1BB1 22544D  store result
	ld      hl,(speed_pat_diff1)		; @1BB4 2A524D  load HL with speed bit patterns for first difficulty flag
	adc     hl,hl		; @1BB7 ED6A  double
	ld      (speed_pat_diff1),hl		; @1BB9 22524D  store result.  have we exceeded the threshold ?
	ret     nc		; @1BBC D0  no, return

	ld      hl,#4d54		; @1BBD 21544D  yes, load HL with speed bit patterns for first difficulty flag
	inc     (hl)		; @1BC0 34  increase
	jp      j_1bd8		; @1BC1 C3D81B  skip ahead

j_1bc4:
	ld      hl,(#4d58)		; @1BC4 2A584D  load HL with speed bit patterns for red ghost normal state
	add     hl,hl		; @1BC7 29  double
	ld      (#4d58),hl		; @1BC8 22584D  store result
	ld      hl,(speed_pat_red_normal)		; @1BCB 2A564D  load HL with  speed bit patterns for red ghost normal state
	adc     hl,hl		; @1BCE ED6A  double
	ld      (speed_pat_red_normal),hl		; @1BD0 22564D  store result.  have we exceed the threshold ?
	ret     nc		; @1BD3 D0  no, return

	ld      hl,#4d58		; @1BD4 21584D  yes, load HL with speed bit patterns for red ghost normal state
	inc     (hl)		; @1BD7 34  increase

; called from #10C0 and several other places
; handles red ghost movement

j_1bd8:
	ld hl,red_tile_dy		; @1BD8 21144D  load HL with red ghost Y tile changes address
	ld      a,(hl)		; @1BDB 7E  load A with red ghost Y tile changes
	and     a		; @1BDC A7  is the red ghost moving left to right or right to left ?
	jp      z,j_1bed		; @1BDD CAED1B  yes, skip ahead

	ld      a,(red_y)		; @1BE0 3A004D  load A with red ghost Y position
	and     #07		; @1BE3 E607  mask out bits, result is between 0 and 7
	cp      #04		; @1BE5 FE04  == #04 ?  Is the red ghost in the middle of a tile where he can change direction?
	jp      z,j_1bf7		; @1BE7 CAF71B  yes, skip ahead
	jp      j_1c36		; @1BEA C3361C  no, jump ahead

j_1bed:
	ld      a,(red_x)		; @1BED 3A014D  load A with red ghost X position
	and     #07		; @1BF0 E607  mask bits.  result is between 0 and 7
	cp      #04		; @1BF2 FE04  == #04 ? Is the red ghost in the middle of a tile where he can change direction?
	jp      nz,j_1c36		; @1BF4 C2361C  no, jump ahead

j_1bf7:
	ld      a,#01		; @1BF7 3E01  A := #01
	call    j_1ed0		; @1BF9 CDD01E  check to see if red ghost is on the edge of the screen (tunnel)
	jr      c,j_1c19		; @1BFC 381B  yes, jump ahead

	ld      a,(red_frightened)		; @1BFE 3AA74D  no, load A with red ghost blue flag (0=not blue)
	and     a		; @1C01 A7  is the red ghost blue (edible) ?
	jp      z,j_1c0b		; @1C02 CA0B1C  no, skip ahead
	rst     #28		; @1C05 EF  yes, insert task #0C to control red ghost movement when power pill active
	db	#0C,#00	; @1C06 0C00
	jp      j_1c19		; @1C08 C3191C  skip ahead

j_1c0b:
	ld      hl,(red_tile_y)		; @1C0B 2A0A4D  else load HL with red tile position (Y,X)
	call    j_2052		; @1C0E CD5220  convert ghost Y,X position in HL to a color screen location
	ld      a,(hl)		; @1C11 7E  load A with color of screen location of ghost
	cp      #1a		; @1C12 FE1A  == #1A ?  (this color marks zones where ghosts cannot change direction, e.g. above the ghost house in pac-man)
	jr      z,j_1c19		; @1C14 2803  yes, skip next step

	rst     #28		; @1C16 EF  no, insert task #08 to control red ghost AI
	db	#08,#00	; @1C17 0800

j_1c19:
	call    j_1efe		; @1C19 CDFE1E  check for and handle red ghost direction reversals
	ld ix,red_tile_dy2		; @1C1C DD211E4D  load IX with red ghost tile changes
	ld iy,red_tile_y		; @1C20 FD210A4D  load IY with red ghost tile position
	call    j_2000		; @1C24 CD0020  HL := (IX) + (IY)
	ld      (red_tile_y),hl		; @1C27 220A4D  store new result into red ghost tile position
	ld      hl,(red_tile_dy2)		; @1C2A 2A1E4D  load HL with red ghost tile changes
	ld      (red_tile_dy),hl		; @1C2D 22144D  store into red ghost tile changes (A)
	ld      a,(red_dir)		; @1C30 3A2C4D  load A with red ghost orientation
	ld      (red_prev_dir),a		; @1C33 32284D  store into previous red ghost orientation

j_1c36:
	ld ix,red_tile_dy		; @1C36 DD21144D  load IX with red ghost tile changes (A)
	ld iy,red_y		; @1C3A FD21004D  load IY with red ghost position
	call    j_2000		; @1C3E CD0020  HL := (IX) + (IY)
	ld      (red_y),hl		; @1C41 22004D  store result into red ghost position
	call    j_2018		; @1C44 CD1820  convert sprite position into a tile position
	ld      (red_tile_y2),hl		; @1C47 22314D  store into red ghost tile position 2 
	ret		; @1C4A C9  return

; control movement patterns for pink ghost
; called from #104A

j_1c4b:
	ld      a,(pink_substate)		; @1C4B 3AA14D  load A with pink ghost substate
	cp      #01		; @1C4E FE01  is pink ghost at home ?
	ret     nz		; @1C50 C0  yes, return

	ld      a,(pink_state)		; @1C51 3AAD4D  else load A with pink ghost state
	and     a		; @1C54 A7  is pink ghost alive ?
	ret     nz		; @1C55 C0  no, return

	ld      hl,(pink_tile_y2)		; @1C56 2A334D  load HL with pink ghost tile position 2
	ld bc,pink_tunnel_slow		; @1C59 019A4D  load BC with address of aux var used by pink ghost to check positions
	call    j_205a		; @1C5C CD5A20  check to see if pink ghost has entered a tunnel slowdown area
	ld      a,(pink_tunnel_slow)		; @1C5F 3A9A4D  load A with aux var used by pink ghost to check positions
	and     a		; @1C62 A7  is the pink ghost in a tunnel slowdown area ?
	jp      z,j_1c7d		; @1C63 CA7D1C  no, skip ahead

	ld      hl,(#4d6c)		; @1C66 2A6C4D  else load HL with speed bit patterns for pink ghost tunnel areas
	add     hl,hl		; @1C69 29  double it
	ld      (#4d6c),hl		; @1C6A 226C4D  store result
	ld      hl,(speed_pat_pink_tunnel)		; @1C6D 2A6A4D  load HL with speed bit patterns for pink ghost tunnel areas
	adc     hl,hl		; @1C70 ED6A  double it
	ld      (speed_pat_pink_tunnel),hl		; @1C72 226A4D  store result.   Have we exceeded the threshold ?
	ret     nc		; @1C75 D0  no, return

	ld      hl,#4d6c		; @1C76 216C4D  else load HL with address of speed bit patterns for pink ghost tunnel areas
	inc     (hl)		; @1C79 34  increase
	jp      j_1caf		; @1C7A C3AF1C  skip ahead

j_1c7d:
	ld      a,(pink_frightened)		; @1C7D 3AA84D  load A with pink ghost blue flag
	and     a		; @1C80 A7  is the pink ghost blue ?
	jp      z,j_1c9b		; @1C81 CA9B1C  no, skip ahead

	ld      hl,(#4d68)		; @1C84 2A684D  yes, load HL with speed bit patterns for pink ghost blue state
	add     hl,hl		; @1C87 29  double it
	ld      (#4d68),hl		; @1C88 22684D  store result
	ld      hl,(speed_pat_pink_blue)		; @1C8B 2A664D  load HL with speed bit patterns for pink ghost blue state
	adc     hl,hl		; @1C8E ED6A  double it
	ld      (speed_pat_pink_blue),hl		; @1C90 22664D  store result.  have we exceeded the threshold ?
	ret     nc		; @1C93 D0  no, return

	ld      hl,#4d68		; @1C94 21684D  yes, load HL with speed bit patterns for pink ghost blue state
	inc     (hl)		; @1C97 34  increase
	jp      j_1caf		; @1C98 C3AF1C  skip ahead

j_1c9b:
	ld      hl,(#4d64)		; @1C9B 2A644D  load HL with speed bit patterns for pink ghost normal state
	add     hl,hl		; @1C9E 29  double it
	ld      (#4d64),hl		; @1C9F 22644D  store result
	ld      hl,(speed_pat_pink_normal)		; @1CA2 2A624D  load HL with speed bit patterns for pink ghost normal state
	adc     hl,hl		; @1CA5 ED6A  double it
	ld      (speed_pat_pink_normal),hl		; @1CA7 22624D  store result.  have we exceeded the threshold ?
	ret     nc		; @1CAA D0  no, return

	ld      hl,#4d64		; @1CAB 21644D  yes, load HL with speed bit patterns for pink ghost normal state
	inc     (hl)		; @1CAE 34  increase

j_1caf:
	ld hl,pink_tile_dy		; @1CAF 21164D  load HL with address for pink ghost Y tile changes
	ld      a,(hl)		; @1CB2 7E  load A with pink ghost Y tile changes
	and     a		; @1CB3 A7  Is the pink ghost moving left-right or right-left ?
	jp      z,j_1cc4		; @1CB4 CAC41C  yes, skip ahead

	ld      a,(pink_y)		; @1CB7 3A024D  no, load A with pink ghost Y position
	and     #07		; @1CBA E607  mask bits
	cp      #04		; @1CBC FE04  is pink ghost in the middle of the tile ?
	jp      z,j_1cce		; @1CBE CACE1C  yes, skip ahead

	jp      j_1d0d		; @1CC1 C30D1D  no, jump ahead

j_1cc4:
	ld      a,(pink_x)		; @1CC4 3A034D  load A with pink ghost X position
	and     #07		; @1CC7 E607  mask bits
	cp      #04		; @1CC9 FE04  is pink ghost in the middle of the tile ?
	jp      nz,j_1d0d		; @1CCB C20D1D  no, skip ahead

j_1cce:
	ld      a,#02		; @1CCE 3E02  yes, A := #02
	call    j_1ed0		; @1CD0 CDD01E  check to see if pink ghost is on the edge of the screen (tunnel)
	jr      c,j_1cf0		; @1CD3 381B  yes, jump ahead

	ld      a,(pink_frightened)		; @1CD5 3AA84D  no, load A with pink ghost blue flag (0=not blue)
	and     a		; @1CD8 A7  is the pink ghost blue ?
	jp      z,j_1ce2		; @1CD9 CAE21C  no, skip ahead

	rst     #28		; @1CDC EF  yes, insert task to handle pink ghost movement when power pill active
	db	#0D,#00	; @1CDD 0D00  task data
	jp      j_1cf0		; @1CDF C3F01C  skip ahead

j_1ce2:
	ld      hl,(pink_tile_y)		; @1CE2 2A0C4D  load HL with pink ghost Y,X tile pos
	call    j_2052		; @1CE5 CD5220  convert ghost Y,X position in HL to a color screen location
	ld      a,(hl)		; @1CE8 7E  load A with color screen position of ghost
	cp      #1a		; @1CE9 FE1A  == #1A? (this color marks zones where ghosts cannot change direction, e.g. above the ghost house in pac-man)
	jr      z,j_1cf0		; @1CEB 2803  yes, skip next step

	rst     #28		; @1CED EF  insert task to handle pink ghost AI
	db	#09,#00	; @1CEE 0900  task data

j_1cf0:
	call    j_1f25		; @1CF0 CD251F  check for and handle when pink ghost reverses directions
	ld ix,pink_tile_dy2		; @1CF3 DD21204D  load IX with pink ghost tile changes
	ld iy,pink_tile_y		; @1CF7 FD210C4D  load IY with pink ghost tile position
	call    j_2000		; @1CFB CD0020  HL := (IX) + (IY)
	ld      (pink_tile_y),hl		; @1CFE 220C4D  store new result into pink ghost tile position
	ld      hl,(pink_tile_dy2)		; @1D01 2A204D  load HL with pink ghost tile changes
	ld      (pink_tile_dy),hl		; @1D04 22164D  store into pink ghost tile changes (A)
	ld      a,(pink_dir)		; @1D07 3A2D4D  load A with pink ghost orientation
	ld      (pink_prev_dir),a		; @1D0A 32294D  store into previous pink ghost orientation

j_1d0d:
	ld ix,pink_tile_dy		; @1D0D DD21164D  load IX with pink ghost tile changes (A)
	ld iy,pink_y		; @1D11 FD21024D  load IY with pink ghost position
	call    j_2000		; @1D15 CD0020  HL := (IX) + (IY)
	ld      (pink_y),hl		; @1D18 22024D  store result into pink ghost postion
	call    j_2018		; @1D1B CD1820  convert sprite position into a tile position
	ld      (pink_tile_y2),hl		; @1D1E 22334D  store into pink ghost tile position 2
	ret		; @1D21 C9  return

; check movement patterns for inky
; called from #104D

j_1d22:
	ld      a,(blue_substate)		; @1D22 3AA24D  load A with blue ghost (inky) substate
	cp      #01		; @1D25 FE01  is blue ghost at home ?
	ret     nz		; @1D27 C0  yes, return

	ld      a,(blue_state)		; @1D28 3AAE4D  else load A with blue ghost (inky) state
	and     a		; @1D2B A7  is inky alive ?
	ret     nz		; @1D2C C0  no, return

	ld      hl,(blue_tile_y2)		; @1D2D 2A354D  load HL with inky tile position 2
	ld bc,blue_tunnel_slow		; @1D30 019B4D  load BC with address of aux var used by inky to check positions
	call    j_205a		; @1D33 CD5A20  check to see if inky has entered a tunnel slowdown area
	ld      a,(blue_tunnel_slow)		; @1D36 3A9B4D  load A with aux var used by inky to check positions
	and     a		; @1D39 A7  is inky in a tunnel slowdown area?
	jp      z,j_1d54		; @1D3A CA541D  no, skip ahead

	ld      hl,(#4d78)		; @1D3D 2A784D  yes, load HL with speed bit patterns for inky tunnel areas
	add     hl,hl		; @1D40 29  double it
	ld      (#4d78),hl		; @1D41 22784D  store result
	ld      hl,(speed_pat_blue_tunnel)		; @1D44 2A764D  load HL with speed bit patterns for inky tunnel areas
	adc     hl,hl		; @1D47 ED6A  double it
	ld      (speed_pat_blue_tunnel),hl		; @1D49 22764D  store result.  have we exceeded the threshold?
	ret     nc		; @1D4C D0  no, return

	ld      hl,#4d78		; @1D4D 21784D  yes, load HL with address of speed bit patterns for inky tunnel areas
	inc     (hl)		; @1D50 34  increase
	jp      j_1d86		; @1D51 C3861D  skip ahead

j_1d54:
	ld      a,(blue_frightened)		; @1D54 3AA94D  load A with inky blue flag
	and     a		; @1D57 A7  is inky edible ?
	jp      z,j_1d72		; @1D58 CA721D  no, skip ahead

	ld      hl,(#4d74)		; @1D5B 2A744D  yes, load HL with speed bit patterns for inky in blue state
	add     hl,hl		; @1D5E 29  double it
	ld      (#4d74),hl		; @1D5F 22744D  store result
	ld      hl,(speed_pat_blue_blue)		; @1D62 2A724D  load HL with speed bit patterns for inky in blue state
	adc     hl,hl		; @1D65 ED6A  double it
	ld      (speed_pat_blue_blue),hl		; @1D67 22724D  store result.  have we exceeded the threshold?
	ret     nc		; @1D6A D0  no, return

	ld      hl,#4d74		; @1D6B 21744D  yes, load HL with speed bit patterns for inky in blue state
	inc     (hl)		; @1D6E 34  increase
	jp      j_1d86		; @1D6F C3861D  jump ahead

j_1d72:
	ld      hl,(#4d70)		; @1D72 2A704D  load HL with speed bit patterns for inky normal state
	add     hl,hl		; @1D75 29  double it
	ld      (#4d70),hl		; @1D76 22704D  store result
	ld      hl,(speed_pat_blue_normal)		; @1D79 2A6E4D  load HL with speed bit patterns for inky normal state
	adc     hl,hl		; @1D7C ED6A  double it
	ld      (speed_pat_blue_normal),hl		; @1D7E 226E4D  store result. have we exceeded the threshold ?
	ret     nc		; @1D81 D0  no, return

	ld      hl,#4d70		; @1D82 21704D  yes, load HL with speed bit patterns for inky normal state
	inc     (hl)		; @1D85 34  increase
		
j_1d86:
	ld hl,blue_tile_dy		; @1D86 21184D  load HL with address of inky Y tile changes
	ld      a,(hl)		; @1D89 7E  load A with inky Y tile changes
	and     a		; @1D8A A7  is inky moving left-right or right left ?
	jp      z,j_1d9b		; @1D8B CA9B1D  yes, skip ahead

	ld      a,(blue_y)		; @1D8E 3A044D  no, load A with inky Y position
	and     #07		; @1D91 E607  mask bits
	cp      #04		; @1D93 FE04  is inky in the middle of a tile ?
	jp      z,j_1da5		; @1D95 CAA51D  yes, skip ahead
	jp      j_1de4		; @1D98 C3E41D  no, jump ahead

j_1d9b:
	ld      a,(blue_x)		; @1D9B 3A054D  load A with inky X position
	and     #07		; @1D9E E607  mask bits
	cp      #04		; @1DA0 FE04  is inky in the middle of the tile ?
	jp      nz,j_1de4		; @1DA2 C2E41D  no, skip ahead

j_1da5:
	ld      a,#03		; @1DA5 3E03  yes, A := #03
	call    j_1ed0		; @1DA7 CDD01E  check to see if inky is on the edge of the screen (tunnel)
	jr      c,j_1dc7		; @1DAA 381B  yes, jump ahead

	ld      a,(blue_frightened)		; @1DAC 3AA94D  no, load A with inky blue flag (0 = not blue)
	and     a		; @1DAF A7  is inky edible ?
	jp      z,j_1db9		; @1DB0 CAB91D  no, skip ahead

	rst     #28		; @1DB3 EF  yes, insert task to handle blue ghost (inky) movement when power pill active
	db	#0E,#00	; @1DB4 0E00
	jp      j_1dc7		; @1DB6 C3C71D  skip ahead

j_1db9:
	ld      hl,(blue_tile_y)		; @1DB9 2A0E4D  load HL with inky tile position
	call    j_2052		; @1DBC CD5220  covert to color screen location
	ld      a,(hl)		; @1DBF 7E  load A with color of screen location
	cp      #1a		; @1DC0 FE1A  == #1A ? (this color marks zones where ghosts cannot change direction, e.g. above the ghost house in pac-man)
	jr      z,j_1dc7		; @1DC2 2803  yes, skip next step

	rst     #28		; @1DC4 EF  insert task to handle blue ghost (inky) AI
	db	#0A,#00	; @1DC5 0A00

j_1dc7:
	call    j_1f4c		; @1DC7 CD4C1F  check for and handle when inky reverses directions
	ld ix,blue_tile_dy2		; @1DCA DD21224D  load IX with inky tile changes
	ld iy,blue_tile_y		; @1DCE FD210E4D  load IY with inky tile position
	call    j_2000		; @1DD2 CD0020  HL := (IX) + (IY)
	ld      (blue_tile_y),hl		; @1DD5 220E4D  store new result into inky tile position
	ld      hl,(blue_tile_dy2)		; @1DD8 2A224D  load HL with inky tile changes
	ld      (blue_tile_dy),hl		; @1DDB 22184D  store into inky tile changes (A)
	ld      a,(blue_dir)		; @1DDE 3A2E4D  load A with inky orientation
	ld      (blue_prev_dir),a		; @1DE1 322A4D  store into inky previous orientation

j_1de4:
	ld ix,blue_tile_dy		; @1DE4 DD21184D  load IX with inky tile changes (A)
	ld iy,blue_y		; @1DE8 FD21044D  load IY with inky position
	call    j_2000		; @1DEC CD0020  HL := (IX) + (IY)
	ld      (blue_y),hl		; @1DEF 22044D  store result into inky position
	call    j_2018		; @1DF2 CD1820  convert sprite position into a tile position
	ld      (blue_tile_y2),hl		; @1DF5 22354D  store into inky tile position 2
	ret		; @1DF8 C9  return

; control movement patterns for orange ghost
; called from #1050

j_1df9:
	ld      a,(orange_substate)		; @1DF9 3AA34D  load A with orange ghost substate
	cp      #01		; @1DFC FE01  is orange ghost at home ?
	ret     nz		; @1DFE C0  yes, return

	ld      a,(orange_state)		; @1DFF 3AAF4D  else load A with orange ghost state
	and     a		; @1E02 A7  is orange ghost alive ?
	ret     nz		; @1E03 C0  no, return

	ld      hl,(orange_tile_y2)		; @1E04 2A374D  load HL with orange ghost tile position 2
	ld bc,orange_tunnel_slow		; @1E07 019C4D  load BC with address of aux var used by orange ghost to check positions
	call    j_205a		; @1E0A CD5A20  check to see if orange ghost has entered a tunnel slowdown area
	ld      a,(orange_tunnel_slow)		; @1E0D 3A9C4D  load A with aux var used by orange ghost to check positions
	and     a		; @1E10 A7  is the orange ghost in a tunnel slowdown area?
	jp      z,j_1e2b		; @1E11 CA2B1E  no, skip ahead

	ld      hl,(#4d84)		; @1E14 2A844D  yes, load HL with speed bit patterns for orange ghost tunnel areas
	add     hl,hl		; @1E17 29  double it
	ld      (#4d84),hl		; @1E18 22844D  store result
	ld      hl,(speed_pat_orange_tunnel)		; @1E1B 2A824D  load HL with speed bit patterns for orange ghost tunnel areas
	adc     hl,hl		; @1E1E ED6A  double it
	ld      (speed_pat_orange_tunnel),hl		; @1E20 22824D  store result.  have we exceeded the threshold?
	ret     nc		; @1E23 D0  no, return

	ld      hl,#4d84		; @1E24 21844D  yes, load HL with speed bit patterns for orange ghost tunnel areas
	inc     (hl)		; @1E27 34  increase
	jp      j_1e5d		; @1E28 C35D1E  skip ahead

j_1e2b:
	ld      a,(orange_frightened)		; @1E2B 3AAA4D  load A with orange ghost blue flag
	and     a		; @1E2E A7  is the orange ghost blue ( edible ) ?
	jp      z,j_1e49		; @1E2F CA491E  no, skip ahead

	ld      hl,(#4d80)		; @1E32 2A804D  yes, load HL with speed bit patterns for orange ghost blue state
	add     hl,hl		; @1E35 29  double it
	ld      (#4d80),hl		; @1E36 22804D  store result
	ld      hl,(speed_pat_orange_blue)		; @1E39 2A7E4D  load HL with speed bit patterns for orange ghost blue state
	adc     hl,hl		; @1E3C ED6A  double it
	ld      (speed_pat_orange_blue),hl		; @1E3E 227E4D  store result.  have we exceeded the threshold ?
	ret     nc		; @1E41 D0  no, return

	ld      hl,#4d80		; @1E42 21804D  yes, load HL with speed bit patterns for orange ghost blue state
	inc     (hl)		; @1E45 34  increase 
	jp      j_1e5d		; @1E46 C35D1E  skip ahead

j_1e49:
	ld      hl,(#4d7c)		; @1E49 2A7C4D  load HL with speed bit patterns for orange ghost normal state
	add     hl,hl		; @1E4C 29  double it
	ld      (#4d7c),hl		; @1E4D 227C4D  store result
	ld      hl,(speed_pat_orange_normal)		; @1E50 2A7A4D  load HL with speed bit patterns for orange ghost normal state
	adc     hl,hl		; @1E53 ED6A  double it
	ld      (speed_pat_orange_normal),hl		; @1E55 227A4D  store result.  have we exceeded the threshold ?
	ret     nc		; @1E58 D0  no, return

	ld      hl,#4d7c		; @1E59 217C4D  yes, load HL with speed bit patterns for orange ghost normal state
	inc     (hl)		; @1E5C 34  increase

j_1e5d:
	ld hl,orange_tile_dy		; @1E5D 211A4D  load HL with address for orange ghost Y tile changes
	ld      a,(hl)		; @1E60 7E  load A with orange ghost Y tile changes
	and     a		; @1E61 A7  is the orange ghost moving left-right or right-left ?
	jp      z,j_1e72		; @1E62 CA721E  yes, skip ahead

	ld      a,(orange_y)		; @1E65 3A064D  no, load A with orange ghost Y position
	and     #07		; @1E68 E607  mask bits
	cp      #04		; @1E6A FE04  is orange ghost in the middle of the tile ?
	jp      z,j_1e7c		; @1E6C CA7C1E  yes, skip ahead

	jp      j_1ebb		; @1E6F C3BB1E  no, jump ahead

j_1e72:
	ld      a,(orange_x)		; @1E72 3A074D  load A with orange ghost X position
	and     #07		; @1E75 E607  mask bits
	cp      #04		; @1E77 FE04  is orange ghost in the middle of the tile ?
	jp      nz,j_1ebb		; @1E79 C2BB1E  no, skip ahead

j_1e7c:
	ld      a,#04		; @1E7C 3E04  yes, A := #04
	call    j_1ed0		; @1E7E CDD01E  check to see if orange ghost is on the edge of the screen (tunnel)
	jr      c,j_1e9e		; @1E81 381B  yes, jump ahead

	ld      a,(orange_frightened)		; @1E83 3AAA4D  no, load A with orange ghost blue flag (0 = not blue)
	and     a		; @1E86 A7  is the orange ghost blue (edible) ?
	jp      z,j_1e90		; @1E87 CA901E  no, skip ahead

	rst     #28		; @1E8A EF  yes, insert task to handle orange ghost movement when power pill active
	db	#0F,#00	; @1E8B 0F00  task data
	jp      j_1e9e		; @1E8D C39E1E  skip ahead

j_1e90:
	ld      hl,(orange_tile_y)		; @1E90 2A104D  load HL with orange ghost Y,X tile position
	call    j_2052		; @1E93 CD5220  covert Y,X position in HL to color screen location
	ld      a,(hl)		; @1E96 7E  load A with color screen position of ghost
	cp      #1a		; @1E97 FE1A  == #1A ((this color marks zones where ghosts cannot change direction, e.g. above the ghost house in pac-man)
	jr      z,j_1e9e		; @1E99 2803  yes, skip next step

	rst     #28		; @1E9B EF  insert task to control orange ghost AI
	db	#0B,#00	; @1E9C 0B00  task data

j_1e9e:
	call    j_1f73		; @1E9E CD731F  check for and handle when orange ghost reverses directions
	ld ix,orange_tile_dy2		; @1EA1 DD21244D  load IX with orange ghost tile changes
	ld iy,orange_tile_y		; @1EA5 FD21104D  load IY with orange ghost tile position
	call    j_2000		; @1EA9 CD0020  HL := (IX) + (IY)
	ld      (orange_tile_y),hl		; @1EAC 22104D  store result into orange ghost tile position
	ld      hl,(orange_tile_dy2)		; @1EAF 2A244D  load HL with orange ghost tile changes
	ld      (orange_tile_dy),hl		; @1EB2 221A4D  store into orange ghost tile changes (A)
	ld      a,(orange_dir)		; @1EB5 3A2F4D  load A with orange ghost orientation
	ld      (orange_prev_dir),a		; @1EB8 322B4D  store into previous orange ghost orientation
j_1ebb:
	ld ix,orange_tile_dy		; @1EBB DD211A4D  load IX with orange ghost tile changes (A)
	ld iy,orange_y		; @1EBF FD21064D  load IY with orange ghost position
	call    j_2000		; @1EC3 CD0020  HL := (IX) + (IY)
	ld      (orange_y),hl		; @1EC6 22064D  store result into orange ghost position
	call    j_2018		; @1EC9 CD1820  convert sprite position into a tile position
	ld      (orange_tile_y2),hl		; @1ECC 22374D  store into orange ghost tile position 2
	ret		; @1ECF C9  return

; called from #1A3A while in demo mode
; called from #1BF9 when red ghost movement checking.  A is preloaded with #01
; if the ghost/pacman is on the edge of the screen, the carry flag is set, else it is cleared

j_1ed0:
	add     a,a		; @1ED0 87  A := A * 2
	ld      c,a		; @1ED1 4F  copy to C
	ld      b,#00		; @1ED2 0600  B := #00
	ld hl,pac_x		; @1ED4 21094D  load HL with pacman X position address
	add     hl,bc		; @1ED7 09  add offset to HL.  HL how has the ghost/pacman tile position address
	ld      a,(hl)		; @1ED8 7E  load A with ghost/pacman tile X position
	cp      #1d		; @1ED9 FE1D  has the ghost moved off the far right side of the screen?
	jp      nz,j_1ee3		; @1EDB C2E31E  no, skip next 2 steps

	ld      (hl),#3d		; @1EDE 363D  yes, change ghost/pacman X position to far left side of screen
	jp      j_1efc		; @1EE0 C3FC1E  jump ahead, set carry flag and return

j_1ee3:
	cp      #3e		; @1EE3 FE3E  has the ghost/pacman moved off the far left side of the screen ?
	jp      nz,j_1eed		; @1EE5 C2ED1E  no, skip next 2 steps

	ld      (hl),#1e		; @1EE8 361E  yes, change ghost/pacman X position to far right side of screen
	jp      j_1efc		; @1EEA C3FC1E  jump ahead, set carry flag and return

j_1eed:
	ld      b,#21		; @1EED 0621  B := #21
	sub     b		; @1EEF 90  subtract from ghost/pacman X position.  is the ghost on the far right edge ?
	jp      c,j_1efc		; @1EF0 DAFC1E  yes, set carry flag and return

	ld      a,(hl)		; @1EF3 7E  else load A with ghost/pacman tile X position
	ld      b,#3b		; @1EF4 063B  B := #3B
	sub     b		; @1EF6 90  subtract.  is the ghost/pacman on the far left edge?
	jp      nc,j_1efc		; @1EF7 D2FC1E  yes, set carry flag and return

	and     a		; @1EFA A7  else clear carry flag
	ret		; @1EFB C9  return

j_1efc:
	scf		; @1EFC 37  set carry flag   
	ret		; @1EFD C9  return

; check for reverse direction of red ghost

j_1efe:
	ld      a,(red_reverse_flag)		; @1EFE 3AB14D  load A with red ghost change orientation flag
	and     a		; @1F01 A7  is the red ghost reversing direction ?
	ret     z		; @1F02 C8  no, return

; reverse direction of red ghost

	xor     a		; @1F03 AF  yes, A := #00
	ld      (red_reverse_flag),a		; @1F04 32B14D  clear red ghost change orientation flag
	ld      hl,#32ff		; @1F07 21FF32  load HL with table data - tile differences tables for movements
	ld      a,(red_prev_dir)		; @1F0A 3A284D  load A with previous red ghost orientation
	xor     #02		; @1F0D EE02  toggle bit 1
	ld      (red_dir),a		; @1F0F 322C4D  store into red ghost orientation
	ld      b,a		; @1F12 47  copy to B
	rst     #18		; @1F13 DF  load HL with tile difference for movements based on table at #32FF
	ld      (red_tile_dy2),hl		; @1F14 221E4D  store into red ghost tile changes
	ld      a,(game_mode_sub1)		; @1F17 3A024E  load A with main routine 1, subroutine #
	cp      #22		; @1F1A FE22  == #22 ?
	ret     nz		; @1F1C C0  no, return

	ld      (red_tile_dy),hl		; @1F1D 22144D  yes, store movement into alternate red ghost tile changes
	ld      a,b		; @1F20 78  load A with red ghost orientation
	ld      (red_prev_dir),a		; @1F21 32284D  store into previous red ghost orientation
	ret		; @1F24 C9  return

; check for reverse direction of pink ghost

j_1f25:
	ld      a,(pink_reverse_flag)		; @1F25 3AB24D  load A with pink ghost change orientation flag
	and     a		; @1F28 A7  is the pink ghost reversing direction ?
	ret     z		; @1F29 C8  no, return

; reverse direction of pink ghost

	xor     a		; @1F2A AF  yes, A := #00
	ld      (pink_reverse_flag),a		; @1F2B 32B24D  clear pink ghost change orientation flag
j_1f2e:
	ld      hl,#32ff		; @1F2E 21FF32  load HL with table data - tile differences tables for movements
	ld      a,(pink_prev_dir)		; @1F31 3A294D  load A with previous pink ghost orientation
	xor     #02		; @1F34 EE02  flip bit #1
	ld      (pink_dir),a		; @1F36 322D4D  store into pink ghost orientation
	ld      b,a		; @1F39 47  copy to B
	rst     #18		; @1F3A DF  load HL with new direction tile offsets
	ld      (pink_tile_dy2),hl		; @1F3B 22204D  store into pink ghost tile offsets
	ld      a,(game_mode_sub1)		; @1F3E 3A024E  load A with main routine 1, subroutine #
	cp      #22		; @1F41 FE22  == #22 (check for demo mode, pac-man only, when pac-man is chased by 4 ghosts on title screen)
	ret     nz		; @1F43 C0  no, return

	ld      (pink_tile_dy),hl		; @1F44 22164D  yes, store new direction tile offsets into alternate pink ghost tile changes
	ld      a,b		; @1F47 78  load A with pink ghost orientation
	ld      (pink_prev_dir),a		; @1F48 32294D  store into previous pink ghost direction
	ret		; @1F4B C9  return

; check for reverse direction of inky

j_1f4c:
	ld      a,(blue_reverse_flag)		; @1F4C 3AB34D  load A with blue ghost (inky) change orientation flag
	and     a		; @1F4F A7  is inky reversing direction ?
	ret     z		; @1F50 C8  no, return

; reverse direction of inky

;+-------1f51  af        xor     a		; yes, A := #00
	; ;; gap-fill from golden boots $1F51-$1F51
	db	#AF		; @1F51
	ld      (blue_reverse_flag),a		; @1F52 32B34D  clear inky ghost change orienation flag
j_1f55:
	ld      hl,#32ff		; @1F55 21FF32  load HL with table data - tile differences tables for movements
	ld      a,(blue_prev_dir)		; @1F58 3A2A4D  load A with previous inky orientation
	xor     #02		; @1F5B EE02  flip bit #1
	ld      (blue_dir),a		; @1F5D 322E4D  store into inky orientation
	ld      b,a		; @1F60 47  copy to B
	rst     #18		; @1F61 DF  load HL with new direction tile offsets
	ld      (blue_tile_dy2),hl		; @1F62 22224D  store into inky ghost tile offsets
	ld      a,(game_mode_sub1)		; @1F65 3A024E  load A with main routine 1, subroutine #
	cp      #22		; @1F68 FE22  == #22 ? (check for demo mode, pac-man only, when pac-man is chased by 4 ghosts on title screen)
	ret     nz		; @1F6A C0  no, return

	ld      (blue_tile_dy),hl		; @1F6B 22184D  yes, store new direction tile offsets into alternate inky ghost tile changes
	ld      a,b		; @1F6E 78  load A with inky orientation
	ld      (blue_prev_dir),a		; @1F6F 322A4D  store into previous inky direction
	ret		; @1F72 C9  return

; check for reverse direction of orange ghost

j_1f73:
	ld      a,(orange_reverse_flag)		; @1F73 3AB44D  load A with orange ghost change orientation flag
	and     a		; @1F76 A7  is orange ghost reversing direction ?
	ret     z		; @1F77 C8  no, return

; reverse direction of orange ghost

	xor     a		; @1F78 AF  yes, A := #00
	ld      (orange_reverse_flag),a		; @1F79 32B44D  clear orange ghost change orientation flag
j_1f7c:
	ld      hl,#32ff		; @1F7C 21FF32  load HL with table data - tile differences tables for movements
	ld      a,(orange_prev_dir)		; @1F7F 3A2B4D  load A with previous orange ghost orienation
	xor     #02		; @1F82 EE02  flip bit #1
	ld      (orange_dir),a		; @1F84 322F4D  store into orange ghost orienation
	ld      b,a		; @1F87 47  copy to B
	rst     #18		; @1F88 DF  load HL with new direction tile offsets
	ld      (orange_tile_dy2),hl		; @1F89 22244D  store into orange ghost tile offsets
	ld      a,(game_mode_sub1)		; @1F8C 3A024E  load A with main routine 1, subroutine #
	cp      #22		; @1F8F FE22  == #22 ? (check for demo mode, pac-man only, when pac-man is chased by 4 ghosts on title screen)
	ret     nz		; @1F91 C0  no, return

	ld      (orange_tile_dy),hl		; @1F92 221A4D  yes, store new direction tile offsets into alternate orange ghost tile changes
	ld      a,b		; @1F95 78  load A with orange ghost orienation
	ld      (orange_prev_dir),a		; @1F96 322B4D  store into previous orange ghost direction
	ret		; @1F99 C9  return

	db	#21	; @1F9A 21  junk

	;; new for INTERRUPT MODE 1
	;; rst 38 continuation  (vblank)
	;; This code not found in original hardware 

j_1f9b:
	push	af		; @1F9B F5  save AF
	ld	a,i		; @1F9C ED57  load A with interrupt vector
	or      a		; @1F9E B7  check to see if we're in test mode
	jr      z,j_1fa5		; @1F9F 2804  jp, pop, to 3000 if yes

	; not in test mode

	pop     af		; @1FA1 F1  restore AF
	jp      j_008d		; @1FA2 C38D00  continue the original handler

	; in test mode

j_1fa5:
	pop     af		; @1FA5 F1  restore AF
	jp      j_3000		; @1FA6 C30030  we're in init, continue testing


;	db	#00,#00,#00,#00,#00,#00	; @1F9A 000000000000
;	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @1FA0 00000000000000000000000000000000
	; ;; gap-fill from golden boots $1FA9-$1FAF
	db	#00,#00,#00,#00,#00,#00,#00		; @1FA9
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @1FB0 00000000000000000000000000000000


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; patch to fix the green-eye ghost
; by don hodges 1/19/2009
; part 2/2 (continuation from #1AB1)
;
; 	1FB0 	3A CB 4D	LD	a,(#4DCB)	; load A with energizer timer
; 	1FB3	FE 01		CP	#01		; is this energizer a "reverse-only" ?
; 	1FB5	CA C1 1A	JP	Z,#1AC1		; yes, jump back without bothering to change the ghost colors
;	1FB8	DD 36 03 11  	LD	(IX+#03),#11	; else set red ghost color to blue
; 	1FBC	C3 B5 1A	JP	#1AB5		; return and change rest of ghosts to blue and continue normally
; 	1FBF    55 80					; checksum fixes
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @1FC0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @1FD0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @1FE0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @1FF0 0000000000000000000000000000

	db	#5D,#E1	; @1FFE 5DE1  checksum bytes for #1000 to #1FFF

    

	;; fast/invincibilty ; HACK3
	;  Collision detection elimination

	; 1fb0  21a64d    ld      hl,#4da6  
	; 1fb3  5f        ld      e,a       
	; 1fb4  1600      ld      d,#00
	; 1fb6  19        add     hl,de     
	; 1fb7  7e        ld      a,(hl)    
	; 1fb8  a7        and     a
	; 1fb9  cac31f    jp      z,#1fc3
	; 1fbc  78        ld      a,b
	; 1fbd  32a44d    ld      (#4da4),a 
	; 1fc0  c36717    jp      #1767
	; 1fc3  3a4050    ld      a,(#5040)	; IN1
	; 1fc6  e620      and     #20		; Start 1
	; 1fc8  c8        ret     z		; not pressed, return
	; 1fc9  78        ld      a,b      
	; 1fca  32a44d    ld      (#4da4),a
	; 1fcd  c36717    jp      #1767 

	;; fast intermission fix ; HACK8 (2 of 3)

	; 1fc0  3a044e    ld      a, (#4e04)	; load in game mode
	; 1fc3  fe03      cp      #03		; ghost move mode (gameplay)
	; 1fc5  ca4518    jp      z, #1845	; return to the middle of an opcode?
	; 1fc7  3eff      ld      a, ff	; a = 0xff
	; 1fc9  be        cp      (hl)
	; 1fca  ca1118    jp      z, #1811
	; 1fcd  35        dec     (hl)
	; 1fce  c9        ret


	;; fast/invincibilty ; HACK3
	;  Speedup

	; 1fd0  3a4050    ld      a,(#5040)	; IN1
	; 1fd3  cb77      bit     6,a       	; Start 2
	; 1fd5  ca4518    jp      z,#1845  	; not pressed, jp to 1845
	; 1fd8  3eff      ld      a,ff     
	; 1fda  be        cp      (hl)     
	; 1fdb  ca1118    jp      z,#1811   
	; 1fde  35        dec     (hl)      
	; 1fdf  c9        ret
     
	; set to 0xbd for fast cheat checksum check hack  ; HACK2 (2 of 2)

	; 1ffd  00        nop     
	; 1ffe  5d e1

	; fast/invincibilty checksum ; HACK3

	; 1ffe bf dc

	;; fast intermission fix ; HACK8 (3 of 3)

	; 1ffe 8A 6D 



	;; this is a common function
	; IY is preloaded with sprite locations
	; IX is preloaded with offset to add
	; result is stored into HL
	; HL := (IX) + (IY)

j_2000:
	ld      a,(iy+#00)		; @2000 FD7E00  load A with IY value (Y position)
	add     a,(ix+#00)		; @2003 DD8600  add with destination Y value
	ld      l,a		; @2006 6F  store result into L
	ld      a,(iy+#01)		; @2007 FD7E01  load A with IY value (X position)
	add     a,(ix+#01)		; @200A DD8601  add with destination X value
	ld      h,a		; @200D 67  store result into H
	ret		; @200E C9  return

; load A with screen value of position computed in (IX) + (IY)

j_200f:
	call    j_2000		; @200F CD0020  HL := (IX) + (IY)
	call    j_0065		; @2012 CD6500  convert to screen position
	ld      a,(hl)		; @2015 7E  load A with the value in this screen position
	and     a		; @2016 A7  clear flags
	ret		; @2017 C9  return

; converts a sprite position into a tile position
; HL is preloaded with sprite position
; at end, HL is loaded with tile position

j_2018:
	ld      a,l		; @2018 7D  load A with X position
	srl     a		; @2019 CB3F
	srl     a		; @201B CB3F
	srl     a		; @201D CB3F  shift right 3 times
	add     a,#20		; @201F C620  add offset
	ld      l,a		; @2021 6F  store into L
	ld      a,h		; @2022 7C  load A with Y position
	srl     a		; @2023 CB3F
	srl     a		; @2025 CB3F
	srl     a		; @2027 CB3F  shift right 3 times
	add     a,#1e		; @2029 C61E  add offset
	ld      h,a		; @202B 67  store into H.  HL now has screen location
	ret		; @202C C9  return

; converts pac-mans sprite position into a grid position
; HL has sprite position at start, grid position at end
; 0065 jumps to here. 

j_202d:
	push af		; @202D F5  save AF
	push bc		; @202E C5  save BC
	ld   a,l		; @202F 7D  load A with L.  
	sub  #20		; @2030 D620  subtract #20.  
	ld   l,a		; @2032 6F  store back into L. 
	ld   a,h		; @2033 7C  load A with H.  
	sub  #20		; @2034 D620  subtract 20.  
	ld   h,a		; @2036 67  store back into H. 
	ld   b,#00		; @2037 0600  load B with #00
	sla  h		; @2039 CB24  shift left through carry flag.  mult by 2
	sla  h		; @203B CB24
	sla  h		; @203D CB24
	sla  h		; @203F CB24
	rl   b		; @2041 CB10
	sla  h		; @2043 CB24
	rl   b		; @2045 CB10
	ld   c,h		; @2047 4C
	ld   h,#00		; @2048 2600
	add  hl,bc		; @204A 09  add into HL
	ld   bc,#4040		; @204B 014040  load BC with grid offset
	add  hl,bc		; @204E 09  add into HL
	pop  bc		; @204F C1  restore BC
	pop  af		; @2050 F1  restore AF
	ret		; @2051 C9  return    

; converts pac-man or ghost Y,X position in HL to a color screen location

j_2052:
	call    j_0065		; @2052 CD6500  convert Y,X position to screen position
	ld      de,#0400		; @2055 110004  load DE with color grid offset
	add     hl,de		; @2058 19  add offset.  HL now has color screen position
	ret		; @2059 C9  return

; checks for ghost entering a slowdown area in a tunnel

j_205a:
	call    j_2052		; @205A CD5220  convert ghost Y,X position in HL to a color screen location
	ld      a,(hl)		; @205D 7E  load A with the color of the ghost's location
	cp      #1b		; @205E FE1B  == #1b ? (code for no change of direction, eg above the ghost home in pac-man)

; OTTOPATCH
;PATCH TO MAKE BIT 6 OF THE COLOR MAP INDICATE SLOW AREAS
;ORG 2060H
;JP SLOWMAP
;NOP
	jp      j_366f		; @2060 C36F36  jump to new patch for ms. pac man.  if no tunnel match, returns to #2066

	nop		; @2063 00  junk from ms-pac patch

	; original pac-man code:
	;
	; 2060: 20 04         jr   nz,$2066	; no, skip ahead
	; 2062: 3E 01         ld   a,$01	; else A := #01
	;

	ld      (bc),a		; @2064 02  store into ghost tunnel slowdown flag (pac-man only)
	ret		; @2065 C9  return (pac-man only)

j_2066:
	xor     a		; @2066 AF  A := #00
	ld      (bc),a		; @2067 02  store into ghost tunnel slowdown flag
	ret		; @2068 C9  return

; called from #105C

j_2069:
	ld      a,(pink_substate)		; @2069 3AA14D  load A with pink ghost substate
	and     a		; @206C A7  is the pink ghost at home ?
	ret     nz		; @206D C0  no, return

	ld      a,(died_this_level)		; @206E 3A124E  load A with flag that is 1 after dying in a level, reset to 0 if ghosts have left home
	and     a		; @2071 A7  is this flag set ?
	jp      z,j_207e		; @2072 CA7E20  no, skip ahead

	ld      a,(pills_after_death)		; @2075 3A9F4D  yes, load A with eaten pills counter after pacman has died in a level
	cp      #07		; @2078 FE07  == #07 ?
	ret     nz		; @207A C0  no, return

	jp      j_2086		; @207B C38620  yes, jump ahead and release pink ghost

j_207e:
	ld hl,pink_exit_limit		; @207E 21B84D  load HL with address of pink ghost counter to go out of home pill limit
	ld      a,(pink_exit_counter)		; @2081 3A0F4E  load A with counter incremented if orange, blue and pink ghosts are home and pacman is eating pills.
	cp      (hl)		; @2084 BE  has the counter been exceeded?
	ret     c		; @2085 D8  no, return

; releases pink ghost from the ghost house
; called from #1408

j_2086:
	ld      a,#02		; @2086 3E02  A := #02
	ld      (pink_substate),a		; @2088 32A14D  store into pink ghost substate to indicate he is leaving the ghost house
	ret		; @208B C9  return

; called from #105F

j_208c:
	ld      a,(blue_substate)		; @208C 3AA24D  load A with blue ghost (inky) substate
	and     a		; @208F A7  is inky at home ?
	ret     nz		; @2090 C0  no, return

	ld      a,(died_this_level)		; @2091 3A124E  yes, load A with flag that is 1 after dying in a level, reset to 0 if ghosts have left home
	and     a		; @2094 A7  is this flag set ?
	jp      z,j_20a1		; @2095 CAA120  no, skip ahead

	ld      a,(pills_after_death)		; @2098 3A9F4D  yes, load A with eaten pills counter after pacman has died in a level 
	cp      #11		; @209B FE11  == #11 ?
	ret     nz		; @209D C0  no, return

	jp      j_20a9		; @209E C3A920  yes, skip ahead and release inky

j_20a1:
	ld hl,blue_exit_limit		; @20A1 21B94D  load HL with address of inky counter to go out of home pill limit
	ld      a,(blue_exit_counter)		; @20A4 3A104E  load A with counter incremented if blue ghost and orange ghost is home and pacman is eating pills.
	cp      (hl)		; @20A7 BE  has the counter been exceeded ?
	ret     c		; @20A8 D8  no, return

; releases blue ghost (inky) from the ghost house
; called from #1412

j_20a9:
	ld      a,#03		; @20A9 3E03  A := #03
	ld      (blue_substate),a		; @20AB 32A24D  store in inky's ghost state
	ret		; @20AE C9  return

; called from #1062

j_20af:
	ld      a,(orange_substate)		; @20AF 3AA34D  load A with orange ghost substate
	and     a		; @20B2 A7  is orange ghost at home ?
	ret     nz		; @20B3 C0  no, return

	ld      a,(died_this_level)		; @20B4 3A124E  yes, load A with flag that is 1 after dying in a level, reset to 0 if ghosts have left home
	and     a		; @20B7 A7  is this flag set ?
	jp      z,j_20c9		; @20B8 CAC920  no, skip ahead

	ld      a,(pills_after_death)		; @20BB 3A9F4D  yes, load A with eaten pills counter after pacman has died in a level
	cp      #20		; @20BE FE20  == #20 ?
	ret     nz		; @20C0 C0  no, return

	xor     a		; @20C1 AF  yes, A := #00
	ld      (died_this_level),a		; @20C2 32124E  clear flag that is 1 after dying in a level, reset to 0 if ghosts have left home
	ld      (pills_after_death),a		; @20C5 329F4D  clear eaten pills counter after pacman has died in a level
	ret		; @20C8 C9  return

j_20c9:
	ld hl,orange_exit_limit		; @20C9 21BA4D  load HL with address of orange ghost to go out of home pill limit
	ld      a,(orange_exit_counter)		; @20CC 3A114E  load A with counter incremented if orange ghost is home alone and pacman is eating pills
	cp      (hl)		; @20CF BE  has the counter been exceeded ?
	ret     c		; @20D0 D8  no, return
;`
; releases orange ghost from the ghost house
; called from #141b

j_20d1:
	ld      a,#03		; @20D1 3E03  A := #03
	ld      (orange_substate),a		; @20D3 32A34D  store into orange ghost state
	ret		; @20D6 C9  return

; checks for and sets the difficulty flags based on number of pellets eaten
; called from #1B40

j_20d7:
	ld      a,(orange_substate)		; @20D7 3AA34D  load A with orange ghost state
	and     a		; @20DA A7  is the ghost living in the ghost house?
	ret     z		; @20DB C8  yes, return

	ld hl,dots_eaten		; @20DC 210E4E  load HL with number of pellets eaten address
	ld      a,(cruise_elroy_1)		; @20DF 3AB64D  load A with first difficulty flag
	and     a		; @20E2 A7  has flag been set ?
	jp      nz,j_20f4		; @20E3 C2F420  yes, skip ahead

	ld      a,#F4		; @20E6 3EF4  no, A := F4
	sub     (hl)		; @20E8 96  subract number of pellets eaten
	ld      b,a		; @20E9 47  load B with the result
	ld      a,(elroy1_pill_threshold)		; @20EA 3ABB4D  load A with remainder of pills when first diff. flag is set
	sub     b		; @20ED 90  subtract the result found above.  is it time to set the flag ?
	ret     c		; @20EE D8  no, return

	ld      a,#01		; @20EF 3E01  A := #01
	ld      (cruise_elroy_1),a		; @20F1 32B64D  set 1st difficulty flag so red ghost goes for pacman

j_20f4:
	ld      a,(cruise_elroy_2)		; @20F4 3AB74D  load A with 2nd difficulty flag
	and     a		; @20F7 A7  2nd difficulty flag set yet ?
	ret     nz		; @20F8 C0  no, return

	ld      a,#F4		; @20F9 3EF4  else A := F4
	sub     (hl)		; @20FB 96  subtract number of pellets eaten
	ld      b,a		; @20FC 47  save result into B
	ld      a,(elroy2_pill_threshold)		; @20FD 3ABC4D  load A with remainder of pills when second diff. flag is set
	sub     b		; @2100 90  subract result computed above.  is it time to set the 2nd difficulty flag?
	ret     c		; @2101 D8  no, return

	ld      a,#01		; @2102 3E01  yes, A := #01
	ld      (cruise_elroy_2),a		; @2104 32B74D  set 2nd difficulty flag
	ret		; @2107 C9  return

; arrive here from #0A44 when 1st intermission starts

	jp      j_3435		; @2108 C33534  jump to new ms. pac man routine

; Pac-man code:
; 2108  3a064e	ld	a,(#4e06)
; end pac-man code

; junk from pac-man

	rst  #20		; @210B E7  jump based on A
	db	#1A,#21	; @210C 1A21  #211A
	db	#40,#21	; @210E 4021  #2140
	db	#4B,#21	; @2110 4B21  #214B
	db	#0C,#00	; @2112 0C00  #000C
	db	#70,#21	; @2114 7021  #2170
	db	#7B,#21	; @2116 7B21  #217B
	db	#86,#21	; @2118 8621  #2186

	ld	a,(pac_tile_x)		; @211A 3A3A4D
	sub	#21		; @211D D621
	jr      nz,j_2130		; @211F 200F

	inc     a		; @2121 3C
	ld      (red_substate),a		; @2122 32A04D
	ld      (cruise_elroy_2),a		; @2125 32B74D
	call    j_0506		; @2128 CD0605

;

j_212b:
	ld hl,cutscene1_state		; @212B 21064E  load HL with state in first cutscene
	inc     (hl)		; @212E 34  increase
	ret		; @212F C9  return

j_2130:
	call    j_1806		; @2130 CD0618
	call    j_1806		; @2133 CD0618
j_2136:
	call    j_1b36		; @2136 CD361B
	call    j_1b36		; @2139 CD361B
	call    j_0e23		; @213C CD230E  change animation of ghosts every 8th frame
	ret		; @213F C9

	ld      a,(pac_tile_x)		; @2140 3A3A4D
	sub     #1e		; @2143 D61E
	jp      nz,j_2130		; @2145 C23021
	jp      j_212b		; @2148 C32B21

	ld      a,(red_tile_x2)		; @214B 3A324D
	sub     #1e		; @214E D61E
	jp      nz,j_2136		; @2150 C23621

	call    j_1a70		; @2153 CD701A
	xor	a		; @2156 AF  A: = #00
	ld	(CH2_E_NUM),a		; @2157 32AC4E  clear sound channel 2
	ld	(CH3_E_NUM),a		; @215A 32BC4E  clear sound channel 3
	call    j_05a5		; @215D CDA505
	ld      (pac_tile_dy),hl		; @2160 221C4D
	ld      a,(pac_wanted_dir)		; @2163 3A3C4D
	ld      (pac_dir),a		; @2166 32304D
	rst     #30		; @2169 F7  set timed task to to increase state in 1st cutscene (cutscene1_state)
	db	#45,#07,#00	; @216A 450700  task timer=#45, task=7, param=0     
	jp      j_212b		; @216D C32B21

	ld      a,(red_tile_x2)		; @2170 3A324D
	sub     #2f		; @2173 D62F
	jp      nz,j_2136		; @2175 C23621

	jp      j_212b		; @2178 C32B21

	ld      a,(red_tile_x2)		; @217B 3A324D
	sub     #3d		; @217E D63D
	jp      nz,j_2130		; @2180 C23021

	jp      j_212b		; @2183 C32B21

	call    j_1806		; @2186 CD0618
	call    j_1806		; @2189 CD0618
	ld      a,(pac_tile_x)		; @218C 3A3A4D
	sub     #3d		; @218F D63D
	ret     nz		; @2191 C0

	ld      (cutscene1_state),a		; @2192 32064E
j_2195:
	rst     #30		; @2195 F7  set timed task to increase main subroutine number (level_state)
	db	#45,#00,#00	; @2196 450000  task timer = #45, task = 0, parameter = 0     
	ld hl,level_state		; @2199 21044E
	inc     (hl)		; @219C 34  increase main subroutine number
	ret		; @219D C9  return

; arrive here from #0A44 when 2nd intermission begins

	ld      a,(cutscene2_state)		; @219E 3A074E  load A with 2nd cutscene subroutine number
	jp      j_344f		; @21A1 C34F34  jump to new code for ms. pac-man

;; pac-man code:
; 21a1  fd21d241  ld      iy,#41d2
;; end pac-man code

; junk from pac-man

	db	#41	; @21A4 41  junk
	rst  #20		; @21A5 E7  jump based on A

	db	#C2,#21	; @21A6 C221  #21C2
	db	#0C,#00	; @21A8 0C00  #000C
	db	#E1,#21	; @21AA E121  #21E1
	db	#F5,#21	; @21AC F521  #21F5
	db	#0C,#22	; @21AE 0C22  #220C
	db	#1E,#22	; @21B0 1E22  #221E
	db	#44,#22	; @21B2 4422  #2244
	db	#5D,#22	; @21B4 5D22  #225D
	db	#0C,#00	; @21B6 0C00  #000C
	db	#6A,#22	; @21B8 6A22  #226A
	db	#0C,#00	; @21BA 0C00  #000C
	db	#86,#22	; @21BC 8622  #2286
	db	#0C,#00	; @21BE 0C00  #000C
	db	#8D,#22	; @21C0 8D22  #228D

	ld	a,#01		; @21C2 3E01
	ld	(#45D2),a		; @21C4 32D245
	ld      (#45d3),a		; @21C7 32D345
	ld      (#45f2),a		; @21CA 32F245
	ld      (#45f3),a		; @21CD 32F345
	call    j_0506		; @21D0 CD0605
	ld      (iy+#00),#60		; @21D3 FD360060
	ld      (iy+#01),#61		; @21D7 FD360161
	rst     #30		; @21DB F7  set timed task to increase state in 2nd cutscene (cutscene2_state)
	db	#43,#08,#00	; @21DC 430800  task timer = #43, task = 8, parameter = 0    
	jr      j_21f0		; @21DF 180F  skip ahead

	ld      a,(pac_tile_x)		; @21E1 3A3A4D
	sub     #2c		; @21E4 D62C
	jp      nz,j_2130		; @21E6 C23021
	inc     a		; @21E9 3C
	ld      (red_substate),a		; @21EA 32A04D
	ld      (cruise_elroy_2),a		; @21ED 32B74D

;

j_21f0:
	ld hl,cutscene2_state		; @21F0 21074E  load HL with state in second cutscene
	inc     (hl)		; @21F3 34  increase
	ret		; @21F4 C9  return

	ld      a,(red_x)		; @21F5 3A014D
	cp      #77		; @21F8 FE77
	jr      z,j_2201		; @21FA 2805  (5)

	cp      #78		; @21FC FE78
	jp      nz,j_2130		; @21FE C23021

j_2201:
	ld      hl,#2084		; @2201 218420
	ld      (speed_pat_diff2),hl		; @2204 224E4D
	ld      (#4d50),hl		; @2207 22504D
	jr      j_21f0		; @220A 18E4  (-28)

	ld      a,(red_x)		; @220C 3A014D
	sub     #78		; @220F D678
	jp      nz,j_2237		; @2211 C23722

	ld      (iy+#00),#62		; @2214 FD360062
	ld      (iy+#01),#63		; @2218 FD360163
	jr      j_21f0		; @221C 18D2  (-46)

	ld      a,(red_x)		; @221E 3A014D
	sub     #7b		; @2221 D67B
	jr      nz,j_2237		; @2223 2012  (18)

	ld      (iy+#00),#64		; @2225 FD360064
	ld      (iy+#01),#65		; @2229 FD360165
	ld      (iy+#20),#66		; @222D FD362066
	ld      (iy+#21),#67		; @2231 FD362167
	jr      j_21f0		; @2235 18B9  (-71)

j_2237:
	call    j_1806		; @2237 CD0618
	call    j_1806		; @223A CD0618
	call    j_1b36		; @223D CD361B
	call    j_0e23		; @2240 CD230E  change animation of ghosts every 8th frame
	ret		; @2243 C9

	ld      a,(red_x)		; @2244 3A014D
	sub     #7e		; @2247 D67E
	jr      nz,j_2237		; @2249 20EC  (-20)

	ld      (iy+#00),#68		; @224B FD360068
	ld      (iy+#01),#69		; @224F FD360169
	ld      (iy+#20),#6a		; @2253 FD36206A
	ld      (iy+#21),#6b		; @2257 FD36216B
	jr      j_21f0		; @225B 1893  (-109)

	ld      a,(red_x)		; @225D 3A014D
	sub     #80		; @2260 D680
	jr      nz,j_2237		; @2262 20D3  (-45)

	rst     #30		; @2264 F7  set timed task to increase state in 2nd cutscene (cutscene2_state)
	db	#4F,#08,#00	; @2265 4F0800  task timer = #4F, task = 8, parameter = 0     
	jr      j_21f0		; @2268 1886  jump back

	ld hl,red_x		; @226A 21014D
	inc     (hl)		; @226D 34
	inc     (hl)		; @226E 34
	ld      (iy+#00),#6c		; @226F FD36006C
	ld      (iy+#01),#6d		; @2273 FD36016D
	ld      (iy+#20),#40		; @2277 FD362040
	ld      (iy+#21),#40		; @227B FD362140
	rst     #30		; @227F F7  set timed task to increase state in 2nd cutscene (cutscene2_state)
	db	#4A,#08,#00	; @2280 4A0800  task timer = #4A, task = 8, parameter = 0     
	jp      j_21f0		; @2283 C3F021  jump back

	rst     #30		; @2286 F7  set timed task to increase state in 2nd cutscene (cutscene2_state)
	db	#54,#08,#00	; @2287 540800  task timer = #54, task = 8, parameter = 0    
	jp      j_21f0		; @228A C3F021  jump back

	xor     a		; @228D AF  A := #00
	ld      (cutscene2_state),a		; @228E 32074E  store into cutscene subroutine number
	ld hl,level_state		; @2291 21044E  load HL with main subroutine number
	inc     (hl)		; @2294 34
	inc     (hl)		; @2295 34  add 2 to main subroutine number
	ret		; @2296 C9  return

; arrive here from #0A44 for 3rd intermission

	ld      a,(cutscene3_state)		; @2297 3A084E  load A with 3rd cutscene subroutine number (pac-man only)
	jp      j_3469		; @229A C36934  jump to new code for ms. pac-man

;; Pac-man code
; 229a  e7        rst     #20		; jump based on A
; 229b  a7 22		; #22A7
;; end pac-man code

; junk from pac-man

	db	#BE,#22	; @229D BE22  #22BE
;	db	#0C,#00	; @229E 0C00  #000C
	; ;; gap-fill from golden boots $229F-$22A0
	db	#0C,#00		; @229F
	db	#DD,#22	; @22A1 DD22  #22DD
	db	#F5,#22	; @22A3 F522  #22F5
	db	#FE,#22	; @22A5 FE22  #22FE

; pac-man only

	ld	a,(pac_tile_x)		; @22A7 3A3A4D
	sub 	#25		; @22AA D625
	jp      nz,j_2130		; @22AC C23021
	inc     a		; @22AF 3C
	ld      (red_substate),a		; @22B0 32A04D
	ld      (cruise_elroy_2),a		; @22B3 32B74D
	call    j_0506		; @22B6 CD0605

; 

j_22b9:
	ld hl,cutscene3_state		; @22B9 21084E  load HL with state in third cutscene
	inc     (hl)		; @22BC 34  increase
	ret		; @22BD C9  return

; pac-man only
; referenced in #229D

	ld      a,(red_x)		; @22BE 3A014D
	cp      #FF		; @22C1 FEFF
	jr      z,j_22ca		; @22C3 2805  (5)
	cp      #FE		; @22C5 FEFE
	jp      nz,j_2130		; @22C7 C23021
j_22ca:
	inc     a		; @22CA 3C
	inc     a		; @22CB 3C
	ld      (red_x),a		; @22CC 32014D
	ld      a,#01		; @22CF 3E01
	ld      (red_reverse_flag),a		; @22D1 32B14D
	call    j_1efe		; @22D4 CDFE1E
	rst     #30		; @22D7 F7  set timed task to increase state in 3rd cutscene (cutscene3_state)
	db	#4A,#09,#00	; @22D8 4A0900  task timer = #4A, task = 9, parameter = 0     
	jr      j_22b9		; @22DB 18DC  jump back and return

; pac-man only 
; referenced in #22A1

	ld      a,(red_tile_x2)		; @22DD 3A324D
	sub     #2d		; @22E0 D62D
	jr      z,j_22b9		; @22E2 28D5  (-43)

j_22e4:
	ld      a,(red_y)		; @22E4 3A004D
	ld      (fruit_pos_lo),a		; @22E7 32D24D
	ld      a,(red_x)		; @22EA 3A014D
	sub     #08		; @22ED D608
	ld      (fruit_pos_hi),a		; @22EF 32D34D
	jp      j_2130		; @22F2 C33021

	ld      a,(red_tile_x2)		; @22F5 3A324D
	sub     #1e		; @22F8 D61E
	jr      z,j_22b9		; @22FA 28BD  (-67)

	jr      j_22e4		; @22FC 18E6  (-26)

; pac-man only
; refereneced in line #22A5

	xor     a		; @22FE AF  A := #00
	ld      (cutscene3_state),a		; @22FF 32084E  clear state in third cutscene
	rst     #30		; @2302 F7  set timed task to increase main subroutine number (level_state)
	db	#45,#00,#00	; @2303 450000  task timer = #45, task = #00, parameter = #00     
	ld hl,level_state		; @2306 21044E  load HL with level state subroutine #
	inc     (hl)		; @2309 34  increment
	ret		; @230A C9  return

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;; Main program start (reset)
	;; 0 -> 5000 - 5007  (special registers)
	;; irq off, sound off, flip off, etc.
	;; arrive here from #0005 after game has powered on
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


j_230b:
	ld hl,IN0		; @230B 210050  load HL with starting memory address
	ld      b,#08		; @230E 0608  For B = 1 to 8
	xor     a		; @2310 AF  A := #00
j_2311:
	ld      (hl),a		; @2311 77  clear memory
	inc     l		; @2312 2C  next memory
	djnz    j_2311		; @2313 10FC  next B

	;; Clear screen
	;; 40 -> 4000-43ff (Video RAM)

	ld      hl,#4000		; @2315 210040  load HL with start of Video RAM
	ld      b,#04		; @2318 0604  For B = 1 to 4

j_231a:
	ld      (watchdog),a		; @231A 32C050  kick the dog
	ld      (coin_counter_out),a		; @231D 320750  kick coin counter?
	ld      a,#40		; @2320 3E40  A := #40 (clear character)

j_2322:
	ld      (hl),a		; @2322 77  clear screen memory
	inc     l		; @2323 2C  next address (low byte)
	jr      nz,j_2322		; @2324 20FC  loop FF times
	inc     h		; @2326 24  next address (high byte)
	djnz    j_231a		; @2327 10F1  Next B

	;; 0f -> 4400 - 47ff (Color RAM)

	ld      b,#04		; @2329 0604  For B = 1 to 4

j_232b:
	ld      (watchdog),a		; @232B 32C050  kick the dog
	xor     a		; @232E AF  A := #00
	ld      (coin_counter_out),a		; @232F 320750  kick coin counter?
	ld      a,#0f		; @2332 3E0F  A := #0F

j_2334:
	ld      (hl),a		; @2334 77  set color
	inc     l		; @2335 2C  next address (low byte)
	jr      nz,j_2334		; @2336 20FC  loop FF times
	inc     h		; @2338 24  next high address
	djnz    j_232b		; @2339 10F0  Next B

	;; test the interrupt hardware now
	; INTERRUPT MODE 1

	im      1		; @233B ED56  set interrupt mode 1
	
	nop		; @233D 00  no other setup is necessary..
	nop		; @233E 00  interrupts all go through 0x0038
	nop		; @233F 00
	nop		; @2340 00

	; Pac's routine: (Puckman, Pac-Man Plus)
	; INTERRUPT MODE 2
	; 233b  ed5e      im      2		; interrupt mode 2
	; 233d  3efa      ld      a,fa
	; 233f  d300      out     (#00),a	; interrupt vector -> 0xfa #3ffa vector to #3000
	; see also "INTERRUPT MODE 2" above...


	xor     a		; @2341 AF  A := #00
	ld      (coin_counter_out),a		; @2342 320750  clear coin counter
	inc     a		; @2345 3C  A := #01    (a++)
	ld      (IN0),a		; @2346 320050  Enable interrupts (pcb)
	ei		; @2349 FB  Enable interrupts (cpu)
	halt		; @234A 76  WAIT for interrupt then jump 0x0038 

		
	;; main program init
	;; perhaps a contiuation from 3295

j_234b:
	ld      (watchdog),a		; @234B 32C050  kick dog
	ld      sp,#4fc0		; @234E 31C04F  set stack pointer

	;; reset custom registers.  Set them to 0

	xor     a		; @2351 AF  A := #00
	ld hl,IN0		; @2352 210050  load HL with starting address #5000
	ld      bc,#0808		; @2355 010808  load counters with #08 and #08
	rst     #8		; @2358 CF  clear #5000 through #5007

	;; clear ram

	ld hl,spr_unk_4c00		; @2359 21004C  load HL with start of RAM
	ld      b,#BE		; @235C 06BE  load counter with BE
	rst     #8		; @235E CF  clear #4000 through #40BD
	rst     #8		; @235F CF  clear #40BE through #41BD
	rst     #8		; @2360 CF  clear #41BE through #42BD
	rst     #8		; @2361 CF  clear #42BE through #43BD

	;; clear sound registers, color ram, screen, task list 

	ld hl,IN1		; @2362 214050  load HL with start of sound output
	ld      b,#40		; @2365 0640  set counter at #40
	rst     #8		; @2367 CF  clear #5040 through #5079

	ld      (watchdog),a		; @2368 32C050  kick dog
	call    j_240d		; @236B CD0D24  clear color ram
	ld      (watchdog),a		; @236E 32C050  kick dog
	ld      b,#00		; @2371 0600  set parameter to clear entire screen
	call    j_23ed		; @2373 CDED23  clear entire screen
	ld      (watchdog),a		; @2376 32C050  kick dog
	ld hl,main_task_list		; @2379 21C04C  HL := #4CC0
	ld      (task_list_tail_ptr),hl		; @237C 22804C  store into  pointer to the end of the tasks list
	ld      (task_list_head_ptr),hl		; @237F 22824C  store into  pointer to the beginning of the tasks list
	ld      a,#FF		; @2382 3EFF  set data to FF
	ld      b,#40		; @2384 0640  set counter to #40
	rst     #8		; @2386 CF  store data into #4CC0 through #4CFF = clears task list
	ld      a,#01		; @2387 3E01  A := #01
	ld      (IN0),a		; @2389 320050  enable software interrupts
	ei		; @238C FB  enable hardware interrupts

; process the task list, a core game loop

j_238d:
	ld      hl,(task_list_head_ptr)		; @238D 2A824C  load HL with the pointer to beginning of tasks list
	ld      a,(hl)		; @2390 7E  load A with the task value
	and     a		; @2391 A7  examine value
	jp      m,j_238d		; @2392 FA8D23  if sign negative (EG FF), loop again; nothing to do

	ld      (hl),#FF		; @2395 36FF  else store FF into task value
	inc     l		; @2397 2C  next task parameter
	ld      b,(hl)		; @2398 46  load B with task parameter
	ld      (hl),#FF		; @2399 36FF  store FF into task parameter value
	inc     l		; @239B 2C  next task
	jr      nz,j_23a0		; @239C 2002  If HL has not reached #4C00 then skip next step
	ld      l,#C0		; @239E 2EC0  else load L with C0 to make HL #4CC0
j_23a0:
	ld      (task_list_head_ptr),hl		; @23A0 22824C  store result into the task pointer

	ld	hl,#238D		; @23A3 218D23  load HL with return address
	push	hl		; @23A6 E5  push to stack
	rst	#20		; @23A7 E7  jump based on A

	db	#ED,#23	; @23A8 ED23  #23ED	; A=00	; clears the whole screen if parameter == 0, just the maze if parameter == 1
	db	#D7,#24	; @23AA D724  #24D7	; A=01	; colors the maze depending on parameter. if parameter == 2, then color maze white
	db	#19,#24	; @23AC 1924  #2419	; A=02	; draws the maze
	db	#48,#24	; @23AE 4824  #2448	; A=03	; draws the pellets
	db	#3D,#25	; @23B0 3D25  #253D	; A=04	; resets a bunch of memories based on parameter 0 or 1
	db	#8B,#26	; @23B2 8B26  #268B	; A=05	; resets ghost home counter and if parameter = 1, sets red ghost to chase pac man
	db	#0D,#24	; @23B4 0D24  #240D	; A=06	; clears the color RAM
	db	#98,#26	; @23B6 9826  #2698	; A=07	; set game to demo mode
	db	#30,#27	; @23B8 3027  #2730	; A=08	; red ghost AI
	db	#6C,#27	; @23BA 6C27  #276C	; A=09	; pink ghost AI
	db	#A9,#27	; @23BC A927  #27A9	; A=0A	; blue ghost (inky) AI	
	db	#F1,#27	; @23BE F127  #27F1	; A=0B	; orange ghost AI	
	db	#3B,#28	; @23C0 3B28  #283B	; A=0C	; red ghost movement when power pill active
	db	#65,#28	; @23C2 6528  #2865	; A=0D	; pink ghost movement when power pill active
	db	#8F,#28	; @23C4 8F28  #288F	; A=0E	; blue ghost (inky) movement when power pill active
	db	#B9,#28	; @23C6 B928  #28B9	; A=0F	; orange ghost movement when power pill active
	db	#0D,#00	; @23C8 0D00  #000D	; A=10	; sets up difficulty
	db	#A2,#26	; @23CA A226  #26A2	; A=11	; clears memories from #4D00 through #4DFF
	db	#C9,#24	; @23CC C924  #24C9	; A=12	; sets up coded pills and power pills memories
	db	#35,#2A	; @23CE 352A  #2A35	; A=13	; clears the sprites
	db	#D0,#26	; @23D0 D026  #26D0	; A=14	; checks all dip switches and assigns memories to the settings indicated
	db	#87,#24	; @23D2 8724  #2487	; A=15	; update the current screen pill config to video ram
	db	#E8,#23	; @23D4 E823  #23E8	; A=16	; increase main subroutine number (level_state)
	db	#E3,#28	; @23D6 E328  #28E3	; A=17	; controls pac-man AI during demo.  pacman will avoid pink ghost, or chase it when red ghost is edible
	db	#E0,#2A	; @23D8 E02A  #2AE0	; A=18	; draws "high score" and scores.  clears player 1 and 2 scores to zero.
	db	#5A,#2A	; @23DA 5A2A  #2A5A	; A=19	; update score.  B has code for items scored, draw score on screen, check for high score and extra lives
	db	#6A,#2B	; @23DC 6A2B  #2B6A	; A=1A	; draws remaining lives at bottom of screen
	db	#EA,#2B	; @23DE EA2B  #2BEA	; A=1B	; draws fruit at bottom right of screen

; OTTOPATCH
;MISCELLANEOUS HACKS THAT OCCUR WHEN PROMPTS ARE WRITTEN.
;!    ORG 23E0H
;!    WORD PROMPTHACKS
	db	#E3,#95	; @23E0 E395  #95E3	; A=1C	; used to draw text and some other functions  ; parameter lookup for text found at #36a5
	db	#A1,#2B	; @23E2 A12B  #2BA1	; A=1D	; write # of credits on screen
	db	#75,#26	; @23E4 7526  #2675	; A=1E	; clear fruit, pacman, and all ghosts
	db	#B2,#26	; @23E6 B226  #26B2	; A=1F	; writes points needed for extra life digits to screen

	ld hl,level_state		; @23E8 21044E  load HL with main subroutine number
	inc	(hl)		; @23EB 34  increase
	ret		; @23EC C9  return

; task #00, called from #23A7

j_23ed:
	ld	a,b		; @23ED 78  load A with parameter
	rst	#20		; @23EE E7  jump based on A
	db	#F3,#23	; @23EF F323  #23F3		; clears entire screen
	db	#00,#24	; @23F1 0024  #2400		; clears the maze

; clears the entire screen

	ld	a,#40		; @23F3 3E40  A := #40 (clear character)
	ld	bc,#0004		; @23F5 010400  set up counters
	ld      hl,#4000		; @23F8 210040  start of video ram
j_23fb:
	rst     #8		; @23FB CF  clear the screen
	dec     c		; @23FC 0D  loop done?
	jr      nz,j_23fb		; @23FD 20FC  no, loop again
	ret		; @23FF C9  return

; clears the maze only

	ld      a,#40		; @2400 3E40  A := #40 (clear character)
	ld      hl,#4040		; @2402 214040  load HL with start of maze area of screen
	ld      bc,#8004		; @2405 010480  set up counters
j_2408:
	rst     #8		; @2408 CF  clear screen memory
	dec     c		; @2409 0D  loop done ?
	jr      nz,j_2408		; @240A 20FC  no, loop again
	ret		; @240C C9  yes, return

; clears color ram

j_240d:
	xor     a		; @240D AF  A := #00
	ld      bc,#0004		; @240E 010400  set up counters
	ld      hl,#4400		; @2411 210044  load hL with start of color ram
j_2414:
	rst     #8		; @2414 CF  clear color ram
	dec     c		; @2415 0D  loop done ?
	jr      nz,j_2414		; @2416 20FC  no, loop again
	ret		; @2418 C9  return

	;; Draw out the maze to the screen

	ld      hl,#4000		; @2419 210040  load HL with start of video ram

; OTTOPATCH
;PATCH TO USE A MAZE FROM THE NEW MAZE TABLE RATHER THAN THE OLD MAZE
;ORG 241CH
;CALL WALLADR
	call    j_946a		; @241C CD6A94  ms. pac patch to retreive map info.  loads BC based on the map

j_241f:
	ld      a,(bc)		; @241F 0A  get maze data
	and     a		; @2420 A7  == #00 ?
	ret     z		; @2421 C8  yes, the end of the level data, return
	jp      m,j_242c		; @2422 FA2C24  if it's < #80, data is an offset.  if not, jump ahead
	ld      e,a		; @2425 5F  else copy to E
	ld      d,#00		; @2426 1600  D := #00
	add     hl,de		; @2428 19  adjust VRAM pointer
	dec     hl		; @2429 2B  decrease to offset the upcoming increase
	inc     bc		; @242A 03  point to next data
	ld      a,(bc)		; @242B 0A  load next data from table

j_242c:
	inc     hl		; @242C 23  screen location
	ld      (hl),a		; @242D 77  store maze data to screen
	push    af		; @242E F5  save AF
	push    hl		; @242F E5  save HL
	ld      de,#83e0		; @2430 11E083  load DE with mirror position offset
	ld      a,l		; @2433 7D  load A with L
	and     #1f		; @2434 E61F  mask bits
	add     a,a		; @2436 87  A := A * 2
	ld      h,#00		; @2437 2600  H := #00
	ld      l,a		; @2439 6F  load L with A
	add     hl,de		; @243A 19  add offset to HL
	pop     de		; @243B D1  restore HL into DE
	and     a		; @243C A7  clear carry flag
	sbc     hl,de		; @243D ED52  subtract offset
	pop     af		; @243F F1  restore AF
	xor     #01		; @2440 EE01  flip bit 1 of maze data = calculate reflected maze tile
	ld      (hl),a		; @2442 77  store reflected tile in position
	ex      de,hl		; @2443 EB  DE <-> HL
	inc     bc		; @2444 03  next data
	jp      j_241f		; @2445 C31F24  loop again

	; draw out the player pills

	ld      hl,#4000		; @2448 210040  load HL with start of video ram
; OTTOPATCH
;PATCH TO DO SAME THING FOR DOTS
;NOTE THAT THE DOT TABLE IS USED TWICE, ONCE TO WRITE THE DOTS ONTO
;THE SCREEN THEN AGAIN TO SEE WHICH DOTS HAVE BEEN EATEN.
;ORG 244BH
;JP DOTSA1

	jp      j_947c		; @244B C37C94  jump to ms pac patch.  it returns to #2453

	db	#4E	; @244E 4E  junk
	ld      iy,#35b5		; @244F FD21B535  points to pill data (pac-man only)

	ld      d,#00		; @2453 1600  D := #00
	ld      b,#1e		; @2455 061E  load B with total # of pill entries

j_2457:
	ld      c,#08		; @2457 0E08  C := #08
	ld      a,(ix+#00)		; @2459 DD7E00  load A with pill entry

j_245c:
	ld      e,(iy+#00)		; @245C FD5E00  load E with current offset
	add     hl,de		; @245F 19  adjust vram
	rlca		; @2460 07  rotate left.  was there a bit at bit 7 ?
	jr      nc,j_2465		; @2461 3002  skip pill if no
	ld      (hl),#10		; @2463 3610  else draw pill onscreen
j_2465:
	inc     iy		; @2465 FD23  next table data
	dec     c		; @2467 0D  decrease counter
	jr      nz,j_245c		; @2468 20F2  loop again if not zero

	inc     ix		; @246A DD23  go to next pill entry
	dec     b		; @246C 05  decrease counter
	jr      nz,j_2457		; @246D 20E8  loop again if not zero

	ld hl,power_pill_data		; @246F 21344E  load HL with power pills data entries address

; OTTOPATCH
;PATCH TO USE NEW ENERGIZER LOCATIONS
;ORG 2472H
;JP DRAWEN
	jp      j_94ec		; @2472 C3EC94  jump to ms pac patch for power pellet drawing

	; pac's version:
;2472  116440	ld	de,#4064	; power pellet address (upper right)

	; pac-man only:
	ldi		; @2475 EDA0
	ld      de,#4078		; @2477 117840  power pellet address (lower right)
	ldi		; @247A EDA0
	ld      de,#4384		; @247C 118443  power pellet address (upper left)
	ldi		; @247F EDA0
	ld      de,#4398		; @2481 119843  power pellet address (lower left)
	ldi		; @2484 EDA0
	ret		; @2486 C9  return  

	;; update the current screen pill config to video ram
	; called from #0912
	; called from #23A7 as task #15

j_2487:
	ld      hl,#4000		; @2487 210040  load HL with start of video ram

; OTTOPATCH
;ORG 248AH
;JP DOTSA2
	jp      j_9481		; @248A C38194  jump to Ms Pac Man patch.  returns to #2492.  Loads IY with start of pellet table based on level

	db	#4E	; @248D 4E  junk
	; pac's version:
;248a  dd21164e  ld      ix,#4e16

	ld      iy,#35b5		; @248E FD21B535  load IY with start of pill data table (pac-man only)

	ld      d,#00		; @2492 1600  D := #00
	ld      b,#1e		; @2494 061E  B := #1E (used for loop counter)
j_2496:
	ld      c,#08		; @2496 0E08  C := #08 (used for loop counter)

j_2498:
	ld      e,(iy+#00)		; @2498 FD5E00  load E with pellet data
	add     hl,de		; @249B 19  add to video ram counter
	ld      a,(hl)		; @249C 7E  load A with the value that is already there
	cp      #10		; @249D FE10  == #10 ?  (is there a dot on the screen ?)
	scf		; @249F 37  set carry flag
	jr      z,j_24a3		; @24A0 2801  if equal then skip next step
	ccf		; @24A2 3F  invert the carry flag
j_24a3:
	rl      (ix+#00)		; @24A3 DDCB0016  rotate left.  sets or clears the bit used for this code
	inc     iy		; @24A7 FD23  next pellet
	dec     c		; @24A9 0D  decrease counter.   is this loop done ?
	jr      nz,j_2498		; @24AA 20EC  no, loop again

	inc     ix		; @24AC DD23  next coded address
	dec     b		; @24AE 05  decrease counter.  is this loop done?
	jr      nz,j_2496		; @24AF 20E5  no, loop again

	ld      hl,#4064		; @24B1 216440  load HL with power pellet address

; OTTOPATCH
;ORG 24B4H
;JP READEN
	jp      j_9504		; @24B4 C30495  jump to ms. pac patch for pellet check routine and return

	; pac's version:
; 24b4  11344e    ld      de,#4e34	;  power pellet address
	;

	; this code is pac-man only:

	ldi		; @24B7 EDA0
	ld      hl,#4078		; @24B9 217840  power pellet address
	ldi		; @24BC EDA0
	ld      hl,#4384		; @24BE 218443  power pellet address
	ldi		; @24C1 EDA0
	ld      hl,#4398		; @24C3 219843  power pellet address
	ldi		; @24C6 EDA0
	ret		; @24C8 C9

; called from #23A7 as task #12
; called from #0880, #0a89, and other places
; sets up the pills and power pills??

j_24c9:
	ld hl,pill_bitmap		; @24C9 21164E  load HL with pill address start
	ld      a,#FF		; @24CC 3EFF  A := FF
	ld      b,#1e		; @24CE 061E  load counter with #1E addresses to fill
	rst     #8		; @24D0 CF  store FF into #4E16 through #4E16 + #1E
	ld      a,#14		; @24D1 3E14  A := #14
	ld      b,#04		; @24D3 0604  load counter with #04
	rst     #8		; @24D5 CF  store #14 into next 4 addresses (power pills)
	ret		; @24D6 C9  return

; sets up the maze color
; called from #23A7 as task #01

	ld      e,b		; @24D7 58  save task parameter to E, for use later at #24F3
	ld      a,b		; @24D8 78  load A with task parameter
	cp      #02		; @24D9 FE02  == # 02 ?
	ld      a,#1f		; @24DB 3E1F  load A with #1F = white color for flashing at end of level

; OTTOPATCH
;PATCH TO CALL AMAZING NEW COLOR ROUTINE INSTEAD OF USING THE SAME DULL BLUE
;ORG 24DDH
	jp      j_9580		; @24DD C38095  jump to new sub to select screen color (ms pac patch.  returns to #24E1)

;; Pac-man code:
; 24dd  2802      jr      z,#24e1	; was the task parameter set for white ?  Yes, skip next step
; 24df  3e10      ld      a,#10		; no, set color to blue
;; end pac-man code

	db	#10	; @24E0 10  junk from pac-man

; arrive back here from ms pac patch

j_24e1:
	ld	hl,#4440		; @24E1 214044  load HL with screen color RAM start addr.
	ld      bc,#8004		; @24E4 010480  load counters (#80 * #4 = #200 (or 512 decimal) screen locations)

j_24e7:
	rst     #8		; @24E7 CF  color the screen
	dec     c		; @24E8 0D  decrease counter. are we done?
	jr      nz,j_24e7		; @24E9 20FC  no, loop again

	ld      a,#0f		; @24EB 3E0F  else load A with white color
	ld      b,#40		; @24ED 0640  load counter with #40
	ld      hl,#47c0		; @24EF 21C047  start address at top left of screen
	rst     #8		; @24F2 CF  color top bar white
	ld      a,e		; @24F3 7B  load A with E, this is the task parameter saved at #24D7
	cp      #01		; @24F4 FE01  == #01 ?
	ret     nz		; @24F6 C0  no, return

	ld      a,#1a		; @24F7 3E1A  else A := #1A.  this is the color code to prevent ghosts from changing directions above the ghost house and next to where pacman starts

; OTTOPATCH
;PATCH TO MAKE THE SLOW AREAS OF THE SCREEN DEPENDENT ON THE MAZE
;ORG 24F9H
;JP SCOLOR
	jp      j_95c3		; @24F9 C3C395  jump to new ms. pac man patch to color the tunnels with invisible slowdown "paint".  returns to #2534

;; Pac-man code:
; 24f9  112000    ld      de,#0020	; load DE with column offset
;; end pac-man code


; pac-man only

	ld      b,#06		; @24FC 0606  for B = 1 to 6
	ld      ix,#45a0		; @24FE DD21A045  load IX with start of color memory (near center right of screen)

j_2502:
	ld      (ix+#0c),a		; @2502 DD770C  paint area above ghost house with color code to prevent changing directions
	ld      (ix+#18),a		; @2505 DD7718  paint area above pacman start area with color code to prevent changing directions
	add     ix,de		; @2508 DD19  add offset for next column
	djnz    j_2502		; @250A 10F6  loop until done

	ld      a,#1b		; @250C 3E1B  load A with color code to slow down ghosts in tunnel
	ld      b,#05		; @250E 0605  for B = 1 to 5
	ld      ix,#4440		; @2510 DD214044  load IX with start of color memory

j_2514:
	ld      (ix+#0e),a		; @2514 DD770E  paint tunnel with slowdown color
	ld      (ix+#0f),a		; @2517 DD770F  paint tunnel with slowdown color
	ld      (ix+#10),a		; @251A DD7710  paint tunnel with slowdown color
	add     ix,de		; @251D DD19  add offset for next column
	djnz    j_2514		; @251F 10F3  loop until done

	ld      b,#05		; @2521 0605  for B = 1 to 5
	ld      ix,#4720		; @2523 DD212047  load IX with start of color memory for left side of screen
j_2527:
	ld      (ix+#0e),a		; @2527 DD770E  paint tunnel with slowdown color
	ld      (ix+#0f),a		; @252A DD770F  paint tunnel with slowdown color
	ld      (ix+#10),a		; @252D DD7710  paint tunnel with slowdown color
	add     ix,de		; @2530 DD19  add offset for next column
	djnz    j_2527		; @2532 10F3  loop until done

; ms. pac resumes here

j_2534:
	ld      a,#18		; @2534 3E18  A := #18 = code for pink color
	ld      (#45ed),a		; @2536 32ED45  store into ghost house door (right side) color
	ld      (#460d),a		; @2539 320D46  store into ghost house door (left side) color
	ret		; @253C C9  return

; called from #23A7 for task #04
; resets a bunch of memories to predefined values

	ld ix,spr_unk_4c00		; @253D DD21004C
	ld      (ix+#02),#20		; @2541 DD360220  set red ghost sprite
	ld      (ix+#04),#20		; @2545 DD360420  set pink ghost sprite
	ld      (ix+#06),#20		; @2549 DD360620  set inky sprite
	ld      (ix+#08),#20		; @254D DD360820  set orange ghost sprite
	ld      (ix+#0a),#2c		; @2551 DD360A2C  set ms pac sprite
	ld      (ix+#0c),#3f		; @2555 DD360C3F  set fruit sprite
	ld      (ix+#03),#01		; @2559 DD360301  set red ghost color
	ld      (ix+#05),#03		; @255D DD360503  set pink ghost color
	ld      (ix+#07),#05		; @2561 DD360705  set inky color
	ld      (ix+#09),#07		; @2565 DD360907  set orange ghost color
	ld      (ix+#0b),#09		; @2569 DD360B09  set ms pac color
	ld      (ix+#0d),#00		; @256D DD360D00  set fruit color

	ld      a,b		; @2571 78  load task parameter
	and     a		; @2572 A7  == #00 ?
	jp      nz,j_260f		; @2573 C20F26  no, skip ahead

	ld      hl,#8064		; @2576 216480
	ld      (red_y),hl		; @2579 22004D  set red ghost position
	ld      hl,#807c		; @257C 217C80
	ld      (pink_y),hl		; @257F 22024D  set pink ghost position
	ld      hl,#907c		; @2582 217C90
	ld      (blue_y),hl		; @2585 22044D  set inky position
	ld      hl,#707c		; @2588 217C70
	ld      (orange_y),hl		; @258B 22064D  set orange ghost position
	ld      hl,#80c4		; @258E 21C480
	ld      (pac_y),hl		; @2591 22084D  set ms pac position
	ld      hl,#2e2c		; @2594 212C2E
	ld      (red_tile_y),hl		; @2597 220A4D  set red ghost tile position
	ld      (red_tile_y2),hl		; @259A 22314D  set red ghost tile position 2
	ld      hl,#2e2f		; @259D 212F2E
	ld      (pink_tile_y),hl		; @25A0 220C4D  set pink ghost tile position
	ld      (pink_tile_y2),hl		; @25A3 22334D  set pink ghost tile position 2
	ld      hl,#302f		; @25A6 212F30
	ld      (blue_tile_y),hl		; @25A9 220E4D  set inky tile position
	ld      (blue_tile_y2),hl		; @25AC 22354D  set inky tile position 2
	ld      hl,#2c2f		; @25AF 212F2C
	ld      (orange_tile_y),hl		; @25B2 22104D  set orange ghost tile position
	ld      (orange_tile_y2),hl		; @25B5 22374D  set orange ghost tile position 2
	ld      hl,#2e38		; @25B8 21382E
	ld      (pac_demo_tile_y),hl		; @25BB 22124D  set pacman tile position
	ld      (pac_tile_y),hl		; @25BE 22394D  set pacman tile position 2
	ld      hl,#0100		; @25C1 210001
	ld      (red_tile_dy),hl		; @25C4 22144D  set red ghost tile changes
	ld      (red_tile_dy2),hl		; @25C7 221E4D  set red ghost tile changes 2
	ld      hl,#0001		; @25CA 210100
	ld      (pink_tile_dy),hl		; @25CD 22164D  set pink ghost tile changes
	ld      (pink_tile_dy2),hl		; @25D0 22204D  set pink ghost tile changes 2
	ld      hl,#00ff		; @25D3 21FF00
	ld      (blue_tile_dy),hl		; @25D6 22184D  set inky tile changes
	ld      (blue_tile_dy2),hl		; @25D9 22224D  set inky tile changes 2
	ld      hl,#00ff		; @25DC 21FF00
	ld      (orange_tile_dy),hl		; @25DF 221A4D  set orange ghost tile changes
	ld      (orange_tile_dy2),hl		; @25E2 22244D  set orange ghost tile changes 2
	ld      hl,#0100		; @25E5 210001
	ld      (pac_tile_dy),hl		; @25E8 221C4D  set pacman tile changes
	ld      (pac_wanted_tile_dy),hl		; @25EB 22264D  set pacman tile changes 2
	ld      hl,#0102		; @25EE 210201
	ld      (red_prev_dir),hl		; @25F1 22284D  set previous red and pink ghost orientation
	ld      (red_dir),hl		; @25F4 222C4D  set red and pink ghost orientation
	ld      hl,#0303		; @25F7 210303
	ld      (blue_prev_dir),hl		; @25FA 222A4D  set previous blue and orange ghost orientation
	ld      (blue_dir),hl		; @25FD 222E4D  set blue and orange ghost orientation
	ld      a,#02		; @2600 3E02
	ld      (pac_dir),a		; @2602 32304D  set pacman orientation
	ld      (pac_wanted_dir),a		; @2605 323C4D  set wanted pacman orientation
	ld      hl,#0000		; @2608 210000
	ld      (fruit_pos_lo),hl		; @260B 22D24D  set fruit position
	ret		; @260E C9  return

; pac-man only, sets up sprites for character introduction screen

j_260f:
	ld      hl,#0094		; @260F 219400
	ld      (red_y),hl		; @2612 22004D
	ld      (pink_y),hl		; @2615 22024D
	ld      (blue_y),hl		; @2618 22044D
	ld      (orange_y),hl		; @261B 22064D
	ld      hl,#1e32		; @261E 21321E
	ld      (red_tile_y),hl		; @2621 220A4D
	ld      (pink_tile_y),hl		; @2624 220C4D
	ld      (blue_tile_y),hl		; @2627 220E4D
	ld      (orange_tile_y),hl		; @262A 22104D
	ld      (red_tile_y2),hl		; @262D 22314D
	ld      (pink_tile_y2),hl		; @2630 22334D
	ld      (blue_tile_y2),hl		; @2633 22354D
	ld      (orange_tile_y2),hl		; @2636 22374D
	ld      hl,#0100		; @2639 210001
	ld      (red_tile_dy),hl		; @263C 22144D
	ld      (pink_tile_dy),hl		; @263F 22164D
	ld      (blue_tile_dy),hl		; @2642 22184D
	ld      (orange_tile_dy),hl		; @2645 221A4D
	ld      (red_tile_dy2),hl		; @2648 221E4D
	ld      (pink_tile_dy2),hl		; @264B 22204D
	ld      (blue_tile_dy2),hl		; @264E 22224D
	ld      (orange_tile_dy2),hl		; @2651 22244D
	ld      (pac_tile_dy),hl		; @2654 221C4D
	ld      (pac_wanted_tile_dy),hl		; @2657 22264D
	ld hl,red_prev_dir		; @265A 21284D
	ld      a,#02		; @265D 3E02
	ld      b,#09		; @265F 0609
	rst     #8		; @2661 CF
	ld      (pac_wanted_dir),a		; @2662 323C4D
	ld      hl,#0894		; @2665 219408
	ld      (pac_y),hl		; @2668 22084D
	ld      hl,#1f32		; @266B 21321F
	ld      (pac_demo_tile_y),hl		; @266E 22124D
	ld      (pac_tile_y),hl		; @2671 22394D
	ret		; @2674 C9  return

; called from #136E after mspac has died
; called from #23A7 as task #1E

j_2675:
	ld      hl,#0000		; @2675 210000  HL := #0000
	ld      (fruit_pos_lo),hl		; @2678 22D24D  clear fruit position
	ld      (pac_y),hl		; @267B 22084D  clear pacman position

; called from #09F6

j_267e:
	ld      (red_y),hl		; @267E 22004D  clear red ghost
	ld      (pink_y),hl		; @2681 22024D  clear pink ghost
	ld      (blue_y),hl		; @2684 22044D  clear blue ghost (inky)
	ld      (orange_y),hl		; @2687 22064D  clear orange ghost
	ret		; @268A C9  return

; task #05 called from #23A7

	ld      a,#55		; @268B 3E55
	ld      (ghost_home_move_counter),a		; @268D 32944D  store #55 into counter related to ghost movement inside home
	dec     b		; @2690 05  check parameter
	ret     z		; @2691 C8  return if parameter == #00

	ld      a,#01		; @2692 3E01
	ld      (red_substate),a		; @2694 32A04D  else store #01 into red ghost substate.  makes red ghost chase pac man.
	ret		; @2697 C9  return

; sets demo mode

	ld      a,#01		; @2698 3E01  A := #01
	ld      (game_mode),a		; @269A 32004E  store into game mode, selects demo mode is starting
	xor     a		; @269D AF  A := #00
	ld	(game_mode_sub0),a		; @269E 32014E  store into subroutine # (listing said 4E03/sub2; boots have 4E01)
	ret		; @26A1 C9  return

; task #11 called from #23A7

	xor     a		; @26A2 AF  A := #00
	ld de,red_y		; @26A3 11004D  load DE with starting address

j_26a6:
	ld hl,game_mode		; @26A6 21004E  load HL with ending address
	ld      (de),a		; @26A9 12  store #00 into memory location
	inc     de		; @26AA 13  next address
	and     a		; @26AB A7  clear carry flag
	sbc     hl,de		; @26AC ED52  subtract offset.  are we done ?
	jp      nz,j_26a6		; @26AE C2A626  no, loop again

	ret		; @26B1 C9  return

; called from #23A7 as task #1F
; writes points needed for extra life digits to screen

	ld      ix,#4136		; @26B2 DD213641  load IX with screen position
	ld      a,(dip_bonus_life)		; @26B6 3A714E  load A with points needed for bonus life (#10, #15, #20 or FF)
	and     #0f		; @26B9 E60F  mask out left digit bits
	add     a,#30		; @26BB C630  add #30, gives ascii code for this digit
	ld      (ix+#00),a		; @26BD DD7700  write digit to screen
	ld      a,(dip_bonus_life)		; @26C0 3A714E  load A with points needed for bonus life (#10, #15, #20 or FF) 
	rrca		; @26C3 0F
	rrca		; @26C4 0F
	rrca		; @26C5 0F
	rrca		; @26C6 0F  rotate right 4 times.  A now has the tens digit
	and     #0f		; @26C7 E60F  mask out left digit bits
	ret     z		; @26C9 C8  return if zero (when would this happen?)

	add     a,#30		; @26CA C630  add #30, gives ascii code for this digit
	ld      (ix+#20),a		; @26CC DD7720  write digit to screen
	ret		; @26CF C9  return

; check dip switches 0 and 1 .  Free play or coins per credit

	ld      a,(DSW1)		; @26D0 3A8050  load A with Dip Switch
	ld      b,a		; @26D3 47  copy to B
	and     #03		; @26D4 E603  mask bits 0000 0011 - is free play set in the DIP ?
	jp      nz,j_26de		; @26D6 C2DE26  no, skip ahead

	ld hl,credits		; @26D9 216E4E  yes, load HL with credit memory address
	ld      (hl),#FF		; @26DC 36FF  store FF to indicate free play
j_26de:
	ld      c,a		; @26DE 4F  load C with result computed above
	rra		; @26DF 1F  roll right = moves bit 0 to the carry bit and carry flag to bit 7
	adc     a,#00		; @26E0 CE00  A := #00 plus carry bit
	ld      (dip_coins_per_credit),a		; @26E2 326B4E  store into coins per credit
	and     #02		; @26E5 E602  mask bits 0000 0010 
	xor     c		; @26E7 A9  XOR with original result.  this will toggle bit 1 on or off
	ld      (dip_credits_per_coin),a		; @26E8 326D4E  store into number of credits per coin

; check dip switches 2 and 3.  number of starting lives per game

	ld      a,b		; @26EB 78  load A with Dip Switch original value from #5080
	rrca		; @26EC 0F
	rrca		; @26ED 0F  roll right twice
	and     #03		; @26EE E603  mask bits.  how many pacmen per game?
	inc     a		; @26F0 3C  increment
	cp      #04		; @26F1 FE04  == #04 ?  (swtich set of 3 which gives 5 pacmen per game)
	jr      nz,j_26f6		; @26F3 2001  no, skip next step
	inc     a		; @26F5 3C  increment
j_26f6:
	ld      (dip_lives),a		; @26F6 326F4E  store result into # of pacmen per game

; check dip switches 4 and 5.  points for bonus pac man

	ld      a,b		; @26F9 78  load A with Dip switch
	rrca		; @26FA 0F
	rrca		; @26FB 0F
	rrca		; @26FC 0F
	rrca		; @26FD 0F  roll right four times   
	and     #03		; @26FE E603  mask bits - checks score for bonus packman
	ld      hl,#2728		; @2700 212827  load HL with start of table for this option
	rst     #10		; @2703 D7  A := (HL + A).  loads A with table value based on dip switch setting
	ld      (dip_bonus_life),a		; @2704 32714E  store result into extra life setting

; check dip switch 7 for ghost names during attract mode

	ld      a,b		; @2707 78  load A with Dip Switch
	rlca		; @2708 07  rotate left with bit 7 moved to bit 0
	cpl		; @2709 2F  invert A (one's complement)
	and     #01		; @270A E601  mask bits
	ld      (ghost_names_mode),a		; @270C 32754E  store result into ghost names mode

; check dip switch 6 for difficulty

	ld      a,b		; @270F 78  load A with Dip Switch
	rlca		; @2710 07
	rlca		; @2711 07  rotate left twice
	cpl		; @2712 2F  invert A
	and     #01		; @2713 E601  mask bits
	ld      b,a		; @2715 47  copy result to B
	ld      hl,#272c		; @2716 212C27  load HL with start address of difficulty table
	rst     #18		; @2719 DF  HL := HL + A
	ld      (dip_difficulty_ptr_lo),hl		; @271A 22734E  store into difficulty table lookup

; check bit 7 on IN1 for upright / cocktail

	ld      a,(IN1)		; @271D 3A4050  load A with IN1
	rlca		; @2720 07  rotatle left
	cpl		; @2721 2F  invert A
	and     #01		; @2722 E601  mask bits
	ld      (dip_cocktail),a		; @2724 32724E  store result into cocktail/upright setting
	ret		; @2727 C9  return

	; data - bonus/life
	; called from #2700

	db	#10	; @2728 10  10,000 points
	db	#15	; @2729 15  15,000 points
	db	#20	; @272A 20  20,000 points
	db	#FF	; @272B FF  code for no extra life

	; data - difficulty settings table
	; called from #2716

	db	#68,#00	; @272C 6800  normal at #0068
	db	#7D,#00	; @272E 7D00  hard at #007D	

; red ghost logic: (not edible)

	ld      a,(ghost_orient_index)		; @2730 3AC14D  load A with movement indicator .  0= random movement , 1= normal movement
	bit     0,a		; @2733 CB47  random movement ?
	jp      nz,j_2758		; @2735 C25827  no, jump to get normal red movement

	ld      a,(cruise_elroy_1)		; @2738 3AB64D  yes, load A with red ghost mode 0=normal  1= faster ghost,most dots
	and     a		; @273B A7  faster mode ?
	jr      nz,j_2758		; @273C 201A  yes, get norm red direction

	ld      a,(level_state)		; @273E 3A044E  no, load A with game mode (3=ghost move, 2=ghost wait for start) (when is this 2 ???)
	cp      #03		; @2741 FE03  is this normal game mode ?
	jr      nz,j_2758		; @2743 2013  no, get normal red direction

; random red ghost directions

	ld      hl,(red_tile_y)		; @2745 2A0A4D  yes, load HL with red ghost location  YY XX
	ld      a,(red_dir)		; @2748 3A2C4D  load A with red ghost direction

; OTTPATCH
;PATCH TO MAKE THE MONSTERS MOVE RANDOMLY
;ORG 274BH
;CALL RCORNER
	call    j_9561		; @274B CD6195  load DE with a (random ?) quadrant for the destination
	call    j_2966		; @274E CD6629  get dir. by finding shortest distance
	ld      (red_tile_dy2),hl		; @2751 221E4D  store red ghost movement offsets
	ld      (red_dir),a		; @2754 322C4D  store red ghost direction
	ret		; @2757 C9  return

; normal movement get direction for red ghost

j_2758:
	ld      hl,(red_tile_y)		; @2758 2A0A4D  load HL with red ghost location  YY XX
	ld      de,(pac_tile_y)		; @275B ED5B394D  load DE with ms pac location YY XX
	ld      a,(red_dir)		; @275F 3A2C4D  load A with red ghost current direction
	call    j_2966		; @2762 CD6629  get best new dir. by finding shortest distance
	ld      (red_tile_dy2),hl		; @2765 221E4D  store red ghost tile changes
	ld      (red_dir),a		; @2768 322C4D  store red ghost direction
	ret		; @276B C9  return

; pink ghost AI start

	ld      a,(ghost_orient_index)		; @276C 3AC14D  load A with movement indicator
	bit     0,a		; @276F CB47  random movement ?
	jp      nz,j_278e		; @2771 C28E27  no, skip ahead and do pink ghost AI
	ld      a,(level_state)		; @2774 3A044E  yes, load A with level cleared register
	cp      #03		; @2777 FE03  == # 03 ? (why?  when game is played, this is always 3 ???)
	jr      nz,j_278e		; @2779 2013  no, skip ahead and do pink ghost AI (never will take this route??)

; pink ghost random movement

	ld      hl,(pink_tile_y)		; @277B 2A0C4D  else load HL with pink ghost position
	ld      a,(pink_dir)		; @277E 3A2D4D  load A with pink ghost direction

; OTTPATCH
;PATCH TO MAKE THE MONSTERS MOVE RANDOMLY
;ORG 2781H
;CALL RCORNER
	call    j_9561		; @2781 CD6195  call new code to pick a location to move toward ?
	call    j_2966		; @2784 CD6629  get new direction by finding shortest distance
	ld      (pink_tile_dy2),hl		; @2787 22204D  store new pink ghost Y and X tile changes
	ld      (pink_dir),a		; @278A 322D4D  store new pink ghost direction
	ret		; @278D C9  return

; pink ghost normal movement

j_278e:
	ld      de,(pac_tile_y)		; @278E ED5B394D  load DE with pac man position
	ld      hl,(pac_tile_dy)		; @2792 2A1C4D  load HL with pac man direction

	; hard hack: HACK6
	; 2795  00        nop

	add     hl,hl		; @2795 29  HL := HL * 2
	add     hl,hl		; @2796 29  HL := HL * 2
	add     hl,de		; @2797 19  add direction to position
	ex      de,hl		; @2798 EB  copy to DE
	ld      hl,(pink_tile_y)		; @2799 2A0C4D  load HL with pink ghost position
	ld      a,(pink_dir)		; @279C 3A2D4D  load A with pink ghost direction
	call    j_2966		; @279F CD6629  compute best new directions
	ld      (pink_tile_dy2),hl		; @27A2 22204D  store new ping ghost Y and X tile changes
	ld      (pink_dir),a		; @27A5 322D4D  store new pink ghost direction
	ret		; @27A8 C9  return

; blue ghost (inky) AI

	ld      a,(ghost_orient_index)		; @27A9 3AC14D  load A with movement indicator
	bit     0,a		; @27AC CB47  random movement ?
	jp      nz,j_27cb		; @27AE C2CB27  no ,skip ahead and do normal inky ghost AI
	ld      a,(level_state)		; @27B1 3A044E  yes, load A with level cleared register
	cp      #03		; @27B4 FE03  == # 03 ?  (this always 3 during a game ... ?)
	jr      nz,j_27cb		; @27B6 2013  jump if not 3 ahead to do normal AI

; random (?) blue ghost (inky) movement

	ld      hl,(blue_tile_y)		; @27B8 2A0E4D  load HL with inky position

; OTTPATCH
;PATCH TO MAKE THE MONSTERS MOVE RANDOMLY
;ORG 2781H
;CALL RCORNER
	call    j_9559		; @27BB CD5995  pick a random quadrant (why ??? DE is loaded new in next step)
	ld      de,#2040		; @27BE 114020  load DE with lower right corner destination
	call    j_2966		; @27C1 CD6629  get best new direction
	ld      (blue_tile_dy2),hl		; @27C4 22224D  store new direction into inky's tile changes
	ld      (blue_dir),a		; @27C7 322E4D  store inky's new direction
	ret		; @27CA C9  return

; normal blue ghost (inky) movement

j_27cb:
	ld      bc,(red_tile_y)		; @27CB ED4B0A4D  load BC with red ghost position (X, Y)
	ld      de,(pac_tile_y)		; @27CF ED5B394D  load DE with pac man position
	ld      hl,(pac_tile_dy)		; @27D3 2A1C4D  load HL with pacman direction 
					; H loads with (0 = facing up or down, 01 = facing left, FF = facing right)
					; L loads with (0= facing left or right, 01 = facing down, FF = facing up)
	add     hl,hl		; @27D6 29  HL := HL * 2
	add     hl,de		; @27D7 19  add result to pac position.  this now has the position 2 in front of pac
	ld      a,l		; @27D8 7D  load A with computed Y position
	add     a,a		; @27D9 87  A := A * 2
	sub     c		; @27DA 91  subtract red ghost Y position
	ld      l,a		; @27DB 6F  save result into L
	ld      a,h		; @27DC 7C  load A with computed X position
	add     a,a		; @27DD 87  A := A * 2
	sub     b		; @27DE 90  subract red ghost X position
	ld      h,a		; @27DF 67  save result into H
	ex      de,hl		; @27E0 EB  save total result into DE
	ld      hl,(blue_tile_y)		; @27E1 2A0E4D  load HL with blue ghost (Inky) position
	ld      a,(blue_dir)		; @27E4 3A2E4D  load A with blue ghost (Inky) direction
	call    j_2966		; @27E7 CD6629  get best new direction
	ld      (blue_tile_dy2),hl		; @27EA 22224D  Store blue ghost (inky) y tile changes
	ld      (blue_dir),a		; @27ED 322E4D  store new blue direction
	ret		; @27F0 C9  return  

; orange ghost AI

	ld      a,(ghost_orient_index)		; @27F1 3AC14D  load A with movement indicator
	bit     0,a		; @27F4 CB47  random movement ?
	jp      nz,j_2813		; @27F6 C21328  no, skip ahead and normal orange ghost AI
	ld      a,(level_state)		; @27F9 3A044E  load A with level cleared register
	cp      #03		; @27FC FE03  == #03 ?  ( this is always 3 during game)
	jr      nz,j_2813		; @27FE 2013  jump if not 3 to normal orange ghost AI

; random orange ghost movement
; not really random, the random quadrant gets overridden with the lower left corner

j_2800:
	ld      hl,(orange_tile_y)		; @2800 2A104D  load HL with orange ghost position
; OTTPATCH
;PATCH TO MAKE THE MONSTERS MOVE RANDOMLY
;ORG 2803H
;CALL R2CORNER
	call    j_955e		; @2803 CD5E95  pick a random quadrant (why?  DE is loaded new in next step)
	ld de,EFFECT_TABLE_2		; @2806 11403B  load DE with lower left corner destination
	call    j_2966		; @2809 CD6629  get best new direction
	ld      (orange_tile_dy2),hl		; @280C 22244D  store new orange ghost direction tile changes
	ld      (orange_dir),a		; @280F 322F4D  store new orange ghost direction 
	ret		; @2812 C9  return

; normal orange ghost movement

j_2813:
	ld ix,pac_tile_y		; @2813 DD21394D  load IX with pacman Y and X tile position
	ld iy,orange_tile_y		; @2817 FD21104D  load IY with orange ghost tile future posiiton
	call    j_29ea		; @281B CDEA29  load HL with sum of square of X and Y distances
	ld      de,#0040		; @281E 114000  load DE with offset. #40 is hex for 64 deciamal, which is 8 squared.

    	; hard hack: HACK6
	; 281e  112400    ld      de,#0024
	;

	and     a		; @2821 A7  clear carry flag
	sbc     hl,de		; @2822 ED52  subtract offset from distance.   is orange ghost getting too close to pac-man?  (<8 units)
	jp      c,j_2800		; @2824 DA0028  yes, jump back and have ghost move toward lower left corner

	ld      hl,(orange_tile_y)		; @2827 2A104D  else load HL with orange ghost future position
	ld      de,(pac_tile_y)		; @282A ED5B394D  load DE with pac man position
	ld      a,(orange_dir)		; @282E 3A2F4D  load A with orange ghost direction
	call    j_2966		; @2831 CD6629  get best new direction
	ld      (orange_tile_dy2),hl		; @2834 22244D  store orange ghost tile changes
	ld      (orange_dir),a		; @2837 322F4D  store orange ghost direction
	ret		; @283A C9  return


; called from #23A7 when task = #0C
; check red ghost movement when power pill active

	ld      a,(red_state)		; @283B 3AAC4D  load A with red ghost state
	and     a		; @283E A7  is red ghost alive ?
	jp      z,j_2855		; @283F CA5528  yes, skip ahead and give random direction

	ld      de,#2e2c		; @2842 112C2E  no, load DE with the destination 2E, 2C which is right above the ghost house
	ld      hl,(red_tile_y)		; @2845 2A0A4D  load HL with red ghost tile positions
	ld      a,(red_dir)		; @2848 3A2C4D  load A with red ghost direction
	call    j_2966		; @284B CD6629  get best new direction
	ld      (red_tile_dy2),hl		; @284E 221E4D  store new direction tiles for red ghost
	ld      (red_dir),a		; @2851 322C4D  store new ghost direction
	ret		; @2854 C9  return

j_2855:
	ld      hl,(red_tile_y)		; @2855 2A0A4D  load HL with red ghost tile positions
	ld      a,(red_dir)		; @2858 3A2C4D  load A with red ghost direction
	call    j_291e		; @285B CD1E29  load A and HL with random direction and tile direction
	ld      (red_tile_dy2),hl		; @285E 221E4D  store new direction tiles for red ghost
	ld      (red_dir),a		; @2861 322C4D  store new red ghost direction
	ret		; @2864 C9  return

; check pink ghost

	ld      a,(pink_state)		; @2865 3AAD4D  load A with pink ghost state
	and     a		; @2868 A7  is pink ghost alive ?
	jp      z,j_287f		; @2869 CA7F28  yes, skip ahead and give random direction

	ld      de,#2e2c		; @286C 112C2E  no, load DE with the destination 2E, 2C which is right above the ghost house 
	ld      hl,(pink_tile_y)		; @286F 2A0C4D  load HL with pink ghost tile positions
	ld      a,(pink_dir)		; @2872 3A2D4D  load A with pink ghost direction
	call    j_2966		; @2875 CD6629  get best new direction
	ld      (pink_tile_dy2),hl		; @2878 22204D  store new direction tiles for pink ghost
	ld      (pink_dir),a		; @287B 322D4D  store new pink ghost direction
	ret		; @287E C9  return

;

j_287f:
	ld      hl,(pink_tile_y)		; @287F 2A0C4D  load HL with pink ghost tile direction
	ld      a,(pink_dir)		; @2882 3A2D4D  load A with pink ghost orientation
	call    j_291e		; @2885 CD1E29  load A and HL with random direction and tile direction
	ld      (pink_tile_dy2),hl		; @2888 22204D  store new direction tiles for pink ghost
	ld      (pink_dir),a		; @288B 322D4D  store new pink ghost orientation
	ret		; @288E C9  return

; check blue ghost (inky)

	ld      a,(blue_state)		; @288F 3AAE4D  load A with inky state
	and     a		; @2892 A7  is inky alive ?
	jp      z,j_28a9		; @2893 CAA928  yes, skip ahead and give random direction

	ld      de,#2e2c		; @2896 112C2E  no, load DE with the destination 2E, 2C which is right above the ghost house 
	ld      hl,(blue_tile_y)		; @2899 2A0E4D  load HL with inky tile positions
	ld      a,(blue_dir)		; @289C 3A2E4D  load A with ink direction
	call    j_2966		; @289F CD6629  get best new direction
	ld      (blue_tile_dy2),hl		; @28A2 22224D  store new direction tiles for inky
	ld      (blue_dir),a		; @28A5 322E4D  store new inky direction
	ret		; @28A8 C9  return

j_28a9:
	ld      hl,(blue_tile_y)		; @28A9 2A0E4D  load HL with inky tile changes
	ld      a,(blue_dir)		; @28AC 3A2E4D  load A with inky direction
	call    j_291e		; @28AF CD1E29  load A and HL with random direction and tile direction
	ld      (blue_tile_dy2),hl		; @28B2 22224D  store inky new tile directions
	ld      (blue_dir),a		; @28B5 322E4D  store new inky direction
	ret		; @28B8 C9  return

; check orange ghost

	ld      a,(orange_state)		; @28B9 3AAF4D  load A with orange ghost state
	and     a		; @28BC A7  is orange ghost alive ?
	jp      z,j_28d3		; @28BD CAD328  yes, skip ahead and assign random direction

	ld      de,#2e2c		; @28C0 112C2E  no, load DE with the destination 2E, 2C which is right above the ghost house 
	ld      hl,(orange_tile_y)		; @28C3 2A104D  load HL with orange ghost tile directions
	ld      a,(orange_dir)		; @28C6 3A2F4D  load A with orange ghost direction
	call    j_2966		; @28C9 CD6629  get best new directions
	ld      (orange_tile_dy2),hl		; @28CC 22244D  store new orange ghost tile directions
	ld      (orange_dir),a		; @28CF 322F4D  store new orange ghost direction
	ret		; @28D2 C9  return

j_28d3:
	ld      hl,(orange_tile_y)		; @28D3 2A104D  load HL with orange ghost tile directions
	ld      a,(orange_dir)		; @28D6 3A2F4D  load A with orange ghost direction
	call    j_291e		; @28D9 CD1E29  load A and HL with random direction and tile direction
	ld      (orange_tile_dy2),hl		; @28DC 22244D  store new orange ghost tile directions
	ld      (orange_dir),a		; @28DF 322F4D  store new orange ghost direction
	ret		; @28E2 C9  return

; called from #23A7 for task #17
; arrive here only during demo mode ?
; conrtrols pacman AI during demo mode
; pac-man will avoid the pink ghost normally, except after eating a power pill
; pac-man will chase the pink ghost when the red ghost is blue, even if the pink ghost is not

	ld      a,(red_frightened)		; @28E3 3AA74D  load A with red ghost blue flag (0=not blue)
	and     a		; @28E6 A7  is red ghost blue (edible) ?
	jp      z,j_28fe		; @28E7 CAFE28  no, skip ahead
	ld      hl,(pac_demo_tile_y)		; @28EA 2A124D  yes, load HL with pacman tile pos (Y,X) in demo and cut scenes 
	ld      de,(pink_tile_y)		; @28ED ED5B0C4D  load DE with pink ghost tile pos (Y,X)
	ld      a,(pac_wanted_dir)		; @28F1 3A3C4D  load A with wanted pacman orientation
	call    j_2966		; @28F4 CD6629  get best new direction
	ld      (pac_wanted_tile_dy),hl		; @28F7 22264D  store into wanted pacman tile changes
	ld      (pac_wanted_dir),a		; @28FA 323C4D  store into wanted pacman orientation
	ret		; @28FD C9  return

; pacman will run away from pink ghost

j_28fe:
	ld      hl,(pac_tile_y)		; @28FE 2A394D  load HL with pacman (Y,X) tile positions
	ld      bc,(pink_tile_y)		; @2901 ED4B0C4D  load BC with pink ghost (Y,X) tile positions
	ld      a,l		; @2905 7D  load A with pacman X tile position
	add     a,a		; @2906 87  A := A * 2
	sub     c		; @2907 91  subtract pink ghost X tile position
	ld      l,a		; @2908 6F  store result into L
	ld      a,h		; @2909 7C  load A with pacman Y tile position
	add     a,a		; @290A 87  A := A * 2
	sub     b		; @290B 90  subtract pink ghost Y tile position
	ld      h,a		; @290C 67  store result into H
	ex      de,hl		; @290D EB  DE <-> HL.  The new destination is away from pink ghost
	ld      hl,(pac_demo_tile_y)		; @290E 2A124D  load HL with pacman tile positions
	ld      a,(pac_wanted_dir)		; @2911 3A3C4D  load A with wanted pacman orientation
	call    j_2966		; @2914 CD6629  get best new direction
	ld      (pac_wanted_tile_dy),hl		; @2917 22264D  store new tile changes
	ld      (pac_wanted_dir),a		; @291A 323C4D  store new wanted pacman orientation
	ret		; @291D C9  return

; called from routines above with HL loaded with ghost position and A loaded with ghost direction
; used when ghosts are blue (edible)
; load A with new direction, and HL with tile offset for this direction

j_291e:
	ld      (path_cur_tile_lo),hl		; @291E 223E4D  store HL into current tile position
	xor     #02		; @2921 EE02  reverse ghost direction
	ld      (path_opposite_dir),a		; @2923 323D4D  store into the opposite orientation
	call    j_2a23		; @2926 CD232A  load A with a pseudo random number
	and     #03		; @2929 E603  mask bits, now between 0 and 3
	ld hl,path_best_dir		; @292B 213B4D  load HL with best orientation found address
	ld      (hl),a		; @292E 77  store the random direction
	add     a,a		; @292F 87  A := A * 2
	ld      e,a		; @2930 5F  store into E
	ld      d,#00		; @2931 1600  D := #00.  DE now has #000X where X is 2 * direction
	ld      ix,#32ff		; @2933 DD21FF32  load IX with data - tile differences tables for movements
	add     ix,de		; @2937 DD19  IX now has the tile difference address
	ld iy,path_cur_tile_lo		; @2939 FD213E4D  load IY with current tile position

j_293d:
	ld      a,(path_opposite_dir)		; @293D 3A3D4D  load A with opposite direction
	cp      (hl)		; @2940 BE  is the random direction == opposite direction ?
	jp      z,j_2957		; @2941 CA5729  yes, skip ahead to choose a new direction

	call    j_200f		; @2944 CD0F20  no, load A with the character in the destination screen position
	and     #C0		; @2947 E6C0  mask bits
	sub     #C0		; @2949 D6C0  subtract. is there a wall in the way of this direction ?
	jr      z,j_2957		; @294B 280A  yes, choose a new direction and try again

	ld      l,(ix+#00)		; @294D DD6E00  no, load L with tile offset low byte
	ld      h,(ix+#01)		; @2950 DD6601  load H with tile offset high byte
	ld      a,(path_best_dir)		; @2953 3A3B4D  load A with new direction
	ret		; @2956 C9  return

; arrive here from #2941 when random direction == opposite direction, or a wall is in the way of the direction computed

j_2957:
	inc     ix		; @2957 DD23
	inc     ix		; @2959 DD23  next direction tile
	ld hl,path_best_dir		; @295B 213B4D  load HL with best orientation found address
	ld      a,(hl)		; @295E 7E  load A with the random direction
	inc     a		; @295F 3C  increase
	and     #03		; @2960 E603  mask bits to make between #00 and #03, in case #04 was reached it will revert to #00
	ld      (hl),a		; @2962 77  store into new random direction
	jp      j_293d		; @2963 C33D29  jump back


; distance check - used for ghost logic and for pacman logic in the demo

; this subroutine determines the best direction to take based upon the input.
; DE is preloaded with the destination tile
; HL is preloaded with the current position tile
; A is preloaded with the current direction of the ghost

; the output is the best new direction which is stored into A
; and the best new tile changes stored into HL


j_2966:
	ld      (path_cur_tile_lo),hl		; @2966 223E4D  store current position
	ld      (path_dest_tile_lo),de		; @2969 ED53404D  store destination
	ld      (path_best_dir),a		; @296D 323B4D  store direction
	xor     #02		; @2970 EE02  flip bit 1 of the direction
	ld      (path_opposite_dir),a		; @2972 323D4D  store reversed direction, this will never be allowed
	ld      hl,#FFFF		; @2975 21FFFF  HL := FFFF
	ld      (path_min_dist_lo),hl		; @2978 22444D  store HL into minimum distance^2 found
	ld      ix,#32ff		; @297B DD21FF32  load IX with start of table data - tile differences tables for movements
	ld iy,path_cur_tile_lo		; @297F FD213E4D  load IY with current position
	ld hl,path_try_dir		; @2983 21C74D  load HL with address of counter
	ld      (hl),#00		; @2986 3600  clear counter

j_2988:
	ld      a,(path_opposite_dir)		; @2988 3A3D4D  load A with reversed direction
	cp      (hl)		; @298B BE  == counter ?
	jp      z,j_29c6		; @298C CAC629  yes, skip ahead and try next position

	call    j_2000		; @298F CD0020  no, HL := (IX) + (IY)
	ld      (path_temp_pos_lo),hl		; @2992 22424D  store into temp position
	call    j_0065		; @2995 CD6500  convert to screen position
	ld      a,(hl)		; @2998 7E  load A with the character in the new position
	and     #C0		; @2999 E6C0  mask bits
	sub     #C0		; @299B D6C0  is there something blocking the way of this direction?
	jr      z,j_29c6		; @299D 2827  yes, skip ahead and try next position

	push    ix		; @299F DDE5  no, save IX
	push    iy		; @29A1 FDE5  save IY
	ld ix,path_dest_tile_lo		; @29A3 DD21404D  load IX with destination
	ld iy,path_temp_pos_lo		; @29A7 FD21424D  load IY with temp position
	call    j_29ea		; @29AB CDEA29  load HL with sum of the square of the X and Y distances between the 2 positions
	pop     iy		; @29AE FDE1  restore IY
	pop     ix		; @29B0 DDE1  restore IX
	ex      de,hl		; @29B2 EB  store result into DE
	ld      hl,(path_min_dist_lo)		; @29B3 2A444D  load HL with minimum distance^2 found
	and     a		; @29B6 A7  clear carry flag
	sbc     hl,de		; @29B7 ED52  subtract.  Is this distance less than the minimum found so far ?
	jp      c,j_29c6		; @29B9 DAC629  no, skip ahead and try next position

	ld      (path_min_dist_lo),de		; @29BC ED53444D  yes, store new minimum distance^2 found
	ld      a,(path_try_dir)		; @29C0 3AC74D  load A with counter
	ld      (path_best_dir),a		; @29C3 323B4D  store counter into direction

j_29c6:
	inc     ix		; @29C6 DD23
	inc     ix		; @29C8 DD23  next direction tile difference
	ld hl,path_try_dir		; @29CA 21C74D  load HL with counter
	inc     (hl)		; @29CD 34  increase counter
	ld      a,#04		; @29CE 3E04  A := #04
	cp      (hl)		; @29D0 BE  have we tried all 4 directions?
	jp      nz,j_2988		; @29D1 C28829  no, loop again and try more

	ld      a,(path_best_dir)		; @29D4 3A3B4D  yes, load A with best direction
	add     a,a		; @29D7 87  A := A * 2
	ld      e,a		; @29D8 5F  store into E
	ld      d,#00		; @29D9 1600  D := #00
	ld      ix,#32ff		; @29DB DD21FF32  load IX with start of tile differences
	add     ix,de		; @29DF DD19  add DE, now it has the tile difference for best direction
	ld      l,(ix+#00)		; @29E1 DD6E00
	ld      h,(ix+#01)		; @29E4 DD6601  store tile difference for best direction into HL
	srl     a		; @29E7 CB3F  A := A / 2
	ret		; @29E9 C9  return

; sub called for orange ghost logic and during distance check
; loads HL with the sum of the square of the X and Y distances between pac and ghost

j_29ea:
	ld      a,(ix+#00)		; @29EA DD7E00  load A with pacman Y position
	ld      b,(iy+#00)		; @29ED FD4600  load B with ghost Y position
	sub     b		; @29F0 90  subtract.  is A > B ?
	jp      nc,j_29f9		; @29F1 D2F929  yes, skip ahead

	ld      a,b		; @29F4 78  else load A with B
	ld      b,(ix+#00)		; @29F5 DD4600  load B with pacman position
	sub     b		; @29F8 90  subtract from ghost position

j_29f9:
	call    j_2a12		; @29F9 CD122A  result should always be a small number.  HL := A * A

	push    hl		; @29FC E5  save HL

	ld      a,(ix+#01)		; @29FD DD7E01  load A with pacman X position
	ld      b,(iy+#01)		; @2A00 FD4601  load B with ghost X position
	sub     b		; @2A03 90  subtract.  is A > B ?
	jp      nc,j_2a0c		; @2A04 D20C2A  yes, skip ahead

	ld      a,b		; @2A07 78  else load A with B
	ld      b,(ix+#01)		; @2A08 DD4601  load B with pacman X position
	sub     b		; @2A0B 90  subtract.

j_2a0c:
	call    j_2a12		; @2A0C CD122A  HL = A * A

	pop     bc		; @2A0F C1  restore the result found based on Y position
	add     hl,bc		; @2A10 09  add together into HL (no check for overflow ???)
	ret		; @2A11 C9  return

; called from #29F9
; takes the value in A and squares it, places result into HL

j_2a12:
	ld      h,a		; @2A12 67  H := A
	ld      e,a		; @2A13 5F  E := A
	ld      l,#00		; @2A14 2E00  L := #00
	ld      d,l		; @2A16 55  D := #00
	ld      c,#08		; @2A17 0E08  C := #08 (loop counter)

j_2a19:
	add     hl,hl		; @2A19 29  HL := HL * 2
	jp      nc,j_2a1e		; @2A1A D21E2A  no carry, skip next step

	add     hl,de		; @2A1D 19  add result to DE

j_2a1e:
	dec     c		; @2A1E 0D  decrease counter
	jp      nz,j_2a19		; @2A1F C2192A  loop if not done, 8 times
	ret		; @2A22 C9  return

    ;; Random number generator

;; #2a23 random number generator, only active when ghosts are blue.    
;; n=(n*5+1) && #1fff.  n is used as an address to read a byte from a rom.
;; #4dc9, #4dca=n  and a=rnd number. n is reset to 0 at #26a9 when you die,
;; start of first level, end of every level.  Later a is anded with 3.

j_2a23:
	ld      hl,(rng_rom_ptr_lo)		; @2A23 2AC94D
	ld      d,h		; @2A26 54
	ld      e,l		; @2A27 5D
	add     hl,hl		; @2A28 29
	add     hl,hl		; @2A29 29
	add     hl,de		; @2A2A 19
	inc     hl		; @2A2B 23
	ld      a,h		; @2A2C 7C
	and     #1f		; @2A2D E61F
	ld      h,a		; @2A2F 67
	ld      a,(hl)		; @2A30 7E
	ld      (rng_rom_ptr_lo),hl		; @2A31 22C94D
	ret		; @2A34 C9

;  

	ld      de,#4040		; @2A35 114040

j_2a38:
	ld      hl,#43c0		; @2A38 21C043
	and     a		; @2A3B A7
	sbc     hl,de		; @2A3C ED52
	ret     z		; @2A3E C8

	ld      a,(de)		; @2A3F 1A
	cp      #10		; @2A40 FE10
	jp      z,j_2a53		; @2A42 CA532A

	cp      #12		; @2A45 FE12
	jp      z,j_2a53		; @2A47 CA532A

	cp      #14		; @2A4A FE14
	jp      z,j_2a53		; @2A4C CA532A

	inc     de		; @2A4F 13
	jp      j_2a38		; @2A50 C3382A

j_2a53:
	ld      a,#40		; @2A53 3E40
	ld      (de),a		; @2A55 12
	inc     de		; @2A56 13
	jp      j_2a38		; @2A57 C3382A

; arrive here from #1780 when a ghost is eaten. 
; B contains the # of ghosts eaten +1 (2-5)

; or arrive from #23A7 for a task
; B is loaded with code of scoring item

j_2a5a:
	ld      a,(game_mode)		; @2A5A 3A004E  load A with game mode
	cp      #01		; @2A5D FE01  is this the intro mode ?
	ret     z		; @2A5F C8  yes, return			; change this to #00 (NOP) to enable scoring in demo mode

	; this updates the score when something is eaten
	; (from the table at 2b17)
	; A is loaded with the code for item eaten

	ld      hl,#2b17		; @2A60 21172B  load HL with start of scoring table data
	rst     #18		; @2A63 DF  load HL with score based on item eaten stored in A
	ex      de,hl		; @2A64 EB  copy to DE
	call    j_2b0b		; @2A65 CD0B2B  load HL with score address for current player
	ld      a,e		; @2A68 7B  load A with low byte of score to add
	add     a,(hl)		; @2A69 86  add player's score low byte to A
	daa		; @2A6A 27  decimal adjust
	ld      (hl),a		; @2A6B 77  store result into score
	inc     hl		; @2A6C 23  next memory, for second byte of score
	ld      a,d		; @2A6D 7A  load A with high byte of score to add
	adc     a,(hl)		; @2A6E 8E  add with carry players's score second byte to A
	daa		; @2A6F 27  decimal adjust
	ld      (hl),a		; @2A70 77  store result into score second byte
	ld      e,a		; @2A71 5F  load E with this value as well
	inc     hl		; @2A72 23  next memory for third byte of score
	ld      a,#00		; @2A73 3E00  A := #00
	adc     a,(hl)		; @2A75 8E  add with carry third byte of score into A.  This will only add a carry bit if needed
	daa		; @2A76 27  decimal adjust
	ld      (hl),a		; @2A77 77  store result into third byte of score
	ld      d,a		; @2A78 57  load D with A.  DE now has third and second bytes of score
	ex      de,hl		; @2A79 EB  exchange DE with HL
	add     hl,hl		; @2A7A 29  double HL
	add     hl,hl		; @2A7B 29  double HL
	add     hl,hl		; @2A7C 29  double HL
	add     hl,hl		; @2A7D 29  HL now has 16 times what it had before
	ld      a,(dip_bonus_life)		; @2A7E 3A714E  load A with bonus life code
	dec     a		; @2A81 3D  decrement
	cp      h		; @2A82 BC  compare with H.  Is the players score higher than that needed for extra life?
	call    c,j_2b33		; @2A83 DC332B  if yes, call sub to continue check for extra life
	call    j_2aaf		; @2A86 CDAF2A  draw player score onscreen
	inc     de		; @2A89 13
	inc     de		; @2A8A 13
	inc     de		; @2A8B 13  DE now has msb byte of player's score

	; check for high score change

	ld hl,high_score_hi		; @2A8C 218A4E  load HL with msb high score ram area
	ld      b,#03		; @2A8F 0603  For B = 1 to 3 digits to check

j_2a91:
	ld      a,(de)		; @2A91 1A  load a with score digit
	cp      (hl)		; @2A92 BE  compare to high score digit
	ret     c		; @2A93 D8  return if high score not beat

	jr      nz,j_2a9b		; @2A94 2005  if they are equal, continue, else update the high score
	dec     de		; @2A96 1B  next digit
	dec     hl		; @2A97 2B  next digit
	djnz    j_2a91		; @2A98 10F7  next B
	ret		; @2A9A C9  return

	; arrive when player score beats the current high score

j_2a9b:
	call    j_2b0b		; @2A9B CD0B2B  load HL with score address for current player
	ld de,high_score_lo		; @2A9E 11884E  load DE with lsb high score memory
	ld      bc,#0003		; @2AA1 010300  counter  = 3 bytes
	ldir		; @2AA4 EDB0  copy score to high score
	dec     de		; @2AA6 1B  DE now has high score
	ld      bc,#0304		; @2AA7 010403  set up counters
	ld      hl,#43f2		; @2AAA 21F243  load HL with start of screen memory for high score
	jr      j_2abe		; @2AAD 180F  draw high score to screen and return

; called from #2A86

j_2aaf:
	ld      a,(player_number)		; @2AAF 3A094E  load A with current player number:  0=P1, 1=P2 
	ld      bc,#0304		; @2AB2 010403  load counters
	ld      hl,#43fc		; @2AB5 21FC43  screen pos for player 1 score
	and     a		; @2AB8 A7  is this player 1 ?
	jr      z,j_2abe		; @2AB9 2803  yes, skip ahead

	ld      hl,#43e9		; @2ABB 21E943  else load HL with screen pos for player 2 score

	;; draw the score to the screen
	; DE has the address of msb of the score
	; HL has starting screen position
	; B has #03, and C has #04 or #06

j_2abe:
	ld      a,(de)		; @2ABE 1A  load A with byte of score
	rrca		; @2ABF 0F
	rrca		; @2AC0 0F
	rrca		; @2AC1 0F
	rrca		; @2AC2 0F  roll right 4 times through carry flag, result is digits transposed (eg. 82 converts to #28)    
	call    j_2ace		; @2AC3 CDCE2A  drawtens digit to screen
	ld      a,(de)		; @2AC6 1A  load A with byte of score
	call    j_2ace		; @2AC7 CDCE2A  draw ones digit to screen
	dec     de		; @2ACA 1B  next score digit
	djnz    j_2abe		; @2ACB 10F1  loop 3 times
	ret		; @2ACD C9  return

j_2ace:
	and     #0f		; @2ACE E60F  mask out left 4 bits to zero
	jr      z,j_2ad6		; @2AD0 2804  result zero?  yes, skip next 2 steps

	ld      c,#00		; @2AD2 0E00  C := #00
	jr      j_2add		; @2AD4 1807  skip ahead

j_2ad6:
	ld      a,c		; @2AD6 79  load A with C
	and     a		; @2AD7 A7  == #00 ?
	jr      z,j_2add		; @2AD8 2803  yes, skip ahead

	ld      a,#40		; @2ADA 3E40  else A := #40
	dec     c		; @2ADC 0D  decrement C

j_2add:
	ld      (hl),a		; @2ADD 77  draw score to screen
	dec     hl		; @2ADE 2B  next screen position
	ret		; @2ADF C9  return

	; prints "high score", player 1 and player 2 score
	; this is task #18 called from #23A7

	ld      b,#00		; @2AE0 0600  B := #00
	call    j_2c5e		; @2AE2 CD5E2C  print HIGH SCORE
	xor     a		; @2AE5 AF  A := #00
	ld hl,score_p1_lo		; @2AE6 21804E  load HL with player 1 score start address
	ld      b,#08		; @2AE9 0608  set counter to 8
	rst     #8		; @2AEB CF  clear player 1 and player 2 scores to zero
	ld      bc,#0304		; @2AEC 010403  load BC with counters
	ld de,score_p1_hi		; @2AEF 11824E  load DE with p1 msb of score
	ld      hl,#43fc		; @2AF2 21FC43  load HL with screen pos for p1 current score
	call    j_2abe		; @2AF5 CDBE2A  draw score to screen
	ld      bc,#0304		; @2AF8 010403  load BC with counters
	ld de,score_p2_hi		; @2AFB 11864E  load DE with player 2 address
	ld      hl,#43e9		; @2AFE 21E943  load HL with screen pos for player 2 score
	ld      a,(num_players)		; @2B01 3A704E  load A with number of players (0=1 player, 1=2 players)
	and     a		; @2B04 A7  is this a 1 player game?
	jr      nz,j_2abe		; @2B05 20B7  no, draw player 2 score and return
	ld      c,#06		; @2B07 0E06  else C := #06
	jr      j_2abe		; @2B09 18B3  draw player 2 score and return

; called from #2A65, #2A9B

j_2b0b:
	ld      a,(player_number)		; @2B0B 3A094E  load A with current player number:  0=P1, 1=P2
	ld hl,score_p1_lo		; @2B0E 21804E  load HL with player 1 score start address
	and     a		; @2B11 A7  is this player 1 ?
	ret     z		; @2B12 C8  yes, return

	ld hl,score_p2_lo		; @2B13 21844E  else load HL with player 2 start address
	ret		; @2B16 C9  return

	;; score table
	;; (Spaeth)

	db	#10,#00	; @2B17 1000  dot        	=   10	0
	db	#50,#00	; @2B19 5000  power pellet	=   50	1
	db	#00,#02	; @2B1B 0002  ghost 1    	=  200	2
	db	#00,#04	; @2B1D 0004  ghost 2    	=  400	3
	db	#00,#08	; @2B1F 0008  ghost 3    	=  800  4
	db	#00,#16	; @2B21 0016  ghost 4    	= 1600	5
	db	#00,#01	; @2B23 0001  Cherry     	=  100	6
	db	#00,#02	; @2B25 0002  Strawberry 	=  200	7	; 300 in pac-man
	db	#00,#05	; @2B27 0005  Orange     	=  500	8
	db	#00,#07	; @2B29 0007  Pretzel    	=  700	9
	db	#00,#10	; @2B2B 0010  Apple      	= 1000	a
	db	#00,#20	; @2B2D 0020  Pear       	= 2000	b
	db	#00,#50	; @2B2F 0050  Banana     	= 5000	c	; 3000 in pac-man
	db	#00,#50	; @2B31 0050  Junior!    	= 5000	d

	; [The 8th fruit is a legacy thing from pacman, which
	;  used 8 bonus items. it is not used in mspac]

; arrive here from #2A83 when checking for extra life
; DE has the address of the third byte of the player's score

j_2b33:
	INC	DE		; @2B33 13  increment DE, it now points to fourth byte of score.  This is used only for extra life check 
	ld      l,e		; @2B34 6B  load L with E
	ld      h,d		; @2B35 62  load H with D.  HL now has a copy of DE, which is the fourth byte of score
	dec     de		; @2B36 1B  decrement DE, this now points to third byte again
	bit     0,(hl)		; @2B37 CB46  test bit 0 of this score.  is it already set?
	ret     nz		; @2B39 C0  no, return.  extra life has already been awarded

	; else start bonus life routine

	set     0,(hl)		; @2B3A CBC6  set bit 0 of HL. this will deny any future extra lives
	ld hl,CH1_E_NUM		; @2B3C 219C4E  set sound 0
	set     0,(hl)		; @2B3F CBC6  play bonus life sound
	ld hl,lives_real		; @2B41 21144E  load HL with number of lives left
	inc     (hl)		; @2B44 34  inc lives left
	ld hl,lives_displayed		; @2B45 21154E  load HL with number of lives on the screen
	inc     (hl)		; @2B48 34  inc lives displayed
	ld      b,(hl)		; @2B49 46  load B with number of lives on the screen.  This is used for a loop counter at instruction #2B5F

j_2b4a:
	ld      hl,#401a		; @2B4A 211A40  load HL with start screen location for extra lives
	ld      c,#05		; @2B4D 0E05  C := #05.  This counter is used to determine how many blanks to draw
	ld      a,b		; @2B4F 78  load A with B which has number of lives on the screen
	and     a		; @2B50 A7  == #00 ?
	jr      z,j_2b61		; @2B51 280E  yes, skip ahead, nothing to draw

	cp      #06		; @2B53 FE06  >= #06 ?
	jr      nc,j_2b61		; @2B55 300A  yes, skip ahead, we can't draw more than 5 extra lives

j_2b57:
	ld      a,#20		; @2B57 3E20  A := #20
	call    j_2b8f		; @2B59 CD8F2B  draw extra life
	dec     hl		; @2B5C 2B
	dec     hl		; @2B5D 2B  HL is now 2 less than before.  If another life is to be drawn, it will be in correct location.
	dec     c		; @2B5E 0D  decrement C 
	djnz    j_2b57		; @2B5F 10F6  Next B

j_2b61:
	dec     c		; @2B61 0D  decrement C.  Are there blank spaces to be drawn next ?
	ret     m		; @2B62 F8  No, return

	call    j_2b7e		; @2B63 CD7E2B  Yes, draw blank for the next extra life position
	dec     hl		; @2B66 2B
	dec     hl		; @2B67 2B  HL is now 2 less for next position if needed
	jr      j_2b61		; @2B68 18F7  loop again

; draw remaining lives at bottom of screen

j_2b6a:
	ld      a,(game_mode)		; @2B6A 3A004E  load A with game mode
	cp      #01		; @2B6D FE01  == 1 ?  Are we in demo mode?
	ret     z		; @2B6F C8  If yes, return

	call    j_2bcd		; @2B70 CDCD2B  colors the bottom two rows of 10 the color 9 (yellow)
	db	#12,#44	; @2B73 1244  #4412 is starting location for above subroutine
	db	#09,#0A,#02	; @2B75 090A02  data used in above subroutine call.  9 is the color, #0A is the length, #02 is the number of rows
	ld hl,lives_displayed		; @2B78 21154E  load HL with address of number of lives to display
	ld      b,(hl)		; @2B7B 46  load B with number of lives to display
	jr      j_2b4a		; @2B7C 18CC  draw extra lives on screen and return

; Draws colors onscreen for a 2x2 grid.
; It requires that A is loaded with the code for the color,
; and HL is loaded with the memory address of the position on screen where the first color is to be drawn.
; If a clear value is to be drawn, the first address is called (#2B7E). 
; If A is preloaded with a color, then the second address is called (#2B80).

j_2b7e:
	LD 	A,#40		; @2B7E 3E40  Used to draw clear value
j_2b80:
	PUSH 	HL		; @2B80 E5  Save HL
	PUSH 	DE		; @2B81 D5  Save DE
	LD 	(HL),A		; @2B82 77  Draw color into first part
	INC 	HL		; @2B83 23  Set location to second part of fruit
	LD 	(HL),A		; @2B84 77  Draw color into second part
	LD 	DE,#001F		; @2B85 111F00  Offset is used for third part
	ADD 	HL,DE		; @2B88 19  Set location to third part of fruit
	LD 	(HL),A		; @2B89 77  Draw color into third part
	INC 	HL		; @2B8A 23  Set location to fourth part of fruit
	LD 	(HL),A		; @2B8B 77  Draw color into fourth part
	POP 	DE		; @2B8C D1  Restore DE
	POP 	HL		; @2B8D E1  Restore HL
	RET		; @2B8E C9  Return

; Draws the four parts of a fruit onscreen.  Also used to draw extra pac man lives at bottom of screen.
; It requires that A is loaded with the code for the first part of the fruit,
; and HL is loaded with the memory address of the first position on screen where it is to be drawn.

j_2b8f:
	PUSH 	HL		; @2B8F E5  Save HL
	PUSH 	DE		; @2B90 D5  Save DE
	LD 	DE,#001F		; @2B91 111F00  this offset is added later for third part of fruit 
	LD 	(HL),A		; @2B94 77  Draw first part of fruit code into screen memory
	INC 	A		; @2B95 3C  Point to second part of fruit
	INC 	HL		; @2B96 23  Increment screen memory for second part of fruit
	LD 	(HL),A		; @2B97 77  Draw second part of fruit code into screen memory
	INC 	A		; @2B98 3C  Point to third part of fruit
	ADD 	HL,DE		; @2B99 19  Add offset for third part of fruit
	LD 	(HL),A		; @2B9A 77  Draw third part of fruit code into screen memory
	INC 	A		; @2B9B 3C  Point to fourth part of fruit
	INC 	HL		; @2B9C 23  Increment screen memory for fourth part of fruit
	LD 	(HL),A		; @2B9D 77  Draw fourth part of fruit code into screen memory
	POP 	DE		; @2B9E D1  Restore DE
	POP 	HL		; @2B9F E1  Restore HL
	RET		; @2BA0 C9  Return     

	;; display number of credits

j_2ba1:
	ld      a,(credits)		; @2BA1 3A6E4E  load A with number of credits in ram
	cp      #FF		; @2BA4 FEFF  set for free play?
	jr      nz,j_2bad		; @2BA6 2005  no? then skip ahead
	ld      b,#02		; @2BA8 0602  load code for "FREE PLAY"
	jp      j_2c5e		; @2BAA C35E2C  print FREE PLAY and return from sub

j_2bad:
	ld      b,#01		; @2BAD 0601  else load code for "CREDIT"
	call    j_2c5e		; @2BAF CD5E2C  print "CREDIT" on screen
	ld      a,(credits)		; @2BB2 3A6E4E  load A with number of credits in ram
	and     #F0		; @2BB5 E6F0  mask bits.  is it bigger than 9?
	jr      z,j_2bc2		; @2BB7 2809  yes, only draw 1 position
	rrca		; @2BB9 0F  else ...  
	rrca		; @2BBA 0F
	rrca		; @2BBB 0F
	rrca		; @2BBC 0F  rotate right 4 times, which moves the 10's digit to the 1's digit
	add     a,#30		; @2BBD C630  Add #30 to account for ascii code for numbers
	ld      (#4034),a		; @2BBF 323440  put tens digit for number of credits on screen

j_2bc2:
	ld      a,(credits)		; @2BC2 3A6E4E  load A with number of credits in ram
	and     #0f		; @2BC5 E60F  mask out high bits.  result is between 0 and 9
	add     a,#30		; @2BC7 C630  Add #30 to account for ascii code for numbers
	ld      (#4033),a		; @2BC9 323340  put 1's digit number of credits on screen
	ret		; @2BCC C9  return

; this subroutine takes 5 bytes after the call and uses them to copy the 3rd byte into several memories
; first 2 bytes are the initial address to copy into 
; called from #2B70 to color the bottom area yellow where extra lives are drawn

j_2bcd:
	pop     hl		; @2BCD E1  load HL with address of next data byte in code
	ld      e,(hl)		; @2BCE 5E  load E with first byte.  MSB of address to use
	inc     hl		; @2BCF 23  next adddress
	ld      d,(hl)		; @2BD0 56  load D with second byte.  LSB of address to use
	inc     hl		; @2BD1 23  next address
	ld      c,(hl)		; @2BD2 4E  load C with third byte.  used for data to put into these memories
	inc     hl		; @2BD3 23  next address
	ld      b,(hl)		; @2BD4 46  load B with fourth byte ... used for loop counter
	inc     hl		; @2BD5 23  next address
	ld      a,(hl)		; @2BD6 7E  load A with fifth byte.  used for secondary loop counter
	inc     hl		; @2BD7 23  next address
	push    hl		; @2BD8 E5  push to stack for return address when done
	ex      de,hl		; @2BD9 EB  move DE into HL
	ld      de,#0020		; @2BDA 112000  load DE with offset value of #20

j_2bdd:
	push    hl		; @2BDD E5  save HL
	push    bc		; @2BDE C5  save BC

j_2bdf:
	ld      (hl),c		; @2BDF 71  store data into memory
	inc     hl		; @2BE0 23  next address
	djnz    j_2bdf		; @2BE1 10FC  Next B

	pop     bc		; @2BE3 C1  restore BC
	pop     hl		; @2BE4 E1  restore HL
	add     hl,de		; @2BE5 19  add offset (#20)
	dec     a		; @2BE6 3D  decrease counter.  are we done ?
	jr      nz,j_2bdd		; @2BE7 20F4  No, loop again
	ret		; @2BE9 C9  return

; called from #23A7 as task #1B
; called from #0792

j_2bea:
	ld      a,(game_mode)		; @2BEA 3A004E  load A with game mode
	cp      #01		; @2BED FE01  is this the attract mode ?
	ret     z		; @2BEF C8  yes, return

	;; draw the fruit

	ld      a,(level_number)		; @2BF0 3A134E  else Load A with current board level
	inc     a		; @2BF3 3C  increment it

; OTTOPATCH
;PATCH TO MAKE FRUIT not SCROLL ACROSS SCREEN BOTTOM WHEN MAXFRUIT IS REACHED.
;!    ORG 2BF4H
;!    JP MAXFRUIT
	jp      j_8793		; @2BF4 C39387  jump to new ms. pac man sub, returns to #2BF9


;; original pac-man code follows
; 2BF4 FE08 	CP 	#08 		; Is this level < 8 ?
; 2BF6 D22E2C 	JP 	NC,#2C2E 	; No, jump to compute different start for fruit table
;;


	; ;; gap-fill from golden boots $2BF7-$2BF8
	db	#2E,#2C		; @2BF7
j_2bf9:
	LD	DE,#3B08		; @2BF9 11083B  Yes, load DE with address of cherry in fruit table
	LD	B,A		; @2BFC 47  For B = 1 to level number
j_2bfd:
	LD	C,#07		; @2BFD 0E07  C is 7 = the total number of locations to draw
	LD	HL,#4004		; @2BFF 210440  Load HL with the start of video memory

j_2c02:
	LD	A,(DE)		; @2C02 1A  Load A with value from fruit table
	CALL	j_2b8f		; @2C03 CD8F2B  Draw fruit subroutine
	LD	A,#04		; @2C06 3E04
	ADD	A,H		; @2C08 84  Add 400 to HL
	LD	H,A		; @2C09 67  HL now points to color memory
	INC	DE		; @2C0A 13  DE now points to color code in fruit table
	LD	A,(DE)		; @2C0B 1A  Load A with color code from fruit table
	CALL	j_2b80		; @2C0C CD802B  Draw color subroutine
	LD	A,#FC		; @2C0F 3EFC
	ADD	A,H		; @2C11 84  Subtract 4 from H
	LD	H,A		; @2C12 67  HL now points back to video memory
	INC	DE		; @2C13 13  Increase pointer to next fruit in table
	INC	HL		; @2C14 23
	INC	HL		; @2C15 23  Next starting point is 2 bytes higher
	DEC	C		; @2C16 0D  Count down how many clears to draw
	DJNZ	j_2c02		; @2C17 10E9  Next B ? loop back and draw next fruit

j_2c19:
	DEC	C		; @2C19 0D  Count down C. Did C just turn negative?
	RET	M		; @2C1A F8  Yes, return to game, we are done
	CALL	j_2b7e		; @2C1B CD7E2B  No, call subroutine to draw a clear
	LD	A,#04		; @2C1E 3E04
	ADD	A,H		; @2C20 84
	LD	H,A		; @2C21 67  Increase HL by 400 for color value to be cleared
	XOR	A		; @2C22 AF  Load A with 0, the code for black color
	CALL	j_2b80		; @2C23 CD802B  Draw color subroutine ? draws black color
	LD	A,#FC		; @2C26 3EFC
	ADD	A,H		; @2C28 84  Subtract 4 from H
	LD	H,A		; @2C29 67  HL now points back to video memory
	INC	HL		; @2C2A 23
	INC	HL		; @2C2B 23  Set next starting point to be 2 bytes more
	JR	j_2c19		; @2C2C 18EB  Jump back and draw next clear

; Arrive here when the level is 8 or higher
; only used in pac-man, not ms. pac

	CP	#13		; @2C2E FE13  Is the level > #13 (19 decimal, 7th key) ?
	JR	C,j_2c34		; @2C30 3802  If not, skip next step
	LD	A,#13		; @2C32 3E13  If yes, treat all levels 19 and up as if they are level 19.
j_2c34:
	SUB	#07		; @2C34 D607  Subtract 7 to point to first value to be drawn
	LD	C,A		; @2C36 4F  Copy result to C
	LD	B,#00		; @2C37 0600  Load B with Zero
	LD	HL,#3B08		; @2C39 21083B  Load HL with pointer to start of fruit table
	ADD	HL,BC		; @2C3C 09
	ADD	HL,BC		; @2C3D 09  Adjust fruit table pointer, based on current level
	EX	DE,HL		; @2C3E EB  Load DE to point to fruit in table
	LD	B,#07		; @2C3F 0607  Load B counter to draw 7 fruit
	JP	j_2bfd		; @2C41 C3FD2B  Jump back up to fruit drawing section

; unknown subroutine [unused ???]
; can't find a call to here

	ld      b,a		; @2C44 47
	and     #0f		; @2C45 E60F
	add     a,#00		; @2C47 C600
	daa		; @2C49 27
	ld      c,a		; @2C4A 4F
	ld      a,b		; @2C4B 78
	and     #F0		; @2C4C E6F0
	jr      z,j_2c5b		; @2C4E 280B

	rrca		; @2C50 0F
	rrca		; @2C51 0F
	rrca		; @2C52 0F
	rrca		; @2C53 0F
	ld      b,a		; @2C54 47
	xor     a		; @2C55 AF
j_2c56:
	add     a,#16		; @2C56 C616
	daa		; @2C58 27
	djnz    j_2c56		; @2C59 10FB

j_2c5b:
	add     a,c		; @2C5B 81
	daa		; @2C5C 27
	ret		; @2C5D C9

	;; 	DrawText

        ;;   Renders messages from a table with coordinates and message data
        ;;   B = message # from table
	;;   B & 0x80 indicates to erase characters instead of draw them

	;; other flags:
	;;	top bit of address word & 0x80 -> draw in top or bottom two rows
	;;	first color & 0x80 -> use this color for the entire string 

; format of the table data:
;   .byte (offs l), (offs h)	; so an offset of #0234 would be #34, #02
;	increase L by 0x01 to move it down by 1 row
;	increase L by 0x20 to move it left one column
;	set H|0x80 to indicate top or bottom two rows
;   .ascii "STRING"
;   .byte #2f			; termination with 2f
;   .byte colordata:
;	if the color data byte's high bit (#80) is set, the entire string
;	gets colored with (colordata & 0x7f) 
;		no termination, just the one entry.
;	if the color data byte's high bit is not set, then:
;	.byte 	ncolors		; number of bytes to set color
;	.byte	color1		; first character's color
;	.byte	color2		; second character's color
;		...		; etc
;	 (no termination - just as many entries as there were characters)

DrawText:
	; drawText( b )  ; b is index
j_2c5e:
	ld      hl,#36a5		; @2C5E 21A536  load HL with the text string lookup table
	rst     #18		; @2C61 DF  (hl+2*b) -> hl

	; 1. get start offset into vid/color buffer
	; e = (hl++) ; d = (hl)		; load two bytes in as a pointer
	; indexOffset = de
	ld      e,(hl)		; @2C62 5E  load E with value from table
	inc     hl		; @2C63 23  next table entry
	ld      d,(hl)		; @2C64 56  DE contains start offset

	; 2. use offset for start of color, save to stack
	; ix = 0x4400 + indexOffset
	ld      ix,#4400		; @2C65 DD210044  load IX with start of color RAM
	add     ix,de		; @2C69 DD19  add offset to calculate start pos in CRAM
	push    ix		; @2C6B DDE5  save to stack for use later (#2C93)

	; 3. use offset for start of character ram
	; ix = characterRam + indexOffset
	; offsetPerCharacter = -1	; de
	; if (hl) & 0x80 then offsetPerCharacter = -0x20
	ld      de,#FC00		; @2C6D 1100FC  load DE with offset for VRAM
	add     ix,de		; @2C70 DD19  add to calculate start position in VRAM
	ld      de,#FFFF		; @2C72 11FFFF  load DE with offset for top & bottom lines (offset equals negative 1)
	bit     7,(hl)		; @2C75 CB7E  test bit 7 of HL.  Is this text for the top + bottom 2 lines ?

	; it should be noted that since the high bit on the offset address
	; is used to denote that the string goes into the top or bottom
	; two rows, it ends up relying on the unused ram mirroring.
	; that is to say that it actually ends up drawing up around C000
	; instead of 4000.  A patch is below as HACK12

	; (this skips the offsetPerCharacter with -20 if necessary)
	jr      nz,j_2c7c		; @2C77 2003  yes, skip next step
	ld      de,#FFE0		; @2C79 11E0FF  no, load DE with offset for normal text (equals negative #20)

	; 4. determine special entry, go to 2cac for that
	; hl++
	; a = stringToDraw * 2
	; if( carry) goto BlankTextDraw	;AKA  if( stringToDraw# & 0x80) then goto BlankTextDraw
BlankTextDrawCheck:
j_2c7c:
	inc     hl		; @2C7C 23  next table entry
	ld      a,b		; @2C7D 78  A := B.  B was preloaded with the code # of the text to display
	ld      bc,#0000		; @2C7E 010000  clear BC
	add     a,a		; @2C81 87  A : = A * 2.  Is this a special entry ?
	jr      c,j_2cac		; @2C82 3828  special draw for entries 80+

textRenderLoop0:
	; ch = current character  	; 'a' = (hl)
	; if ch == 0x2f, goto SingleOrMultiColorCheck:
	; *characterVram = ch		; ram[ix+0] = 'a'
	; characterVram += de		; (+= but it really subtracts 1 or 0x20, contents of 'de')
	; nchars ++  			; 'b'++
	; goto textRenderLoop0
j_2c84:
	ld      a,(hl)		; @2C84 7E  load A with next character
	cp      #2f		; @2C85 FE2F  == #2F ? (end of text code)
	jr      z,j_2c92		; @2C87 2809  yes, done with VRAM, skip ahead to color

	ld      (ix+#00),a		; @2C89 DD7700  write character to screen
	inc     hl		; @2C8C 23  next character
	add     ix,de		; @2C8D DD19  calculate next VRAM pos
	inc     b		; @2C8F 04  increment counter
	jr      j_2c84		; @2C90 18F2  loop

SingleOrMultiColorCHeck:
	; ix = startColorRamPos
j_2c92:
	inc     hl		; @2C92 23  next table entry
j_2c93:
	pop     ix		; @2C93 DDE1  get CRAM start pos

	; color = *colorToUse
	; if (color) is > 80, goto TextSingleColorRender
	ld      a,(hl)		; @2C95 7E  load A with color
	and     a		; @2C96 A7  > #80 ?
	jp      m,j_2ca4		; @2C97 FAA42C  yes, skip ahead

TextMultiColorRender:
	; color = *colorToUse
	; colorRam[ix] = color;
	; colorToUse++
	; move ix to the next screen position ( -=1 or -=0x20)
	; b--; if b>0 then goto TextMultiColorRender
	; return
j_2c9a:
	ld      a,(hl)		; @2C9A 7E  else load A with color
	ld      (ix+#00),a		; @2C9B DD7700  color the screen position Color RAM
	inc     hl		; @2C9E 23  next color
	add     ix,de		; @2C9F DD19  calc next CRAM pos
	djnz    j_2c9a		; @2CA1 10F7  loop until b==0
	ret		; @2CA3 C9  return


	;; same as above, but all the same color
TextSingleColorRender:
	; colorRam[ix] = color
	; move ix to the next screen position( -=1 or -=0x20)
	; b--; if b>0 then goto TextSingleColorRender
	; return
j_2ca4:
	ld      (ix+#00),a		; @2CA4 DD7700  drop in CRAM
	add     ix,de		; @2CA7 DD19  calc next CRAM pos
	djnz    j_2ca4		; @2CA9 10F9  loop until b==0
	ret		; @2CAB C9

	;; message # > 80 se 2nd color code
BlankTextDraw:
	; character = *characterToDraw
	; if( color = 0x2f ) goto FinishUpBlankTextDraw
	; characterRam[ix] = 0x40 ("@", which is ' ' in Pac-Man)
	; characterToDraw++
	; b++
j_2cac:
	ld      a,(hl)		; @2CAC 7E  read next char
	cp      #2f		; @2CAD FE2F  are we done ?
	jr      z,j_2cbb		; @2CAF 280A  yes, done with vram

	ld      (ix+#00),#40		; @2CB1 DD360040  clears the character
	inc     hl		; @2CB5 23  next char
	add     ix,de		; @2CB6 DD19  next screen pos
	inc     b		; @2CB8 04  inc char count
	jr      j_2cac		; @2CB9 18F1  loop

FinishUpBlankTextDraw:
	; while (*hl != 0x2f) hl++
	; goto SingleOrMultiColorCheck +1
j_2cbb:
	inc     hl		; @2CBB 23  next char
	inc     b		; @2CBC 04  inc char count
	cpir		; @2CBD EDB1  loop until [hl] = 2f
	jr      j_2c93		; @2CBF 18D2  do CRAM

	;; HACK12 - fixes the C000 top/bottom draw mirror issue
	; 2c62  c300d0	jp	hack12

	; hack12:   ;;; up at 0xd000 for this example
	; d000  5e        ld	e, (hl)		; patch (2c62)
	; d001  23        inc	hl		; patch (2c63)
	; d002  7e        ld	a, (hl)		; patch (2c64 almost)
	; d003  e67f      and	#0x7f		; mask off the top/bottom flag
	; d005  57        ld	d, a		; d cleared of that bit now (C000-safe!)
	; d006  7e        ld	a, (hl)		; set aside A for part 2, below
	; d007  c3652c    jp	#2c65		; resume


        ;;
        ;; PROCESS WAVE (all voices) (SOUND)
        ;; called from #01BC
	;;

;if MSPACMAN
j_2cc1:
	jp      j_9797		; @2CC1  sprite/cocktail stuff. we don't care for sound.
                          		; The routine ends with "ld hl,#9685", "jp #2cc4"
                          		; so this is a Ms Pacman patch
;else
;	ld      hl,SONG_TABLE_1		; @2CC1
;endif

        ;; channel 1 song

j_2cc4:
	ld      ix,CH1_W_NUM		; @2CC4  ix = Pointer to Song number
	ld      iy,CH1_FREQ0		; @2CC8  iy = Pointer to Freq/Vol parameters
	call    j_2d44		; @2CCC  call process_wave
	ld      b,a		; @2CCF  A is the returned volume (save it in B)
	ld      a,(CH1_W_NUM)		; @2CD0  if we are playing a song
	and     a		; @2CD3
	jr      z,j_2cda		; @2CD4
	ld      a,b		; @2CD6  then
	ld      (CH1_VOL),a		; @2CD7  save volume

        ;; channel 2 song

j_2cda:
	ld      hl,SONG_TABLE_2		; @2CDA
	ld      ix,CH2_W_NUM		; @2CDD
	ld      iy,CH2_FREQ1		; @2CE1
	call    j_2d44		; @2CE5
	ld      b,a		; @2CE8
	ld      a,(CH2_W_NUM)		; @2CE9
	and     a		; @2CEC
	jr      z,j_2cf3		; @2CED
	ld      a,b		; @2CEF
	ld      (CH2_VOL),a		; @2CF0

        ;; channel 3 song

j_2cf3:
	ld      hl,SONG_TABLE_3		; @2CF3
	ld      ix,CH3_W_NUM		; @2CF6
	ld      iy,CH3_FREQ1		; @2CFA
	call    j_2d44		; @2CFE
	ld      b,a		; @2D01
	ld      a,(CH3_W_NUM)		; @2D02
	and     a		; @2D05
	ret     z		; @2D06
	ld      a,b		; @2D07
	ld      (CH3_VOL),a		; @2D08
	ret		; @2D0B


        ;;
        ;; PROCESS EFFECT (all voices)
        ;;

j_2d0c:
	ld      hl,EFFECT_TABLE_1		; @2D0C  pointer to sound table
	ld      ix,CH1_E_NUM		; @2D0F  effect number (voice 1)
	ld      iy,CH1_FREQ0		; @2D13
	call    j_2dee		; @2D17  call process effect, returns volume in A
	ld      (CH1_VOL),a		; @2D1A  store volume

	ld      hl,EFFECT_TABLE_2		; @2D1D  same for voice 2
	ld      ix,CH2_E_NUM		; @2D20
	ld      iy,CH2_FREQ1		; @2D24
	call    j_2dee		; @2D28
	ld      (CH2_VOL),a		; @2D2B

	ld      hl,EFFECT_TABLE_3		; @2D2E  same for voice 3
	ld      ix,CH3_E_NUM		; @2D31
	ld      iy,CH3_FREQ1		; @2D35
	call    j_2dee		; @2D39
	ld      (CH3_VOL),a		; @2D3C

	xor     a		; @2D3F  A = 0
	ld      (CH1_FREQ4),a		; @2D40  freq 4 channel 1 = 0
	ret		; @2D43


        ;;
        ;; Process wave (one voice)
        ;;

j_2d44:
	ld      a,(ix+#00)		; @2D44  if (W_NUM == 0)
	and     a		; @2D47
	jp      z,j_2df4		; @2D48  then goto init_param

	ld      c,a		; @2D4B  c = W_NUM
	ld      b,#08		; @2D4C  b = 0x08
	ld      e,#80		; @2D4E  e = 0x80

j_2d50:
	ld      a,e		; @2D50  find which bit is set in W_NUM
	and     c		; @2D51
	jr      nz,j_2d59		; @2D52  found one, goto process wave bis
	srl     e		; @2D54
	djnz    j_2d50		; @2D56
	ret		; @2D58  return

        ;;
        ;; Process wave bis : process one wave, represented by 1 bit (in E)
        ;;

j_2d59:
	ld      a,(ix+#02)		; @2D59  A = CUR_BIT
	and     e		; @2D5C
	jr      nz,j_2d66		; @2D5D  if (CUR_BIT & E != 0) then goto #2d66
	ld      (ix+#02),e		; @2D5F  else save E in CUR_BIT
	jp      j_364e		; @2D62  jump to new ms. pac man routine.  returns to #2D72

	inc     c		; @2D65  junk from pac-man

j_2d66:
	dec     (ix+#0c)		; @2D66  decrement W_DURATION
	jp      nz,j_2dd7		; @2D69  if W_DURATION == 0

	ld      l,(ix+#06)		; @2D6C  then HL = pointer store in W_OFFSET
	ld      h,(ix+#07)		; @2D6F

        ;; process byte

j_2d72:
	ld      a,(hl)		; @2D72  A = (HL)
	inc     hl		; @2D73
	ld      (ix+#06),l		; @2D74  W_OFFSET = ++HL
	ld      (ix+#07),h		; @2D77
	cp      #F0		; @2D7A  if (A < F0)
	jr      c,j_2da5		; @2D7C  then process A  (regular byte)
	ld      hl,#2d6c		; @2D7E  else process special byte using a jump table.  load HL with return address
	push    hl		; @2D81  push return address to stack
	and     #0f		; @2D82  mask bits; takes lowest nibble of special byte
	rst     #20		; @2D84  and jump based on A (return in HL = 2d6c)

        ;; jump table

	db	#55,#2F	; @2D85 552F  #2F55 ; byte is F0
	db	#65,#2F	; @2D87 652F  #2F65 ; byte is F1
	db	#77,#2F	; @2D89 772F  #2F77 ; byte is F2
	db	#89,#2F	; @2D8B 892F  #2F89 ; byte is F3
	db	#9B,#2F	; @2D8D 9B2F  #2F9B ; byte is F4
	db	#0C,#00	; @2D8F 0C00  #000C ; returns immediately ; byte is F5
	db	#0C,#00	; @2D91 0C00  #000C ; returns immediately ; byte is F6
	db	#0C,#00	; @2D93 0C00  #000C ; returns immediately ; byte is F7
	db	#0C,#00	; @2D95 0C00  #000C ; returns immediately ; byte is F8
	db	#0C,#00	; @2D97 0C00  #000C ; returns immediately ; byte is F9
	db	#0C,#00	; @2D99 0C00  #000C ; returns immediately ; byte is FA
	db	#0C,#00	; @2D9B 0C00  #000C ; returns immediately ; byte is FB
	db	#0C,#00	; @2D9D 0C00  #000C ; returns immediately ; byte is FC
	db	#0C,#00	; @2D9F 0C00  #000C ; returns immediately ; byte is FD
	db	#0C,#00	; @2DA1 0C00  #000C ; returns immediately ; byte is FE
	db	#AD,#2F	; @2DA3 AD2F  #2FAD ; byte is FF


        ;; process regular byte (A=byte to process, it's not a special byte)

j_2da5:
	ld      b,a		; @2DA5  copy A into B

	and     #1f		; @2DA6
	jr      z,j_2dad		; @2DA8  if (A & 0x1f == 0)
	ld      (ix+#0d),b		; @2DAA  then W_DIR = B
j_2dad:
	ld      c,(ix+#09)		; @2DAD  C = W_9
	ld      a,(ix+#0b)		; @2DB0
	and     #08		; @2DB3
	jr      z,j_2db9		; @2DB5  if (W_8 & 0x8 == 0)
	ld      c,#00		; @2DB7  then VOL = 0
j_2db9:
	ld      (ix+#0f),c		; @2DB9  else VOL = W_9

	ld      a,b		; @2DBC  restore A
	rlca		; @2DBD
	rlca		; @2DBE
	rlca		; @2DBF
	and     #07		; @2DC0  A = (A & 0xE0) >> 5
	ld      hl,#3bb0		; @2DC2
	rst     #10		; @2DC5  A = ROM[0x3bb0 + A]
                                ; Note: this is just A = 2**A

	ld      (ix+#0c),a		; @2DC6  W_DURATION = A

	ld      a,b		; @2DC9  restore A
	and     #1f		; @2DCA
	jr      z,j_2dd7		; @2DCC  if (A & 0x1f == 0) then goto compute_wave_freq
	and     #0f		; @2DCE  A = A & 0x0F
	ld      hl,#3bb8		; @2DD0  lookup table, contains a table a frequencies
	rst     #10		; @2DD3
	ld      (ix+#0e),a		; @2DD4  W_BASE_FREQ = ROM[3bb8 + A]

        ;; compute wave frequency

j_2dd7:
	ld      l,(ix+#0e)		; @2DD7
	ld      h,#00		; @2DDA  HL = W_BASE_FREQ (on 16 bits)

	ld      a,(ix+#0d)		; @2DDC  A = W_DIR
	and     #10		; @2DDF
	jr      z,j_2de5		; @2DE1  if (W_DIR & 0x10 != 0) then
	ld      a,#01		; @2DE3  A = 1
j_2de5:
	add     a,(ix+#04)		; @2DE5  A += W_4

	jp      z,j_2ee8		; @2DE8  compute new frequency  FREQ = BASE_FREQ * (1 << A)
	jp      j_2ee4		; @2DEB


        ;;
        ;; Process effect (one voice)
        ;;

j_2dee:
	ld      a,(ix+#00)		; @2DEE  if (E_NUM != 0)
	and     a		; @2DF1
	jr      nz,j_2e1b		; @2DF2  then goto find effect

        ;;
        ;; Init Param
        ;;

j_2df4:
	ld      a,(ix+#02)		; @2DF4  if (CUR_BIT == 0)
	and     a		; @2DF7
	ret     z		; @2DF8  then return


	ld      (ix+#02),#00		; @2DF9  CUR_BIT = 0
	ld      (ix+#0d),#00		; @2DFD  DIR = 0
	ld      (ix+#0e),#00		; @2E01  BASE_FREQ = 0
	ld      (ix+#0f),#00		; @2E05  VOL = 0
	ld      (iy+#00),#00		; @2E09  FREQ0 or 1   (5 freq for channel 1)
	ld      (iy+#01),#00		; @2E0D  FREQ1 or 2
	ld      (iy+#02),#00		; @2E11  FREQ2 or 3
	ld      (iy+#03),#00		; @2E15  FREQ3 or 4
	xor     a		; @2E19
	ret		; @2E1A  return 0

        ;;
        ;; find effect. Effect num is not zero, find which bits are set
        ;;

j_2e1b:
	ld      c,a		; @2E1B  c = E_NUM
	ld      b,#08		; @2E1C  b = 0x08
	ld      e,#80		; @2E1E  e = 0x80

j_2e20:
	ld      a,e		; @2E20  find which bit is set in E_NUM
	and     c		; @2E21
	jr      nz,j_2e29		; @2E22  found one, goto proces effect bis
	srl     e		; @2E24
	djnz    j_2e20		; @2E26
	ret		; @2E28


        ;;
        ;; Process effect bis : process one effect, represented by 1 bit (in E)
        ;;

j_2e29:
	ld      a,(ix+#02)		; @2E29  A = CUR_BIT
	and     e		; @2E2C
	jr      nz,j_2e6e		; @2E2D  if (CUR_BIT & E != 0) then goto 2e6e
	ld      (ix+#02),e		; @2E2F  else save E in CUR_BIT

                                ; locate the 8 bytes for this effect in the rom tables
	dec     b		; @2E32  the address is at HL + (B-1) * 8
	ld      a,b		; @2E33
	rlca		; @2E34
	rlca		; @2E35
	rlca		; @2E36
	ld      c,a		; @2E37  C = (B-1)*8
	ld      b,#00		; @2E38  B = 0
	push    hl		; @2E3A  save HL (pointer to EFFECT_TABLE)
	add     hl,bc		; @2E3B  HL = HL + (B-1)*8
	push    ix		; @2E3C
	pop     de		; @2E3E  DE = E_NUM
	inc     de		; @2E3F
	inc     de		; @2E40
	inc     de		; @2E41  DE = E_TABLE0
	ld      bc,#0008		; @2E42
	ldir		; @2E45  copy 8 bytes from rom
	pop     hl		; @2E47  restore HL (pointer to EFFECT_TABLE)

	ld      a,(ix+#06)		; @2E48
	and     #7f		; @2E4B
	ld      (ix+#0c),a		; @2E4D  E_DURATION = E_TABLE3 & 0x7F

	ld      a,(ix+#04)		; @2E50
	ld      (ix+#0e),a		; @2E53  E_BASE_FREQ = E_TABLE1

	ld      a,(ix+#09)		; @2E56
	ld      b,a		; @2E59  B = E_TABLE6
	rrca		; @2E5A
	rrca		; @2E5B
	rrca		; @2E5C
	rrca		; @2E5D
	and     #0f		; @2E5E
	ld      (ix+#0b),a		; @2E60  E_TYPE = (E_TABLE6 >> 4) & 0xF

	and     #08		; @2E63
	jr      nz,j_2e6e		; @2E65  if (E_TYPE & 0x8 == 0) then
	ld      (ix+#0f),b		; @2E67  E_VOL = E_TABLE6
	ld      (ix+#0d),#00		; @2E6A  E_DIR = 0

        ;; compute effect

j_2e6e:
	dec     (ix+#0c)		; @2E6E  E_DURATION--
	jr      nz,j_2ecd		; @2E71  if (E_DURATION == 0) then
	ld      a,(ix+#08)		; @2E73
	and     a		; @2E76
	jr      z,j_2e89		; @2E77  if (E_TABLE5 != 0) then
	dec     (ix+#08)		; @2E79  E_TABLE5--
	jr      nz,j_2e89		; @2E7C  if (E_TABLE5 == 0) then
	ld      a,e		; @2E7E
	cpl		; @2E7F
	and     (ix+#00)		; @2E80
	ld      (ix+#00),a		; @2E83  E_NUM &= ~E_CUR_BIT
	jp      j_2dee		; @2E86  goto process effect (one voice)
j_2e89:
	ld      a,(ix+#06)		; @2E89
	and     #7f		; @2E8C
	ld      (ix+#0c),a		; @2E8E  E_DURATION = E_TABLE3 & 0x7F
	bit     7,(ix+#06)		; @2E91
	jr      z,j_2ead		; @2E95  if (E_TABLE3 & 0x80 != 0) then
	ld      a,(ix+#05)		; @2E97
	neg		; @2E9A
	ld      (ix+#05),a		; @2E9C  E_TABLE2 = - E_TABLE2
	bit     0,(ix+#0d)		; @2E9F  if (E_DIR & 0x1 == 0) then
	set     0,(ix+#0d)		; @2EA3  E_DIR |= 0x1
	jr      z,j_2ecd		; @2EA7  goto update_freq
	res     0,(ix+#0d)		; @2EA9  E_DIR &= ~0x1
j_2ead:
	ld      a,(ix+#04)		; @2EAD
	add     a,(ix+#07)		; @2EB0
	ld      (ix+#04),a		; @2EB3  E_TABLE1 += E_TABLE4
	ld      (ix+#0e),a		; @2EB6  E_BASE_FREQ = E_TABLE1
	ld      a,(ix+#09)		; @2EB9
	add     a,(ix+#0a)		; @2EBC
	ld      (ix+#09),a		; @2EBF  E_TABLE6 += E_TABLE7
	ld      b,a		; @2EC2
	ld      a,(ix+#0b)		; @2EC3
	and     #08		; @2EC6
	jr      nz,j_2ecd		; @2EC8  if (E_TYPE & 0x8 == 0) then
	ld      (ix+#0f),b		; @2ECA  E_VOL = E_TABLE6


        ;; update freq

j_2ecd:
	ld      a,(ix+#0e)		; @2ECD
	add     a,(ix+#05)		; @2ED0
	ld      (ix+#0e),a		; @2ED3  E_BASE_FREQ += E_TABLE2

	ld      l,a		; @2ED6
	ld      h,#00		; @2ED7  HL = E_BASE_FREQ (on 16 bits)

	ld      a,(ix+#03)		; @2ED9  compute new frequency
	and     #70		; @2EDC  FREQ = E_BASE_FREQ * ((1 << E_TABLE0 & 0x70) >> 4)
	jr      z,j_2ee8		; @2EDE
	rrca		; @2EE0
	rrca		; @2EE1
	rrca		; @2EE2
	rrca		; @2EE3

        ;; compute new frequency

j_2ee4:
	ld      b,a		; @2EE4  B = counter
j_2ee5:
	add     hl,hl		; @2EE5  HL = 2 * HL
	djnz    j_2ee5		; @2EE6
                                ; HL = HL * 2**B
                                ; now extract the nibbles from HL

j_2ee8:
	ld      (iy+#00),l		; @2EE8  1st nibble
	ld      a,l		; @2EEB
	rrca		; @2EEC
	rrca		; @2EED
	rrca		; @2EEE
	rrca		; @2EEF
	ld      (iy+#01),a		; @2EF0  2nd nibble
	ld      (iy+#02),h		; @2EF3  3rd nibble
	ld      a,h		; @2EF6
	rrca		; @2EF7
	rrca		; @2EF8
	rrca		; @2EF9
	rrca		; @2EFA
	ld      (iy+#03),a		; @2EFB  4th nibble

	ld      a,(ix+#0b)		; @2EFE  A = W_TYPE
	rst     #20		; @2F01  jump table to volume adjust routine

        ; jump table to adjust volume

	db	#22,#2F	; @2F02 222F  #2F22
	db	#26,#2F	; @2F04 262F  #2F26
	db	#2B,#2F	; @2F06 2B2F  #2F2B
	db	#3C,#2F	; @2F08 3C2F  #2F3C
	db	#43,#2F	; @2F0A 432F  #2F43
	db	#4A,#2F	; @2F0C 4A2F  #2F4A
	db	#4B,#2F	; @2F0E 4B2F  #2F4B
	db	#4C,#2F	; @2F10 4C2F  #2F4C
	db	#4D,#2F	; @2F12 4D2F  #2F4D
	db	#4E,#2F	; @2F14 4E2F  #2F4E
	db	#4F,#2F	; @2F16 4F2F  #2F4F
	db	#50,#2F	; @2F18 502F  #2F50
	db	#51,#2F	; @2F1A 512F  #2F51
	db	#52,#2F	; @2F1C 522F  #2F52
	db	#53,#2F	; @2F1E 532F  #2F53
	db	#54,#2F	; @2F20 542F  #2F54

        ;; type 0

	ld      a,(ix+#0f)		; @2F22  constant volume
	ret		; @2F25

        ;; type 1

	ld      a,(ix+#0f)		; @2F26  decreasing volume
	jr      j_2f34		; @2F29

        ;; type 2

	ld      a,(SOUND_COUNTER)		; @2F2B  decreasing volume (1/2 rate)
	and     #01		; @2F2E
j_2f30:
	ld      a,(ix+#0f)		; @2F30  (skip decrease if sound_counter (4c84) is odd)
	ret     nz		; @2F33

j_2f34:
	and     #0f		; @2F34  decrease routine
	ret     z		; @2F36
	dec     a		; @2F37
	ld      (ix+#0f),a		; @2F38
	ret		; @2F3B

        ;; type 3

	ld      a,(SOUND_COUNTER)		; @2F3C  decreasing volume (1/4 rate)
	and     #03		; @2F3F
	jr      j_2f30		; @2F41

        ;; type 4

	ld      a,(SOUND_COUNTER)		; @2F43  decreasing volume (1/8 rate)
	and     #07		; @2F46
	jr      j_2f30		; @2F48

        ;; type 5-15

	ret		; @2F4A C9
	ret		; @2F4B C9
	ret		; @2F4C C9
	ret		; @2F4D C9
	ret		; @2F4E C9
	ret		; @2F4F C9
	ret		; @2F50 C9
	ret		; @2F51 C9
	ret		; @2F52 C9
	ret		; @2F53 C9
	ret		; @2F54 C9

        ;;
        ;; Special byte F0 : this is followed by 2 bytes, the new offset (to allow loops)
        ;;

	ld      l,(ix+#06)		; @2F55
	ld      h,(ix+#07)		; @2F58  HL = (W_OFFSET)
	ld      a,(hl)		; @2F5B
	ld      (ix+#06),a		; @2F5C
	inc     hl		; @2F5F
	ld      a,(hl)		; @2F60
	ld      (ix+#07),a		; @2F61  HL = (HL)
	ret		; @2F64

        ;;
        ;; Special byte F1 : followed by one byte (wave select)
        ;;

	ld      l,(ix+#06)		; @2F65
	ld      h,(ix+#07)		; @2F68
	ld      a,(hl)		; @2F6B  A = (++HL)
	inc     hl		; @2F6C
	ld      (ix+#06),l		; @2F6D
	ld      (ix+#07),h		; @2F70
	ld      (ix+#03),a		; @2F73  save A in W_WAVE_SEL
	ret		; @2F76

        ;;
        ;; Special byte F2 : followed by one byte (Frequency increment)
        ;;

	ld      l,(ix+#06)		; @2F77
	ld      h,(ix+#07)		; @2F7A
	ld      a,(hl)		; @2F7D  A = (++HL)
	inc     hl		; @2F7E
	ld      (ix+#06),l		; @2F7F
	ld      (ix+#07),h		; @2F82
	ld      (ix+#04),a		; @2F85  save A in W_A
	ret		; @2F88

        ;;
        ;; Special byte F3 : followed by one byte (Volume)
        ;;

	ld      l,(ix+#06)		; @2F89
	ld      h,(ix+#07)		; @2F8C
	ld      a,(hl)		; @2F8F  A = (++HL)
	inc     hl		; @2F90
	ld      (ix+#06),l		; @2F91
	ld      (ix+#07),h		; @2F94
	ld      (ix+#09),a		; @2F97  save A in W_VOL
	ret		; @2F9A

        ;;
        ;; Special byte F4 : followed by one byte (Type)
	;;

	ld      l,(ix+#06)		; @2F9B
	ld      h,(ix+#07)		; @2F9E
	ld      a,(hl)		; @2FA1  A = (++HL)
	inc     hl		; @2FA2
	ld      (ix+#06),l		; @2FA3
	ld      (ix+#07),h		; @2FA6
	ld      (ix+#0b),a		; @2FA9  save A in W_TYPE
	ret		; @2FAC

        ;;
        ;; Special byte FF : mark the end of the song
        ;;

	ld      a,(ix+#02)		; @2FAD
	cpl		; @2FB0
	and     (ix+#00)		; @2FB1
	ld      (ix+#00),a		; @2FB4  W_NUM &= ~W_CUR_BIT
	jp      j_2df4		; @2FB7

;

	db	#00,#00,#00,#00,#00,#00	; @2FBA 000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @2FC0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @2FD0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @2FE0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @2FF0 0000000000000000000000000000

	db	#83,#4C	; @2FFE 834C  checksum bytes for #2000-#2FFF


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 3000 - 3fff
;; this rom is somehow overlayed from U7 on the aux board.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	;; rst 38 continuation (initalization routine portion)
	;; the rom checksum routine 

j_3000:
	ld      hl,#0000		; @3000 210000  clear HL
j_3003:
	ld      bc,#1000		; @3003 010010  B := #10 (loop counter), C := #00

	; reclaim a lot of romspace by skipping self test ; HACK4
	; 3000  31c04f    ld      sp,#4fc0
	; 3003  c3c130    jp      #30c1
	;

j_3006:
	ld      (watchdog),a		; @3006 32C050  kick the dog

j_3009:
	ld      a,c		; @3009 79  A := C
	add     a,(hl)		; @300A 86  add the value in HL into A
	ld      c,a		; @300B 4F  copy to C
	ld      a,l		; @300C 7D  load A with the low byte of HL
	add     a,#02		; @300D C602  add 2.  this ensures only checking even or odd bytes
	ld      l,a		; @300F 6F  store result
	cp      #02		; @3010 FE02  < #02 ?
	jp      nc,j_3009		; @3012 D20930  no, loop again

	inc     h		; @3015 24  yes, increase H
	djnz    j_3006		; @3016 10EE  next B

	ld      a,c		; @3018 79  load A with the final result
	and     a		; @3019 A7  == #00 ?  It must be zero for the checksum to work out

	nop		; @301A 00  ; this is a hack to disregard bad csums
	nop		; @301B 00  ; this is a hack to disregard bad csums
	
	; PAC and ms pac non-bootleg
	;301a  2015	jr 	nz, #3031	; check for bad checksum
	;

	ld      (coin_counter_out),a		; @301C 320750  clear coin
	ld      a,h		; @301F 7C  load A with high byte
	cp      #30		; @3020 FE30  == #30 ?
	jp      nz,j_3003		; @3022 C20330  no, loop back and continue for other roms

	ld      h,#00		; @3025 2600  else H := #00
	inc     l		; @3027 2C  increase L.  this will give a check of the odd numbered bytes
	ld      a,l		; @3028 7D  load A with this value. 
	cp      #02		; @3029 FE02  are we all done ?
	jp      c,j_3003		; @302B DA0330  no, loop again

	jp      j_3042		; @302E C34230  yes, skip ahead for RAM test

		;; bad rom checksum  (not called in bootleg, due to above patch)

	dec     h		; @3031 25  decrease H
	ld      a,h		; @3032 7C  store into A
	and     #F0		; @3033 E6F0  mask bits
	ld      (coin_counter_out),a		; @3035 320750  clear Coin counter
	rrca		; @3038 0F
	rrca		; @3039 0F
	rrca		; @303A 0F
	rrca		; @303B 0F  rotate right 4 times 
	ld      e,a		; @303C 5F  load E with failed ROM number
	ld      b,#00		; @303D 0600  load B with code for error
	jp      j_30bd		; @303F C3BD30  skip ahead

		;; RAM TEST (4c00)

j_3042:
	ld      sp,#3154		; @3042 315431  set stack pointer to ram test data table
j_3045:
	ld      b,#FF		; @3045 06FF  B := FF

j_3047:
	pop     hl		; @3047 E1  load HL with table data = starting address to test
	pop     de		; @3048 D1  load DE with table data.  D = loop counter (always #04) , E = mask (either #0F or F0)
	ld      c,b		; @3049 48  C := FF

		; write to RAM

j_304a:
	ld      (watchdog),a		; @304A 32C050  kick the dog

j_304d:
	ld      a,c		; @304D 79  A := C
	and     e		; @304E A3  mask bits with E
	ld      (hl),a		; @304F 77  store into memory
	add     a,#33		; @3050 C633  add #33
	ld      c,a		; @3052 4F  store into C
	inc     l		; @3053 2C  next memory
	ld      a,l		; @3054 7D  A : = L
	and     #0f		; @3055 E60F  mask bits.  are we done ?
	jp      nz,j_304d		; @3057 C24D30  no, loop again

	ld      a,c		; @305A 79  yes, A := C
	add     a,a		; @305B 87  A := A * 2
	add     a,a		; @305C 87  A := A * 2
	add     a,c		; @305D 81  A := A + C
	add     a,#31		; @305E C631  A := A + #31
	ld      c,a		; @3060 4F  C := A
	ld      a,l		; @3061 7D  A := L
	and     a		; @3062 A7  are we done ?
	jp      nz,j_304d		; @3063 C24D30  no, loop again

	inc     h		; @3066 24  yes, next high byte
	dec     d		; @3067 15  decrement counter.  are we done ?
	jp      nz,j_304a		; @3068 C24A30  no, loop again

	dec     sp		; @306B 3B
	dec     sp		; @306C 3B
	dec     sp		; @306D 3B
	dec     sp		; @306E 3B  yes, set stack pointer back to beginning
	pop     hl		; @306F E1  load HL with table data
	pop     de		; @3070 D1  load DE with table data
	ld      c,b		; @3071 48  C := B

		; check RAM again

j_3072:
	ld      (watchdog),a		; @3072 32C050  kick the dog

j_3075:
	ld      a,c		; @3075 79  A := C
	and     e		; @3076 A3  mask bits with E
	ld      c,a		; @3077 4F  C := A
	ld      a,(hl)		; @3078 7E  load A with memory value
	and     e		; @3079 A3  mask bits with E
	cp      c		; @307A B9  are they the same ?
	jp      nz,j_30b5		; @307B C2B530  no, RAM test failed, jump ahead for bad RAM

	add     a,#33		; @307E C633  yes, A := A + #33
	ld      c,a		; @3080 4F  C := A
	inc     l		; @3081 2C  next address
	ld      a,l		; @3082 7D  A := L
	and     #0f		; @3083 E60F  mask bits, are we done ?
	jp      nz,j_3075		; @3085 C27530  no, loop again

	ld      a,c		; @3088 79  yes, A := C
	add     a,a		; @3089 87  A := A * 2
	add     a,a		; @308A 87  A := A * 2
	add     a,c		; @308B 81  A := A + C
	add     a,#31		; @308C C631  A := A + #31
	ld      c,a		; @308E 4F  C := A
	ld      a,l		; @308F 7D  A := L
	and     a		; @3090 A7  are we done ?
	jp      nz,j_3075		; @3091 C27530  no, loop again

	inc     h		; @3094 24  yes, next high byte
	dec     d		; @3095 15  decrement counter.  are we done ?
	jp      nz,j_3072		; @3096 C27230  no, loop again

	dec     sp		; @3099 3B
	dec     sp		; @309A 3B
	dec     sp		; @309B 3B
	dec     sp		; @309C 3B  yes, set stack pointer back to beginning
	ld      a,b		; @309D 78  A := B
	sub     #10		; @309E D610  A := A - #10
	ld      b,a		; @30A0 47  B := A
	djnz    j_3047		; @30A1 10A4  loop until done


	pop     af		; @30A3 F1  load AF with table data = address
	pop     de		; @30A4 D1  load DE with loop counter and mask
	cp      #44		; @30A5 FE44  was this the last group of addresses ?
	jp      nz,j_3045		; @30A7 C24530  no, loop again

	ld      a,e		; @30AA 7B  yes, A := E
	xor     #F0		; @30AB EEF0  was this the very last group with mask F0 ?
	jp      nz,j_3045		; @30AD C24530  no, loop again

	ld      b,#01		; @30B0 0601  load B with code for no errors
	jp      j_30bd		; @30B2 C3BD30  jump ahead


	; bad RAM

j_30b5:
	ld      a,e		; @30B5 7B  A := E
	and     #01		; @30B6 E601  mask bits
	xor     #01		; @30B8 EE01  flip bit 0
	ld      e,a		; @30BA 5F  E := A
	ld      b,#00		; @30BB 0600  load B with code for error

	; display bad ROM

j_30bd:
	ld      sp,#4fc0		; @30BD 31C04F  set stack pointer
	exx		; @30C0 D9  swap register pairs


	; clear all program RAM

	ld hl,spr_unk_4c00		; @30C1 21004C  load HL with start of program RAM
	ld      b,#04		; @30C4 0604  For B = 1 to 4
j_30c6:
	ld      (watchdog),a		; @30C6 32C050  kick the dog
j_30c9:
	ld      (hl),#00		; @30C9 3600  clear RAM
	inc     l		; @30CB 2C  next address.  are we done?
	jr      nz,j_30c9		; @30CC 20FB  no, loop again

	inc     h		; @30CE 24  next high byte
	djnz    j_30c6		; @30CF 10F5  next B

	; set all video ram to 0x40 - clear screen

	ld      hl,#4000		; @30D1 210040  load HL with start of video RAM
	ld      b,#04		; @30D4 0604  For B = 1 to 4
j_30d6:
	ld      (watchdog),a		; @30D6 32C050  kick the dog
	ld      a,#40		; @30D9 3E40  A := #40 = clear character

j_30db:
	ld      (hl),a		; @30DB 77  clear the RAM
	inc     l		; @30DC 2C  next address
	jr      nz,j_30db		; @30DD 20FC  loop until zero

	inc     h		; @30DF 24  next high byte
	djnz    j_30d6		; @30E0 10F4  Next B

	;; set all color ram to 0x0f

	ld      b,#04		; @30E2 0604  For B = 1 to 4
j_30e4:
	ld      (watchdog),a		; @30E4 32C050  kick the dog
	ld      a,#0f		; @30E7 3E0F  A := #0F

j_30e9:
	ld      (hl),a		; @30E9 77  store
	inc     l		; @30EA 2C  next address
	jr      nz,j_30e9		; @30EB 20FC  loop until zero

	inc     h		; @30ED 24  next high byte
	djnz    j_30e4		; @30EE 10F4  next B


	;; change 30f0 - 30f2 to "00 nop" to skip checksum check. ; HACK4
	;;  if you do that, 30fb - 3173 can be reclaimed for other code use.
	; 30f0  00	nop
	; 30f1  00	nop
	; 30f2  00	nop
	;;
	;;


	exx		; @30F0 D9  reswap register pairs
	djnz    j_30fb		; @30F1 1008  Decrease B.  was there an error?  Yes, jump ahead

	ld      b,#23		; @30F3 0623  else load B with code for "MEMORY OK"

	;; eliminate startup tests ; HACK7
	; 30f5  00	nop
	; 30f6  00	nop
	; 30f7  00	nop
	;;

	call    j_2c5e		; @30F5 CD5E2C  print to screen
	jp      j_3174		; @30F8 C37431  jump ahead to test mode

	; skip the checksum test, change 30fb to: ; HACK 0
	; 30fb  c37431    jp      #3174		; run the game!
	;

j_30fb:
	ld      a,e		; @30FB 7B  load A with bad rom #
	add     a,#30		; @30FC C630  add offset for ascii code

	ld      (#4184),a		; @30FE 328441  write to screen
	push    bc		; @3101 C5  save BC
	push    hl		; @3102 E5  save HL
	ld      b,#24		; @3103 0624  load B with code for "BAD R M"
	call    j_2c5e		; @3105 CD5E2C  print to screen
	pop     hl		; @3108 E1  restore HL
	ld      a,h		; @3109 7C  A := H
	cp      #40		; @310A FE40  <= #40 ?
	ld      hl,(#316c)		; @310C 2A6C31  load HL with #4F (code for "O"), #40 (code for " ")
	jr      c,j_3122		; @310F 3811  yes, jump ahead to display

	cp      #4c		; @3111 FE4C  <= #4C ?
	ld      hl,(#316e)		; @3113 2A6E31  load HL with #41 (code for "A"), #57 (code for "W")
	jr      nc,j_3122		; @3116 300A  yes, jump ahead to display

	cp      #44		; @3118 FE44  <= #44 ?
	ld      hl,(#3170)		; @311A 2A7031  load HL with #41 (code for "A"), #56 (code for "V")
	jr      c,j_3122		; @311D 3803  yes, jump ahed to display

	ld      hl,(#3172)		; @311F 2A7231  else load HL with #41 (code for "A"), #43 (code for "C")

j_3122:
	ld      a,l		; @3122 7D  A := L
	ld      (#4204),a		; @3123 320442  display to screen
	ld      a,h		; @3126 7C  A := H
	ld      (#4264),a		; @3127 326442  display to screen
	ld      a,(IN0)		; @312A 3A0050  load A with IN0
	ld      b,a		; @312D 47  store into B
	ld      a,(IN1)		; @312E 3A4050  load A with IN1
	or      b		; @3131 B0  mix with IN0
	and     #01		; @3132 E601  check for bit 0 .  are both joysticks being pushed up?
	jr      nz,j_3147		; @3134 2011  no, skip ahead

	pop     bc		; @3136 C1  yes, restore BC
	ld      a,c		; @3137 79  A := C
	and     #0f		; @3138 E60F  mask bits
	ld      b,a		; @313A 47  B := A
	ld      a,c		; @313B 79  A := C
	and     #F0		; @313C E6F0  mask bits
	rrca		; @313E 0F
	rrca		; @313F 0F
	rrca		; @3140 0F
	rrca		; @3141 0F  rotate right 4 times
	ld      c,a		; @3142 4F  C := A
	ld      (#4185),bc		; @3143 ED438541  display to screen

j_3147:
	ld      (watchdog),a		; @3147 32C050  kick the dog
	ld      a,(IN1)		; @314A 3A4050  load A with IN1
	and     #10		; @314D E610  is service mode switch on?
	jr      z,j_3147		; @314F 28F6  no, loop forever

	jp      j_230b		; @3151 C30B23  yes, jump back to program

	; ram test data, used in routine at #3042

	db	#00,#4C,#0F,#04	; @3154 004C0F04  #4C00, mask = #0F, counter = 4, work ram low nibble
	db	#00,#4C,#F0,#04	; @3158 004CF004  #4C00, mask = F0, counter = 4, work ram high nibble
	db	#00,#40,#0F,#04	; @315C 00400F04  #4000, mask = #0F, counter = 4, video ram low nibble
	db	#00,#40,#F0,#04	; @3160 0040F004  #4000, mask = F0, counter = 4, video ram high nibble
	db	#00,#44,#0F,#04	; @3164 00440F04  #4400, mask = #0F, counter = 4, color ram low nibble
	db	#00,#44,#F0,#04	; @3168 0044F004  #4400, mask = F0, counter = 4, color ram high nibble

	; data used in the error routine for printing, starting at #310C
	; BAD (W/V/CRAM, ROM)

	db	#4F,#40	; @316C 4F40  "O", " "
	db	#41,#57	; @316E 4157  "A", "W"
	db	#41,#56	; @3170 4156  "A", "V"
	db	#41,#43	; @3172 4143  "A", "C"


	;; start the main section... (tests first)

j_3174:
	ld hl,coin_lockout		; @3174 210650  load HL with coin lockout (not used?)
	ld      a,#01		; @3177 3E01  A := #01

j_3179:
	ld      (hl),a		; @3179 77  enable coin lockout, players start lamps, flip screen, sound, and interrupt enable
	dec     l		; @317A 2D  decrease
	jr      nz,j_3179		; @317B 20FC  loop until zero

	xor     a		; @317D AF  A := #00
	ld      (flip_screen),a		; @317E 320350  unflip screen
	sub     #04		; @3181 D604  A := FC
	ld      i,a		; @3183 ED47  set interrupt vector to #3FFC.  [This address has the value of #008D]

	; pac:
	; 3183  d300      out     (#00),a         ; set vector TO #8D WHEN INTERRUPT
	;

	ld      sp,#4fc0		; @3185 31C04F  set stack pointer at #4FC0

j_3188:
	ld      (watchdog),a		; @3188 32C050  kick the dog
	xor     a		; @318B AF  A := #00

	; Skip test mode: HACK7
	; 318c  31c04f	ld	sp,#4fc0	; set stack pointer
	; 318f  c39032	jp	#3290		; skip over the test mode
	;

	ld      (game_mode),a		; @318C 32004E  set main routine number to initialize
	inc     a		; @318F 3C  A : = #01

	ld      (game_mode_sub0),a		; @3190 32014E  set main routine 0, subroutine # to 1
	ld      (IN0),a		; @3193 320050  enable hardware interrupts
	ei		; @3196 FB  enable software interrupts

	;; test mode sound checks
	;; this gets called if the test switch is on at bootup

	ld      a,(IN0)		; @3197 3A0050  load A with IN0
	cpl		; @319A 2F  invert
	ld      b,a		; @319B 47  copy to B
	and     #E0		; @319C E6E0  check all coin/credit inputs
	jr      z,j_31a5		; @319E 2805  if no credits, skip to next test
	ld      a,#02		; @31A0 3E02  set credit sound
	ld      (CH1_E_NUM),a		; @31A2 329C4E  play sound

j_31a5:
	ld      a,(IN1)		; @31A5 3A4050  load A with IN1
	cpl		; @31A8 2F  invert
	ld      c,a		; @31A9 4F  copy to C
	and     #60		; @31AA E660  check p1/p2 start
	jr      z,j_31b3		; @31AC 2805  if start buttons not pressed, skip to next test
	ld      a,#01		; @31AE 3E01  set sound to extra base
	ld      (CH1_E_NUM),a		; @31B0 329C4E  play sound

j_31b3:
	ld      a,b		; @31B3 78  load A with IN0 inverted
	or      c		; @31B4 B1  or with IN1 inverted
	and     #01		; @31B5 E601  check up on either IN0 or IN1
	jr      z,j_31be		; @31B7 2805  if not, skip ahead to next test
	ld      a,#08		; @31B9 3E08  set sound to ghost eat
	ld      (CH3_E_NUM),a		; @31BB 32BC4E  play sound

j_31be:
	ld      a,b		; @31BE 78  load A with IN0 inverted
	or      c		; @31BF B1  or with IN1 inverted
	and     #02		; @31C0 E602  check left on either IN0 or IN1
	jr      z,j_31c9		; @31C2 2805  if not, skip to next test
	ld      a,#04		; @31C4 3E04  set sound to fruit eat
	ld      (CH3_E_NUM),a		; @31C6 32BC4E  play sound

j_31c9:
	ld      a,b		; @31C9 78  load A with IN0 inverted
	or      c		; @31CA B1  or with IN1 inverted
	and     #04		; @31CB E604  check right on either In0 or In1
	jr      z,j_31d4		; @31CD 2805  if not, skip to next test
	ld      a,#10		; @31CF 3E10  set sound to death
	ld      (CH3_E_NUM),a		; @31D1 32BC4E  play sound

j_31d4:
	ld      a,b		; @31D4 78  load A with IN0 inverted
	or      c		; @31D5 B1  or with IN1 inverted
	and     #08		; @31D6 E608  check down on either IN0 or IN1
	jr      z,j_31df		; @31D8 2805  if not, skip to next test
	ld      a,#20		; @31DA 3E20  set sound to fruit bouncing sound
	ld      (CH3_E_NUM),a		; @31DC 32BC4E  play sound

j_31df:
	ld      a,(DSW1)		; @31DF 3A8050  load A with DSW1 (dip switches)
	and     #03		; @31E2 E603  mask bits to only look at coins/credits information
	add     a,#25		; @31E4 C625  add #25
	ld      b,a		; @31E6 47  copy to B
	call    j_2c5e		; @31E7 CD5E2C  print "FREE PLAY" or "1 COIN 1 CREDIT" etc, based on what the DIP settings are

	ld      a,(DSW1)		; @31EA 3A8050  load A with DSW1 (dip switches)
	rrca		; @31ED 0F
	rrca		; @31EE 0F
	rrca		; @31EF 0F
	rrca		; @31F0 0F  roll right 4 times 
	and     #03		; @31F1 E603  mask bits, now reads the settings for points needed for bonus life
	cp      #03		; @31F3 FE03  == #03 (no bonus life) ?
	jr      nz,j_31ff		; @31F5 2008  no, skip ahead

	ld      b,#2a		; @31F7 062A  load B with code for "BONUS NONE"
	call    j_2c5e		; @31F9 CD5E2C  print
	jp      j_321c		; @31FC C31C32  skip ahead for next test

j_31ff:
	rlca		; @31FF 07  rotate left  
	ld      e,a		; @3200 5F  copy to E
	push    de		; @3201 D5  save to stack
	ld      b,#2b		; @3202 062B  load B with code for "BONUS"
	call    j_2c5e		; @3204 CD5E2C  print
	ld      b,#2e		; @3207 062E  load B with code for "000"
	call    j_2c5e		; @3209 CD5E2C  print
	pop     de		; @320C D1  restore original value
	ld      d,#00		; @320D 1600  D := #00
	ld      hl,#32f9		; @320F 21F932  load HL with bonus table start
	add     hl,de		; @3212 19  add offset
	ld      a,(hl)		; @3213 7E  load A with first byte from bonus table
	ld      (#422a),a		; @3214 322A42  write to screen
	inc     hl		; @3217 23  next table value
	ld      a,(hl)		; @3218 7E  load A with second byte from bonus table
	ld      (#424a),a		; @3219 324A42  write to screen

j_321c:
	ld      a,(DSW1)		; @321C 3A8050  load A with DSW1 (dip switches)
	rrca		; @321F 0F
	rrca		; @3220 0F  roll right twice
	and     #03		; @3221 E603  mask bits.  now shows # of lives per game settings
	add     a,#31		; @3223 C631  add offset to compute which text to display
	cp      #34		; @3225 FE34  == #34 (setting for 5 lives per game) ?
	jr      nz,j_322a		; @3227 2001  no, skip next step
	inc     a		; @3229 3C  A := A + 1 (A := #35)
j_322a:
	ld      (#41ac),a		; @322A 32AC41  write this digit to the screen (1, 2, 3, or 5)

	; pac:
; 322a  320c42    ld      (#420c),a
	;

	ld      b,#29		; @322D 0629  load B with code for "MS PAC-MEN"
	call    j_2c5e		; @322F CD5E2C  print
	ld      a,(IN1)		; @3232 3A4050  load A with IN1 (bit 7 has the DIP setting for upright/cocktail)
	rlca		; @3235 07  rotate left. moves bit 7 into bit 0
	and     #01		; @3236 E601  mask bits.  is this set for upright or cocktail?
	add     a,#2c		; @3238 C62C  add #2C to adjust for "TABLE" or "UPRIGHT" message
	ld      b,a		; @323A 47  set message
	call    j_2c5e		; @323B CD5E2C  print
	ld      a,(IN1)		; @323E 3A4050  check in1
	and     #10		; @3241 E610  mask bits.  is the service mode switch still on ?
	jp      z,j_3188		; @3243 CA8831  yes, loop again

	xor     a		; @3246 AF  no, A := #00
	ld      (IN0),a		; @3247 320050  disable hardware interrupts
	di		; @324A F3  disable software interrupts
	ld hl,coin_counter_out		; @324B 210750  load HL with coin counter hardware address
	xor     a		; @324E AF  A := #00
j_324f:
	ld      (hl),a		; @324F 77  store, disable coin lockout, players start lamps, flip screen, sound, and interrupts
	dec     l		; @3250 2D  decrease address
	jr      nz,j_324f		; @3251 20FC  loop until zero


	; eliminate just the test grid: HACK7 (alternate)
	; 3253  31c04f    ld      sp,#4fc0
	; 3262  c38632    jp      #3286


	; preload the stack with some data for the grid test
	; prep for the test grid


	ld      sp,#3ae2		; @3253 31E23A  set stack pointer at #3AE2
	ld      b,#03		; @3256 0603  B := #03

j_3258:
	exx		; @3258 D9  exchange register pairs BC, DE, and HL with alternates
	pop     hl		; @3259 E1  load HL with table data - 3 screen region grid data for self test.  first value is #4002
	pop     de		; @325A D1  load DE with table data (EG. #3E01)

j_325b:
	ld      (watchdog),a		; @325B 32C050  kick the dog
	pop     bc		; @325E C1  load BC with next value from table.   (EG #103D) 

	;; draw the test grid to the screen

j_325f:
	ld      a,#3c		; @325F 3E3C  A := #3C (graphic for upper right)
	ld      (hl),a		; @3261 77  write to screen 
	inc     hl		; @3262 23  next screen address
	ld      (hl),d		; @3263 72  write to screen (#3E = graphic for lower right)
	inc     hl		; @3264 23  next screen address
	djnz    j_325f		; @3265 10F8  loop until done

	dec     sp		; @3267 3B
	dec     sp		; @3268 3B  next table data
	pop     bc		; @3269 C1  load BC with next value from table

j_326a:
	ld      (hl),c		; @326A 71  write upper left graphic to screen
	inc     hl		; @326B 23  next screen address
	ld      a,#3f		; @326C 3E3F  load A with lower left graphic
	ld      (hl),a		; @326E 77  write to screen
	inc     hl		; @326F 23  next address
	djnz    j_326a		; @3270 10F8  loop until done

	dec     sp		; @3272 3B
	dec     sp		; @3273 3B  next table address
	dec     e		; @3274 1D  decrease E, are we done ?
	jp      nz,j_325b		; @3275 C25B32  no, loop again

	pop     af		; @3278 F1  restore AF
	exx		; @3279 D9  exchange register pairs BC, DE, and HL with alternates
	djnz    j_3258		; @327A 10DC  loop until done

	ld      sp,#4fc0		; @327C 31C04F  set stack pointer to #4FC0

	ld      b,#08		; @327F 0608  For B = 1 to 8
j_3281:
	call    j_32ed		; @3281 CDED32  call the delay routine
	djnz    j_3281		; @3284 10FB  Next B

	; loop until service switch turned off

j_3286:
	ld      (watchdog),a		; @3286 32C050  kick the dog
	ld      a,(IN1)		; @3289 3A4050  load A with IN1
	and     #10		; @328C E610  is the service switch off?
	jr      z,j_3286		; @328E 28F6  no, loop until test switch is off

;; 	check the condition to display the easter egg
;	This piece of code is found in the original Midway Pac-Man ROMs @ #3289.
;	Place the game in the test grid screen (Monitor Convergence screen) by switching test mode on.
;	Then, hold down the player 1 and player 2 buttons and then quickly jiggle the test switch out &
;	back into test. Next move the joystick:
;		Up 4 times 
;		Left 4 times 
;		Right 4 times 
;		Down 4 times
;;				- Widel/Mowerman

	ld      a,(IN1)		; @3290 3A4050  load A with IN1
	and     #60		; @3293 E660  apply bitmask 0110 0000.  are player 1 and 2 buttons being pressed ?
	jp      nz,j_234b		; @3295 C24B23  no, jump to main program start

	ld      b,#08		; @3298 0608  For B = 1 to 8

j_329a:
	call    j_32ed		; @329A CDED32  call the delay routine
	djnz    j_329a		; @329D 10FB  Next B

	ld      a,(IN1)		; @329F 3A4050  load A with IN1
	and     #10		; @32A2 E610  is the service mode switch set ?
	jp      nz,j_234b		; @32A4 C24B23  no, jump to main program start
	ld      e,#01		; @32A7 1E01  yes, load E with #01, used for checking direction below

j_32a9:
	ld      b,#04		; @32A9 0604  for B = 1 to 4

j_32ab:
	ld      (watchdog),a		; @32AB 32C050  kick the dog
	call    j_32ed		; @32AE CDED32  call the delay routine
	ld      a,(IN0)		; @32B1 3A0050  load A with IN0 (joystick)
	and     e		; @32B4 A3  pushing on joystick in proper direction?
	jr      nz,j_32ab		; @32B5 20F4  no, jump back

j_32b7:
	call    j_32ed		; @32B7 CDED32  yes, call the delay routine
	ld      (watchdog),a		; @32BA 32C050  kick the dog
	ld      a,(IN0)		; @32BD 3A0050  load A with IN0 (joystick)
	xor     #FF		; @32C0 EEFF  joystick has no direction ?
	jr      nz,j_32b7		; @32C2 20F3  no, loop again
	djnz    j_32ab		; @32C4 10E5  Next B

	rlc     e		; @32C6 CB03  rotate left E with carry E becomes 2, 4, 8, and finally 16 (#10 hex)
	ld      a,e		; @32C8 7B  load into A
	cp      #10		; @32C9 FE10  result >= #10 ?
	jp      c,j_32a9		; @32CB DAA932  no, loop and try again

	;; draw the "Made By Namco" easter egg
	; clear the screen...

	ld      hl,#4000		; @32CE 210040  load HL with start of video RAM
	ld      b,#04		; @32D1 0604  set counter to run 4 times
j_32d3:
	ld      a,#40		; @32D3 3E40  A := #40 (clear character)

j_32d5:
	ld      (hl),a		; @32D5 77  clear the video ram location
	inc     l		; @32D6 2C  next location
	jr      nz,j_32d5		; @32D7 20FC  loop until L is zero

	inc     h		; @32D9 24  next H
	djnz    j_32d3		; @32DA 10F7  next B
	call    j_3af4		; @32DC CDF43A  draw the easter egg to the screen

	; wait for service switch to be off

j_32df:
	ld      (watchdog),a		; @32DF 32C050  kick the dog
	ld      a,(IN1)		; @32E2 3A4050  load A with IN1
	and     #10		; @32E5 E610  is the service switch on?
	jp      z,j_32df		; @32E7 CADF32  yes, loop
	jp      j_234b		; @32EA C34B23  no, jump to main program

	; delay timer

j_32ed:
	ld      (watchdog),a		; @32ED 32C050  kick the dog
	ld      hl,#2800		; @32F0 210028

j_32f3:
	dec     hl		; @32F3 2B
	ld      a,h		; @32F4 7C
	or      l		; @32F5 B5
	jr      nz,j_32f3		; @32F6 20FB  (-5)
	ret		; @32F8 C9

	; data - bonus table text
	; referred to at #320F

	db	#30,#31	; @32F9 3031  "10" for 10,000 pts
	db	#35,#31	; @32FB 3531  "15" for 15,000 pts
	db	#30,#32	; @32FD 3032  "20" for 20,000 pts

	; data - tile differences tables for movements

	db	#00,#FF	; @32FF 00FF  move right
	db	#01,#00	; @3301 0100  move down
	db	#00,#01	; @3303 0001  move left
	db	#FF,#00	; @3305 FF00  move up

	; second copy for speed, or for overflow when blue ghosts random directions aren't allowed

	db	#00,#FF	; @3307 00FF  move right
	db	#01,#00	; @3309 0100  move down
	db	#00,#01	; @330B 0001  move left
	db	#FF,#00	; @330D FF00  move up

	; data - table for difficulty
	; 	each entry has 3 sections
	;	0: 0x10 bytes - speed bit patterns
	;	1: 0x0c bytes - ghost data movement bit patterns
	;	2: 0x0e bytes - ghost counters for orientation changes
	;			4dc1-4dc3 related
	;
	; this table is referenced at #0733

;	2A552A55 55555555 2A552A55 4A5294A5		; @330F
;      25252525 22222222 01010101
;      0258 0708 0960 0E10 1068 1770 1914

;	4A5294A5 2AAA5555 2A552A55 4A5294A5		; @3339
;      24924925 24489122 01010101
;      0000 0000 0000 0000 0000 0000 0000

;	2A552A55 55555555 2AAA5555 2A552A55		; @3363
;      4A5294A5 24489122 44210844
;      0258 0834 09D8 0FB4 1158 1608 1734

; pac original continues on here:
;        entry 3:
;                55555555 6AD56AD5 6AAAD555 55555555
;                2AAA5555 24922492 22222222
;                01A4 0654 07F8 0CA8 0DD4 1284 13B0

;        entry 4:
;                6AD56AD5 5AD6B5AD 5AD6B5AD 6AD56AD5
;                6AAAD555 24924925 24489122
;                01A4 0654 07F8 0CA8 0DD4 FFFE FFFF

;        entry 5:
;                6D6D6D6D 6D6D6D6D 6DB6DB6D 6D6D6D6D
;                5AD6B5AD 25252525 24922492
;                012C 05DC 0708 0BB8 0CE4 FFFE FFFF

;        entry 6:
;                6AD56AD5 6AD56AD5 6DB6DB6D 6D6D6D6D
;                5AD6B5AD 24489122 24922492
;                012C 05DC 0708 0BB8 0CE4 FFFE FFFF

; end pac original

	;; speed control table

	; ;; gap-fill from golden boots $330F-$338C
	db	#55,#2A,#55,#2A,#55,#55,#55,#55,#55,#2A,#55,#2A,#52,#4A,#A5,#94		; @330F
	db	#25,#25,#25,#25,#22,#22,#22,#22,#01,#01,#01,#01,#58,#02,#08,#07		; @331F
	db	#60,#09,#10,#0E,#68,#10,#70,#17,#14,#19,#52,#4A,#A5,#94,#AA,#2A		; @332F
	db	#55,#55,#55,#2A,#55,#2A,#52,#4A,#A5,#94,#92,#24,#25,#49,#48,#24		; @333F
	db	#22,#91,#01,#01,#01,#01,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00		; @334F
	db	#00,#00,#00,#00,#55,#2A,#55,#2A,#55,#55,#55,#55,#AA,#2A,#55,#55		; @335F
	db	#55,#2A,#55,#2A,#52,#4A,#A5,#94,#48,#24,#22,#91,#21,#44,#44,#08		; @336F
	db	#58,#02,#34,#08,#D8,#09,#B4,#0F,#58,#11,#08,#16,#34,#17		; @337F
	db	#55,#55,#55,#55	; @338D 55555555  ; #338d - 3390 = Pacman normal speed for Board 1 = this will increase exactly every other time

; 55555555 -> AAAAAAAA -> 55555555 = 1/2 = 50% speed = 1010101010101010101010101010101

	db	#D5,#6A,#D5,#6A	; @3391 D56AD56A  ; #3391 - 3394 = Pacman Blue speed for Board 1 = 11010101011010101101010101101010 = 18/32 =  56.25%
	db	#AA,#6A,#55,#D5	; @3395 AA6A55D5  ; #3395 - 3398 = 2nd alternate speed for red ghost = 10101010011010100101010111010101 = 17/32 = 53.125% 
	db	#55,#55,#55,#55	; @3399 55555555  ; #3399 - 339c = 1st alt. speed for red ghost = 50% speed
	db	#AA,#2A,#55,#55	; @339D AA2A5555  ; #339d - 33a0 = Ghost normal speed for board 1 = 10101010001010100101010101010101 = 15/32 = 46.875%
	db	#92,#24,#92,#24	; @33A1 92249224  ; #33a1 - 33a4 = Ghost blue speed for board 1 = 10010010001001001001001000100100 = 10/32 = 31.25%
	db	#22,#22,#22,#22	; @33A5 22222222  ; #33a5 - 33a8 = Ghost tunnel speed for board 1 = 1/4 OR 25% speed


; refer to code segment at #0E55
; timer is saved in memory #4DC2

	db	#A4,#01	; @33A9 A401  timer for first reversal #01A4 (start at scatter, 7 seconds until first chase) [1 second = #3C (60 decimal) units]
	db	#54,#06,#F8,#07	; @33AB 5406F807  2nd & 3rd reversals at #0654 and #07F8 (20 seconds of chase, 7 seconds of scatter)
	db	#A8,#0C,#D4,#0D	; @33AF A80CD40D  4th & 5th reversals at #0CA8 and #0DD4 (20 seconds of chase, 5 seconds of scatter)
	db	#84,#12,#B0,#13	; @33B3 8412B013  6th & 7th reversals at #1284 and #13B0 (20 seconds of chase, 5 seconds of scatter)


; codes for boards 2-4

	db	#D5,#6A,#D5,#6A	; @33B7 D56AD56A  Pacman normal speed = 56.25%
	db	#D6,#5A,#AD,#B5	; @33BB D65AADB5  Pacman blue speed = 11010110010110101010110110110101 = 19/32 = 59.375%
	db	#D6,#5A,#AD,#B5	; @33BF D65AADB5  2nd alt. speed for red ghost = 59.375%
	db	#D5,#6A,#D5,#6A	; @33C3 D56AD56A  alt. speed for red ghost = 56.25%
	db	#AA,#6A,#55,#D5	; @33C7 AA6A55D5  Ghost reg speed = 17/32 = 53.125% 
	db	#92,#24,#25,#49	; @33CB 92242549  Ghost blue speed = 10010010001001000010010101001001 = 11/32 = 34.375%
	db	#48,#24,#22,#91	; @33CF 48242291  ghost tunnel speed = 1001000001001000010001010010001 = 9/32 = 28.125%

	db	#A4,#01,#54,#06	; @33D3 A4015406  1st & 2nd reversal timers #01A4 and #0654 (7 second scatter, chase 20 seconds, then start of 2nd scatter)
	db	#F8,#07,#A8,#0C	; @33D7 F807A80C  3rd & 4th reversal timers #07F8 and #0CA8 (7 second scatter, chase 20 seconds, start of 3rd scatter)
	db	#D4,#0D,#FE,#FF	; @33DB D40DFEFF  5th & 6th reversal timers #0DD4 and FFFE (5 second scatter, chase 1033 seconds or 17.2 minutes to final reversal)
	db	#FF,#FF	; @33DF FFFF  last reversal timer FFFF

; codes for boards 5 through - 9th key

	db	#6D,#6D,#6D,#6D	; @33E1 6D6D6D6D  pacman normal speed

; 6D6D6D6D -> DADADADA ->  B5B5B5B5 -> 6B6B6B6B -> D6D6D6D6 -> ADADADAD -> 5B5B5B5B -> B6B6B6B6 -> 6D6D6D6D (0110 1101 = 5/8 SPEED OR 62.5%)


	db	#6D,#6D,#6D,#6D	; @33E5 6D6D6D6D  pacman blue speed (5/8 SPEED) = 0110 1101 = 62.5%
;	DB		; @33E9 B66D6D  2nd alt. speed for red ghost = 10110110011011010110110111011011 = 21/32 = 65.625%
	; ;; gap-fill from golden boots $33E9-$33EC
	db	#B6,#6D,#6D,#DB		; @33E9
	db	#6D,#6D,#6D,#6D	; @33ED 6D6D6D6D  1st alt. speed for red ghost (5/8 SPEED) = 62.5%
	db	#D6,#5A,#AD,#B5	; @33F1 D65AADB5  ghost normal speed = 19/32 = 59.375%
	db	#25,#25,#25,#25	; @33F5 25252525  ghost blue speed = 0010 0101 = 3/8 SPEED OR 37.5%
	db	#92,#24,#92,#24	; @33F9 92249224  ghost tunnel speed = 1001001000100100 = 5/16 = 31.25%

	db	#2C,#01,#DC,#05	; @33FD 2C01DC05  reversal timers #012C and #05DC (start at scatter, 5 seconds to first chase, 20 seconds of chase, start of 2nd scatter)
	db	#08,#07,#B8,#0B	; @3401 0807B80B  reversal timers #0708 and #0BB8 (2nd scatter for 5 seconds, 2nd chase  for 20 seconds, start of 3rd scatter)
	db	#E4,#0C,#FE,#FF	; @3405 E40CFEFF  reversal timers #0CE4 and FFFE (3rd scatter for 5 seconds, then chase 1037 seconds or 17.3 minutes to final reversal)
	db	#FF,#FF	; @3409 FFFF  last reversal timer FFFF

; codes for boards 9th key and beyond

	db	#D5,#6A,#D5,#6A	; @340B D56AD56A  pacman normal speed = 18/32 =  56.25%
	db	#D5,#6A,#D5,#6A	; @340F D56AD56A  pacman blue speed = 18/32 =  56.25% (not used, energizers have no effect here)
;	DB		; @3413 B66D6D  2nd alt speed for red ghost = 21/32 = 65.625%
	; ;; gap-fill from golden boots $3413-$3416
	db	#B6,#6D,#6D,#DB		; @3413
	db	#6D,#6D,#6D,#6D	; @3417 6D6D6D6D  1st alt. speed for red ghost = 5/8 = 0110 1101 = 62.5%
	db	#D6,#5A,#AD,#B5	; @341B D65AADB5  ghost normal speed = 19/32 = 59.375%
	db	#48,#24,#22,#91	; @341F 48242291  ghost blue speed = 9/32 = 28.125%  (not used, energizers have no effect here, would be very slow)
	db	#92,#24,#92,#24	; @3423 92249224  ghost tunnel speed = 5/16 = 31.25%

	db	#2C,#01,#DC,#05	; @3427 2C01DC05  reversal timers #012C and #05DC
	db	#08,#07,#B8,#0B	; @342B 0807B80B  reversal timers #0708 and #0BB8
	db	#E4,#0C,#FE,#FF	; @342F E40CFEFF  reversal timers #0CE4 and FFFE
	db	#FF,#FF	; @3433 FFFF  last reversal timer FFFF




; resume in the middle of original pac, in entry 4. see above.

	; entry 4, 5, etc is here.

; orignal pac rom:
; data - level map information

j_3435:
;	-D2 D2 D2 D2 D2 D2 D2 D2		; @3435 40FCD0
;	-FC FC D0 D2 D2 D2 D2 D6		; @3440 D4FCFCFCDA02DCFC
;	-09 DC FC FC FC DA 02 DC		; @3450 D8D2D2D2D2D4FCDA
;	-DC FC DA 02 E6 E8 EA 02		; @3460 FCFCFCDA05DEE405
;	-02 DC FC FC FC DA 02 E6		; @3470 E6EA02DCFCFCFCDA
;	-DC FC DA 02 DE FC E4 02		; @3480 EA02E7EB02E6EA02
;	-02 DC FC FC FC DA 02 DE		; @3490 DEE402DCFCFCFCDA
;	-02 DE FC E4 02 DE E4 02		; @34A0 E405DEE402DCFCDA
;	-FC FC DA 02 DE F2 E8 E8		; @34B0 DCFCFCFCDA02DCFC
;	-02 E7 E9 EB 02 E7 EB 02		; @34C0 EA02DEE402DCFCDA
;	-D2 D2 EB 02 E7 E9 E9 E9		; @34D0 E7D2D2D2EB02E7D2
;	-1B DE E4 02 DC FC DA 02		; @34E0 EB02DEE402DCFCDA
;	-E8 E8 E8 F8 02 F6 E8 E8		; @34F0 E6E8F802F6E8E8E8
;	-E8 F4 E4 02 DC FC DA 02		; @3500 E8EA02E6F802F6E8
;	-F3 E9 E9 F9 02 F7 E9 E9		; @3510 DEFCE402F7E9E9F5
;	-E9 F5 E4 02 DC FC DA 02		; @3520 E9EB02DEE402F7E9
;	-E4 05 DE E4 02 DC FC DA		; @3530 DEFCE405DEE40BDE
;	-DE E4 02 EC D3 D3 D3 EE		; @3540 02DEFCE402E6EA02
;	-EA 02 DE E4 02 DC FC DA		; @3550 02E6EA02DEE402E6
;	-E7 EB 02 DC FC FC FC DA		; @3560 02E7E9EB02DEE402
;	-E4 02 E7 EB 02 DC FC DA		; @3570 02DEE402E7EB02DE
;	-DA 02 DE E4 05 DE E4 05		; @3580 06DEE405F0FCFCFC
;	-DE F2 E8 E8 EA 02 CE FC		; @3590 DCFCFAE8E8E8EA02
;	-EA 02 DE F2 E8 E8 EA 02		; @35A0 FCFCDA02DEF2E8E8
;	db	#DC,#00,#00,#00,#00	; @35B0 DC00000000

; original pac rom:
; data - level pill information

;	-01 01 01 01 0C 01 01 04		; @35B5 620102
;	-03 03 04 04 03 0C 03 01		; @35C0 0101010404030C03
;	-03 04 04 03 0C 06 03 04		; @35D0 0101030404030C06
;	-01 01 01 01 01 01 01 01		; @35E0 0101010101010101
;	-01 03 04 04 0F 03 06 04		; @35F0 0101010101010101
;	-01 0C 03 01 01 01 03 04		; @3600 040F030604040101
;	-03 0C 03 03 03 04 01 01		; @3610 04030C0303030404
;	-01 01 01 08 18 08 18 04		; @3620 0101030C01010103
;	-01 03 01 01 01 04 04 03		; @3630 01010101030C0101
;	-03 03 03 04 04 01 01 01		; @3640 0C0303030404030C
;	-0F 03 06 04 04 0F 03 06		; @3650 0C03010101030404
;	-01 01 01 01 01 01 01 01		; @3660 0401010101010101
;	-01 01 03 04 04 03 0C 06		; @3670 0101010101010101
;	-04 03 0C 03 01 01 01 03		; @3680 030404030C060304
;	-01 02 01 01 01 01 0C 01		; @3690 0404030C03030304
;	db	#01,#04,#01,#01,#01	; @36A0 0104010101
; end pac-man only


;  the following resumes Ms Pac
;  the whole section from 0x3435-0x36a2 differs from Pac roms.


; arrive here from #2108 when 1st intermission begins

	ld      a,(intermission_flag)		; @3435 3A004F  load A with intermission indicator
	cp      #01		; @3438 FE01  is the intermission already running ?
	jp      z,j_349c		; @343A CA9C34  yes, skip ahead

	rst     #28		; @343D EF  no, insert task to draw text "THEY MEET"
	db	#1C,#32	; @343E 1C32  1c = draw text,  32 = string code
	ld      a,#01		; @3440 3E01  load A with code for "1"
	ld      (#42ac),a		; @3442 32AC42  write text "1" to screen
	ld      a,#16		; @3445 3E16  load A with code for color = white
	ld      (#46ac),a		; @3447 32AC46  paint the "1" white
	ld      c,#00		; @344A 0E00  C := #00
	jp      j_349c		; @344C C39C34  jump ahead

; arrive here from #21A1 when 2nd intermission begins

j_344f:
	ld      a,(intermission_flag)		; @344F 3A004F  load A with intermission indicator
	cp      #01		; @3452 FE01  is the intermission already running ?
	jp      z,j_349c		; @3454 CA9C34  yes, skip ahead

	rst     #28		; @3457 EF  no, insert task to display text "THE CHASE"
	db	#1C,#17	; @3458 1C17  1c = draw text,  17 = string code
	ld      a,#02		; @345A 3E02  load A with code for "2"
	ld      (#42ac),a		; @345C 32AC42  write text "2" to screen
	ld      a,#16		; @345F 3E16  load A with code for color = white
	ld      (#46ac),a		; @3461 32AC46  paint the "2" white
	ld      c,#0c		; @3464 0E0C  C := #0C.  This offset is added later to set up act 2
	jp      j_349c		; @3466 C39C34  jump ahead

; arrive here from #229A when 3rd intermission begins

j_3469:
	ld      a,(intermission_flag)		; @3469 3A004F  load A with intermission indicator
	cp      #01		; @346C FE01  is the intermission already running ?
	jp      z,j_349c		; @346E CA9C34  yes, skip ahead

	rst     #28		; @3471 EF  insert task to display text "JUNIOR"
	db	#1C,#15	; @3472 1C15  1c = draw text,  15 = string code
	; print "ACT **3**"
	ld      a,#03		; @3474 3E03  load A with code for "3"
	ld      (#42ac),a		; @3476 32AC42  write text "3" to screen
	ld      a,#16		; @3479 3E16  load A with code for color = white
	ld      (#46ac),a		; @347B 32AC46  paint the "3" white
	ld      c,#18		; @347E 0E18  C := #18.  this offset is added later to set up act 3
	jp      j_349c		; @3480 C39C34  jump ahead

; arrive here from #3E67 after Blinky has been introduced

	ld      c,#24		; @3483 0E24  load C with offset for moving Blinky
	jp      j_349c		; @3485 C39C34  begin moving Blinky across marquee and up left side

; arrive here from #3E67 after Pinky has been introduced

	ld      c,#30		; @3488 0E30  load C with offset for moving Pinky
	jp      j_349c		; @348A C39C34  begin moving Pinky across marquee and up left side

; arrive here from #3E67 after Inky has been introduced

	ld      c,#3c		; @348D 0E3C  load C with offset for moving Inky
	jp      j_349c		; @348F C39C34  begin moving Inky across marquee and up left side

; arrive here from #3E67 after Sue has been introduced

	ld      c,#48		; @3492 0E48  load C with offset for moving Sue
	jp      j_349c		; @3494 C39C34  begin moving Sue across marquee and up left side

; arrive here from #3e67 after Ms. Pac Man has been introduced

	ld      c,#54		; @3497 0E54  load C with offset for moving MS pac man
	jp      j_349c		; @3499 C39C34  begin moving ms pac man across marquee



; main routine to handle intermissions and attract mode ANIMATIONS


j_349c:
	ld      a,(intermission_flag)		; @349C 3A004F  load A with intermission indicator
	and     a		; @349F A7  is the intermission running ?
	call    z,j_3611		; @34A0 CC1136  no, call this sub to get it started

	ld      b,#06		; @34A3 0606  B := #06
	ld      ix,#4f0c		; @34A5 DD210C4F  load IX with stack.  This holds the list of addresses for the data

; get the next ANIMATION code.. (codes return to here when done)
j_34a9:
	ld      l,(ix+#00)		; @34A9 DD6E00
	ld      h,(ix+#01)		; @34AC DD6601  load HL with stack data.  this is an address for data
	ld      a,(hl)		; @34AF 7E  load data
	cp      #F0		; @34B0 FEF0  == F0 ?
	jp      z,j_34de		; @34B2 CADE34  handle code F0 - LOOP
	cp      #F1		; @34B5 FEF1
	jp      z,j_356b		; @34B7 CA6B35  handle code F1 - SETPOS
	cp      #F2		; @34BA FEF2
	jp      z,j_3597		; @34BC CA9735  handle code F2 - SETN
	cp      #F3		; @34BF FEF3
	jp      z,j_3577		; @34C1 CA7735  handle code F3 - SETCHAR
	cp      #F5		; @34C4 FEF5
	jp      z,j_3607		; @34C6 CA0736  handle code F5 - PLAYSOUND
	cp      #F6		; @34C9 FEF6
	jp      z,j_35a4		; @34CB CAA435  handle code F6 - PAUSE
	cp      #F7		; @34CE FEF7
	jp      z,j_35f3		; @34D0 CAF335  handle code F7 - SHOWACT ?
	cp      #F8		; @34D3 FEF8
	jp      z,j_35fd		; @34D5 CAFD35  handle code F8 - CLEARACT ?
	cp      #FF		; @34D8 FEFF
	jp      z,j_35cb		; @34DA CACB35  handle code FF - END

	halt		; @34DD 76  wait for interrupt

; for value == F0 - LOOP
    
j_34de:
	push    hl		; @34DE E5
	ld      a,#01		; @34DF 3E01
	rst     #10		; @34E1 D7
	ld      c,a		; @34E2 4F
	ld      hl,#4f2e		; @34E3 212E4F
	rst     #18		; @34E6 DF
	ld      a,c		; @34E7 79
	add     a,h		; @34E8 84
	call    j_3556		; @34E9 CD5635
	ld      (de),a		; @34EC 12
	call    j_3641		; @34ED CD4136
	rst     #18		; @34F0 DF
	ld      a,h		; @34F1 7C
	add     a,c		; @34F2 81
	ld      (de),a		; @34F3 12
	pop     hl		; @34F4 E1
	push    hl		; @34F5 E5
	ld      a,#02		; @34F6 3E02
	rst     #10		; @34F8 D7
	ld      c,a		; @34F9 4F
	ld      hl,#4f2e		; @34FA 212E4F
	rst     #18		; @34FD DF
	ld      a,c		; @34FE 79
	add     a,l		; @34FF 85
	call    j_3556		; @3500 CD5635
	dec     de		; @3503 1B
	ld      (de),a		; @3504 12
	call    j_3641		; @3505 CD4136
	rst     #18		; @3508 DF
	ld      a,l		; @3509 7D
	add     a,c		; @350A 81
	dec     de		; @350B 1B
	ld      (de),a		; @350C 12
	ld      hl,#4f0f		; @350D 210F4F
	ld      a,b		; @3510 78
	rst     #10		; @3511 D7
	push    hl		; @3512 E5
	inc     a		; @3513 3C
	ld      c,a		; @3514 4F

j_3515:
	ld      hl,#4f3e		; @3515 213E4F
	rst     #18		; @3518 DF  load HL with address (EG 8663)
	ld      a,c		; @3519 79  Copy C to A
	sra     a		; @351A CB2F  Shift right (div by 2)
	rst     #10		; @351C D7  dereference sprite number for intro.  loads A with value in HL+A
	cp      #FF		; @351D FEFF  are we done ?
	jp      nz,j_3526		; @351F C22635  no, skip ahead

	ld      c,#00		; @3522 0E00  else reset counter
	jr      j_3515		; @3524 18EF  loop again

j_3526:
	pop     hl		; @3526 E1
	ld      (hl),c		; @3527 71
	ld      e,a		; @3528 5F
	pop     hl		; @3529 E1
	ld      a,#03		; @352A 3E03
	rst     #10		; @352C D7
	ld      d,a		; @352D 57
	push    de		; @352E D5
	ld      hl,#4f4e		; @352F 214E4F
	rst     #18		; @3532 DF
	pop     hl		; @3533 E1
	ex      de,hl		; @3534 EB
	ld      (hl),d		; @3535 72
	dec     hl		; @3536 2B
	ld      a,(player_number)		; @3537 3A094E
	ld      c,a		; @353A 4F
	ld      a,(dip_cocktail)		; @353B 3A724E
	and     c		; @353E A1
	jr      z,j_3545		; @353F 2804  (4)

	ld      a,#C0		; @3541 3EC0
	xor     e		; @3543 AB
	ld      e,a		; @3544 5F

j_3545:
	ld      (hl),e		; @3545 73
	ld      hl,#4f17		; @3546 21174F
	ld      a,b		; @3549 78
	rst     #10		; @354A D7
	dec     a		; @354B 3D
	ld      (hl),a		; @354C 77
	ld      de,#0000		; @354D 110000
	jr      nz,j_35b4		; @3550 2062  (98)

	ld      e,#04		; @3552 1E04
	jr      j_35b4		; @3554 185E  (94)

j_3556:
	ld      c,a		; @3556 4F
	sra     c		; @3557 CB29
	sra     c		; @3559 CB29
	sra     c		; @355B CB29
	sra     c		; @355D CB29
	and     a		; @355F A7
	jp      p,j_3568		; @3560 F26835

; arrive here when ghost is moving up the left side of the marquee

	or      #F0		; @3563 F6F0
	inc     c		; @3565 0C
	jr      j_356a		; @3566 1802  (2)

j_3568:
	and     #0f		; @3568 E60F
j_356a:
	ret		; @356A C9

; for value == F1 - SETPOS

j_356b:
	ex      de,hl		; @356B EB
	call    j_3641		; @356C CD4136  load HL with either #4CFE or #4Dc6
	ex      de,hl		; @356F EB
	push    de		; @3570 D5
	inc     hl		; @3571 23
	ld      d,(hl)		; @3572 56
	inc     hl		; @3573 23
	ld      e,(hl)		; @3574 5E
	jr      j_358a		; @3575 1813  (19)

; for value == F3 - SETCHAR

j_3577:
	ex      de,hl		; @3577 EB  save HL into DE
	ld      hl,#4f0f		; @3578 210F4F  HL := #4F0F (stack)
	ld      a,b		; @357B 78  A := B
	rst     #10		; @357C D7  load A with the data in HL+A
	ld      (hl),#00		; @357D 3600  clear this location
	ex      de,hl		; @357F EB  restore HL from DE
	ld      de,#4f3e		; @3580 113E4F  DE := #4F3E (stack)
	push    de		; @3583 D5  save DE
	inc     hl		; @3584 23  next location
	ld      e,(hl)		; @3585 5E
	inc     hl		; @3586 23
	ld      d,(hl)		; @3587 56  DE how has the address word after the code F3
;	jr      j_358a		; @3588 1800  does nothing (?) -- jumps to next instruction

	; It's my gyess that the jr at 3588 and the lack of code F4 
	; are related.  In fitting with the style of the other F-commands,
	; they all end with a jr to 0x358a, including this one. 
	; I think that in the source code, they removed whatever F4 
	; was, but forgot to erase the jr just before it, so you end up with
	; a jr to the next instruction.  -scott

; cleanup for return from F0, F1, F3
	; ;; gap-fill from golden boots $3588-$3589
	db	#18,#00		; @3588
j_358a:
	pop     hl		; @358A E1  restore DE saved earlier into HL
	push    de		; @358B D5  save the address
	rst     #18		; @358C DF  load HL with the data in (HL + 2*B)
	ex      de,hl		; @358D EB  DE <-> HL
	pop     de		; @358E D1  restore the address
	ld      (hl),d		; @358F 72
	dec     hl		; @3590 2B
	ld      (hl),e		; @3591 73
	ld      de,#0003		; @3592 110300  3 bytes used from the code program
	jr      j_35b4		; @3595 181D  (29)

; for value = F2 - SETN

j_3597:
	inc     hl		; @3597 23
	ld      c,(hl)		; @3598 4E
	ld      hl,#4f17		; @3599 21174F
	ld      a,b		; @359C 78
	rst     #10		; @359D D7
	ld      (hl),c		; @359E 71
	ld      de,#0002		; @359F 110200
	jr      j_35b4		; @35A2 1810  (16)

; for value == F6 - PAUSE

j_35a4:
	ld      hl,#4f17		; @35A4 21174F
	ld      a,b		; @35A7 78
	rst     #10		; @35A8 D7

	dec     a		; @35A9 3D
	ld      (hl),a		; @35AA 77
	ld      de,#0000		; @35AB 110000
	jr      nz,j_35b4		; @35AE 2004  (4)
	ld      e,#01		; @35B0 1E01  1 byte used from the code program
	jr      j_35b4		; @35B2 1800  (0)

; finish up for the above

j_35b4:
	ld      l,(ix+#00)		; @35B4 DD6E00
	ld      h,(ix+#01)		; @35B7 DD6601  load HL with next value
	add     hl,de		; @35BA 19  add offset
	ld      (ix+#00),l		; @35BB DD7500
	ld      (ix+#01),h		; @35BE DD7401
	dec     ix		; @35C1 DD2B
	dec     ix		; @35C3 DD2B
	djnz    j_35c8		; @35C5 1001  (1)
	ret		; @35C7 C9

j_35c8:
	jp      j_34a9		; @35C8 C3A934

; for value == FF (end code)

j_35cb:
	ld      hl,#4f1f		; @35CB 211F4F
	ld      a,b		; @35CE 78
	rst     #10		; @35CF D7
	ld      (hl),#01		; @35D0 3601
	ld      hl,#4f20		; @35D2 21204F
	ld      a,(hl)		; @35D5 7E
	inc     hl		; @35D6 23
	and     (hl)		; @35D7 A6
	inc     hl		; @35D8 23
	and     (hl)		; @35D9 A6
	inc     hl		; @35DA 23
	and     (hl)		; @35DB A6
	inc     hl		; @35DC 23
	and     (hl)		; @35DD A6
	inc     hl		; @35DE 23
	and     (hl)		; @35DF A6
	ld      de,#0000		; @35E0 110000
	jr      z,j_35b4		; @35E3 28CF  (-49)

	ld      a,(game_mode_sub1)		; @35E5 3A024E  load A with main routine 1, subroutine #
	and     a		; @35E8 A7  == #00 ?
	jp      z,j_2195		; @35E9 CA9521  yes, jump back to program

	xor     a		; @35EC AF  else A := #00
	ld      (intermission_flag),a		; @35ED 32004F  clear the intermission indicator
	jp      j_058e		; @35F0 C38E05  jump back to program

; for value == F7 - SHOWACT ?

j_35f3:
	ld      a,b		; @35F3 78
	rst     #28		; @35F4 EF  insert task to display text "        "
	db	#1C,#30	; @35F5 1C30
;	ld      b,a		; @35F6 47
	; ;; gap-fill from golden boots $35F7-$35F7
	db	#47		; @35F7
	ld      de,#0001		; @35F8 110100
	jr      j_35b4		; @35FB 18B7  (-73)

; for value == F8 - CLEARACT

j_35fd:
	ld      a,#40		; @35FD 3E40
	ld      (#42ac),a		; @35FF 32AC42  blank out the character where the 'ACT' # was displayed
	ld      de,#0001		; @3602 110100
	jr      j_35b4		; @3605 18AD  (-83)

; for value == F5 - PLAYSOUND

j_3607:
	inc     hl		; @3607 23
	ld      a,(hl)		; @3608 7E
	ld   	(CH3_E_NUM),a		; @3609 32BC4E  set sound channel #3.  used when ghosts bump during 1st intermission
	ld      de,#0002		; @360C 110200
	jr      j_35b4		; @360F 18A3  (-93)

; arrive here at intermissions and attract mode
; called from above, with C preloaded with an offset depending on which intermission / attract mode we are in

j_3611:
	ld      a,(game_mode_sub1)		; @3611 3A024E  load A with main routine 1, subroutine #
	and     a		; @3614 A7  check for zero.  is a game being played?
	jr      nz,j_361f		; @3615 2008  no, skip next 3 steps.  no sounds during attract mode

	ld      a,#02		; @3617 3E02  else A := #02
	ld      (CH1_W_NUM),a		; @3619 32CC4E  store in wave to play
	ld      (CH2_W_NUM),a		; @361C 32DC4E  store in wave to play

; this is used to generate the animations with the animation programs stored in the tables
j_361f:
	ld      hl,#81f0		; @361F 21F081  load HL with start of table data
	ld      b,#00		; @3622 0600  B:=#00
	add     hl,bc		; @3624 09  add BC to HL to offset the start of the data
	ld      de,#4f02		; @3625 11024F  load Destination with #4F02
	ld      bc,#000c		; @3628 010C00  load byte counter with #0C
	ldir		; @362B EDB0  copy data from table into memory
	ld      a,#01		; @362D 3E01  A := #01
	ld      (intermission_flag),a		; @362F 32004F  set intermission indicator
	ld      (ghosts_killed_pending),a		; @3632 32A44D  set # of ghost killed but no collision for yet to 1
	ld      hl,#4f1f		; @3635 211F4F  load HL with stack pointer (?)
	ld      a,#00		; @3638 3E00  A := #00
	ld      (pac_death_anim),a		; @363A 32A54D  set pacman dead animation state to not dead
	ld      b,#14		; @363D 0614  B := #14
	rst     #8		; @363F CF
	ret		; @3640 C9  return    

j_3641:
	ld      a,b		; @3641 78
	cp      #06		; @3642 FE06
	jr      nz,j_364a		; @3644 2004  (4)
	ld hl,death_counter_hi		; @3646 21C64D
	ret		; @3649 C9

j_364a:
	ld      hl,#4cfe		; @364A 21FE4C
	ret		; @364D C9

        ; select song
	; arrive here from #2D62

j_364e:
	dec	b		; @364E 05  B = current bit of song being played (from loop in #2d50)
					; adapt B to the current level to find out the song number
	push	bc		; @364F C5  save BC	
	ld	a,b		; @3650 78  load A with B
	cp	#01		; @3651 FE01  == #01 ?
	jr	z,j_3659		; @3653 2804  yes, skip next 2 steps
	ld	b,#00		; @3655 0600  else B := #00
	jr	j_366a		; @3657 1811  jump ahead

j_3659:
	ld	a,(level_number)		; @3659 3A134E  load A with current game level
	ld	b,#01		; @365C 0601  B := #01 (song #1 for 1st intermission)
	cp	#01		; @365E FE01  game level == #01 (level 2) ?
	jr	z,j_366a		; @3660 2808  yes, jump ahead
	ld	b,#02		; @3662 0602  B := #02 (song #2 for 2nd intermission)
	cp	#04		; @3664 FE04  game level == #04 (level 5) ?
	jr	z,j_366a		; @3666 2802  yes, jump ahead
	ld	b,#03		; @3668 0603  else B := #03 (song #3 for 3rd intermission)

j_366a:
	rst	#18		; @366A DF  HL = (HL+2B)  [read from table in HL, i.e. SONG_TABLE_x]
	pop	bc		; @366B C1  restore BC
	jp	j_2d72		; @366C C3722D  jump back to main program to "process byte" routine

; arrive here from #2060 
; A is loaded with the color of the tile the ghost is on

j_366f:
	bit     6,a		; @366F CB77  test bit 6 of the tile.  is this a slow down zone (tunnel) ?
	jp      z,j_2066		; @3671 CA6620  no, jump back and set the var to zero
	ld      a,#01		; @3674 3E01  yes, A := #01
	ld      (bc),a		; @3676 02  store into ghost tunnel slowdown flag
	ret		; @3677 C9  return

; arrive here from #100B, continuation of task #05

j_3678:
	ld      hl,#0000		; @3678 210000  clear HL
	ld      (fruit_pos_lo),hl		; @367B 22D24D  clears the fruit score sprite 
	ret		; @367E C9  return

; can't find a call to here ???

	ld      a,(pac_y)		; @367F 3A084D  load A with pacman position
	and     #0f		; @3682 E60F  mask bits
	srl     a		; @3684 CB3F
	srl     a		; @3686 CB3F  shift right twice
	cpl		; @3688 2F  invert
	ld      e,#1c		; @3689 1E1C  E := #1C
	add     a,e		; @368B 83  add
	cp      #18		; @368C FE18  == #18 ?
	jr      nz,j_3692		; @368E 2002  no, skip next step

	ld      a,#36		; @3690 3E36  yes, A := #36
j_3692:
	ld      (spr_pac_code),a		; @3692 320A4C  store result into mspac sprite number
	ret		; @3695 C9  return


		;; garbage, leftover from patching pac-man rom.
		;; this is the tail end of the pellet table. heh.

	db	#03,#04,#01,#02,#01,#01,#01,#01,#0C,#01	; @3696 03040102010101010C01
	db	#01,#04,#01,#01,#01	; @36A0 0104010101

        ;; Indirect Lookup table for #2C5E routine  (0x48 entries)
        ;; patched from Pac-Man.  Pac-man items are indented

	db	#13,#37	; @36A5 1337  #3713	; 00        HIGH SCORE
	db	#23,#37	; @36A7 2337  #3723	; 01        CREDIT   
	db	#32,#37	; @36A9 3237  #3732	; 02        FREE PLAY
	db	#41,#37	; @36AB 4137  #3741	; 03        PLAYER ONE
	db	#5A,#37	; @36AD 5A37  #375A	; 04        PLAYER TWO
	db	#6A,#37	; @36AF 6A37  #376A	; 05        GAME  OVER
	db	#7A,#37	; @36B1 7A37  #377A	; 06        READY!
	db	#86,#37	; @36B3 8637  #3786	; 07        PUSH START BUTTON
	db	#9D,#37	; @36B5 9D37  #379D	; 08        1 PLAYER ONLY 
	db	#B1,#37	; @36B7 B137  #37B1	; 09        1 OR 2 PLAYERS
	db	#21,#3D	; @36B9 213D  #3D21	; 0a        "     "
;	003d	;			BONUS PAC-MAN FOR  00PTS
	db	#00,#3D	; @36BB 003D  #3D00	; 0b        ADDITIONAL    AT   000
;	213d				@ 1980 Midway Mfg Co
	db	#FD,#37	; @36BD FD37  #37FD	; 0c        "MS PAC-MAN"
;	    				CHARACTER / NICKNAME
	db	#67,#3D	; @36BF 673D  #3D67	; 0d        BLINKY
	db	#E3,#3D	; @36C1 E33D  #3DE3	; 0e        WITH
;					BBBBBBBB
	db	#86,#3D	; @36C3 863D  #3d86	; 0f        PINKY  
	db	#02,#3E	; @36C5 023E  #3E02	; 10        STARRING
;					DDDDDDDD
	db	#4C,#38	; @36C7 4C38  #384C	; 11        . 10 Pts (pac-man only)
	db	#5A,#38	; @36C9 5A38  #385A	; 12        o 50 Pts (pac-man only)
	db	#3C,#3D	; @36CB 3C3D  #3D3C	; 13        (C) MIDWAY MFG CO
	db	#57,#3D	; @36CD 573D  #3D57	; 14        MAD DOG
;					-SHADOW
	db	#D3,#3D	; @36CF D33D  #3DD3	; 15        JUNIOR
;					AAAAAAAA
	db	#76,#3D	; @36D1 763D  #3D76	; 16        KILLER
;					-SPEEDY
	db	#F2,#3D	; @36D3 F23D  #3DF2	; 17        THE CHASE
;					CCCCCCCC
	db	#01,#00	; @36D5 0100  #0001	; 18 	    - unused -
	db	#02,#00	; @36D7 0200  #0002	; 19	    - unused -
	db	#03,#00	; @36D9 0300  #0003	; 1a	    - unused -

	db	#BC,#38	; @36DB BC38  #38BC	; 1b        100
	db	#C4,#38	; @36DD C438  #38C4	; 1c        SUPER PAC-MAN
;					300
	db	#CE,#38	; @36DF CE38  #38CE	; 1d        MAN
;					500
	db	#D8,#38	; @36E1 D838  #38D8	; 1e        AN
;					700
	db	#E2,#38	; @36E3 E238  #38E2	; 1f        - ? -
;					1000
	db	#EC,#38	; @36E5 EC38  #3820	; 20        - ? -
;					2000
	db	#F6,#38	; @36E7 F638  #38F6	; 21        - ? -
;					3000
	db	#00,#39	; @36E9 0039  #3900	; 22        - ? -
;					5000
	db	#0A,#39	; @36EB 0A39  #390A	; 23        MEMORY  OK
	db	#1A,#39	; @36ED 1A39  #391A	; 24        BAD    R M
	db	#6F,#39	; @36EF 6F39  #396F	; 25        FREE  PLAY       
	db	#2A,#39	; @36F1 2A39  #392A	; 26        1 COIN  1 CREDIT 
	db	#58,#39	; @36F3 5839  #3958	; 27        1 COIN  2 CREDITS
	db	#41,#39	; @36F5 4139  #3941	; 28        2 COINS 1 CREDIT 
	db	#11,#3E	; @36F7 113E  #3E11	; 29        MS. PAC-MEN	(service mode screen)
;	4f3e				PAC-MAN
;	db	#86,#39	; @36F8 8639  #3986	; 2a        BONUS  NONE
	; ;; gap-fill from golden boots $36F9-$36FA
	db	#86,#39		; @36F9
	db	#97,#39	; @36FB 9739  #3997	; 2b        BONUS
	db	#B0,#39	; @36FD B039  #39B0	; 2c        TABLE  
	db	#BD,#39	; @36FF BD39  #39BD	; 2d        UPRIGHT
	db	#CA,#39	; @3701 CA39  #39CA	; 2e        000		for test screen
	db	#A5,#3D	; @3703 A53D  #3DA5	; 2f        INKY    
	db	#21,#3E	; @3705 213E  #3E21	; 30        "        "
;					FFFFFFFF
	db	#C6,#3D	; @3707 C63D  #3DC6	; 31        SUE 
;					CLYDE
	db	#40,#3E	; @3709 403E  #3E40	; 32        THEY MEET
;					HHHHHHHH
	db	#95,#3D	; @370B 953D  #3D95	; 33        MS. PAC-MAN  (For "Starring" bit)
;					BASHFUL
	db	#11,#3E	; @370D 113E  #3E11	; 34        MS. PAC-MEN	 (service mode screen)
;					EEEEEEEE
	db	#B4,#3D	; @370F B43D  #3DB4	; 35        1980,1981
;					POKEY
	db	#30,#3E	; @3711 303E  #3E30	; 36        ACT III
;					GGGGGGGG

	;; there's another one of these for the text over at 3D00

	;; text string table 1
;offset   0  1  2  3  4  5  6  7   8  9  a  b  c  d  e  f    0123456789abcdef
;00003710           d4 83 48 49 47  48 40 53 43 4f 52 45 2f  |   ..HIGH@SCORE/|
;00003720  8f 2f 80 3b 80 43 52 45  44 49 54 40 40 40 2f 8f  |./.;.CREDIT@@@/.|
;00003730  2f 80 3b 80 46 52 45 45  40 50 4c 41 59 2f 8f 2f  |/.;.FREE@PLAY/./|
;00003740  80 8c 02 50 4c 41 59 45  52 40 4f 4e 45 2f 85 2f  |...PLAYER@ONE/./|
;00003750  10 10 1a 1a 1a 1a 1a 1a  10 10 8c 02 50 4c 41 59  |............PLAY|
;00003760  45 52 40 54 57 4f 2f 85  2f 80 92 02 47 41 4d 45  |ER@TWO/./...GAME|
;00003770  40 40 4f 56 45 52 2f 81  2f 80 52 02 52 45 41 44  |@@OVER/./.R.READ|
;00003780  59 5b 2f 89 2f 90 ed 02  50 55 53 48 40 53 54 41  |Y[/./...PUSH@STA|
;00003790  52 54 40 42 55 54 54 4f  4e 2f 87 2f 80 af 02 31  |RT@BUTTON/./...1|
;000037a0  40 50 4c 41 59 45 52 40  4f 4e 4c 59 40 2f 87 2f  |@PLAYER@ONLY@/./|
;000037b0  80 af 02 31 40 4f 52 40  32 40 50 4c 41 59 45 52  |...1@OR@2@PLAYER|
;000037c0  53 2f 87 00 2f 00 80 00  96 03 42 4f 4e 55 53 40  |S/../.....BONUS@|
;000037d0  50 55 43 4b 4d 41 4e 40  46 4f 52 40 40 40 30 30  |PUCKMAN@FOR@@@00|
;000037e0  30 40 5d 5e 5f 2f 8e 2f  80 ba 02 5c 40 28 29 2a  |0@]^_/./...\@()*|
;000037f0  2b 2c 2d 2e 40 31 39 38  30 2f 83 2f 80 65 03 40  |+,-.@1980/./.e.@|

; offset   0  1  2  3  4  5  6  7   8  9  a  b  c  d  e  f    0123456789abcdef
;00003800  40 40 40 40 40 40 40 26  4d 53 40 50 41 43 3b 4d  |@@@@@@@&MS@PAC;M|
;00003810  41 4e 27 40 2f 87 2f 80  01 26 41 4b 41 42 45 49  |AN'@/./..&AKABEI|
;00003820  26 2f 81 2f 80 45 01 26  4d 41 43 4b 59 26 2f 81  |&/./.E.&MACKY&/.|
;00003830  2f 80 48 01 26 50 49 4e  4b 59 26 2f 83 2f 80 48  |/.H.&PINKY&/./.H|
;00003840  01 26 4d 49 43 4b 59 26  2f 83 2f 80 76 02 10 40  |.&MICKY&/./.v..@|
;00003850  31 30 40 5d 5e 5f 2f 9f  2f 80 78 02 14 40 35 30  |10@]^_/./.x..@50|
;00003860  40 5d 5e 5f 2f 9f 2f 80  5d 02 28 29 2a 2b 2c 2d  |@]^_/./.].()*+,-|
;00003870  2e 2f 83 2f 80 c5 02 40  4f 49 4b 41 4b 45 3b 3b  |././...@OIKAKE;;|
;00003880  3b 3b 2f 81 2f 80 c5 02  40 55 52 43 48 49 4e 3b  |;;/./...@URCHIN;|
;00003890  3b 3b 3b 3b 2f 81 2f 80  c8 02 40 4d 41 43 48 49  |;;;;/./...@MACHI|
;000038a0  42 55 53 45 3b 3b 2f 83  2f 80 c8 02 40 52 4f 4d  |BUSE;;/./...@ROM|
;000038b0  50 3b 3b 3b 3b 3b 3b 3b  2f 83 2f 80 25 80 81 85  |P;;;;;;;/./.%...|
;000038c0  2f 81 2f 90 6e 02 53 55  50 45 52 40 50 41 43 3b  |/./.n.SUPER@PAC;|
	;; Note "SUPER PAC-MAN" in the text above.  This was a stepping stone
	;; between Crazy Otto and Ms. Pac-Man.
;000038d0  4d 41 4e 2f 89 2f 80 4d  41 4e 2f 89 2f 80 2f 90  |MAN/./.MAN/././.|
;000038e0  00 00 2e 80 86 8b 8d 8e  2f 8f 2f 90[30 80 40 40  |.......././.0.@@|
;000038f0  40 40 2f 94 2f 90 32 80  89 8a 8d 8e 2f 89 2f 90  |@@/./.2....././.|

; offset   0  1  2  3  4  5  6  7   8  9  a  b  c  d  e  f    0123456789abcdef
;00003900  34 80 89 8a 8d 8e 2f 89  2f 90 04 03 4d 45 4d 4f  |4....././...MEMO|
;00003910  52 59 40 40 4f 4b 2f 8f  2f 80 04 03 42 41 44 40  |RY@@OK/./...BAD@|
;00003920  40 40 40 52 40 4d 2f 8f  2f 80 08 03 31 40 43 4f  |@@@R@M/./...1@CO|
;00003930  49 4e 40 40 31 40 43 52  45 44 49 54 40 2f 8f 2f  |IN@@1@CREDIT@/./|
;00003940  80 08 03 32 40 43 4f 49  4e 53 40 31 40 43 52 45  |...2@COINS@1@CRE|
;00003950  44 49 54 40 2f 8f 2f 80  08 03 31 40 43 4f 49 4e  |DIT@/./...1@COIN|
;00003960  40 40 32 40 43 52 45 44  49 54 53 2f 8f 2f 80 08  |@@2@CREDITS/./..|
;00003970  03 46 52 45 45 40 40 50  4c 41 59 40 40 40 40 40  |.FREE@@PLAY@@@@@|
;00003980  40 40 2f 8f 2f 80 0a 03  42 4f 4e 55 53 40 40 4e  |@@/./...BONUS@@N|
;00003990  4f 4e 45 2f 8f 2f 80 0a  03 42 4f 4e 55 53 40 2f  |ONE/./...BONUS@/|
;000039a0  8f 2f 80 0c 03 50 55 43  4b 4d 41 4e 2f 8f 2f 80  |./...PUCKMAN/./.|
;000039b0  0e 03 54 41 42 4c 45 40  40 2f 8f 2f 80 0e 03 55  |..TABLE@@/./...U|
;000039c0  50 52 49 47 48 54 2f 8f  2f 80 0a 02 30 30 30 2f  |PRIGHT/./...000/|
;000039d0  8f 2f 80 6b 01 26 41 4f  53 55 4b 45 26 2f 85 2f  |./.k.&AOSUKE&/./|
;000039e0  3d 4f 21 00 4d d7 eb 79  21 f2 39 d7 12 23 13 7e  |=O!.M..y!.9..#.~|
;000039f0  12 c9 2a da 42 da 5a da  72 da ef 05 01 ef 10 14  |..*.B.Z.r.......|

; offset   0  1  2  3  4  5  6  7   8  9  a  b  c  d  e  f    0123456789abcdef
;00003a00  3e 01 32 14 4e c9 87 2f  80 cb 02 40 4b 49 4d 41  |>.2.N../...@KIMA|
;00003a10  47 55 52 45 3b 3b 2f 85  2f 80 cb 02 40 53 54 59  |GURE;;/./...@STY|
;00003a20  4c 49 53 54 3b 3b 3b 3b  2f 85 2f 80 ce 02 40 4f  |LIST;;;;/./...@O|
;00003a30  54 4f 42 4f 4b 45 3b 3b  3b 2f 87 2f 80 ce 02 40  |TOBOKE;;;/./...@|
;00003a40  43 52 59 42 41 42 59 3b  3b 3b 3b 2f 87 2f 80     |CRYBABY;;;;/./. |

; and here it is in a more readable format

;	0x83d4, "HIGH@SCORE", 		0x2f, 0x8f, 0x2f, 0x80,		; @3713
;	0x803b, "CREDIT@@@", 			0x2f, 0x8f, 0x2f, 0x80,		; @3723
;	0x803b, "FREE@PLAY", 			0x2f, 0x8f, 0x2f, 0x80,		; @3732
;	0x028c, "PLAYER@ONE", 		0x2f, 0x85, 0x2f, 0x10,		; @3741
;	0x028c, "PLAYER@TWO", 		0x2f, 0x85, 0x2f, 0x80,		; @375A
;	0x0292, "GAME@@OVER", 		0x2f, 0x81, 0x2f, 0x80,		; @376A
;	0x0252, "READY[", 			0x2f, 0x89, 0x2f, 0x90,		; @377A
;	0x02ed, "PUSH@START@BUTTON", 		0x2f, 0x87, 0x2f, 0x80,		; @3786
;	0x02af, "1@PLAYER@ONLY@", 		0x2f, 0x87, 0x2f, 0x80,		; @379D
;	0x0396, "BONUS@PUCKMAN@FOR@@@000@]^_", 0x2f, 0x8e, 0x2f, 0x80,		; @37C8
;	0x02ba, "\@()*+,-.@1980", 		0x2f, 0x83, 0x2f, 0x80,		; @37E9
;	0x0365, "@@@@@@@@&MS@PAC;MAN'@", 	0x2f, 0x87, 0x2f, 0x80,		; @37FD
;	P   0x02c3, "CHARACTER@:@NICKNAME", 	0x2f, 0x8f, 0x2f, 0x80,		; @37FD
;	0x0180, "&AKABEI&", 			0x2f, 0x81, 0x2f, 0x80,		; @3817
;	0x0145, "&MACKY&", 			0x2f, 0x81, 0x2f, 0x80,		; @3825
;	0x0148, "&PINKY&", 			0x2f, 0x83, 0x2f, 0x80,		; @3832
;	0x0148, "&MICKY&", 			0x2f, 0x83, 0x2f, 0x80,		; @383F
;	0x1002, "@10@]^_", 			0x2f, 0x9f, 0x2f, 0x80,		; @384D
;	0x1402, "@50@]^_", 			0x2f, 0x9f, 0x2f, 0x80,		; @385B
;	0x025d, "()*+,-.", 			0x2f, 0x83, 0x2f, 0x80,		; @3868
;	0x02c5, "@OIKAKE;;;;", 		0x2f, 0x81, 0x2f, 0x80,		; @3875
;	0x02c5, "@URCHIN;;;;;", 		0x2f, 0x81, 0x2f, 0x80,		; @3886
;	0x02c8, "@MACHIBUSE;;", 		0x2f, 0x83, 0x2f, 0x80,		; @3898
;	0x02c8, "@ROMP;;;;;;;", 		0x2f, 0x83, 0x2f, 0x80,		; @38AA
;	0x8581, "", 				0x2f, 0x81, 0x2f, 0x90,		; @38BE
;	0x026e, "SUPER@PAC;MAN", 		0x2f, 0x89, 0x2f, 0x80,		; @38C4
;	P   0x8582, "@", 				0x2f, 0x83, 0x2f, 0x90,		; @38C7
;	P   0x8583, "@", 				0x2f, 0x83, 0x2f, 0x90,		; @38D1
;	0x802f, "MAN", 			0x2f, 0x89, 0x2f, 0x80,		; @38D5
;	P   0x8584, "@", 				0x2f, 0x83, 0x2f, 0x90,		; @38DB
;	0x8e8d, "", 				0x2f, 0x8f, 0x2f, 0x90,		; @38E6
;	P   0x8e8d, "", 				0x2f, 0x83, 0x2f, 0x90,		; @38E6
;	0x8030, "@@@@", 			0x2f, 0x94, 0x2f, 0x90,		; @38EC
;	P   0x8e8d, "", 				0x2f, 0x83, 0x2f, 0x90,		; @38F0
;	0x8e8d, "", 				0x2f, 0x89, 0x2f, 0x90,		; @38FA
;	0x8e8d, "", 				0x2f, 0x89, 0x2f, 0x90,		; @3904
;	0x0304, "MEMORY@@OK", 		0x2f, 0x8f, 0x2f, 0x80,		; @390A
;	0x0304, "BAD@@@@R@M", 		0x2f, 0x8f, 0x2f, 0x80,		; @391A
;	0x0308, "1@COIN@@1@CREDIT@",		0x2f, 0x8f, 0x2f, 0x80,		; @392A
;	0x0308, "2@COINS@1@CREDIT@",	 	0x2f, 0x8f, 0x2f, 0x80,		; @3941
;	0x0308, "1@COIN@@2@CREDITS", 		0x2f, 0x8f, 0x2f, 0x80,		; @3958
;	0x0308, "FREE@@PLAY@@@@@@@", 		0x2f, 0x8f, 0x2f, 0x80,		; @396F
;	0x030a, "BONUS@@NONE", 		0x2f, 0x8f, 0x2f, 0x80,		; @3986
;	0x030a, "BONUS@", 			0x2f, 0x8f, 0x2f, 0x80,		; @3997
;	0x030c, "PUCKMAN", 			0x2f, 0x8f, 0x2f, 0x80,		; @39A3
;	0x030e, "TABLE@@", 			0x2f, 0x8f, 0x2f, 0x80,		; @39B0
;	0x030e, "UPRIGHT", 			0x2f, 0x8f, 0x2f, 0x80,		; @39BD
;	0x020a, "000", 			0x2f, 0x8f, 0x2f, 0x80,		; @39CA
;	0x016b, "&AOSUKE&", 			0x2f, 0x85, 0x2f, 0x3d,		; @39D3
;	P   0x014b, "&MUCKY&", 			0x2f, 0x85, 0x2f, 0x80,		; @39E1
;	P   0x016e, "&GUZUTA&", 			0x2f, 0x87, 0x2f, 0x80,		; @39EE
;	P   0x014e, "&MOCKY&", 			0x2f, 0x87, 0x2f, 0x80,		; @39FC
;	0x02cb, "@KIMAGURE;;", 		0x2f, 0x85, 0x2f, 0x80,		; @3A09
;	0x02cb, "@STYLIST;;;;", 		0x2f, 0x85, 0x2f, 0x80,		; @3A1A
;	0x02ce, "@OTOBOKE;;;", 		0x2f, 0x87, 0x2f, 0x80,		; @3A2C
;	0x02ce, "@CRYBABY;;;;", 		0x2f, 0x87, 0x2f, 0x80,		; @3A3D


	;; "Made By Namco" easter egg text

; This is stored the same way as the pellet information.
;  #3af4 routine:
;  1  retrieve the value
;  2  if (value == 0), done.
;  3  draw a pellet (#14)
;  4  increment the position by the value retrieved
;  5  repeat at 1 above

; offset   0  1  2  3  4  5  6  7   8  9  a  b  c  d  e  f

	; namco
;00003a40                                                01
;00003a50  01 03 01 01 01 03 02 02  02 01 01 01 01 02 04 04
;00003a60  04 06 02 02 02 02 04 02  04 04 04 06 02 02 02 02
;00003a70  01 01 01 01 02 04 04 04  06 02 02 02 02 06 04 05
;00003a80  01 01 03 01 01 01 04 01  01 01 03 01 01 04 01 01
;00003a90  01

	; by
;00003a90     6c 05 01 01 01 18 04  04 18 05 01 01 01 17 02
;00003aa0  03 04 16 04 03 01 01 01

	; made
;00003aa0                           76 01 01 01 01 03 01 01
;00003ab0  01 02 04 02 04 0e 02 04  02 04 02 04 0b 01 01 01
;00003ac0  02 04 02 01 01 01 01 02  02 02 0e 02 04 02 04 02
;00003ad0  01 02 01 0a 01 01 01 01  03 01 01 01 03 01 01 03
;00003ae0  04 00                                             


	; data - 3 screen region grid data for self test
	; referenced at #3259

	; ;; gap-fill from golden boots $3713-$3AE1
	db	#D4,#83,#48,#49,#47,#48,#40,#53,#43,#4F,#52,#45,#2F,#8F,#2F,#80		; @3713
	db	#3B,#80,#43,#52,#45,#44,#49,#54,#40,#40,#40,#2F,#8F,#2F,#80,#3B		; @3723
	db	#80,#46,#52,#45,#45,#40,#50,#4C,#41,#59,#2F,#8F,#2F,#80,#8C,#02		; @3733
	db	#50,#4C,#41,#59,#45,#52,#40,#4F,#4E,#45,#2F,#85,#2F,#10,#10,#1A		; @3743
	db	#1A,#1A,#1A,#1A,#1A,#10,#10,#8C,#02,#50,#4C,#41,#59,#45,#52,#40		; @3753
	db	#54,#57,#4F,#2F,#85,#2F,#80,#92,#02,#47,#41,#4D,#45,#40,#40,#4F		; @3763
	db	#56,#45,#52,#2F,#81,#2F,#80,#52,#02,#52,#45,#41,#44,#59,#5B,#2F		; @3773
	db	#89,#2F,#90,#ED,#02,#50,#55,#53,#48,#40,#53,#54,#41,#52,#54,#40		; @3783
	db	#42,#55,#54,#54,#4F,#4E,#2F,#87,#2F,#80,#AF,#02,#31,#40,#50,#4C		; @3793
	db	#41,#59,#45,#52,#40,#4F,#4E,#4C,#59,#40,#2F,#87,#2F,#80,#AF,#02		; @37A3
	db	#31,#40,#4F,#52,#40,#32,#40,#50,#4C,#41,#59,#45,#52,#53,#2F,#87		; @37B3
	db	#00,#2F,#00,#80,#00,#96,#03,#42,#4F,#4E,#55,#53,#40,#50,#55,#43		; @37C3
	db	#4B,#4D,#41,#4E,#40,#46,#4F,#52,#40,#40,#40,#30,#30,#30,#40,#5D		; @37D3
	db	#5E,#5F,#2F,#8E,#2F,#80,#BA,#02,#5C,#40,#28,#29,#2A,#2B,#2C,#2D		; @37E3
	db	#2E,#40,#31,#39,#38,#30,#2F,#83,#2F,#80,#65,#03,#40,#40,#40,#40		; @37F3
	db	#40,#40,#40,#40,#26,#4D,#53,#40,#50,#41,#43,#3B,#4D,#41,#4E,#27		; @3803
	db	#40,#2F,#87,#2F,#80,#01,#26,#41,#4B,#41,#42,#45,#49,#26,#2F,#81		; @3813
	db	#2F,#80,#45,#01,#26,#4D,#41,#43,#4B,#59,#26,#2F,#81,#2F,#80,#48		; @3823
	db	#01,#26,#50,#49,#4E,#4B,#59,#26,#2F,#83,#2F,#80,#48,#01,#26,#4D		; @3833
	db	#49,#43,#4B,#59,#26,#2F,#83,#2F,#80,#76,#02,#10,#40,#31,#30,#40		; @3843
	db	#5D,#5E,#5F,#2F,#9F,#2F,#80,#78,#02,#14,#40,#35,#30,#40,#5D,#5E		; @3853
	db	#5F,#2F,#9F,#2F,#80,#5D,#02,#28,#29,#2A,#2B,#2C,#2D,#2E,#2F,#83		; @3863
	db	#2F,#80,#C5,#02,#40,#4F,#49,#4B,#41,#4B,#45,#3B,#3B,#3B,#3B,#2F		; @3873
	db	#81,#2F,#80,#C5,#02,#40,#55,#52,#43,#48,#49,#4E,#3B,#3B,#3B,#3B		; @3883
	db	#3B,#2F,#81,#2F,#80,#C8,#02,#40,#4D,#41,#43,#48,#49,#42,#55,#53		; @3893
	db	#45,#3B,#3B,#2F,#83,#2F,#80,#C8,#02,#40,#52,#4F,#4D,#50,#3B,#3B		; @38A3
	db	#3B,#3B,#3B,#3B,#3B,#2F,#83,#2F,#80,#25,#80,#81,#85,#2F,#81,#2F		; @38B3
	db	#90,#6E,#02,#53,#55,#50,#45,#52,#40,#50,#41,#43,#3B,#4D,#41,#4E		; @38C3
	db	#2F,#89,#2F,#80,#4D,#41,#4E,#2F,#89,#2F,#80,#2F,#90,#00,#00,#2E		; @38D3
	db	#80,#86,#8B,#8D,#8E,#2F,#8F,#2F,#90,#30,#80,#40,#40,#40,#40,#2F		; @38E3
	db	#94,#2F,#90,#32,#80,#89,#8A,#8D,#8E,#2F,#89,#2F,#90,#34,#80,#89		; @38F3
	db	#8A,#8D,#8E,#2F,#89,#2F,#90,#04,#03,#4D,#45,#4D,#4F,#52,#59,#40		; @3903
	db	#40,#4F,#4B,#2F,#8F,#2F,#80,#04,#03,#42,#41,#44,#40,#40,#40,#40		; @3913
	db	#52,#40,#4D,#2F,#8F,#2F,#80,#08,#03,#31,#40,#43,#4F,#49,#4E,#40		; @3923
	db	#40,#31,#40,#43,#52,#45,#44,#49,#54,#40,#2F,#8F,#2F,#80,#08,#03		; @3933
	db	#32,#40,#43,#4F,#49,#4E,#53,#40,#31,#40,#43,#52,#45,#44,#49,#54		; @3943
	db	#40,#2F,#8F,#2F,#80,#08,#03,#31,#40,#43,#4F,#49,#4E,#40,#40,#32		; @3953
	db	#40,#43,#52,#45,#44,#49,#54,#53,#2F,#8F,#2F,#80,#08,#03,#46,#52		; @3963
	db	#45,#45,#40,#40,#50,#4C,#41,#59,#40,#40,#40,#40,#40,#40,#40,#2F		; @3973
	db	#8F,#2F,#80,#0A,#03,#42,#4F,#4E,#55,#53,#40,#40,#4E,#4F,#4E,#45		; @3983
	db	#2F,#8F,#2F,#80,#0A,#03,#42,#4F,#4E,#55,#53,#40,#2F,#8F,#2F,#80		; @3993
	db	#0C,#03,#50,#55,#43,#4B,#4D,#41,#4E,#2F,#8F,#2F,#80,#0E,#03,#54		; @39A3
	db	#41,#42,#4C,#45,#40,#40,#2F,#8F,#2F,#80,#0E,#03,#55,#50,#52,#49		; @39B3
	db	#47,#48,#54,#2F,#8F,#2F,#80,#0A,#02,#30,#30,#30,#2F,#8F,#2F,#80		; @39C3
	db	#6B,#01,#26,#41,#4F,#53,#55,#4B,#45,#26,#2F,#85,#2F,#3D,#4F,#21		; @39D3
	db	#00,#4D,#D7,#EB,#79,#21,#F2,#39,#D7,#12,#23,#13,#7E,#12,#C9,#2A		; @39E3
	db	#DA,#42,#DA,#5A,#DA,#72,#DA,#EF,#05,#01,#EF,#10,#14,#3E,#01,#32		; @39F3
	db	#14,#4E,#C9,#87,#2F,#80,#CB,#02,#40,#4B,#49,#4D,#41,#47,#55,#52		; @3A03
	db	#45,#3B,#3B,#2F,#85,#2F,#80,#CB,#02,#40,#53,#54,#59,#4C,#49,#53		; @3A13
	db	#54,#3B,#3B,#3B,#3B,#2F,#85,#2F,#80,#CE,#02,#40,#4F,#54,#4F,#42		; @3A23
	db	#4F,#4B,#45,#3B,#3B,#3B,#2F,#87,#2F,#80,#CE,#02,#40,#43,#52,#59		; @3A33
	db	#42,#41,#42,#59,#3B,#3B,#3B,#3B,#2F,#87,#2F,#80,#01,#01,#03,#01		; @3A43
	db	#01,#01,#03,#02,#02,#02,#01,#01,#01,#01,#02,#04,#04,#04,#06,#02		; @3A53
	db	#02,#02,#02,#04,#02,#04,#04,#04,#06,#02,#02,#02,#02,#01,#01,#01		; @3A63
	db	#01,#02,#04,#04,#04,#06,#02,#02,#02,#02,#06,#04,#05,#01,#01,#03		; @3A73
	db	#01,#01,#01,#04,#01,#01,#01,#03,#01,#01,#04,#01,#01,#01,#6C,#05		; @3A83
	db	#01,#01,#01,#18,#04,#04,#18,#05,#01,#01,#01,#17,#02,#03,#04,#16		; @3A93
	db	#04,#03,#01,#01,#01,#76,#01,#01,#01,#01,#03,#01,#01,#01,#02,#04		; @3AA3
	db	#02,#04,#0E,#02,#04,#02,#04,#02,#04,#0B,#01,#01,#01,#02,#04,#02		; @3AB3
	db	#01,#01,#01,#01,#02,#02,#02,#0E,#02,#04,#02,#04,#02,#01,#02,#01		; @3AC3
	db	#0A,#01,#01,#01,#01,#03,#01,#01,#01,#03,#01,#01,#03,#04,#00		; @3AD3
	db	#02,#40	; @3AE2 0240  #4002
	db	#01,#3E	; @3AE4 013E  #3E01
	db	#3D,#10	; @3AE6 3D10  #103D
	db	#40,#40	; @3AE8 4040  #4040
	db	#0E,#3D	; @3AEA 0E3D  #3D0E
	db	#3E,#10	; @3AEC 3E10  #103E
;	db	#C2,#43	; @3AED C243  #43C2
	; ;; gap-fill from golden boots $3AEE-$3AEF
	db	#C2,#43		; @3AEE
	db	#01,#3E	; @3AF0 013E  #3E01
	db	#3D,#10	; @3AF2 3D10  #103D


	; Draw the "Made By Namco" text (egg)

j_3af4:
	ld      hl,#40a2		; @3AF4 21A240  load HL with video ram start position
	ld      de,#3a4f		; @3AF7 114F3A  load DE with pellet data start

j_3afa:
	ld      (hl),#14		; @3AFA 3614  set the screen to pellet (#14)
	ld      a,(de)		; @3AFC 1A  load A with table data
	and     a		; @3AFD A7  are we done ?
	ret     z		; @3AFE C8  yes, return

	inc     de		; @3AFF 13  else increase table pointer
	add     a,l		; @3B00 85  add the value to screen position
	ld      l,a		; @3B01 6F  store result.  is the carry flag set ?
	jp      nc,j_3afa		; @3B02 D2FA3A  no, loop again
	inc     h		; @3B05 24  yes, increase H
	jr      j_3afa		; @3B06 18F2  and loop again


	; data - fruit table, referred in #2BF9
	; the first code is the 1st value of the graphic for the fruit
	; the second code is the color value for the fruit


	db	#90,#14	; @3B08 9014  cherry
	db	#94,#0F	; @3B0A 940F  strawberry
	db	#98,#15	; @3B0C 9815  peach
	db	#9C,#07	; @3B0E 9C07  pretzel
	db	#A0,#14	; @3B10 A014  apple
	db	#A4,#17	; @3B12 A417  pear
	db	#A8,#16	; @3B14 A816  banana
	db	#AC,#16	; @3B16 AC16  key (unused in ms. pac)
	db	#00,#00,#00,#00,#00,#00,#00,#00	; @3B18 0000000000000000  unused
	db	#00,#00,#00,#00,#00,#00,#00,#00	; @3B20 0000000000000000  unused
	db	#00,#00,#9C,#16,#9C,#16,#9C,#16	; @3B28 00009C169C169C16  unused, pretzels

	; pac-man data follows, fruit table

	;3B08:	90 14   			; cherry
	;3B0A:	94 0F   			; strawberry
	;3B0C:	98 15   			; 1st orange
	;3B0E:	98 15   			; 2nd orange
	;3B10:	A0 14   			; 1st apple
	;3B12:	A0 14   			; 2nd apple
	;3B14:  A4 17   			; 1st pineapple
	;3B16:	A4 17   			; 2nd pineapple
	;3B18:	A8 09   			; 1st galaxian / pretzel
	;3B1A:	A8 09   			; 2nd galaxian / pretzel
	;3B1C:	9C 16   			; 1st bell / banana
	;3B1E:	9C 16   			; 2nd bell / banana
	;3B20:	AC 16   			; 1st key
	;3B22:	AC 16   			; 2nd key
	;3B24:	AC 16   			; 3rd key
	;3B26:	AC 16   			; 4th key
	;3B28:	AC 16   			; 5th key
	;3B2A:	AC 16   			; 6th key
	;3B2C:	AC 16   			; 7th key
	;3B2E:	AC 16   			; 8th key

	; end pac-man data

	;;
	;; MSPACMAN sound tables
	;;

	;; 2 effects for channel 1

	db	#73,#20,#00,#0C,#00,#0A,#1F,#00	; @3B30 7320000C000A1F00  extra life sound
	db	#72,#20,#FB,#87,#00,#02,#0F,#00	; @3B38 7220FB8700020F00  credit sound

	;; 8 effects for channel 2

	db	#59,#01,#06,#08,#00,#00,#02,#00	; @3B40 5901060800000200  end of energizer
	db	#59,#01,#06,#09,#00,#00,#02,#00	; @3B48 5901060900000200  higher frequency when 155 dots eaten
	db	#59,#02,#06,#0A,#00,#00,#02,#00	; @3B50 5902060A00000200  higher frequency when 179 dots eaten
	db	#59,#03,#06,#0B,#00,#00,#02,#00	; @3B58 5903060B00000200  higher frequency when 12 dots left
	db	#59,#04,#06,#0C,#00,#06,#02,#00	; @3B60 5904060C00060200  reset higher frequency when 12 or less dots left
	db	#24,#00,#06,#08,#02,#00,#0A,#00	; @3B68 2400060802000A00  engergizer eaten
	db	#36,#07,#87,#6F,#00,#00,#04,#00	; @3B70 3607876F00000400  eyes returning sound
	db	#70,#04,#00,#00,#00,#00,#08,#00	; @3B78 7004000000000800  unused ???

	;; 6 effects for channel 3

	db	#1C,#70,#8B,#08,#00,#01,#06,#00	; @3B80 1C708B0800010600  dot eating sound 1
	db	#1C,#70,#8B,#08,#00,#01,#06,#00	; @3B88 1C708B0800010600  dot eating sound 2
	db	#56,#0C,#FF,#8C,#00,#02,#08,#00	; @3B90 560CFF8C00020800  fruit eating sound
	db	#56,#00,#02,#0A,#07,#03,#0C,#00	; @3B98 5600020A07030C00  blue ghost eaten sound
	db	#36,#38,#FE,#12,#F8,#04,#0F,#FC	; @3BA0 3638FE12F8040FFC  ghosts bumping during act 1 sound
	db	#22,#01,#01,#06,#00,#01,#07,#00	; @3BA8 2201010600010700  fruit bouncing sound
        
        ;; lookup tables

	db	#01,#02,#04,#08,#10,#20,#40,#80	; @3BB0 0102040810204080

	db	#00,#57,#5C,#61,#67,#6D,#74,#7B,#82,#8A,#92,#9A,#A3,#AD,#B8,#C3	; @3BB8 00575C61676D747B828A929AA3ADB8C3
        
        ;; channel 1 : jump table to song data

	db	#D4,#3B	; @3BC8 D43B  #3BD4
	db	#F3,#3B	; @3BCA F33B  #3BF3
        
        ;; channel 2 : jump table to song data

	db	#58,#3C	; @3BCC 583C  #3C58
	db	#95,#3C	; @3BCE 953C  #3C95
        
        ;; channel 3 : jump table to song data

	db	#DE,#3C	; @3BD0 DE3C  #3CDE	; data is #00, no sounds on this channel
	db	#DF,#3C	; @3BD2 DF3C  #3CDF	; data is #00, no sounds on this channel
        
        ;; song data 

; act 2 song

	db	#F1,#03,#F2,#03,#F3,#0A,#F4,#02,#90,#7C,#7B,#7A,#79,#79,#78,#97		; @3BD4 F102F203F30FF4018270698270698370
	db	#76,#75,#74,#73,#73,#72,#91,#A8,#88,#60,#4A,#4C,#91,#95,#88		; @3BE4 6A83706A827069827069898B8D8EFF

; act 2 song

	db	#95,#91,#95,#88,#95,#91,#95,#88,#95,#95,#98,#94,#97,#93,#96,#88		; @3BF3 F102F203F30FF4016750304730675030
	db	#96,#93,#96,#88,#96,#93,#96,#88,#96,#B6,#B3,#75,#76,#77,#78,#78		; @3C03 473067503047304B104C104D104E1067
	db	#75,#73,#68,#91,#95,#88,#95,#91,#95,#88,#95,#86,#96,#95,#92,#93		; @3C13 50304730675030473067503047304B10
	db	#8C,#8A,#88,#86,#90,#90,#96,#95,#90,#90,#86,#90,#96,#90,#96,#91		; @3C23 4C104D104E1067503047306750304730
	db	#88,#81,#FF,#47,#30,#4B,#10,#4C,#10,#4D,#10,#4E,#10,#77,#20,#4E		; @3C33 67503047304B104C104D104E1077204E
	db	#10,#4D,#10,#4C,#10,#4A,#10,#47,#10,#46,#10,#65,#30,#66,#30,#67	; @3C43 104D104C104A10471046106530663067
	db	#40,#70,#F0,#FB,#3B	; @3C53 4070F0FB3B

; act 2 song

	db	#F1,#00,#F2,#02,#F3,#0A,#F4,#00,#88,#6C,#71,#72,#73,#73,#71,#93		; @3C58 F100F202F30FF40042504E5049504650
	db	#6C,#73,#75,#76,#76,#75,#96,#7C,#7A,#78,#76,#75,#96,#6C,#91,#A0		; @3C68 4E4970667043504F504A5047504F4A70
	db	#88,#75,#76,#77,#78,#71,#73,#74,#75,#71,#75,#71,#68,#68,#65,#66		; @3C78 677042504E50495046504E4970667045
	db	#67,#A8,#AB,#AC,#8C,#86,#76,#75,#6C,#71,#75,#73,#6B		; @3C88 46475047484950494A4B506EFF

; act 2 song (2nd half)

	db	#6C,#73,#76,#7A,#78,#78,#76,#73,#6C,#AA,#A8,#71,#73,#74,#75,#6A		; @3C95 F101F201F30FF4002667266726672344
;	db	#42,#47,#30,#67,#2A,#8B,#70,#26,#67,#26,#67,#26,#67,#23,#44,#42	; @3CA4 424730672A8B70266726672667234442
	; ;; gap-fill from golden boots $3CA5-$3CB3
	db	#6B,#6C,#73,#75,#76,#77,#78,#71,#73,#74,#75,#71,#75,#71,#68		; @3CA5
	db	#48,#40,#68,#67,#68,#AA,#A9,#AA,#6A,#60,#8A,#76,#75,#73,#71,#71		; @3CB4 47306723847026672667266723444247
	db	#73,#95,#75,#73,#71,#68,#68,#61,#63,#6A,#A8,#6C,#76,#6A,#6C,#91		; @3CC4 3067296A2B6C302C6D402B6C296A6720
	db	#90,#91,#FF,#40,#26,#87,#70,#F0,#9D,#3C		; @3CD4 296A40268770F09D3C00

	db	#00	; @3CDE 00

	db	#00	; @3CDF 00

	;; text strings 2  (copyright, ghost names, intermission)

;	..@ADDITIONAL@@@		; @3D00 9603404144444954494F4E414C404040
	; ;; gap-fill from golden boots $3CE0-$3D0F
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00		; @3CE0
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00		; @3CF0
	db	#96,#03,#40,#41,#44,#44,#49,#54,#49,#4F,#4E,#41,#4C,#40,#40,#40		; @3D00
	db	#40,#41,#54,#40,#40,#40,#30,#30,#30,#40,#5D,#5E,#5F,#2F,#95,#2F		; @3D10 404154404040303030405D5E5F2F952F  @AT@@@000@]^_/./
;	.Z.@@@@@@@/.....		; @3D20 805A02404040404040402F0707070101
;	../.P@@@/./.[.\@		; @3D30 01012F80504040402F872F805B025C40
	; ;; gap-fill from golden boots $3D20-$3D3F
	db	#80,#5A,#02,#40,#40,#40,#40,#40,#40,#40,#2F,#07,#07,#07,#01,#01		; @3D20
	db	#01,#01,#2F,#80,#50,#40,#40,#40,#2F,#87,#2F,#80,#5B,#02,#5C,#40		; @3D30
	db	#4D,#49,#44,#57,#41,#59,#40,#4D,#46,#47,#40,#43,#4F,#40,#40,#40		; @3D40 4D4944574159404D464740434F404040  MIDWAY@MFG@CO@@@
;	@/././...;MAD@DO		; @3D50 402F812F802F80C5023B4D414440444F
	; ;; gap-fill from golden boots $3D50-$3D5F
	db	#40,#2F,#81,#2F,#80,#2F,#80,#C5,#02,#3B,#4D,#41,#44,#40,#44,#4F		; @3D50
	db	#47,#40,#40,#2F,#81,#2F,#80,#6E,#02,#40,#40,#40,#42,#4C,#49,#4E		; @3D60 4740402F812F806E02404040424C494E  G@@/./.n.@@@BLIN
;	KY/./...;KILLER@		; @3D70 4B592F812F80C8023B4B494C4C455240
	; ;; gap-fill from golden boots $3D70-$3D7F
	db	#4B,#59,#2F,#81,#2F,#80,#C8,#02,#3B,#4B,#49,#4C,#4C,#45,#52,#40		; @3D70
	db	#40,#40,#2F,#83,#2F,#80,#6E,#02,#40,#40,#40,#50,#49,#4E,#4B,#59		; @3D80 40402F832F806E0240404050494E4B59  @@/./.n.@@@PINKY
	db	#40,#2F,#83,#2F,#80,#6E,#02,#4D,#53,#40,#50,#41,#43,#3B,#4D,#41		; @3D90 402F832F806E024D53405041433B4D41  @/./.n.MS@PAC;MA
	db	#4E,#2F,#89,#2F,#80,#6E,#02,#40,#40,#40,#49,#4E,#4B,#59,#40,#40		; @3DA0 4E2F892F806E02404040494E4B594040  N/./.n.@@@INKY@@
	db	#2F,#85,#2F,#80,#3D,#02,#40,#40,#31,#39,#38,#30,#3A,#31,#39,#38		; @3DB0 2F852F803D024040313938303A313938  /./.=.@@1980:198
	db	#31,#40,#2F,#81,#2F,#80,#6E,#02,#40,#40,#40,#40,#53,#55,#45,#2F		; @3DC0 31402F812F806E02404040405355452F  1@/./.n.@@@@SUE/
	db	#87,#2F,#80,#6B,#02,#4A,#55,#4E,#49,#4F,#52,#40,#40,#40,#40,#2F		; @3DD0 872F806B024A554E494F52404040402F  ./.k.JUNIOR@@@@/
	db	#8F,#2F,#80,#6B,#02,#57,#49,#54,#48,#40,#40,#40,#40,#40,#2F,#8F		; @3DE0 8F2F806B025749544840404040402F8F  ./.k.WITH@@@@@/.
	db	#2F,#80,#6B,#02,#54,#48,#45,#40,#43,#48,#41,#53,#45,#40,#2F,#8F		; @3DF0 2F806B02544845404348415345402F8F  /.k.THE@CHASE@/.
	db	#2F,#80,#6B,#02,#53,#54,#41,#52,#52,#49,#4E,#47,#40,#2F,#8F,#2F		; @3E00 2F806B025354415252494E47402F8F2F  /.k.STARRING@/./
;	...MS@PAC;MEN/./		; @3E10 800C034D53405041433B4D454E2F8F2F
	; ;; gap-fill from golden boots $3E10-$3E1F
	db	#80,#0C,#03,#4D,#53,#40,#50,#41,#43,#3B,#4D,#45,#4E,#2F,#8F,#2F		; @3E10
	db	#80,#6B,#02,#40,#40,#40,#40,#40,#40,#40,#40,#40,#2F,#85,#2F,#80		; @3E20 806B024040404040404040402F852F80  .k.@@@@@@@@@/./.
	db	#6B,#02,#41,#43,#54,#40,#49,#49,#49,#26,#40,#40,#2F,#87,#2F,#80		; @3E30 6B02414354404949492640402F872F80  k.ACT@III&@@/./.
	db	#6B,#02,#54,#48,#45,#59,#40,#4D,#45,#45,#54,#2F,#8F,#2F,#80,#0C		; @3E40 6B0254484559404D4545542F8F2F800C  k.THEY@MEET/./..
	db	#03,#4F,#54,#54,#4F,#4D,#45,#4E,#2F,#8F,#2F,#80		; @3E50 034F54544F4D454E2F8F2F80  .OTTOMEN/./.

;	0x0396, "@ADDITIONAL@@@@AT@@@000@]^_", 	0x2f, 0x95, 0x2f, 0x80,		; @3D00
;	P   0x0396, "BONUS@PAC;MAN@FOR@@@000@]^_", 	0x2f, 0x8e, 0x2f, 0x80,		; @3D00
;	P   0x033a, "\@1980@MIDWAY@MFG%CO%", 		0x2f, 0x83, 0x2f, 0x80,		; @3D21
;	0x802f, "P@@@", 				0x2f, 0x87, 0x2f, 0x80,		; @3D32
;	0x025b, "\@MIDWAY@MFG@CO@@@@", 		0x2f, 0x81, 0x2f, 0x80,		; @3D3C
;	P   0x033d, "\@1980@MIDWAY@MFG%CO%", 		0x2f, 0x83, 0x2f, 0x80,		; @3D3C

;	0x02c5, ";MAD@DOG@@", 	0x2f, 0x81, 0x2f, 0x80,		; @3D57
;	P   0x02c5, ";SHADOW@@@", 	0x2f, 0x81, 0x2f, 0x80,		; @3D57
;	0x026e, "@@@BLINKY", 		0x2f, 0x81, 0x2f, 0x80,		; @3D67
;	P   0x0165, "&BLINKY&@", 		0x2f, 0x81, 0x2f, 0x80,		; @3D67
;	0x02c8, ";KILLER@@@", 	0x2f, 0x83, 0x2f, 0x80,		; @3D76
;	P   0x02c8, ";SPEEDY@@@", 	0x2f, 0x83, 0x2f, 0x80,		; @3D76
;	0x026e, "@@@PINKY@", 		0x2f, 0x83, 0x2f, 0x80,		; @3D86
;	P   0x0168, "&PINKY&@@", 		0x2f, 0x83, 0x2f, 0x80,		; @3D86
;	0x026e, "MS@PAC;MAN", 	0x2f, 0x89, 0x2f, 0x80,		; @3D95
;	P   0x02cb, ";BASHFUL@@", 	0x2f, 0x85, 0x2f, 0x80,		; @3D95
;	0x026e, "@@@INKY@@", 		0x2f, 0x85, 0x2f, 0x80,		; @3DA5
;	P   0x016b, "&INKY&@@@", 		0x2f, 0x85, 0x2f, 0x80,		; @3DA5
;	0x023d, "@@1980:1981@", 	0x2f, 0x81, 0x2f, 0x80,		; @3DB4
;	P   0x02ce, ";POKEY@@@@", 	0x2f, 0x87, 0x2f, 0x80,		; @3DB4
;	0x026e, "@@@@SUE", 		0x2f, 0x87, 0x2f, 0x80,		; @3DC6
;	P   0x016e, "&CLYDE&@@", 		0x2f, 0x87, 0x2f, 0x80,		; @3DC4
;	0x026b, "JUNIOR@@@@", 	0x2f, 0x8f, 0x2f, 0x80,		; @3DD3
;	P   0x02c5, ";AAAAAAAA;", 	0x2f, 0x81, 0x2f, 0x80,		; @3DD3
;	0x026b, "WITH@@@@@", 		0x2f, 0x8f, 0x2f, 0x80,		; @3DE3
;	P   0x0165, "&BBBBBBB&", 		0x2f, 0x81, 0x2f, 0x80,		; @3DE3
;	0x026b, "THE@CHASE@", 	0x2f, 0x8f, 0x2f, 0x80,		; @3DF2
;	P   0x02c8, ";CCCCCCCC;", 	0x2f, 0x83, 0x2f, 0x80,		; @3DF2
;	0x026b, "STARRING@", 		0x2f, 0x8f, 0x2f, 0x80,		; @3E02
;	P   0x0168, "&DDDDDDD&", 		0x2f, 0x83, 0x2f, 0x80,		; @3E02
;	0x030c, "MS@PAC;MEN", 	0x2f, 0x8f, 0x2f, 0x80,		; @3E11
;	P   0x02cb, ";EEEEEEEE;", 	0x2f, 0x85, 0x2f, 0x80,		; @3E11
;	0x026b, "@@@@@@@@@", 		0x2f, 0x85, 0x2f, 0x80,		; @3E21
;	P   0x016b, "&FFFFFFF&", 		0x2f, 0x85, 0x2f, 0x80,		; @3E21
;	0x026b, "ACT@III&@@", 	0x2f, 0x87, 0x2f, 0x80,		; @3E30
;	P   0x02ce, ";GGGGGGGG;", 	0x2f, 0x87, 0x2f, 0x80,		; @3E30
;	0x026b, "THEY@MEET", 		0x2f, 0x8f, 0x2f, 0x80,		; @3E40
;	P   0x016e, "&HHHHHHH&", 		0x2f, 0x87, 0x2f, 0x80,		; @3E40
;	0x030c, "OTTOMEN", 		0x2f, 0x8f, 0x2f, 0x80,		; @3E4F
;	P   0x030c, "PAC;MAN", 		0x2f, 0x8f, 0x2f, 0x80,		; @3E4F

	    ;; new code for ms-pacman.  used during demo mode, when there are no credits

j_3e5c:
	ld      a,(game_mode_sub1)		; @3E5C 3A024E  load A with main routine 1, subroutine #
	cp      #10		; @3E5F FE10  == #10 ?  #10 indicates that the maze demo is running, not the marquee
	call    nz,j_3ed0		; @3E61 C4D03E  no, call this sub.  it controls the flashing bulbs around the marquee
	ld      a,(game_mode_sub1)		; @3E64 3A024E  load A with main routine 1, subroutine #
	rst     #20		; @3E67 E7  jump based on A

	db	#5F,#04	; @3E68 5F04  #045F		; A == #00	; display "ms. Pac Man"
	db	#96,#3E	; @3E6A 963E  #3E96		; A == #01 	; draw the midway logo and copyright
	db	#8B,#3E	; @3E6C 8B3E  #3E8B		; A == #02	; display "Ms. Pac Man"
	db	#0C,#00	; @3E6E 0C00  #000C  	; A == #03	; returns immediately
	db	#BD,#3E	; @3E70 BD3E  #3EBD		; A == #04	; display "with"
	db	#9C,#3E	; @3E72 9C3E  #3E9C		; A == #05	; display "Blinky"
	db	#83,#34	; @3E74 8334  #3483		; A == #06	; move blinky across the marquee and up left side
	db	#A2,#3E	; @3E76 A23E  #3EA2		; A == #07	; clear "with" and display "Pinky"
	db	#88,#34	; @3E78 8834  #3488		; A == #08	; move pinky across the marquee and up left side
	db	#AB,#3E	; @3E7A AB3E  #3EAB		; A == #09	; display "Inky"
	db	#8D,#34	; @3E7C 8D34  #348D		; A == #0A	; move Inky across the marquee and up left side
	db	#B1,#3E	; @3E7E B13E  #3EB1		; A == #0B	; display "Sue"
	db	#92,#34	; @3E80 9234  #3492		; A == #0C	; move Sue across the marquee and up left side
	db	#C3,#3E	; @3E82 C33E  #3EC3		; A == #0D	; display "Starring"
	db	#B7,#3E	; @3E84 B73E  #3EB7		; A == #0E	; display "MS. Pac-Man"
	db	#97,#34	; @3E86 9734  #3497		; A == #0F	; move ms pacman across the marquee
	db	#C9,#3E	; @3E88 C93E  #3EC9		; A == #10	; start demo mode where ms. pac plays herself

; arrive here from #3E67 when sub# == 2

	; ;; gap-fill from golden boots $3E8A-$3E8A
	db	#C9		; @3E8A
	rst     #28		; @3E8B EF  insert task to display text "MS Pac Man"
	db	#1C,#0C	; @3E8C 1C0C

	ld      a,#60		; @3E8E 3E60  A := #60
	ld      (cpu_stack_base),a		; @3E90 32014F  store into stack ?
	jp      j_058e		; @3E93 C38E05  jumps back, increases sub # and returns

    ; draw the midway logo and cprt for the attract screen

	call    j_9642		; @3E96 CD4296  draws title screen logo and text
	jp      j_058e		; @3E99 C38E05

	rst     #28		; @3E9C EF  insert task to display text "Blinky"
	db	#1C,#0D	; @3E9D 1C0D
	jp      j_058e		; @3E9F C38E05

	rst     #28		; @3EA2 EF  insert task to display text "       " [clears "with"]
	db	#1C,#30	; @3EA3 1C30
;	rst     #28		; @3EA4 EF  insert task to display text "Pinky"
	; ;; gap-fill from golden boots $3EA5-$3EA5
	db	#EF		; @3EA5
	db	#1C,#0F	; @3EA6 1C0F
	jp      j_058e		; @3EA8 C38E05

	rst     #28		; @3EAB EF  insert task to display text "Inky"
	db	#1C,#2F	; @3EAC 1C2F
	jp      j_058e		; @3EAE C38E05

	rst     #28		; @3EB1 EF  insert task to display text "Sue"
	db	#1C,#31	; @3EB2 1C31
	jp      j_058e		; @3EB4 C38E05

	rst     #28		; @3EB7 EF  insert task to display text "Ms. Pac-Man"
	db	#1C,#33	; @3EB8 1C33
	jp      j_058e		; @3EBA C38E05

	rst     #28		; @3EBD EF  insert task to display text "with"
	db	#1C,#0E	; @3EBE 1C0E
;	jp      j_058e		; @3EBF C38E05

	; ;; gap-fill from golden boots $3EC0-$3EC2
	db	#C3,#8E,#05		; @3EC0
	rst     #28		; @3EC3 EF  insert task to display text "starring"
	db	#1C,#10	; @3EC4 1C10
	jp      j_058e		; @3EC6 C38E05

; demo mode when ms pac plays herself in the maze

	xor     a		; @3EC9 AF  A := #00
	ld      (lives_real),a		; @3ECA 32144E  store into number of lives
	jp      j_057c		; @3ECD C37C05  jump back

; this sub controls the flashing bulbs around the marquee in the attract screen

j_3ed0:
	ld      a,(cpu_stack_base)		; @3ED0 3A014F  load A with counter
	inc     a		; @3ED3 3C  increase
	and     #0f		; @3ED4 E60F  mask bits, now between #00 and #0F
	ld      (cpu_stack_base),a		; @3ED6 32014F  store result
	ld      c,a		; @3ED9 4F  copy to C
	res     0,c		; @3EDA CB81  reset bit #0 on C
	ld      b,#00		; @3EDC 0600  B:= #00
	ld      ix,#3f81		; @3EDE DD21813F  load IX with start of table data
	bit     0,a		; @3EE2 CB47  test bit 0 of A
	jr      z,j_3f19		; @3EE4 2833  if zero then jump ahead to do other part of routine
	add     ix,bc		; @3EE6 DD09  add counter to index of table data
	ld      l,(ix+#00)		; @3EE8 DD6E00
	ld      h,(ix+#01)		; @3EEB DD6601
	ld      (hl),#87		; @3EEE 3687  moves white spot by one
	ld      l,(ix+#10)		; @3EF0 DD6E10
	ld      h,(ix+#11)		; @3EF3 DD6611
	ld      (hl),#87		; @3EF6 3687  moves white spot by one
	ld      l,(ix+#20)		; @3EF8 DD6E20
	ld      h,(ix+#21)		; @3EFB DD6621
	ld      (hl),#8a		; @3EFE 368A  moves white spot by one	
	ld      l,(ix+#30)		; @3F00 DD6E30
	ld      h,(ix+#31)		; @3F03 DD6631
	ld      (hl),#81		; @3F06 3681  moves white spot by one
	ld      l,(ix+#40)		; @3F08 DD6E40
	ld      h,(ix+#41)		; @3F0B DD6641
	ld      (hl),#81		; @3F0E 3681  moves white spot by one
	ld      l,(ix+#50)		; @3F10 DD6E50
	ld      h,(ix+#51)		; @3F13 DD6651
	ld      (hl),#84		; @3F16 3684  moves white spot by one
	ret		; @3F18 C9  return

j_3f19:
	dec     c		; @3F19 0D  decrement C
	xor     a		; @3F1A AF  A := #00
	cp      c		; @3F1B B9  compare
	jp      m,j_3f21		; @3F1C FA213F  if negative, skip next step
	ld      b,#FF		; @3F1F 06FF  load B with FF
j_3f21:
	dec     c		; @3F21 0D  decrement C
	add     ix,bc		; @3F22 DD09  add to index of table data
	ld      l,(ix+#00)		; @3F24 DD6E00
	ld      h,(ix+#01)		; @3F27 DD6601
	dec     (hl)		; @3F2A 35  color marquee spot red
	ld      l,(ix+#02)		; @3F2B DD6E02
	ld      h,(ix+#03)		; @3F2E DD6603
	ld      (hl),#88		; @3F31 3688  color next spot white
	ld      l,(ix+#10)		; @3F33 DD6E10
	ld      h,(ix+#11)		; @3F36 DD6611
	dec     (hl)		; @3F39 35  color marquee spot red
	ld      l,(ix+#12)		; @3F3A DD6E12
	ld      h,(ix+#13)		; @3F3D DD6613
	ld      (hl),#88		; @3F40 3688  color next spot white
	ld      l,(ix+#20)		; @3F42 DD6E20
	ld      h,(ix+#21)		; @3F45 DD6621
	dec     (hl)		; @3F48 35  color marquee spot red
	ld      l,(ix+#22)		; @3F49 DD6E22
	ld      h,(ix+#23)		; @3F4C DD6623
	ld      (hl),#8b		; @3F4F 368B  color next spot white
	ld      l,(ix+#30)		; @3F51 DD6E30
	ld      h,(ix+#31)		; @3F54 DD6631
	dec     (hl)		; @3F57 35  color marquee spot red
	ld      l,(ix+#32)		; @3F58 DD6E32
	ld      h,(ix+#33)		; @3F5B DD6633
	ld      (hl),#82		; @3F5E 3682  color next spot white
	ld      l,(ix+#40)		; @3F60 DD6E40
	ld      h,(ix+#41)		; @3F63 DD6641
	dec     (hl)		; @3F66 35  color marquee spot red
	ld      l,(ix+#42)		; @3F67 DD6E42
	ld      h,(ix+#43)		; @3F6A DD6643
	ld      (hl),#82		; @3F6D 3682  color next spot white
	ld      l,(ix+#50)		; @3F6F DD6E50
	ld      h,(ix+#51)		; @3F72 DD6651
	dec     (hl)		; @3F75 35  color marquee spot red
	ld      l,(ix+#52)		; @3F76 DD6E52
	ld      h,(ix+#53)		; @3F79 DD6653
	ld      (hl),#83		; @3F7C 3683  BUG.  Spot stays red.  SHOULD BE #85, not #83, to color spot white

; BUGFIX04 - Marquee left side animation fix - Don Hodges
;	db	#36,#85	; @3F7C 3685


	ret		; @3F7E C9  return
	ret     nc		; @3F7F D0  junk

; data Used above in #3EDE, for the flashing marquee

	db	#42,#B0,#42,#90,#42,#70,#42,#50,#42,#30,#42,#10,#42,#F0,#41,#D0	; @3F80 42B04290427042504230421042F041D0
	db	#41,#B0,#41,#90,#41,#70,#41,#50,#41,#30,#41,#10,#41,#F0,#40,#D0	; @3F90 41B04190417041504130411041F040D0
	db	#40,#B0,#40,#AF,#40,#AE,#40,#AD,#40,#AC,#40,#AB,#40,#AA,#40,#A9	; @3FA0 40B040AF40AE40AD40AC40AB40AA40A9
	db	#40,#C9,#40,#E9,#40,#09,#41,#29,#41,#49,#41,#69,#41,#89,#41,#A9	; @3FB0 40C940E94009412941494169418941A9
	db	#41,#C9,#41,#E9,#41,#09,#42,#29,#42,#49,#42,#69,#42,#89,#42,#A9	; @3FC0 41C941E94109422942494269428942A9
	db	#42,#C9,#42,#CA,#42,#CB,#42,#CC,#42,#CD,#42,#CE,#42,#CF,#42,#D0	; @3FD0 42C942CA42CB42CC42CD42CE42CF42D0
	db	#42	; @3FE0 42

; unused ?

	db	#C9,#42,#CA,#42,#CB,#42,#CC,#42,#CD,#42,#CE,#42,#CF,#42,#D0	; @3FE1 C942CA42CB42CC42CD42CE42CF42D0
	db	#42,#42,#CF,#42,#D0,#42,#00,#4F,#C9,#00	; @3FF0 4242CF42D042004FC900

	db	#00,#30	; @3FFA 0030  #3000 is an interrupt vector (pac-man only, referenced at #233B in pac-man code)
	db	#8D,#00	; @3FFC 8D00  #008D is an interrupt vector.  Referenced at #3183
	db	#75,#73	; @3FFE 7573  checksum bytes for #3000-#3FFF



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; 8000 through 8800:  U5 on the aux board
;;
;; 8000 through 8200:  U5 on the aux board 
;; 8 byte chunks from here are overlayed down into the pac-man roms
;;

;!    GLOBAL ATTRACT,CALCADR,MAZENUM
;!    GLOBAL DOFRUIT,EATFRUIT,MAXFRUIT,PROMPTHACKS
;!    GLOBAL WALLADR,DOTSA1,DOTSA2,MOREDOTS
;!    GLOBAL DRAWEN,READEN,FLASHEN
;!    GLOBAL RCORNER,R1CORNER,R2CORNER,SCOLOR,RCOLOR,SLOWMAP
;!    GLOBAL ENTRY1,ENTRY2,ENTRY3
;!    GLOBAL FRUITPNTS
;!    GLOBAL CHOOSETUNE,MELODIES,HARMONIES,AUXILIARY

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


; - OVERLAY - 0x2418


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Pad through 4000-7FFF (RAM/IO hole), then aux/high ROM
	ds	#8000 - $
	org	#8000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	ret		; @8000 C9
	ld      hl,#4000		; @8001 210040
	call    j_946a		; @8004 CD6A94
	ld      a,(bc)		; @8007 0A


; sil attack uses: 
;  (there is a second rom with changes, but i can't find how it overlaps.
; 8000  42        ld      b,d
; 8001  ef        rst     #28
; 8002  00 ff     
; 8004  00        nop     
; 8005  ff        rst     #38
; 8006  01ef--    ld      bc,#--ef

; - OVERLAY - 0x0410

	ld      c,(hl)		; @8008 4E
	inc     (hl)		; @8009 34
	ret		; @800A C9
	jp      j_3e5c		; @800B C35C3E
	rst     #20		; @800E E7
	ld      e,a		; @800F 5F

; - OVERLAY - 0x1008

;	--d24d    ld      (fruit_pos_lo),hl		; @8010
	; ;; gap-fill from golden boots $8010-$8011
	db	#D2,#4D		; @8010
	ret		; @8012 C9
	jp      j_3678		; @8013 C37836
	db	#3A,#00	; @8016 3A00

; - OVERLAY - 0x2108

	jp      j_3435		; @8018 C33534
	rst     #20		; @801B E7
	ld      a,(de)		; @801C 1A
	ld      hl,#2140		; @801D 214021

; - OVERLAY - 0x1000

	xor     a		; @8020 AF
	ld      (fruit_points),a		; @8021 32D44D
	ret		; @8024 C9
	nop		; @8025 00
	nop		; @8026 00
;	----    ld      ----		; @8027 22

; - OVERLAY - 0x2800

	; ;; gap-fill from golden boots $8027-$8027
	db	#22		; @8027
	ld      hl,(orange_tile_y)		; @8028 2A104D
	call    j_955e		; @802B CD5E95
;	1140--    ld      de,#--40		; @802E

; - unused -

	; ;; gap-fill from golden boots $802E-$802F
	db	#11,#40		; @802E
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8030 FFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8038 FFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8040 FFFFFFFFFFFFFFFF

; - OVERLAY - 0x3148

;	----4e    ld hl,CH3_E_NUM		; @8048
	; ;; gap-fill from golden boots $8048-$8048
	db	#4E		; @8048
	ld      (hl),#00		; @8049 3600
	ld      a,#3e		; @804B 3E3E
	ld      de,#0159		; @804D 115901

; - OVERLAY - 0x2748

	ld      a,(red_dir)		; @8050 3A2C4D
	call    j_9561		; @8053 CD6195
;	cd66--    call    #--66		; @8056

; - OVERLAY - 0x2448

	; ;; gap-fill from golden boots $8056-$8057
	db	#CD,#66		; @8056
	ld      hl,#4000		; @8058 210040
	jp      j_947c		; @805B C37C94
	ld      c,(hl)		; @805E 4E
	db	#FD	; @805F FD

; - unused -

	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8060 FFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8068 FFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8070 FFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8078 FFFFFFFFFFFFFFFF

; - OVERLAY - 0x2488

;	--0040    ld      hl,#4000		; @8080
	; ;; gap-fill from golden boots $8080-$8081
	db	#00,#40		; @8080
	jp      j_9481		; @8082 C38194
	ld      c,(hl)		; @8085 4E
	db	#FD,#21	; @8086 FD21

; - OVERLAY - 0x1688

;	--360d1e  ld      (ix+#0d),#1e		; @8088
	; ;; gap-fill from golden boots $8088-$8089
	db	#36,#0D,#1E,#C9		; @8088 360D1EC9  overlay stub (listing: ld (ix+#0d),#1e / ret)
;	ret		; @808A C9
	; ;; gap-fill from golden boots $808B-$808B
;	db	#C9		; @808B
	jp      j_869c		; @808C C39C86
	ret		; @808F C9

; - OVERLAY - 0x274a

;	----4d    ld      a,(red_dir)		; @2748
	; ;; gap-fill from golden boots $8090-$8090
	db	#4D		; @8090
	call    j_9561		; @8091 CD6195
	call    j_2966		; @8094 CD6629
;	---	ld      ...		; @8097 22

; - OVERLAY - 0x1288

	; ;; gap-fill from golden boots $8097-$8097
	db	#22		; @8097
	ld      (killed_ghost_anim),a		; @8098 32D14D
	ld hl,CH2_E_NUM		; @809B 21AC4E
	set  6,(hl)		; @809E CBF6

; - OVERLAY - 0x2298

;	--084e    ld      a,(cutscene3_state)		; @80A0
	; ;; gap-fill from golden boots $80A0-$80A1
	db	#08,#4E		; @80A0
	jp      j_3469		; @80A2 C36934
	cp      (hl)		; @80A5 BE
;	ld	...		; @80A6 220C

; - OVERLAY - 0x19a8

;	--084d    ld      hl,(pac_y)		; @80A8
	; ;; gap-fill from golden boots $80A6-$80A9
	db	#22,#0C,#08,#4D		; @80A6
	ld      de,#8094		; @80AA 119480
	jp      j_8818		; @80AD C31888

; - unused

	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @80B0 FFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @80B8 FFFFFFFFFFFFFFFF

; - OVERLAY - 0x24d8

	ld      a,b		; @80C0 78
	cp      #02		; @80C1 FE02
	ld      a,#1f		; @80C3 3E1F
	jp      j_9580		; @80C5 C38095

; - OVERLAY - 0x16d8

;	----4d    ld      a,(pac_x)		; @80C8
	; ;; gap-fill from golden boots $80C8-$80C8
	db	#4D		; @80C8
	jp      j_86c5		; @80C9 C3C586
	db	#C9,#38,#08,#1E,#D2		; @80CC C938081ED2  overlay stub
;	jr      c, +#08		; @80CD 3808
;	--      ld      e,#--		; @80CF 1E

; - OVERLAY - 0x2bc0

;	--d2      jr      #2c93		; @80D0
	; ;; gap-fill from golden boots $80CF-$80D0
;	db	#1E,#D2		; @80CF
	jp      j_9797		; @80D1 C39797
	ld ix,CH1_W_NUM		; @80D4 DD21CC4E

; - OVERLAY - 0x0bd0

;	----0907  ld      (ix+#09),#07		; @80D8
	; ;; gap-fill from golden boots $80D8-$80D9
	db	#09,#07		; @80D8
	dec     (iy+#00)		; @80DA FD3500
	ret		; @80DD C9
	ld      b,#19		; @80DE 0619

; - OVERLAY - 0x2cd8

;	--914e    ld      (CH1_VOL),a		; @80E0
	; ;; gap-fill from golden boots $80E0-$80E1
	db	#91,#4E		; @80E0
	ld hl,SONG_TABLE_2		; @80E2 217D96
;	dd21dc--  ld      ix,#E3DC		; @80E5

; - OVERLAY - 0x23e0

;	----e3    jp      pe,e32b		; @80E5
	; ;; gap-fill from golden boots $80E5-$80E8
	db	#DD,#21,#DC,#E3		; @80E5
	sub     l		; @80E9 95
	and     c		; @80EA A1
	dec     hl		; @80EB 2B
	ld      (hl),l		; @80EC 75
	ld      h,#B2		; @80ED 26B2
;	--      ld      h,#--		; @80EF 26

; - unused -
	; ;; gap-fill from golden boots $80EF-$80EF
	db	#26		; @80EF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @80F0 FFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @80F8 FFFFFFFFFFFFFFFF

; - OVERLAY - 0x2b20  (scoring table)
;	--08		; @8100
	; ;; gap-fill from golden boots $8100-$8100
	db	#08		; @8100
	db	#00,#16	; @8101 0016
	db	#00,#01	; @8103 0001
	db	#00,#02	; @8105 0002
;	--		; @8107 00

; - unused -
	; ;; gap-fill from golden boots $8107-$8107
	db	#00		; @8107
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8108 FFFFFFFFFFFFFFFF

; - OVERLAY - 0x2B30 (scoring table)

	ld      d,b		; @8110 50
	nop		; @8111 00
	ld      d,b		; @8112 50
	inc     de		; @8113 13
	ld      l,e		; @8114 6B
	ld      h,d		; @8115 62
	dec     de		; @8116 1B
;	--		; @8117 CB

; - OVERLAY - 0x0a30

	; ;; gap-fill from golden boots $8117-$8117
	db	#CB		; @8117
	ld      (CH3_E_NUM),a		; @8118 32BC4E
;	jr      #.+06		; @811B 1806
	; ;; gap-fill from golden boots $811B-$811C
	db	#18,#06		; @811B
	ld      (CH1_W_NUM),a		; @811D 32CC4E

; - OVERLAY - 0x0c20

;	----44    ld      hl,#4464		; @8120
	; ;; gap-fill from golden boots $8120-$8120
	db	#44		; @8120
	jp      j_9524		; @8121 C32495
;	jr      nz,#.+02		; @8124 2002
	; ;; gap-fill from golden boots $8124-$8125
	db	#20,#02		; @8124
	ld      a,#00		; @8126 3E00

; - unused -

	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8128 FFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8130 FFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8138 FFFFFFFFFFFFFFFF

; - OVERLAY - 0x2470

;	--344e    ld hl,power_pill_data		; @8140
	; ;; gap-fill from golden boots $8140-$8141
	db	#34,#4E		; @8140
	jp      j_94ec		; @8142 C3EC94
	ldi		; @8145 EDA0
;	----    ld      de,#6fc3		; @8147 11

; - OVERLAY - 0x2060

	; ;; gap-fill from golden boots $8147-$8147
	db	#11		; @8147
	jp      j_366f		; @8148 C36F36
;	nop		; @2063 00
	; ;; gap-fill from golden boots $814B-$814B
	db	#00		; @814B
	ld      (bc),a		; @814C 02
	ret		; @814D C9
	xor     a		; @814E AF
	ld      (bc),a		; @814F 02

; - unused - 

	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8150 FFFFFFFFFFFFFFFF
	; ;; gap-fill from golden boots $8158-$8158
	db	#FF		; @8158
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#73		; @8159 FFFFFFFFFFFFFFFF

; - OVERLAY - 0x2d60

;	--7302    ld      (ix+#02),e		; @8160
	; ;; gap-fill from golden boots $8161-$8161
	db	#02		; @8161
	jp      j_364e		; @8162 C34E36
	inc     c		; @8165 0C
;	dd35--    dec     (ix-#59)		; @8166

; - OVERLAY - 0x0e58

	; ;; gap-fill from golden boots $8166-$8167
	db	#DD,#35		; @8166
	and     a		; @8168 A7
	sbc     hl,de		; @8169 ED52
	ret     nz		; @816B C0
	xor     a		; @816C AF
	nop		; @816D 00
	inc     a		; @816E 3C
;	----    ld      (ffff),a		; @816F 32

; - unused -

	; ;; gap-fill from golden boots $816F-$816F
	db	#32		; @816F
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8170 FFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8178 FFFFFFFFFFFFFFFF

; - OVERLAY - 0x24b0

;	--e5      jr      nz,#2496		; @8180  (-27)
	; ;; gap-fill from golden boots $8180-$8180
	db	#E5		; @8180
	ld      hl,#4064		; @8181 216440
	jp      j_9504		; @8184 C30495
;	--      ldi		; @8187 ED

; - OVERLAY - 0x16b0

	db	#ED		; @8187 ED  ldi (overlay stub; listing mangled)
	ret		; @8188 C9
	; ;; gap-fill from golden boots $8188-$8188
;	db	#C9		; @8188
	jp      j_86b1		; @8189 C3B186
	ret		; @818C C9
	rlca		; @818D 07
	cp      #06		; @818E FE06

; - OVERLAY - 0x27b8

	ld      hl,(blue_tile_y)		; @8190 2A0E4D
	call    j_9559		; @8193 CD5995
;	1140--    ld      de,#--40		; @8196

; - OVERLAY - 0x0ea8

	; ;; gap-fill from golden boots $8196-$8197
	db	#11,#40		; @8196
	and     (hl)		; @8198 A6
	set     0,a		; @8199 CBC7
	ld      (hl),a		; @819B 77
	ret		; @819C C9
	jp      j_86ee		; @819D C3EE86

; - OVERLAY - 0x21a0

;	----4e    ld      a,(cutscene2_state)		; @81A0
	; ;; gap-fill from golden boots $81A0-$81A0
	db	#4E		; @81A0
	jp      j_344f		; @81A1 C34F34
	ld      b,c		; @81A4 41
	rst     #20		; @81A5 E7
;	c221--    jp      nz,#--21		; @81A6

; - OVERLAY - 0x19b8

	; ;; gap-fill from golden boots $81A6-$81A7
	db	#C2,#21		; @81A6
	call    j_1000		; @81A8 CD0010
	db	#18,#07		; @81AB 1807  jr $+9 (was jr j_19c4; out of JR range)
	inc     e		; @81AD 1C
;	cd42--    call    #0042		; @81AE

; - unused -

	; ;; gap-fill from golden boots $81AE-$81AF
	db	#CD,#42		; @81AE
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @81B0 FFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @81B8 FFFFFFFFFFFFFFFF

; - OVERLAY - 0x24f8

;	--1a      ld      a,#1a		; @81C0
	; ;; gap-fill from golden boots $81C0-$81C0
	db	#1A		; @81C0
	jp      j_95c3		; @81C1 C3C395
	ld      b,#06		; @81C4 0606
;	dd21----  ld ix,pac_y		; @81C6

; - OVERLAY - 0x16f8

;	--084d    ld      a,(pac_y)		; @81C6
	; ;; gap-fill from golden boots $81C6-$81C9
	db	#DD,#21,#08,#4D		; @81C6
	jp      j_86d9		; @81CA C3D986
	ret		; @81CD C9
;	jr      c,#.+5		; @81CE 3805

; - OVERLAY - 0x2bf0

	; ;; gap-fill from golden boots $81CE-$81CF
	db	#38,#05		; @81CE
	ld      a,(level_number)		; @81D0 3A134E
	inc     a		; @81D3 3C
	jp      j_8793		; @81D4 C39387
;	--      ld      l,#4e		; @81D7 2E  junk

; - OVERLAY - 0x08e0

;	----4e    ld      a,(dots_eaten)		; @81D8
	; ;; gap-fill from golden boots $81D7-$81D8
	db	#2E,#4E		; @81D7
	jp      j_94a1		; @81D9 C3A194
	nop		; @81DC 00
	ld hl,level_state		; @81DD 21044E

; - OVERLAY - 0x2cf0

	ld      (CH2_VOL),a		; @81E0 32964E
	ld hl,SONG_TABLE_3		; @81E3 218D96
;	dd21----  ld      ix,#FFFF		; @81E6

; - unused -

	; ;; gap-fill from golden boots $81E6-$81E7
	db	#DD,#21		; @81E6
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @81E8 FFFFFFFFFFFFFFFF

; lookup table.  used in #361F for sprite movement
; these contain pointers to the step program/codes to be run

	db	#51,#82	; @81F0 5182  #8251		; 1st intermission
	db	#A3,#82	; @81F2 A382  #82A3
	db	#12,#83	; @81F4 1283  #8312
	db	#4C,#83	; @81F6 4C83  #834C
	db	#69,#85	; @81F8 6985  #8569
	db	#7C,#85	; @81FA 7C85  #857C

	db	#95,#83	; @81FC 9583  #8395		; 2nd intermission
	db	#F0,#83	; @81FE F083  #83F0
	db	#2B,#85	; @8200 2B85  #852B
	db	#4A,#85	; @8202 4A85  #854A
	db	#69,#85	; @8204 6985  #8569
	db	#7C,#85	; @8206 7C85  #857C

	db	#51,#84	; @8208 5184  #8451		; 3rd intermission
	db	#6D,#84	; @820A 6D84  #846D
	db	#CF,#84	; @820C CF84  #84CF
	db	#FD,#84	; @820E FD84  #84FD
	db	#89,#84	; @8210 8984  #8489
	db	#7C,#85	; @8212 7C85  #857C

	db	#94,#85	; @8214 9485  #8594		; attract mode 1st ghost
	db	#50,#82	; @8216 5082  #8250
	db	#50,#82	; @8218 5082  #8250
	db	#50,#82	; @821A 5082  #8250
	db	#50,#82	; @821C 5082  #8250
	db	#50,#82	; @821E 5082  #8250

	db	#50,#82	; @8220 5082  #8250		; attract mode 2nd ghost
	db	#B0,#85	; @8222 B085  #85B0
	db	#50,#82	; @8224 5082  #8250
	db	#50,#82	; @8226 5082  #8250
	db	#50,#82	; @8228 5082  #8250
	db	#50,#82	; @822A 5082  #8250

	db	#50,#82	; @822C 5082  #8250		; attract mode 3rd ghost
	db	#50,#82	; @822E 5082  #8250
	db	#CC,#85	; @8230 CC85  #85CC
	db	#50,#82	; @8232 5082  #8250
	db	#50,#82	; @8234 5082  #8250
	db	#50,#82	; @8236 5082  #8250

	db	#50,#82	; @8238 5082  #8250		; attract mode 4th ghost
	db	#50,#82	; @823A 5082  #8250
	db	#50,#82	; @823C 5082  #8250
	db	#E8,#85	; @823E E885  #85E8
	db	#50,#82	; @8240 5082  #8250
	db	#50,#82	; @8242 5082  #8250

	db	#50,#82	; @8244 5082  #8250		; attract mode ms pac man
	db	#50,#82	; @8246 5082  #8250
	db	#50,#82	; @8248 5082  #8250
	db	#50,#82	; @824A 5082  #8250
	db	#04,#86	; @824C 0486  #8604
	db	#50,#82	; @824E 5082  #8250

	db	#FF	; @8250 FF  no data


; commands: (functionality TBD)
;	cmd	    opc 	bytes	param fcn	opc fcn
;	LOOP      =  F0	; 	3	?		repeat this N times, perhaps?
;							A B (color)
;	SETPOS	  =  F1	; 	2	position?	
;	SETN  	  =  F2	; 	1	value		store for other ops
;	SETCHAR   =  F3	; 	2	table ptr	switch to the specified sprite code table?
;	-         =  F4
;	PLAYSOUND =  F5	;	1	sound code	play a sound (eg 10=ghost bump)
;	PAUSE     =  F6	;	-	-		pause for N ticks?
;	SHOWACT   =  F7	;	
;	CLEARACT  =  F8	; 	-	-		clear the act # from the screen
;	END       =  FF

; this appears to work like,  (guesses here)
;	setchar ADDR	to select the caracter array to work with
;	setpos X Y	moves the sprite to that location instantly
;	loop A B C	moves the sprite to a,b, while using color C
;			for previous SETN units/speed
;	PAUSE		wait for SETN units/time
	

; data for 1st intermission, part 1

	db	#F1,#00,#00	; @8251 F10000  SETPOS	00 00	
; set character set 8675 (act sign)
	db	#F3,#75,#86	; @8254 F37586  SETCHAR	#8675	; ACT sign
	db	#F2,#01	; @8257 F201  SETN		01
	db	#F0,#00,#00	; @8259 F00000  LOOP		00 00
	; ;; gap-fill from golden boots $825C-$825C
	db	#16		; @825C
	db	#F1,#BD,#52	; @825D F1BD52  SETPOS	BD 52
	db	#F2,#28	; @8260 F228  SETN		28
	db	#F6	; @8262 F6  PAUSE
	db	#F2,#16	; @8263 F216  SETN		16
	db	#F0,#00,#00,#16	; @8265 F0000016  LOOP		00 00 16
	;       ^^ color 16 (white)
	db	#F2,#16	; @8269 F216  SETN		16
	db	#F6	; @826B F6  PAUSE
	db	#F1,#FF,#54	; @826C F1FF54  SETPOS	FF 54

	db	#F3,#14,#86	; @826F F31486  SETCHAR	#8614	  ; otto
	db	#F2,#7F	; @8272 F27F  SETN		7F
	db	#F0,#F0,#00,#09	; @8274 F0F00009  LOOP		F0 00 09  ; otto
	;       ^^ color 9 (yellow otto)
	db	#F2,#7F	; @8278 F27F  SETN		7F
	db	#F0,#F0,#00,#09	; @827A F0F00009  LOOP		F0 00 09  ; otto
	db	#F1,#00,#7F	; @827E F1007F  SETPOS	00 7F

	db	#F3,#1D,#86	; @8281 F31D86  SETCHAR	#861D	  ; otto to center
	db	#F2,#75	; @8284 F275  SETN		75
	db	#F0,#10,#00,#09	; @8286 F0100009  LOOP		10 00 09
	db	#F2,#04	; @828A F204  SETN		04
	db	#F0,#10,#F0,#09	; @828C F010F009  LOOP		10 F0 09
	db	#F3,#26,#86	; @8290 F32686  SETCHAR	#8626
	db	#F2,#30	; @8293 F230  SETN		30
	db	#F0,#00,#F0,#09	; @8295 F000F009  LOOP		00 F0 09
	db	#F3,#1D,#86	; @8299 F31D86  SETCHAR	#861D
	db	#F2,#10	; @829C F210  SETN		10
	db	#F0,#00,#00,#09	; @829E F0000009  LOOP		00 00 09
	db	#FF	; @82A2 FF  END 

; data for 1st intermission, part 2

	db	#F1,#00,#00	; @82A3 F10000
	db	#F3,#7F,#86	; @82A6 F37F86  #867F
	db	#F2,#01	; @82A9 F201
	db	#F0,#00,#00,#16	; @82AB F0000016  ACT sign
	db	#F1,#AD,#52	; @82AF F1AD52
	db	#F2,#28	; @82B2 F228
	db	#F6	; @82B4 F6
	db	#F2,#16	; @82B5 F216
	db	#F0,#00,#00,#16	; @82B7 F0000016  ACT sign
	db	#F2,#16	; @82BB F216
	db	#F6	; @82BD F6
	db	#F1,#FF,#54	; @82BE F1FF54
	db	#F3,#5C,#86	; @82C1 F35C86  #865C
	db	#F2,#2F	; @82C4 F22F
	db	#F6	; @82C6 F6
	db	#F2,#70	; @82C7 F270
	db	#F0,#EF,#00,#05	; @82C9 F0EF0005  cyan ghost
	db	#F2,#74	; @82CD F274
	db	#F0,#EC,#00,#05	; @82CF F0EC0005  cyan ghost
	db	#F1,#00,#7F	; @82D3 F1007F
	db	#F3,#63,#86	; @82D6 F36386  #8663
	db	#F2,#1C	; @82D9 F21C
	db	#F6	; @82DB F6
	db	#F2,#58	; @82DC F258
	db	#F0,#16,#00,#05	; @82DE F0160005
	db	#F5,#10	; @82E2 F510  sound for ghost bump
	db	#F2,#06	; @82E4 F206
	db	#F0,#F8,#F8,#05	; @82E6 F0F8F805
	db	#F2,#06	; @82EA F206
	db	#F0,#F8,#08,#05	; @82EC F0F80805
	db	#F2,#06	; @82F0 F206
	db	#F0,#F8,#F8,#05	; @82F2 F0F8F805
	db	#F2,#06	; @82F6 F206
	db	#F0,#F8,#08,#05	; @82F8 F0F80805
	db	#F1,#00,#00	; @82FC F10000
	db	#F3,#73,#86	; @82FF F37386  #8673
	db	#F2,#01	; @8302 F201
	db	#F0,#00,#00,#03	; @8304 F0000003
	db	#F1,#7F,#3A	; @8308 F17F3A
	db	#F2,#40	; @830B F240
	db	#F0,#00,#00,#03	; @830D F0000003
	db	#FF	; @8311 FF  end code

; data for 1st intermission, part 3

	db	#F2,#5A	; @8312 F25A
	db	#F6	; @8314 F6
	db	#F1,#00,#A4	; @8315 F100A4
	db	#F3,#41,#86	; @8318 F34186  #8641	 left anna
	db	#F2,#7F	; @831B F27F
	db	#F0,#10,#00,#09	; @831D F0100009
	db	#F2,#7F	; @8321 F27F
	db	#F0,#10,#00,#09	; @8323 F0100009
	db	#F1,#FF,#7F	; @8327 F1FF7F
	db	#F3,#38,#86	; @832A F33886  #8638	; right anna
	db	#F2,#76	; @832D F276
	db	#F0,#F0,#00,#09	; @832F F0F00009
	db	#F2,#04	; @8333 F204
	db	#F0,#F0,#F0,#09	; @8335 F0F0F009
	db	#F3,#4A,#86	; @8339 F34A86  #864a ; up anna (?)
	db	#F2,#30	; @833C F230
	db	#F0,#00,#F0,#09	; @833E F000F009
	db	#F3,#38,#86	; @8342 F33886  #8638	; stopped anna
	db	#F2,#10	; @8345 F210
	db	#F0,#00,#00,#09	; @8347 F0000009
	db	#FF	; @834B FF  end code

; data for 1st intermission, part 4

	db	#F2,#5F	; @834C F25F
	db	#F6	; @834E F6
	db	#F1,#01,#A4	; @834F F101A4
	db	#F3,#63,#86	; @8352 F36386  #8663
	db	#F2,#2F	; @8355 F22F
	db	#F6	; @8357 F6
	db	#F2,#70	; @8358 F270
	db	#F0,#11,#00,#03	; @835A F0110003
	db	#F2,#74	; @835E F274
	db	#F0,#14,#00,#03	; @8360 F0140003
	db	#F1,#FF,#7F	; @8364 F1FF7F
	db	#F3,#5C,#86	; @8367 F35C86  #865C
	db	#F2,#1C	; @836A F21C
	db	#F6	; @836C F6
	db	#F2,#58	; @836D F258
	db	#F0,#EA,#00,#03	; @836F F0EA0003
	db	#F2,#06	; @8373 F206
	db	#F0,#08,#F8,#03	; @8375 F008F803
	db	#F2,#06	; @8379 F206
	db	#F0,#08,#08,#03	; @837B F0080803
	db	#F2,#06	; @837F F206
	db	#F0,#08,#F8,#03	; @8381 F008F803
	db	#F2,#06	; @8385 F206
	db	#F0,#08,#08,#03	; @8387 F0080803
	db	#F3,#71,#86	; @838B F37186  #8671
	db	#F2,#10	; @838E F210
	db	#F0,#00,#00,#16	; @8390 F0000016
	db	#FF	; @8394 FF  end code


; CODE from CRAZY OTTO actual source: (Rosetta Stone) (tidied up)
; 2nd intermission data, part 1
/*
;!    BYTE SETPOS,   0FFH,34H
;!    BYTE SETCHAR
;!    WORD           RIGHT_OTTO
;!    BYTE SETN,     7FH,PAUSE
;!    BYTE SETN,     24H,PAUSE
;!    BYTE SETN,     68H,LOOP,0D8H,00,09
;!    BYTE SETN,     7FH,PAUSE
;!    BYTE SETN,     18H,PAUSE
;!    BYTE SETPOS,   00H,094H
;!    BYTE SETCHAR
;!    WORD           LEFT_ANNA
;!    BYTE SETN,     68H,LOOP,028H,00,09
;!    BYTE SETN,     7FH,PAUSE
;!    BYTE SETPOS,   0FCH,7FH
;!    BYTE SETCHAR
;!    WORD           RIGHT_OTTO
;!    BYTE SETN,     18H,PAUSE
;!    BYTE SETN,     68H,LOOP,0D8H,0,09
;!    BYTE SETN,     7FH,PAUSE
;!    BYTE SETN,     18H,PAUSE
;!    BYTE SETPOS,   00H,054H
;!    BYTE SETCHAR
;!    WORD           LEFT_ANNA
;!    BYTE SETN,     20H,LOOP,070H,00,09
;!    BYTE SETPOS,   0FFH,0B4H
;!    BYTE SETCHAR
;!    WORD           RIGHT_OTTO
;!    BYTE SETN,     10H,PAUSE
*/


; commands: (functionality TBD)
;	cmd	    opc 	bytes	param fcn	opc fcn
;	LOOP      =  F0	; 	3	?		repeat this N times, perhaps?
;	SETPOS	  =  F1	; 	2	position?	TBD
;	SETN  	  =  F2	; 	1	value		TBD
;	SETCHAR   =  F3	; 	2	table ptr	switch to the specified sprite code table?
;	-         =  F4
;	PLAYSOUND =  F5	;	1	sound code	play a sound (eg 10=ghost bump)
;	PAUSE     =  F6	;	-	-		pause for N ticks?
;	SHOWACT   =  F7	;	
;	CLEARACT  =  F8	; 	-	-		clear the act # from the screen
;	END       =  FF
	
; 2nd intermission data, part 1
;  NOTE: this is the segment that had the above source code published.
;	 That was a rosetta stone for figuring out the animation code system
;	 (work in progress)

	; this is for the pac being chased (red anna)
	db	#F2,#5A	; @8395 F25A  SETN( 5A )
	db	#F6	; @8397 F6  PAUSE
	db	#F1,#FF,#34	; @8398 F1FF34  SETPOS, FF, 34
	db	#F3,#14,#86	; @839B F31486  SETCHAR ( RIGHT_OTTO )  (sprite codes)
	db	#F2,#7F	; @839E F27F  SETN( 7f )
	db	#F6	; @83A0 F6  PAUSE
	db	#F2,#24	; @83A1 F224  SETN( 24 )
	db	#F6	; @83A3 F6  PAUSE
	db	#F2,#68	; @83A4 F268  SETN( 60 )
	db	#F0,#D8,#00,#09	; @83A6 F0D80009  LOOP( d8, 00 09 )
	db	#F2,#7F	; @83AA F27F  SETN( 7f )
	db	#F6	; @83AC F6  PAUSE

	db	#F2,#18	; @83AD F218  SETN( 18 )
	db	#F6	; @83AF F6  PAUSE

	db	#F1,#00,#94	; @83B0 F10094  SETCHAR( LEFT_ANNA )
	db	#F3,#41,#86	; @83B3 F34186  SETN( 
	db	#F2,#68	; @83B6 F268  SETN(
	db	#F0,#28,#00,#09	; @83B8 F0280009  LOOP( 28 00 09 )
	db	#F2,#7F	; @83BC F27F  SETN( 7f )
	db	#F6	; @83BE F6  PAUSE

	db	#F1,#FC,#7F	; @83BF F1FC7F  SETPOS( fc, 7f )
	db	#F3,#14,#86	; @83C2 F31486  SETCHAR( RIGHT_OTTO )
	db	#F2,#18	; @83C5 F218  SETN( 18 )
	db	#F6	; @83C7 F6  PAUSE
	db	#F2,#68	; @83C8 F268  SETN( 68 )
	db	#F0,#D8,#00,#09	; @83CA F0D80009  LOOP ( d8, 0, 09 )
	db	#F2,#7F	; @83CE F27F  SETN( 7f ) 
	db	#F6	; @83D0 F6  PAUSE
	db	#F2,#18	; @83D1 F218  SETN( 18 )
	db	#F6	; @83D3 F6  PAUSE
	db	#F1,#00,#54	; @83D4 F10054  SETPOS( 00 54 ) 
	db	#F3,#41,#86	; @83D7 F34186  SETCHAR( LEFT_ANNA )
	db	#F2,#20	; @83DA F220  SETN( 20 )
	db	#F0,#70,#00,#09	; @83DC F0700009  LOOP
	db	#F1,#FF,#B4	; @83E0 F1FFB4  SETPOS( ff, 04 )

	db	#F3,#14,#86	; @83E3 F31486  SETCHAR( RIGHT_OTTO )
	db	#F2,#10	; @83E6 F210  SETN( 10 )
	db	#F6	; @83E8 F6  PAUSE
	db	#F2,#24	; @83E9 F224  SETN( 24 )
;	  SPEED?
	db	#F0,#90,#00,#09	; @83EB F0900009  LOOP( 90 0 09)
;          XX YY CC
	db	#FF	; @83EF FF  end code

; data for 2nd intermission, part 2

	db	#F2,#63	; @83F0 F263
	db	#F6	; @83F2 F6
	db	#F1,#FF,#34	; @83F3 F1FF34
	db	#F3,#38,#86	; @83F6 F33886  #8638
	db	#F2,#24	; @83F9 F224
	db	#F6	; @83FB F6
	db	#F2,#7F	; @83FC F27F
	db	#F6	; @83FE F6
	db	#F2,#18	; @83FF F218
	db	#F6	; @8401 F6
	db	#F2,#57	; @8402 F257
	db	#F0,#D0,#00,#09	; @8404 F0D00009
	db	#F2,#7F	; @8408 F27F
	db	#F6	; @840A F6
	db	#F2,#28	; @840B F228
	db	#F6	; @840D F6
	db	#F1,#00,#94	; @840E F10094
	db	#F3,#1D,#86	; @8411 F31D86  #861D 8414:  F2 58
	; ;; gap-fill from golden boots $8414-$8415
	db	#F2,#58		; @8414
	db	#F0,#30,#00,#09	; @8416 F0300009
	db	#F2,#7F	; @841A F27F
	db	#F6	; @841C F6
	db	#F2,#24	; @841D F224
	db	#F6	; @841F F6
	db	#F1,#FF,#7F	; @8420 F1FF7F
	db	#F3,#38,#86	; @8423 F33886  #8638
	db	#F2,#58	; @8426 F258
	db	#F0,#D0,#00,#09	; @8428 F0D00009
	db	#F2,#7F	; @842C F27F
	db	#F6	; @842E F6
	db	#F2,#20	; @842F F220
	db	#F6	; @8431 F6
	db	#F1,#00,#54	; @8432 F10054
	db	#F3,#1D,#86	; @8435 F31D86  #861D
	db	#F2,#20	; @8438 F220
	db	#F0,#70,#00,#09	; @843A F0700009
	db	#F1,#FF,#B4	; @843E F1FFB4
	db	#F3,#38,#86	; @8441 F33886  #8638
	db	#F2,#10	; @8444 F210
	db	#F6	; @8446 F6
	db	#F2,#24	; @8447 F224
	db	#F0,#90,#00,#09	; @8449 F0900009
	db	#F2,#7F	; @844D F27F
	db	#F6	; @844F F6
	db	#FF	; @8450 FF  end code

; 3rd intermission data part 1

	db	#F2,#5A	; @8451 F25A
	db	#F6	; @8453 F6
	db	#F1,#00,#60	; @8454 F10060
	db	#F3,#8D,#86	; @8457 F38D86  #868D front of stork
	db	#F2,#7F	; @845A F27F
	db	#F0,#0A,#00,#16	; @845C F00A0016
	db	#F2,#7F	; @8460 F27F
	db	#F0,#10,#00,#16	; @8462 F0100016
	db	#F2,#30	; @8466 F230
	db	#F0,#10,#00,#16	; @8468 F0100016
	db	#FF	; @846C FF  end code

; 3rd intermission data part 2

	db	#F2,#6F	; @846D F26F
	db	#F6	; @846F F6
	db	#F1,#00,#60	; @8470 F10060
	db	#F3,#8F,#86	; @8473 F38F86  #868F flap stork
	db	#F2,#6A	; @8476 F26A
	db	#F0,#0A,#00,#16	; @8478 F00A0016
	db	#F2,#7F	; @847C F27F
	db	#F0,#10	; @847E F010
	db	#00,#16	; @8480 0016
	db	#F2,#3A	; @8482 F23A
	db	#F0,#10,#00,#16	; @8484 F0100016
	db	#FF	; @8488 FF  end code

; 3rd intermission data part 5
; sack fall, baby appears

	db	#F3,#89,#86	; @8489 F38986  #8689 act
	db	#F2,#01	; @848C F201
	db	#F0,#00,#00,#16	; @848E F0000016
	db	#F1,#BD,#62	; @8492 F1BD62
	db	#F2,#5A	; @8495 F25A
	db	#F6	; @8497 F6
	db	#F1,#05,#60	; @8498 F10560

	db	#F3,#98,#86	; @849B F39886  #8698 sack
	db	#F2,#7F	; @849E F27F
	db	#F0,#0A,#00,#16	; @84A0 F00A0016  color 16 makes the sack blue
	db	#F2,#7F	; @84A4 F27F
	db	#F0,#06,#0C,#16	; @84A6 F0060C16  this here is the bounce
	db	#F2,#06	; @84AA F206
	db	#F0,#06,#F0,#16	; @84AC F006F016
	db	#F2,#0C	; @84B0 F20C
	db	#F0,#03,#09,#16	; @84B2 F0030916
	db	#F2,#05	; @84B6 F205
	db	#F0,#05,#F6,#16	; @84B8 F005F616  final parameter is COLOR
	db	#F2,#0A	; @84BC F20A
	db	#F0,#04,#03,#16	; @84BE F0040316
	db	#F3,#9A,#86	; @84C2 F39A86  #869A baby
	db	#F2,#01	; @84C5 F201
	db	#F0,#00,#00,#16	; @84C7 F0000016  change baby color here
	db	#F2,#20	; @84CB F220
	db	#F6	; @84CD F6
	db	#FF	; @84CE FF  end code

; 3rd intermission data part 3

	db	#F1,#00,#00	; @84CF F10000
	db	#F3,#75,#86	; @84D2 F37586  #8675
	db	#F2,#01	; @84D5 F201
	db	#F0,#00,#00,#16	; @84D7 F0000016  ACT 
	db	#F1,#BD,#52	; @84DB F1BD52
	db	#F2,#28	; @84DE F228
	db	#F6	; @84E0 F6
	db	#F2,#16	; @84E1 F216
	db	#F0,#00,#00,#16	; @84E3 F0000016
	db	#F2,#16	; @84E7 F216
	db	#F6	; @84E9 F6
	db	#F1,#00,#00	; @84EA F10000
	db	#F3,#38,#86	; @84ED F33886  #8638
	db	#F2,#01	; @84F0 F201
	db	#F0,#00,#00,#09	; @84F2 F0000009  pac in front, closest to baby
	db	#F1,#C0,#C0	; @84F6 F1C0C0
	db	#F2,#30	; @84F9 F230
	db	#F6	; @84FB F6
	db	#FF	; @84FC FF  end code

; 3rd intermission data part 4

	db	#F1,#00,#00	; @84FD F10000
	db	#F3,#7F,#86	; @8500 F37F86  #867F
	db	#F2,#01	; @8503 F201
	db	#F0,#00,#00,#16	; @8505 F0000016
	db	#F1,#AD,#52	; @8509 F1AD52
	db	#F2,#28	; @850C F228
	db	#F6	; @850E F6
	db	#F2,#16	; @850F F216
	db	#F0,#00,#00,#16	; @8511 F0000016
	db	#F2,#16	; @8515 F216
	db	#F6	; @8517 F6
	db	#F1,#00,#00	; @8518 F10000
	db	#F3,#14,#86	; @851B F31486  #8614
	db	#F2,#01	; @851E F201
	db	#F0,#00,#00,#09	; @8520 F0000009  pac behind, (red)
	db	#F1,#D0,#C0	; @8524 F1D0C0
	db	#F2,#30	; @8527 F230
	db	#F6	; @8529 F6
	db	#FF	; @852A FF  end code

; data for 2nd intermission, part 3

	db	#F1,#00,#00	; @852B F10000
	db	#F3,#75,#86	; @852E F37586  #8675
	db	#F2,#01	; @8531 F201
	db	#F0,#00,#00,#16	; @8533 F0000016
	db	#F1,#BD,#52	; @8537 F1BD52
	db	#F2,#28	; @853A F228
	db	#F6	; @853C F6
	db	#F2,#16	; @853D F216
	db	#F0,#00,#00,#16	; @853F F0000016
	db	#F2,#16	; @8543 F216
	db	#F6	; @8545 F6
	db	#F1,#00,#00	; @8546 F10000
	db	#FF	; @8549 FF  end code

; data for 2nd intermission, part 4

	db	#F1,#00,#00	; @854A F10000
	db	#F3,#7F,#86	; @854D F37F86  #867F
	db	#F2,#01	; @8550 F201
	db	#F0,#00,#00,#16	; @8552 F0000016
	db	#F1,#AD,#52	; @8556 F1AD52
	db	#F2,#28	; @8559 F228
	db	#F6	; @855B F6
	db	#F2,#16	; @855C F216
	db	#F0,#00,#00,#16	; @855E F0000016
	db	#F2,#16	; @8562 F216
	db	#F6	; @8564 F6
	db	#F1,#00,#00	; @8565 F10000
	db	#FF	; @8568 FF  end code

; data for 1st, 2nd intermission, part 5

	db	#F3,#89,#86	; @8569 F38986  #8689
	db	#F2,#01	; @856C F201
	db	#F0,#00,#00,#16	; @856E F0000016
	db	#F1,#BD,#62	; @8572 F1BD62
	db	#F2,#5A	; @8575 F25A
	db	#F6	; @8577 F6
	db	#F1,#00,#00	; @8578 F10000
	db	#FF	; @857B FF  end code

; data for 1st, 2nd, 3rd intermission, part 6

	db	#F3,#8B,#86	; @857C F38B86  #868B
	db	#F2,#01	; @857F F201
	db	#F0,#00,#00,#16	; @8581 F0000016
	db	#F1,#AD,#62	; @8585 F1AD62
	db	#F2,#39	; @8588 F239
	db	#F6	; @858A F6  pause
	db	#F7	; @858B F7  display text
	db	#F2,#1E	; @858C F21E
	db	#F6	; @858E F6
	db	#F8	; @858F F8  clear act number
	db	#F1,#00,#00	; @8590 F10000
	db	#FF	; @8593 FF  end code

; data for attract mode 1st ghost

	db	#F1,#00,#94	; @8594 F10094
	db	#F3,#63,#86	; @8597 F36386  #8663
	db	#F2,#70	; @859A F270
	db	#F0,#10,#00,#01	; @859C F0100001
	db	#F2,#50	; @85A0 F250
	db	#F0,#10,#00,#01	; @85A2 F0100001
	db	#F3,#6A,#86	; @85A6 F36A86  #866A
	db	#F2,#48	; @85A9 F248
	db	#F0,#00	; @85AB F000
	db	#F0,#01	; @85AD F001
	db	#FF	; @85AF FF  end code

; data for attract mode 2nd ghost

	db	#F1,#00,#94	; @85B0 F10094
	db	#F3,#63,#86	; @85B3 F36386  #8663
	db	#F2,#70	; @85B6 F270
	db	#F0,#10,#00,#03	; @85B8 F0100003
	db	#F2,#50	; @85BC F250
	db	#F0,#10,#00,#03	; @85BE F0100003
	db	#F3,#6A,#86	; @85C2 F36A86  #866A
	db	#F2,#38	; @85C5 F238
	db	#F0,#00	; @85C7 F000
	db	#F0,#03	; @85C9 F003
	db	#FF	; @85CB FF  end code

; data for attract mode 3rd ghost

	db	#F1,#00,#94	; @85CC F10094
	db	#F3,#63,#86	; @85CF F36386  #8663
	db	#F2,#70	; @85D2 F270
	db	#F0,#10,#00,#05	; @85D4 F0100005
	db	#F2,#50	; @85D8 F250
	db	#F0,#10,#00,#05	; @85DA F0100005
	db	#F3,#6A,#86	; @85DE F36A86  #866A
	db	#F2,#28	; @85E1 F228
	db	#F0,#00	; @85E3 F000
	db	#F0,#05	; @85E5 F005
	db	#FF	; @85E7 FF  end code

; data for attract mode 4th ghost

	db	#F1,#00,#94	; @85E8 F10094
	db	#F3,#63,#86	; @85EB F36386  #8663
	db	#F2,#70	; @85EE F270
	db	#F0,#10,#00,#07	; @85F0 F0100007
	db	#F2,#50	; @85F4 F250
	db	#F0,#10,#00,#07	; @85F6 F0100007
	db	#F3,#6A,#86	; @85FA F36A86  #866A
	db	#F2,#18	; @85FD F218
	db	#F0,#00	; @85FF F000
	db	#F0,#07	; @8601 F007
	db	#FF	; @8603 FF  end code

; data for attract mode ms. pac-man

	db	#F1,#00,#94	; @8604 F10094
	db	#F3,#41,#86	; @8607 F34186  #8641
	db	#F2,#72	; @860A F272
;	db	#F0,#10,#00,#09	; @850C F0100009
	; ;; gap-fill from golden boots $860C-$860F
	db	#F0,#10,#00,#09		; @860C
	db	#F2,#7F,#F6	; @8610 F27FF6
	db	#FF	; @8613 FF  end code

; used in act 1

; Pac:
	db	#1B,#1B,#19,#19,#1B,#1B,#32,#32,#FF	; @8614 1B1B19191B1B3232FF  msp walking right
	db	#9B,#9B,#99,#99,#9B,#9B,#B2,#B2,#FF	; @861D 9B9B99999B9BB2B2FF  msp walking left
	db	#6E,#6E,#5A,#5A,#6E,#6E,#72,#72,#FF	; @8626 6E6E5A5A6E6E7272FF  walking up

	db	#EE,#EE,#DA,#DA,#EE,#EE,#F2,#F2,#FF	; @862F EEEEDADAEEEEF2F2FF  left pa
	db	#37,#37,#2D,#2D,#37,#37,#2F,#2F,#FF	; @8638 37372D2D37372F2FFF  right pac
;      r  r  R  R  u  u  rc rc

; used in attract mode to control ms pac moving under marquee

; moving left
	db	#B7,#B7,#AD,#AD,#B7,#B7,#AF,#AF,#FF	; @8641 B7B7ADADB7B7AFAFFF  pac left

	db	#36,#36,#F1,#F1,#36,#36,#F3,#F3,#FF	; @864A 3636F1F13636F3F3FF  ms pac man moving up at the end
; moving down?
	db	#34,#34,#31,#31,#34,#34,#33,#33,#FF	; @8653 3434313134343333FF  sprite codes for ms pac man

; used in act 1

	db	#A4,#A4,#A4,#A5,#A5,#A5,#FF	; @865C A4A4A4A5A5A5FF  ghost with eyes looking right sprite

; used in attract mode to control the ghosts moving under marquee

	db	#24,#24,#24,#25,#25,#25,#FF	; @8663 242424252525FF  ghost moving across (sprites with eyes looking left)
	db	#26,#26,#26,#27,#27,#27,#FF	; @866A 262626272727FF  ghost moving up left side (sprites with eyes looking up)

	db	#1F,#FF	; @8671 1FFF  empty sprite
	db	#1E,#FF	; @8673 1EFF  sprite code for heart


	db	#10,#10,#10,#14,#14,#14,#16,#16,#16,#FF	; @8675 101010141414161616FF  sprite codes for ACT sign
	db	#11,#11,#11,#15,#15,#15,#17,#17,#17,#FF	; @867F 111111151515171717FF  sprite codes for ACT sign

; used in act 1

	db	#12,#FF	; @8689 12FF  sprite code for ACT sign
	db	#13,#FF	; @868B 13FF  sprite code for ACT sign

	db	#30,#FF	; @868D 30FF  stork sprite
	db	#18,#18,#18,#18,#2C,#2C,#2C,#2C,#FF	; @868F 181818182C2C2C2CFF  stork sprites
	db	#07,#FF	; @8698 07FF  sack that stork carries sprite
	db	#0F,#FF	; @869A 0FFF  junior pacman sprite

; end data

; resume program

; arrive from #168C when ms pac is facing right
; MSPAC MOVING EAST
j_869c:
	ld      a,(pac_x)		; @869C 3A094D  load A with pacman X position
	and     #07		; @869F E607  mask bits, now between #00 and #07
	srl     a		; @86A1 CB3F  shift right, now between #00 and #03
	cpl		; @86A3 2F  invert
	ld      e,#30		; @86A4 1E30  E := #30
	add     a,e		; @86A6 83  add #30
	bit     0,a		; @86A7 CB47  test bit 0.  is it on ?
	jr      nz,j_86ad		; @86A9 2002  yes, skip next step
	ld      a,#37		; @86AB 3E37  no, A := #37
j_86ad:
	ld      (spr_pac_code),a		; @86AD 320A4C  store into mspac sprite number
	ret		; @86B0 C9  return

; arrive from #16B1 when ms pac is facing down
; MSPAC MOVING SOUTH
j_86b1:
	ld      a,(pac_y)		; @86B1 3A084D  load A with pacman Y position
	and     #07		; @86B4 E607  mask bits, now between #00 and #07
	srl     a		; @86B6 CB3F  shift right, now between #00 and #03
	ld      e,#30		; @86B8 1E30  E := #30
	add     a,e		; @86BA 83  add #30
	bit     0,a		; @86BB CB47  test bit 0.  is it on ?
	jr      nz,j_86c1		; @86BD 2002  yes, skip next step
	ld      a,#34		; @86BF 3E34  no, A := #34
j_86c1:
	ld      (spr_pac_code),a		; @86C1 320A4C  store into mspac sprite number
	ret		; @86C4 C9  return

; arrive from #16D9 when ms pac is facing left
; MSPAC MOVING WEST
j_86c5:
	ld      a,(pac_x)		; @86C5 3A094D  load A with pacman X position
	and     #07		; @86C8 E607  mask bits, now between #00 and #07
	srl     a		; @86CA CB3F  shift right, now between #00 and #03
	ld      e,#AC		; @86CC 1EAC  E := AC
	add     a,e		; @86CE 83  add AC
	bit     0,a		; @86CF CB47  test bit 0 , is it on ?
	jr      nz,j_86d5		; @86D1 2002  yes, skip next step
	ld      a,#35		; @86D3 3E35  no, A := #35
j_86d5:
	ld      (spr_pac_code),a		; @86D5 320A4C  store into mspac sprite number
	ret		; @86D8 C9

; arrive from #16FA when ms pac is facing up
; MSPAC MOVING NORTH
j_86d9:
	ld      a,(pac_y)		; @86D9 3A084D  load A with pacman Y position
	and     #07		; @86DC E607  mask bits, now between #00 and #07
	srl     a		; @86DE CB3F  shift right, now between #00 and #03
	cpl		; @86E0 2F  invert
	ld      e,#F4		; @86E1 1EF4  E := F4
	add     a,e		; @86E3 83  add F4
	bit     0,a		; @86E4 CB47  test bit 0 .  is it on ?
	jr      nz,j_86ea		; @86E6 2002  yes, skip next step
	ld      a,#36		; @86E8 3E36  no, A := #36
j_86ea:
	ld      (spr_pac_code),a		; @86EA 320A4C  store into mspac sprite number
	ret		; @86ED C9

; subroutine called from #0909, per intermediate jump at #0EAD

j_86ee:
	ld	a,(ghosts_killed_pending)		; @86EE 3AA44D  Load A with # of ghost killed but no collision for yet [0..4]
	and	a		; @86F1 A7  == #00 ?
	ret	nz		; @86F2 C0  no, return

	ld	a,(fruit_points)		; @86F3 3AD44D  load A with entry to fruit points, or 0 if no fruit
	and	a		; @86F6 A7  == #00 ?
	jp	z,j_8747		; @86F7 CA4787  yes, check for fruit release

	ld	a,(fruit_pos_lo)		; @86FA 3AD24D  load A with fruit X position
	and	a		; @86FD A7  is a fruit already onscreen?
	jp	z,j_8747		; @86FE CA4787  no, then jump to check for 

	ld      a,(fruit_bounce_index)		; @8701 3A414C  load A with fruit position
	ld      b,a		; @8704 47  copy to B
	ld      hl,#8841		; @8705 214188  load HL with start of table data
	rst     #18		; @8708 DF  load HL with data at table plus offset in B
	ld      de,(fruit_pos_lo)		; @8709 ED5BD24D  load DE with fruit position
	add     hl,de		; @870D 19  add result from above
	ld      (fruit_pos_lo),hl		; @870E 22D24D  store result into fruit position
	ld hl,fruit_bounce_index		; @8711 21414C  load HL with fruit position
	inc     (hl)		; @8714 34  increment that location
	ld      a,(hl)		; @8715 7E  load A with this value
	and     #0f		; @8716 E60F  mask bits, now between #00 and #0F
	ret     nz		; @8718 C0  return if not zero ( returns to #090C)

	ld hl,fruit_path_index		; @8719 21404C  else load HL with fruit position counter
	dec     (hl)		; @871C 35  decrement
	jp      m,j_87b5		; @871D FAB587  if negative, jump out to this subroutine
	ld      a,(hl)		; @8720 7E  else load A with this value
	ld      d,a		; @8721 57  copy to D
	srl     a		; @8722 CB3F
	srl     a		; @8724 CB3F  shift A right twice
	ld hl,CH3_E_NUM		; @8726 21BC4E  load HL with sound channel 3
	set	5,(hl)		; @8729 CBEE  set bit 5 to turn on fruit bouncing sound
	ld      hl,(fruit_path_ptr)		; @872B 2A424C  load HL with address of the fruit path
	rst     #10		; @872E D7  load A with table data
	ld      c,a		; @872F 4F  copy to C
	ld      a,#03		; @8730 3E03  A := #03
	and     d		; @8732 A2  mask bits with the fruit position
	jr      z,j_873c		; @8733 2807  if zero, skip next 4 steps

j_8735:
	srl     c		; @8735 CB39
	srl     c		; @8737 CB39  shift C right twice
	dec     a		; @8739 3D  A := A - 1.  is A == #00 ?
	jr      nz,j_8735		; @873A 20F9  no, loop again

j_873c:
	ld      a,#03		; @873C 3E03  A := #03
	and     c		; @873E A1  mask bits with C
	rlca		; @873F 07
	rlca		; @8740 07
	rlca		; @8741 07
	rlca		; @8742 07  rotate left 4 times
	ld      (fruit_bounce_index),a		; @8743 32414C  store result into fruit position counter
	ret		; @8746 C9  return

; arrive here from #86FE
; to check to see if it is time for a new fruit to be released
; only called when a fruit is not already onscreen

j_8747:
	ld	a,(dots_eaten)		; @8747 3A0E4E  load number of dots eaten
	cp	#40		; @874A FE40  == #40 ? (64 decimal)
	jp	z,j_8758		; @874C CA5887  yes, skip ahead and use HL as 4E0C
	cp	#B0		; @874F FEB0  == B0 (176 deciaml) ?
	ret	nz		; @8751 C0  no, return

	ld hl,fruit2_released		; @8752 210D4E  yes, load HL with #4E0D for 2nd fruit
	jp	j_875b		; @8755 C35B87  skip ahead
;(
j_8758:
	ld hl,fruit1_released		; @8758 210C4E  load HL with 4E0C for first fruit

j_875b:
	ld	a,(hl)		; @875B 7E  load A with fruit flag
	and	a		; @875C A7  has this fruit already appeared?
	ret	nz		; @875D C0  yes, return

	inc	(hl)		; @875E 34

	;; Ms. Pacman Random Fruit Probabilities
	;; (c) 2002 Mark Spaeth
	;; http://rgvac.978.org/files/MsPacFruit.txt

;  A hotly contested issue on rgvac. here's an explanation
;  of how the random fruit selection routine works in Ms.
;  Pacman, and the probabilities associated with the routine:

	ld      a,(level_number)		; @875F 3A134E  Load the board # (cherry = 0)
	cp      #07		; @8762 FE07  Compare it to 7
	jr      c,j_8770		; @8764 380A  If less than 7, use board # as fruit

	ld      b,#07		; @8766 0607  else B := #07

        ;; selector for random fruits
        ;; uses r register to get a random number

	ld      a,r		; @8768 ED5F  Load the DRAM refresh counter 
	and     #1f		; @876A E61F  Mask off the bottom 5 bits

                ;; Compute ((R % 32) % 7)
j_876c:
	sub     b		; @876C 90  Subtract 7
	jr      nc,j_876c		; @876D 30FD  If >=0 loop
	add     a,b		; @876F 80  Add 7 back


j_8770:
	ld      hl,#879d		; @8770 219D87  Level / fruit data table      
	ld      b,a		; @8773 47  3 * a -> a
	add     a,a		; @8774 87
	add     a,b		; @8775 80
	rst     #10		; @8776 D7  hl + a -> hl, (hl) -> a  [table look]

	ld      (spr_fruit_code),a		; @8777 320C4C  Write 3 fruit data bytes (shape code)
	inc     hl		; @877A 23
	ld      a,(hl)		; @877B 7E
	ld      (spr_fruit_color),a		; @877C 320D4C  Color code
	inc     hl		; @877F 23
	ld      a,(hl)		; @8780 7E
	ld      (fruit_points),a		; @8781 32D44D  Score table offset


;    So, a little more background...
;
;    The 'R' register is the dram refresh address register
;    that is not initalized on startup, so it has garbage
;    in it.  During every instruction fetch, the counter is
;    incremented.  Assume on average 4 clock cycles per
;    instruction, with the clock running at 3.072 Mhz, this
;    counter is incremented every 1.3us, so if you read it
;    at any time, it's gonna be pretty damn random.  Of
;    course, it doesn't just get read at any time, since
;    the fruit select routine is called during the vertical
;    blank every 1/60sec, but since the instruction
;    counts between reads are not all the say, it's still
;    random to better than 1/60 sec, which is still too fast
;    for any player to count off.
;
;    So, now, assuming that the counter is random, the bottom
;    5 bits are hacked off giving a number 0-31 (each with
;    probability 1/32), and this number modulo 7 is used to
;    determine which fruit appears...
;
;    So...
;
;     0, 7,14,21,28  ->  Cherry         100 pts @ 5/32 = 15.625 % 
;     1, 8,15,22,29  ->  Strawberry     200 pts @ 5/32 = 15.625 %
;     2, 9,16,23,30  ->  Orange         500 pts @ 5/32 = 15.625 %
;     3,10,17,24,31  ->  Pretzel        700 pts @ 5/32 = 15.625 %
;     4,11,18,25     ->  Apple         1000 pts @ 4/32 = 12.5   %
;     5,12,19,26     ->  Pear          2000 pts @ 4/32 = 12.5   %
;     6,13,20,27     ->  Banana        5000 pts @ 4/32 = 12.5   %
;
;    Also interesting to note is that the expected value of
;    the random fruit is 1234.375 points, which is useful
;    in determining a good estimate of what the killscreen
;    score should be.  The standard deviation of this
;    distribution is 1532.891 / sqrt(n), where n is the
;    number of random fruits eaten, so at the level 243 (?)
;    killscreen, (243-7)*2 = 472 fruits have been eaten,
;    and the SD falls to 21.726, so it should be pretty easy
;    to tell if the fruit distribution has been tampered
;    with.  This SD across 472 fruits is +/- 10k from the
;    mean, is approximaely the difference between the top
;    3 players in twin galaxies, but given the game crash
;    issue, the number of levels the game lets you play is
;    probably a more poingant indicator than the fruits
;    given.
;
;
;
;    How to cheat:
;    -------------
;
;    Of course, if you want to be cutesy you can play with
;    the distribution, by say changing 876b to 0x3f, thus
;    doing 0-63 mod 7 to choose the fruit, bumping the
;    average up to 1337.5, but at an extra 100 points a
;    fruit, thats 47,200 points on average, and without a
;    close statistical analysis like the one I've provided
;    (which shows that this is almost 5 standard deviations
;    above the mean), you could probably get away with it
;    in competition.
;
;    If you really wanted to be cheezy, you could change
;    0x876b to 0x06, so that only cherry, orange, apple,
;    and banana come up, and all have equal probability.
;    That would bump your fruit average up to 1650, but the
;    absence of strawberries, pretzels, and pears would be
;    pretty obvious.
;
;    These changes would't require any other changes in the
;    code, but it's also possible to completely rewrite the
;    routine, in a different part of the code space to do
;    something different, but that's an exercise left to
;    the reader.  (Perhaps the simplest would be to add 3
;    after the mod 32 operation, so that Pretzel-Banana are
;    slightly more likely than Cherry-Orange).
;
;    If you really want to be lame, you can edit the scoring
;    table at 0x2b17 (many pacman bootlegs did this).
;    Seriously, you could probably add 10 points to each
;    value, and the 'judges' couldn't tell whether or not
;    you were eating a dot while eating the fruit in many
;    situations, and you could get almost 5000 extra points
;    over the entire game ;)
;
;    One other 'cool' thing to do would be to chage 0x8763
;    to 0x08, which would utilize the 8th fruit on the 8th
;    board, and subsequently would give you even odds on
;    all of the fruit, but since the junior icon and the
;    banana are both 5000, the average skews WAY up to 1812.5
;    points.
;
;    [To keep things fair, though, note that the junior
;    fruit uses color code 0x00, which is to say, all black,
;    so you'd have to find the invisible fruit.  Since the
;    fruit patterns are pretty well known, that's probably
;    not that big of a deal for top players.]


	;; select the proper fruit path from the table at 87f8

	ld      hl,#87f8		; @8784 21F887  load HL with fruit path entry lookup table
	call    j_87cd		; @8787 CDCD87  set up fruit path
	inc     hl		; @878A 23  HL := HL + 1
	ld      e,(hl)		; @878B 5E  load E with table data
	inc     hl		; @878C 23  next table entry
	ld      d,(hl)		; @878D 56  load D with table data
	ld      (fruit_pos_lo),de		; @878E ED53D24D  store into fruit position
	ret		; @8792 C9  return

; jumped from #2BF4 for fruit drawing subroutine
; A has the level number
; keeps the fruit level at banana after level 7

j_8793:
	CP 	#08		; @8793 FE08  Is Level >= #08 ?
	JP 	C,j_2bf9		; @8795 DAF92B  No, return
	LD 	A,#07		; @8798 3E07  Yes, set A := #07
	JP 	j_2bf9		; @879A C3F92B  Return


	;; fruit shape/color/points table

	db	#00,#14,#06	; @879D 001406  Cherry     = sprite 0, color 14, score table 06
	db	#01,#0F,#07	; @87A0 010F07  Strawberry = sprite 1, color 0f, score table 07
	db	#02,#15,#08	; @87A3 021508  Orange     = sprite 2, color 15, score table 08
	db	#03,#07,#09	; @87A6 030709  Pretzel    = sprite 3, color 07, score table 09
	db	#04,#14,#0A	; @87A9 04140A  Apple      = sprite 4, color 14, score table 0a
	db	#05,#15,#0B	; @87AC 05150B  Pear	     = sprite 5, color 15, score table 0b
	db	#06,#16,#0C	; @87AF 06160C  Banana     = sprite 6, color 16, score table 0c
	db	#07,#00,#0D	; @87B2 07000D  Junior!    = sprite 7, color 00, score table 0d

	; For reference, the score table is at 0x2b17
	; arrive here from #871D

j_87b5:
	ld      a,(fruit_pos_hi)		; @87B5 3AD34D  load A with fruit position
	add     a,#20		; @87B8 C620  add 20
	cp      #40		; @87BA FE40  > 40 ?
	jr      c,j_8810		; @87BC 3852  yes, jump ahead and return
	ld      hl,(fruit_path_ptr)		; @87BE 2A424C  else load HL with value in #4C42 (EG. #8808, #8B71,)
	ld      de,#8808		; @87C1 110888  load DE with start of data table
	scf		; @87C4 37  Set Carry Flag.
	ccf		; @87C5 3F  Invert Carry Flag (cleared in this case)  
	sbc     hl,de		; @87C6 ED52  subtract DE (value = #8808) from HL
	jr      nz,j_87ed		; @87C8 2023  If not zero then jump ahead

	ld      hl,#8800		; @87CA 210088  else if zero then load HL with start of data table for fruit exit

j_87cd:
	call    j_94bd		; @87CD CDBD94  load BC with valued from table based on level
	ld      l,c		; @87D0 69
	ld      h,b		; @87D1 60  copy BC into HL
	ld      a,r		; @87D2 ED5F  load A with a random number
	and     #03		; @87D4 E603  mask bits, now between #00 and #03
	ld      b,a		; @87D6 47  copy to B		
	add     a,a		; @87D7 87  A := A*2
	add     a,a		; @87D8 87  A := A*2
	add     a,b		; @87D9 80  A := A+B (A is now randomly #00, #05, #0A, or #0F)
	rst     #10		; @87DA D7  load A with (HL + A), HL := HL + A
	ld      e,a		; @87DB 5F  copy to E
	inc     hl		; @87DC 23  next table entry
	ld      d,(hl)		; @87DD 56  load D with next value from table.  DE now has fruit path address from table.
	ld      (fruit_path_ptr),de		; @87DE ED53424C  store DE into #4C42
	inc     hl		; @87E2 23  next table entry
	ld      a,(hl)		; @87E3 7E  load A with next value from table

j_87e4:
	ld      (fruit_path_index),a		; @87E4 32404C  store into #4C40
	ld      a,#1f		; @87E7 3E1F  A := #1F
	ld      (fruit_bounce_index),a		; @87E9 32414C  store into #4C41
	ret		; @87EC C9  return

; arrive here from #87C8

j_87ed:
	ld      hl,#8808		; @87ED 210888  load HL with start of table data
	ld      (fruit_path_ptr),hl		; @87F0 22424C  store 08 88 into the addresses in #4C42 and #4C43
	ld      a,#1d		; @87F3 3E1D  A := #1D (resets counter)
	jp      j_87e4		; @87F5 C3E487  jump back

	; fruit path entry lookup table.  referenced in #8784

	db	#4F,#8B	; @87F8 4F8B  #8B4F ; fruit paths for maze 1
	db	#40,#8E	; @87FA 408E  #8E40 ; fruit paths for maze 2
	db	#1A,#91	; @87FC 1A91  #911A ; fruit paths for maze 3
	db	#0A,#94	; @87FE 0A94  #940A ; fruit paths for maze 4

	; fruit path exit lookup table data used from #87CA

	db	#82,#8B	; @8800 828B  #8B82 ; fruit paths for maze 1
	db	#73,#8E	; @8802 738E  #8E73	; fruit paths for maze 2
	db	#42,#91	; @8804 4291  #9142	; fruit paths for maze 3
	db	#3C,#94	; @8806 3C94  #943C	; fruit paths for maze 4

; data used from #87C1 and #87ED

	db	#FA,#FF,#55,#55,#01,#80,#AA,#02	; @8808 FAFF55550180AA02  fruit path ?


; arrive here from #87BC, when fruit exits screen on its own (not eaten)

j_8810:
	ld      a,#00		; @8810 3E00  A := #00
	ld      (spr_fruit_color),a		; @8812 320D4C  store into fruit sprite entry (clears fruit)
	jp      j_1000		; @8815 C30010  jump back to program (clears #4DD4 and returns from sub)

; check for fruit being eaten ... jumped from #19AD
; HL has pacman X,Y

j_8818:
	push	af		; @8818 F5  Save AF
	ld	de,(fruit_pos_lo)		; @8819 ED5BD24D  load fruit X position into D, fruit Y position into E
	ld	a,h		; @881D 7C  load A with pacman X position
	sub	d		; @881E 92  subtract fruit X position
	add	a,#03		; @881F C603  add margin of error == #03
	cp	#06		; @8821 FE06  X values match within margin ?
	jr	nc,j_883d		; @8823 3018  no , jump back to program

	ld	a,l		; @8825 7D  else load A with pacman Y values
	sub	e		; @8826 93  subtract fruit Y position
	add	a,#03		; @8827 C603  add margin of error
	cp	#06		; @8829 FE06  Y values match within margin?
	jr	nc,j_883d		; @882B 3010  no, jump back to program

; else a fruit is being eaten

	ld	a,#01		; @882D 3E01  load A with #01
	ld	(spr_fruit_color),a		; @882F 320D4C  store into fruit sprite entry
	pop	af		; @8832 F1  Restore AF
	add	a,#02		; @8833 C602  add 2 to A
	ld	(spr_fruit_code),a		; @8835 320C4C  store into fruit sprite number
	sub	#02		; @8838 D602  sub 2 from A, make A the same as it was
	jp	j_19b2		; @883A C3B219  jump back to program for fruit being eaten

j_883d:
	pop	af		; @883D F1  Restore AF
	jp	j_19cd		; @883E C3CD19  jump back to program with no fruit eaten


; data used somehow with the fruit
; called from #8705


	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @8841 FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
	db	#FF,#FF,#FF,#00,#00,#FF,#FF,#00,#00,#00,#00,#01,#00,#00,#00,#01	; @8850 FFFFFF0000FFFF000000000100000001
	db	#00,#00,#00,#FF,#FE,#00,#00,#00,#FF,#00,#00,#FF,#FE,#00,#00,#00	; @8860 000000FFFE000000FF0000FFFE000000
	db	#FF,#00,#00,#00,#FF,#00,#00,#00,#FF,#00,#00,#01,#FF,#01,#FF,#00	; @8870 FF000000FF000000FF000001FF01FF00
	db	#00,#00,#00,#00,#00,#FF,#00,#00,#00,#00,#01,#00,#00,#FF,#00,#00	; @8880 0000000000FF00000000010000FF0000
	db	#00,#00,#01,#00,#00,#00,#01,#00,#00,#00,#01,#00,#00,#01,#01,#01	; @8890 00000100000001000000010000010101
	db	#01,#00,#00,#01,#00,#01,#00,#01,#00,#01,#00,#01,#00,#01,#00,#01	; @88A0 01000001000100010001000100010001
	db	#00,#01,#00,#01,#00,#01,#00,#01,#00,#FF,#FF,#FF,#FF,#00,#00,#FF	; @88B0 000100010001000100FFFFFFFF0000FF
	db	#FF	; @88C0 FF

	;; Maze Table 1

	db	#40,#FC,#D0,#D2,#D2,#D2,#D2,#D4,#FC,#DA,#02,#DC,#FC,#FC,#FC	; @88C1 40FCD0D2D2D2D2D4FCDA02DCFCFCFC
	db	#FC,#FC,#FC,#DA,#02,#DC,#FC,#FC,#FC,#D0,#D2,#D2,#D2,#D2,#D2,#D2	; @88D0 FCFCFCDA02DCFCFCFCD0D2D2D2D2D2D2
	db	#D2,#D4,#FC,#DA,#05,#DC,#FC,#DA,#02,#DC,#FC,#FC,#FC,#FC,#FC,#FC	; @88E0 D2D4FCDA05DCFCDA02DCFCFCFCFCFCFC
	db	#DA,#02,#DC,#FC,#FC,#FC,#DA,#08,#DC,#FC,#DA,#02,#E6,#EA,#02,#E7	; @88F0 DA02DCFCFCFCDA08DCFCDA02E6EA02E7
	db	#D2,#EB,#02,#E7,#D2,#D2,#D2,#D2,#D2,#D2,#EB,#02,#E7,#D2,#D2,#D2	; @8900 D2EB02E7D2D2D2D2D2D2EB02E7D2D2D2
	db	#EB,#02,#E6,#E8,#E8,#E8,#EA,#02,#DC,#FC,#DA,#02,#DE,#E4,#15,#DE	; @8910 EB02E6E8E8E8EA02DCFCDA02DEE415DE
	db	#C0,#C0,#C0,#E4,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#E6,#E8,#E8,#E8	; @8920 C0C0C0E402DCFCDA02DEE402E6E8E8E8
	db	#E8,#EA,#02,#E6,#E8,#E8,#E8,#EA,#02,#E6,#EA,#02,#E6,#EA,#02,#DE	; @8930 E8EA02E6E8E8E8EA02E6EA02E6EA02DE
	db	#C0,#C0,#C0,#E4,#02,#DC,#FC,#DA,#02,#E7,#EB,#02,#E7,#E9,#E9,#E9	; @8940 C0C0C0E402DCFCDA02E7EB02E7E9E9E9
	db	#F5,#E4,#02,#DE,#F3,#E9,#E9,#EB,#02,#DE,#E4,#02,#DE,#E4,#02,#E7	; @8950 F5E402DEF3E9E9EB02DEE402DEE402E7
	db	#E9,#E9,#E9,#EB,#02,#DC,#FC,#DA,#09,#DE,#E4,#02,#DE,#E4,#05,#DE	; @8960 E9E9E9EB02DCFCDA09DEE402DEE405DE
	db	#E4,#02,#DE,#E4,#08,#DC,#FC,#FA,#E8,#E8,#EA,#02,#E6,#E8,#EA,#02	; @8970 E402DEE408DCFCFAE8E8EA02E6E8EA02
	db	#DE,#E4,#02,#DE,#E4,#02,#E6,#E8,#E8,#F4,#E4,#02,#DE,#E4,#02,#E6	; @8980 DEE402DEE402E6E8E8F4E402DEE402E6
	db	#E8,#E8,#E8,#EA,#02,#DC,#FC,#FB,#E9,#E9,#EB,#02,#DE,#C0,#E4,#02	; @8990 E8E8E8EA02DCFCFBE9E9EB02DEC0E402
	db	#E7,#EB,#02,#E7,#EB,#02,#E7,#E9,#E9,#F5,#E4,#02,#E7,#EB,#02,#DE	; @89A0 E7EB02E7EB02E7E9E9F5E402E7EB02DE
	db	#F3,#E9,#E9,#EB,#02,#DC,#FC,#DA,#05,#DE,#C0,#E4,#0B,#DE,#E4,#05	; @89B0 F3E9E9EB02DCFCDA05DEC0E40BDEE405
	db	#DE,#E4,#05,#DC,#FC,#DA,#02,#E6,#EA,#02,#DE,#C0,#E4,#02,#E6,#EA	; @89C0 DEE405DCFCDA02E6EA02DEC0E402E6EA
	db	#02,#EC,#D3,#D3,#D3,#EE,#02,#DE,#E4,#02,#E6,#EA,#02,#DE,#E4,#02	; @89D0 02ECD3D3D3EE02DEE402E6EA02DEE402
	db	#E6,#EA,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#E7,#E9,#EB,#02,#DE,#E4	; @89E0 E6EA02DCFCDA02DEE402E7E9EB02DEE4
	db	#02,#DC,#FC,#FC,#FC,#DA,#02,#E7,#EB,#02,#DE,#E4,#02,#E7,#EB,#02	; @89F0 02DCFCFCFCDA02E7EB02DEE402E7EB02
	db	#DE,#E4,#02,#DC,#FC,#DA,#02,#DE,#E4,#06,#DE,#E4,#02,#F0,#FC,#FC	; @8A00 DEE402DCFCDA02DEE406DEE402F0FCFC
	db	#FC,#DA,#05,#DE,#E4,#05,#DE,#E4,#02,#DC,#FC,#DA,#02,#DE,#E4,#02	; @8A10 FCDA05DEE405DEE402DCFCDA02DEE402
	db	#E6,#E8,#E8,#E8,#F4,#E4,#02,#CE,#FC,#FC,#FC,#DA,#02,#E6,#E8,#E8	; @8A20 E6E8E8E8F4E402CEFCFCFCDA02E6E8E8
	db	#F4,#E4,#02,#E6,#E8,#E8,#F4,#E4,#02,#DC,#00	; @8A30 F4E402E6E8E8F4E402DC00

	;; Pellet table for maze 1

	db	#62,#02,#01,#13,#01	; @8A3B 6202011301
	db	#01,#01,#02,#01,#04,#03,#13,#06,#04,#03,#01,#01,#01,#01,#01,#01	; @8A40 01010201040313060403010101010101
	db	#01,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01,#06,#04,#03	; @8A50 01010101010101010101010101060403
	db	#10,#03,#06,#04,#03,#10,#03,#06,#04,#01,#01,#01,#01,#01,#01,#01	; @8A60 10030604031003060401010101010101
	db	#0C,#03,#01,#01,#01,#01,#01,#01,#07,#04,#0C,#03,#06,#07,#04,#0C	; @8A70 0C0301010101010107040C030607040C
	db	#03,#06,#04,#01,#01,#01,#04,#0C,#01,#01,#01,#03,#01,#01,#01,#04	; @8A80 030604010101040C0101010301010104
	db	#03,#04,#0F,#03,#03,#04,#03,#04,#0F,#03,#03,#04,#03,#01,#01,#01	; @8A90 03040F03030403040F03030403010101
	db	#01,#0F,#01,#01,#01,#03,#04,#03,#19,#04,#03,#19,#04,#03,#01,#01	; @8AA0 010F0101010304031904031904030101
	db	#01,#01,#0F,#01,#01,#01,#03,#04,#03,#04,#0F,#03,#03,#04,#03,#04	; @8AB0 01010F010101030403040F0303040304
	db	#0F,#03,#03,#04,#01,#01,#01,#04,#0C,#01,#01,#01,#03,#01,#01,#01	; @8AC0 0F030304010101040C01010103010101
	db	#07,#04,#0C,#03,#06,#07,#04,#0C,#03,#06,#04,#01,#01,#01,#01,#01	; @8AD0 07040C030607040C0306040101010101
	db	#01,#01,#0C,#03,#01,#01,#01,#01,#01,#01,#04,#03,#10,#03,#06,#04	; @8AE0 01010C03010101010101040310030604
	db	#03,#10,#03,#06,#04,#03,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01	; @8AF0 03100306040301010101010101010101
	db	#01,#01,#01,#01,#01,#01,#01,#01,#01,#06,#04,#03,#13,#06,#04,#02	; @8B00 01010101010101010106040313060402
	db	#01,#13,#01,#01,#01,#02,#01,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @8B10 01130101010201000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @8B20 000000000000000000000000

	;; number of pellets to eat for maze 1

	db	#E0	; @8B2C E0  E0 = 224 decimal

	;; ghost destination table for maze 1

	db	#1D,#22	; @8B2D 1D22  column 22, row 1D (top right)
	db	#1D,#39	; @8B2F 1D39  column 39, row 1D (top left)
	db	#40,#20	; @8B31 4020  column 20, row 40 (bottom right)
	db	#40,#3B	; @8B33 403B  column 3B, row 40 (bottom left)


	;; Power Pellet Table for maze 1 (screen locations)

	db	#63,#40	; @8B35 6340  #4063 = location of upper right power pellet
	db	#7C,#40	; @8B37 7C40  #407C = location of lower right power pellet
	db	#83,#43	; @8B39 8343  #4383	= location of upper left power pellet
	db	#9C,#43	; @8B3B 9C43  #439C = location of lower left power pellet


; data table used for drawing slow down tunnels on levels 1 and 2

	db	#49,#09,#17	; @8B3D 490917
	db	#09,#17,#09,#0E,#E0,#E0,#E0,#29,#09,#17,#09,#17,#09,#00,#00	; @8B40 0917090EE0E0E02909170917090000


	;; entrance fruit paths for maze 1:  #8b4f - #8b81

	db	#63,#8B	; @8B4F 638B  #8B63
	db	#13,#94,#0C	; @8B51 13940C
	db	#68,#8B	; @8B54 688B  #8B68
	db	#22,#94,#F4	; @8B56 2294F4
	db	#71,#8B	; @8B59 718B  #8B71
	db	#27,#4C,#F4	; @8B5B 274CF4
	db	#7B,#8B	; @8B5E 7B8B  #8B7B
	db	#1C,#4C,#0C	; @8B60 1C4C0C
	db	#80,#AA,#AA,#BF,#AA	; @8B63 80AAAABFAA
	db	#80,#0A,#54,#55,#55,#55,#FF,#5F,#55	; @8B68 800A54555555FF5F55
	db	#EA,#FF,#57,#55,#F5,#57,#FF,#15,#40,#55	; @8B71 EAFF5755F557FF154055
	db	#EA,#AF,#02,#EA,#FF,#FF,#AA	; @8B7B EAAF02EAFFFFAA

	;; exit fruit paths for maze 1

	db	#94,#8B	; @8B82 948B  #8B94
	db	#14,#00,#00	; @8B84 140000
	db	#99,#8B	; @8B87 998B  #8B99
	db	#17,#00,#00	; @8B89 170000
	db	#9F,#8B	; @8B8C 9F8B  #8B9F
	db	#1A,#00,#00	; @8B8E 1A0000
	db	#A6,#8B	; @8B91 A68B  #8BA6
	db	#1D	; @8B93 1D
	db	#55,#40,#55,#55,#BF	; @8B94 55405555BF
	db	#AA,#80,#AA,#AA,#BF,#AA	; @8B99 AA80AAAABFAA
	db	#AA,#80,#AA,#02,#80,#AA,#AA	; @8B9F AA80AA0280AAAA
	db	#55,#00,#00,#00,#55,#55,#FD,#AA	; @8BA6 550000005555FDAA


	;; Maze 2 Table


	db	#40,#FC	; @8BAE 40FC
	db	#DA,#02,#DE,#D8,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D6,#D8,#D2,#D2,#D2	; @8BB0 DA02DED8D2D2D2D2D2D2D2D6D8D2D2D2
	db	#D2,#D4,#FC,#FC,#FC,#FC,#DA,#02,#DE,#D8,#D2,#D2,#D2,#D2,#D4,#FC	; @8BC0 D2D4FCFCFCFCDA02DED8D2D2D2D2D4FC
	db	#DA,#02,#DE,#E4,#08,#DE,#E4,#05,#DC,#FC,#FC,#FC,#FC,#DA,#02,#DE	; @8BD0 DA02DEE408DEE405DCFCFCFCFCDA02DE
	db	#E4,#05,#DC,#FC,#DA,#02,#DE,#E4,#02,#E6,#E8,#E8,#E8,#EA,#02,#DE	; @8BE0 E405DCFCDA02DEE402E6E8E8E8EA02DE
	db	#E4,#02,#E6,#EA,#02,#E7,#D2,#D2,#D2,#D2,#EB,#02,#E7,#EB,#02,#E6	; @8BF0 E402E6EA02E7D2D2D2D2EB02E7EB02E6
	db	#EA,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#DE,#F3,#E9,#E9,#EB,#02,#DE	; @8C00 EA02DCFCDA02DEE402DEF3E9E9EB02DE
	db	#E4,#02,#DE,#E4,#0C,#DE,#E4,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#DE	; @8C10 E402DEE40CDEE402DCFCDA02DEE402DE
	db	#E4,#05,#DE,#E4,#02,#DE,#F2,#E8,#E8,#E8,#EA,#02,#E6,#EA,#02,#E6	; @8C20 E405DEE402DEF2E8E8E8EA02E6EA02E6
	db	#E8,#E8,#F4,#E4,#02,#DC,#FC,#DA,#02,#E7,#EB,#02,#DE,#E4,#02,#E6	; @8C30 E8E8F4E402DCFCDA02E7EB02DEE402E6
	db	#EA,#02,#E7,#EB,#02,#E7,#E9,#E9,#E9,#E9,#EB,#02,#DE,#E4,#02,#E7	; @8C40 EA02E7EB02E7E9E9E9E9EB02DEE402E7
	db	#E9,#E9,#E9,#EB,#02,#DC,#FC,#DA,#05,#DE,#E4,#02,#DE,#E4,#0C,#DE	; @8C50 E9E9E9EB02DCFCDA05DEE402DEE40CDE
	db	#E4,#08,#DC,#FC,#FA,#E8,#E8,#EA,#02,#DE,#E4,#02,#DE,#F2,#E8,#E8	; @8C60 E408DCFCFAE8E8EA02DEE402DEF2E8E8
	db	#E8,#E8,#EA,#02,#E6,#E8,#E8,#EA,#02,#DE,#F2,#E8,#E8,#EA,#02,#E6	; @8C70 E8E8EA02E6E8E8EA02DEF2E8E8EA02E6
	db	#EA,#02,#DC,#FC,#FB,#E9,#E9,#EB,#02,#E7,#EB,#02,#E7,#E9,#E9,#E9	; @8C80 EA02DCFCFBE9E9EB02E7EB02E7E9E9E9
	db	#E9,#E9,#EB,#02,#E7,#E9,#F5,#E4,#02,#DE,#F3,#E9,#E9,#EB,#02,#DE	; @8C90 E9E9EB02E7E9F5E402DEF3E9E9EB02DE
	db	#E4,#02,#DC,#FC,#DA,#12,#DE,#E4,#02,#DE,#E4,#05,#DE,#E4,#02,#DC	; @8CA0 E402DCFCDA12DEE402DEE405DEE402DC
	db	#FC,#DA,#02,#E6,#EA,#02,#E6,#E8,#E8,#E8,#E8,#EA,#02,#EC,#D3,#D3	; @8CB0 FCDA02E6EA02E6E8E8E8E8EA02ECD3D3
	db	#D3,#EE,#02,#E7,#EB,#02,#E7,#EB,#02,#E6,#EA,#02,#DE,#E4,#02,#DC	; @8CC0 D3EE02E7EB02E7EB02E6EA02DEE402DC
	db	#FC,#DA,#02,#DE,#E4,#02,#E7,#E9,#E9,#E9,#F5,#E4,#02,#DC,#FC,#FC	; @8CD0 FCDA02DEE402E7E9E9E9F5E402DCFCFC
	db	#FC,#DA,#08,#DE,#E4,#02,#E7,#EB,#02,#DC,#FC,#DA,#02,#DE,#E4,#06	; @8CE0 FCDA08DEE402E7EB02DCFCDA02DEE406
	db	#DE,#E4,#02,#F0,#FC,#FC,#FC,#DA,#02,#E6,#E8,#E8,#E8,#EA,#02,#DE	; @8CF0 DEE402F0FCFCFCDA02E6E8E8E8EA02DE
	db	#E4,#05,#DC,#FC,#DA,#02,#DE,#F2,#E8,#E8,#E8,#EA,#02,#DE,#E4,#02	; @8D00 E405DCFCDA02DEF2E8E8E8EA02DEE402
	db	#CE,#FC,#FC,#FC,#DA,#02,#DE,#C0,#C0,#C0,#E4,#02,#DE,#F2,#E8,#E8	; @8D10 CEFCFCFCDA02DEC0C0C0E402DEF2E8E8
	db	#EA,#02,#DC,#00,#00,#00,#00	; @8D20 EA02DC00000000

	;; Pellet table for maze 2

	db	#66,#01,#01,#01,#01,#01,#03,#01,#01	; @8D27 660101010101030101
	db	#01,#0B,#01,#01,#07,#06,#03,#03,#0A,#03,#07,#06,#03,#03,#01,#01	; @8D30 010B0101070603030A03070603030101
	db	#01,#01,#01,#01,#01,#01,#01,#01,#03,#07,#03,#01,#01,#01,#03,#07	; @8D40 01010101010101010307030101010307
	db	#03,#06,#07,#03,#03,#03,#07,#03,#06,#07,#03,#03,#01,#01,#01,#01	; @8D50 03060703030307030607030301010101
	db	#01,#01,#01,#01,#01,#01,#03,#01,#01,#01,#01,#01,#01,#07,#03,#0D	; @8D60 0101010101010301010101010107030D
	db	#06,#03,#07,#03,#0D,#06,#03,#04,#01,#01,#01,#01,#01,#01,#0D,#03	; @8D70 060307030D0603040101010101010D03
	db	#01,#01,#01,#03,#04,#03,#10,#03,#03,#03,#04,#03,#10,#01,#01,#01	; @8D80 01010103040310030303040310010101
	db	#03,#03,#04,#03,#01,#01,#01,#01,#12,#01,#01,#01,#04,#07,#15,#04	; @8D90 03030403010101011201010104071504
	db	#07,#15,#04,#03,#01,#01,#01,#01,#12,#01,#01,#01,#04,#03,#10,#01	; @8DA0 07150403010101011201010104031001
	db	#01,#01,#03,#03,#04,#03,#10,#03,#03,#03,#04,#01,#01,#01,#01,#01	; @8DB0 01010303040310030303040101010101
	db	#01,#0D,#03,#01,#01,#01,#03,#07,#03,#0D,#06,#03,#07,#03,#0D,#06	; @8DC0 010D030101010307030D060307030D06
	db	#03,#07,#03,#03,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01,#03,#01	; @8DD0 03070303010101010101010101010301
	db	#01,#01,#01,#01,#01,#07,#03,#03,#03,#07,#03,#06,#07,#03,#01,#01	; @8DE0 01010101010703030307030607030101
	db	#01,#03,#07,#03,#06,#07,#06,#03,#03,#01,#01,#01,#01,#01,#01,#01	; @8DF0 01030703060706030301010101010101
	db	#01,#01,#01,#03,#07,#06,#03,#03,#0A,#03,#08,#01,#01,#01,#01,#01	; @8E00 01010103070603030A03080101010101
	db	#03,#01,#01,#01,#0B,#01,#01	; @8E10 030101010B0101

	;; number of pellets to eat for map 2

	db	#F4	; @8E17 F4  F4 = 244 decimal


	;; destination table for maze 2

	db	#1D,#22	; @8E18 1D22  column 22, row 1D (top right)
	db	#1D,#39	; @8E1A 1D39  column 39, row 1D (top right)
	db	#40,#20	; @8E1C 4020  column 20, row 40 (bottom right)
	db	#40,#3B	; @8E1E 403B  column 3B, row 40 (bottom left)

	;; Power Pellet Table for maze 2 screen locations

	db	#65,#40	; @8E20 6540  #4065 = power pellet upper right
	db	#7B,#40	; @8E22 7B40  #407B = power pellet lower right
	db	#85,#43	; @8E24 8543  #4385 = power pellet upper left
	db	#9B,#43	; @8E26 9B43  #439B = power pellet lower left


; data table used for drawing slow down tunnels on level 3

	db	#42,#16,#0A,#16,#0A,#16,#0A,#20	; @8E28 42160A160A160A20
	db	#20,#20,#DE,#E0,#22,#20,#20,#20,#20,#16,#0A,#16,#0A,#16,#00,#00		; @8E30 302020DEE02220202020160A16160000


	;; entrance fruit paths for maze 2:  #8E40-8E72

	db	#54,#8E	; @8E40 548E  #8E54
	db	#13,#C4,#0C	; @8E42 13C40C
	db	#59,#8E	; @8E45 598E  #8E59
	db	#1E,#C4,#F4	; @8E47 1EC4F4
	db	#61,#8E	; @8E4A 618E  #8E61
	db	#26,#14,#F4	; @8E4C 2614F4
	db	#6B,#8E	; @8E4F 6B8E  #8E6B
	db	#1D,#14,#0C	; @8E51 1D140C
	db	#02,#AA,#AA,#80,#2A	; @8E54 02AAAA802A
	db	#02,#40,#55,#7F,#55,#15,#50,#05	; @8E59 0240557F55155005
	db	#EA,#FF,#57,#55,#F5,#FF,#57,#7F,#55,#05	; @8E61 EAFF5755F5FF577F5505
	db	#EA,#FF,#FF,#FF,#EA,#AF,#AA,#02	; @8E6B EAFFFFFFEAAFAA02


	;; exit fruit paths for maze 2

	db	#87,#8E	; @8E73 878E  #8E87
	db	#12,#00,#00	; @8E75 120000
	db	#8C,#8E	; @8E78 8C8E  #8E8C
	db	#1D,#00,#00	; @8E7A 1D0000
	db	#94,#8E	; @8E7D 948E  #8E94
	db	#21,#00,#00	; @8E7F 210000
	db	#9D,#8E	; @8E82 9D8E  #8E9D
	db	#2C,#00,#00	; @8E84 2C0000
	db	#55,#7F,#55,#D5,#FF	; @8E87 557F55D5FF
	db	#AA,#BF,#AA,#2A,#A0,#EA,#FF,#FF	; @8E8C AABFAA2AA0EAFFFF
	db	#AA,#2A,#A0,#02,#00,#00,#A0,#AA,#02	; @8E94 AA2AA0020000A0AA02
	db	#55,#15,#A0,#2A,#00,#54,#05,#00,#00,#55,#FD	; @8E9D 5515A02A005405000055FD


	;; Maze Table 3

	db	#40,#FC,#D0,#D2,#D2,#D2,#D2,#D2	; @8EA8 40FCD0D2D2D2D2D2
	db	#D2,#D6,#E4,#02,#E7,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D6	; @8EB0 D2D6E402E7D2D2D2D2D2D2D2D2D2D2D6
	db	#D8,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D4,#FC,#DA,#07,#DE,#E4,#0D,#DE	; @8EC0 D8D2D2D2D2D2D2D2D4FCDA07DEE40DDE
	db	#E4,#08,#DC,#FC,#DA,#02,#E6,#E8,#E8,#EA,#02,#DE,#E4,#02,#E6,#E8	; @8ED0 E408DCFCDA02E6E8E8EA02DEE402E6E8
	db	#E8,#EA,#02,#E6,#E8,#E8,#E8,#EA,#02,#E7,#EB,#02,#E6,#EA,#02,#E6	; @8EE0 E8EA02E6E8E8E8EA02E7EB02E6EA02E6
	db	#EA,#02,#DC,#FC,#DA,#02,#DE,#F3,#E9,#EB,#02,#E7,#EB,#02,#E7,#E9	; @8EF0 EA02DCFCDA02DEF3E9EB02E7EB02E7E9
	db	#F5,#E4,#02,#E7,#E9,#E9,#F5,#E4,#05,#DE,#E4,#02,#DE,#E4,#02,#DC	; @8F00 F5E402E7E9E9F5E405DEE402DEE402DC
	db	#FC,#DA,#02,#DE,#E4,#09,#DE,#E4,#05,#DE,#E4,#02,#E6,#E8,#E8,#F4	; @8F10 FCDA02DEE409DEE405DEE402E6E8E8F4
	db	#E4,#02,#DE,#E4,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#E6,#E8,#E8,#E8	; @8F20 E402DEE402DCFCDA02DEE402E6E8E8E8
	db	#E8,#EA,#02,#E7,#EB,#02,#E6,#EA,#02,#E7,#EB,#02,#E7,#E9,#E9,#E9	; @8F30 E8EA02E7EB02E6EA02E7EB02E7E9E9E9
	db	#EB,#02,#E7,#EB,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#E7,#E9,#E9,#E9	; @8F40 EB02E7EB02DCFCDA02DEE402E7E9E9E9
	db	#F5,#E4,#05,#DE,#E4,#0E,#DC,#FC,#DA,#02,#DE,#E4,#06,#DE,#E4,#02	; @8F50 F5E405DEE40EDCFCDA02DEE406DEE402
	db	#E6,#E8,#E8,#F4,#E4,#02,#E6,#E8,#E8,#E8,#EA,#02,#E6,#E8,#E8,#E8	; @8F60 E6E8E8F4E402E6E8E8E8EA02E6E8E8E8
	db	#E8,#E8,#F4,#FC,#DA,#02,#E7,#EB,#02,#E6,#E8,#EA,#02,#E7,#EB,#02	; @8F70 E8E8F4FCDA02E7EB02E6E8EA02E7EB02
	db	#E7,#E9,#E9,#E9,#EB,#02,#DE,#F3,#E9,#E9,#EB,#02,#DE,#F3,#E9,#E9	; @8F80 E7E9E9E9EB02DEF3E9E9EB02DEF3E9E9
	db	#E9,#E9,#F5,#FC,#DA,#05,#DE,#C0,#E4,#0B,#DE,#E4,#05,#DE,#E4,#05	; @8F90 E9E9F5FCDA05DEC0E40BDEE405DEE405
	db	#DC,#FC,#FA,#E8,#E8,#EA,#02,#DE,#C0,#E4,#02,#E6,#EA,#02,#EC,#D3	; @8FA0 DCFCFAE8E8EA02DEC0E402E6EA02ECD3
	db	#D3,#D3,#EE,#02,#DE,#E4,#02,#E6,#EA,#02,#DE,#E4,#02,#E6,#EA,#02	; @8FB0 D3D3EE02DEE402E6EA02DEE402E6EA02
	db	#DC,#FC,#FB,#E9,#E9,#EB,#02,#E7,#E9,#EB,#02,#DE,#E4,#02,#DC,#FC	; @8FC0 DCFCFBE9E9EB02E7E9EB02DEE402DCFC
	db	#FC,#FC,#DA,#02,#E7,#EB,#02,#DE,#E4,#02,#E7,#EB,#02,#DE,#E4,#02	; @8FD0 FCFCDA02E7EB02DEE402E7EB02DEE402
	db	#DC,#FC,#DA,#09,#DE,#E4,#02,#F0,#FC,#FC,#FC,#DA,#05,#DE,#E4,#05	; @8FE0 DCFCDA09DEE402F0FCFCFCDA05DEE405
	db	#DE,#E4,#02,#DC,#FC,#DA,#02,#E6,#E8,#E8,#E8,#E8,#EA,#02,#DE,#E4	; @8FF0 DEE402DCFCDA02E6E8E8E8E8EA02DEE4
	db	#02,#CE,#FC,#FC,#FC,#DA,#02,#E6,#E8,#E8,#F4,#E4,#02,#E6,#E8,#E8	; @9000 02CEFCFCFCDA02E6E8E8F4E402E6E8E8
	db	#F4,#E4,#02,#DC,#00,#00,#00,#00	; @9010 F4E402DC00000000

	;; Pellet table for maze 3

	db	#62,#01,#02,#01,#01,#03,#01,#01	; @9018 6201020101030101
	db	#01,#01,#01,#01,#01,#01,#01,#01,#01,#04,#01,#01,#01,#01,#01,#04	; @9020 01010101010101010104010101010104
	db	#05,#03,#0B,#03,#03,#03,#04,#05,#03,#0B,#01,#01,#01,#03,#03,#04	; @9030 05030B0303030405030B010101030304
	db	#03,#01,#01,#01,#01,#01,#0B,#06,#03,#04,#03,#10,#06,#03,#04,#03	; @9040 0301010101010B060304031006030403
	db	#10,#01,#01,#01,#01,#01,#01,#01,#01,#01,#04,#03,#01,#01,#01,#01	; @9050 10010101010101010101040301010101
	db	#0F,#0A,#03,#04,#0F,#0A,#01,#01,#01,#04,#0C,#01,#01,#01,#03,#01	; @9060 0F0A03040F0A010101040C0101010301
	db	#01,#01,#07,#04,#0C,#03,#03,#03,#07,#04,#0C,#03,#03,#03,#04,#01	; @9070 010107040C03030307040C0303030401
	db	#01,#01,#01,#01,#01,#01,#0C,#03,#01,#01,#01,#03,#04,#07,#15,#04	; @9080 0101010101010C030101010304071504
	db	#07,#15,#04,#01,#01,#01,#01,#01,#01,#01,#0C,#03,#01,#01,#01,#03	; @9090 071504010101010101010C0301010103
	db	#07,#04,#0C,#03,#03,#03,#07,#04,#0C,#03,#03,#03,#04,#01,#01,#01	; @90A0 07040C03030307040C03030304010101
	db	#04,#0C,#01,#01,#01,#03,#01,#01,#01,#04,#03,#04,#0F,#0A,#03,#01	; @90B0 040C010101030101010403040F0A0301
	db	#01,#01,#01,#0F,#0A,#03,#10,#01,#01,#01,#01,#01,#01,#01,#01,#01	; @90C0 0101010F0A0310010101010101010101
	db	#04,#03,#10,#06,#03,#04,#03,#01,#01,#01,#01,#01,#0B,#06,#03,#04	; @90D0 0403100603040301010101010B060304
	db	#05,#03,#0B,#01,#01,#01,#03,#03,#04,#05,#03,#0B,#03,#03,#03,#04	; @90E0 05030B01010103030405030B03030304
	db	#01,#02,#01,#01,#03,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01	; @90F0 01020101030101010101010101010101
	db	#04,#01,#01,#01,#01,#01,#00,#00,#00	; @9100 040101010101000000

	;; number of pellets to eat for maze 3

	db	#F2	; @9109 F2  F2 = 242 decimal

	;; destination table for maze 3

	db	#40,#2D	; @910A 402D  column 2d, row 40 (bottom center)
	db	#1D,#22	; @910C 1D22  column 22, row 1D (top right)
	db	#1D,#39	; @910E 1D39  column 39, row 1D (top left)
	db	#40,#20	; @9110 4020  column 20, row 40 (bottom right)

	;; Power Pellet Table 3

	db	#64,#40	; @9112 6440  #4064
	db	#78,#40	; @9114 7840  #4078
	db	#84,#43	; @9116 8443  #4384
	db	#98,#43	; @9118 9843  #4398

	;; entrance fruit paths for maze 3:  #911A-9141

	db	#2E,#91	; @911A 2E91  #912E
	db	#15,#54,#0C	; @911C 15540C
	db	#34,#91	; @911F 3491  #9134
	db	#1E,#54,#F4	; @9121 1E54F4
	db	#34,#91	; @9124 3491  #9134
	db	#1E,#54,#F4	; @9126 1E54F4
	db	#3C,#91	; @9129 3C91  #913C
	db	#15,#54,#0C	; @912B 15540C

	db	#EA,#FF,#AB,#FA,#AA,#AA	; @912E EAFFABFAAAAA
	db	#EA,#FF,#57,#55,#55,#D5,#57,#55	; @9134 EAFF575555D55755
	db	#AA,#AA,#BF,#FA	; @913C AAAABFFA

	;; exit fruit paths for maze 3

	; ;; gap-fill from golden boots $9140-$9141
	db	#BF,#AA		; @9140
	db	#56,#91	; @9142 5691  #9156
	db	#22,#00,#00	; @9144 220000
	db	#5F,#91	; @9147 5F91  #915F
	db	#25,#00,#00	; @9149 250000
	db	#5F,#91	; @914C 5F91  #915F
	db	#25,#00,#00	; @914E 250000
	db	#6F,#91	; @9151 6F91  #916F
	db	#28,#00,#00	; @9153 280000

	db	#05,#00,#00,#54,#05,#54,#7F,#F5,#0B	; @9156 0500005405547FF50B
	db	#0A,#00,#00,#A8,#0A,#A8,#BF,#FA,#AB,#AA,#AA,#82,#AA,#00,#A0,#AA	; @915F 0A0000A80AA8BFFAABAAAA82AA00A0AA
	db	#55,#41,#55,#00,#A0,#02,#40,#F5,#57,#BF	; @916F 55415500A00240F557BF


	;; Maze Table 4

	db	#40,#FC,#D0,#D2,#D2,#D2,#D2	; @9179 40FCD0D2D2D2D2
	db	#D2,#D2,#D2,#D2,#D4,#FC,#FC,#DA,#02,#DE,#E4,#02,#DC,#FC,#FC,#FC	; @9180 D2D2D2D2D4FCFCDA02DEE402DCFCFCFC
	db	#FC,#D0,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D4,#FC,#DA,#09,#DC,#FC,#FC	; @9190 FCD0D2D2D2D2D2D2D2D4FCDA09DCFCFC
	db	#DA,#02,#DE,#E4,#02,#DC,#FC,#FC,#FC,#FC,#DA,#08,#DC,#FC,#DA,#02	; @91A0 DA02DEE402DCFCFCFCFCDA08DCFCDA02
	db	#E6,#E8,#E8,#E8,#E8,#EA,#02,#E7,#D2,#D2,#EB,#02,#DE,#E4,#02,#E7	; @91B0 E6E8E8E8E8EA02E7D2D2EB02DEE402E7
	db	#D2,#D2,#D2,#D2,#EB,#02,#E6,#E8,#E8,#E8,#EA,#02,#DC,#FC,#DA,#02	; @91C0 D2D2D2D2EB02E6E8E8E8EA02DCFCDA02
	db	#E7,#E9,#E9,#E9,#F5,#E4,#07,#DE,#E4,#09,#DE,#F3,#E9,#E9,#EB,#02	; @91D0 E7E9E9E9F5E407DEE409DEF3E9E9EB02
	db	#DC,#FC,#DA,#06,#DE,#E4,#02,#E6,#EA,#02,#E6,#E8,#F4,#F2,#E8,#EA	; @91E0 DCFCDA06DEE402E6EA02E6E8F4F2E8EA
	db	#02,#E6,#E8,#E8,#EA,#02,#DE,#E4,#05,#DC,#FC,#DA,#02,#E6,#E8,#EA	; @91F0 02E6E8E8EA02DEE405DCFCDA02E6E8EA
	db	#02,#E7,#EB,#02,#DE,#E4,#02,#E7,#E9,#E9,#E9,#E9,#EB,#02,#E7,#E9	; @9200 02E7EB02DEE402E7E9E9E9E9EB02E7E9
	db	#F5,#E4,#02,#E7,#EB,#02,#E6,#EA,#02,#DC,#FC,#DA,#02,#DE,#C0,#E4	; @9210 F5E402E7EB02E6EA02DCFCDA02DEC0E4
	db	#05,#DE,#E4,#0B,#DE,#E4,#05,#DE,#E4,#02,#DC,#FC,#DA,#02,#DE,#C0	; @9220 05DEE40BDEE405DEE402DCFCDA02DEC0
	db	#E4,#02,#E6,#E8,#E8,#F4,#F2,#E8,#E8,#EA,#02,#E6,#E8,#E8,#E8,#EA	; @9230 E402E6E8E8F4F2E8E8EA02E6E8E8E8EA
	db	#02,#DE,#E4,#02,#E6,#E8,#E8,#F4,#E4,#02,#DC,#FC,#DA,#02,#E7,#E9	; @9240 02DEE402E6E8E8F4E402DCFCDA02E7E9
	db	#EB,#02,#E7,#E9,#E9,#F5,#F3,#E9,#E9,#EB,#02,#E7,#E9,#E9,#F5,#E4	; @9250 EB02E7E9E9F5F3E9E9EB02E7E9E9F5E4
	db	#02,#E7,#EB,#02,#E7,#E9,#E9,#F5,#E4,#02,#DC,#FC,#DA,#09,#DE,#E4	; @9260 02E7EB02E7E9E9F5E402DCFCDA09DEE4
	db	#08,#DE,#E4,#08,#DE,#E4,#02,#DC,#FC,#DA,#02,#E6,#E8,#E8,#E8,#E8	; @9270 08DEE408DEE402DCFCDA02E6E8E8E8E8
	db	#EA,#02,#DE,#E4,#02,#EC,#D3,#D3,#D3,#EE,#02,#DE,#E4,#02,#E6,#E8	; @9280 EA02DEE402ECD3D3D3EE02DEE402E6E8
	db	#E8,#E8,#EA,#02,#DE,#E4,#02,#DC,#FC,#DA,#02,#DE,#F3,#E9,#E9,#E9	; @9290 E8E8EA02DEE402DCFCDA02DEF3E9E9E9
	db	#EB,#02,#E7,#EB,#02,#DC,#FC,#FC,#FC,#DA,#02,#E7,#EB,#02,#E7,#E9	; @92A0 EB02E7EB02DCFCFCFCDA02E7EB02E7E9
	db	#E9,#F5,#E4,#02,#E7,#EB,#02,#DC,#FC,#DA,#02,#DE,#E4,#09,#F0,#FC	; @92B0 E9F5E402E7EB02DCFCDA02DEE409F0FC
	db	#FC,#FC,#DA,#08,#DE,#E4,#05,#DC,#FC,#DA,#02,#DE,#E4,#02,#E6,#E8	; @92C0 FCFCDA08DEE405DCFCDA02DEE402E6E8
	db	#E8,#E8,#E8,#EA,#02,#CE,#FC,#FC,#FC,#DA,#02,#E6,#E8,#E8,#E8,#EA	; @92D0 E8E8E8EA02CEFCFCFCDA02E6E8E8E8EA
	db	#02,#DE,#E4,#02,#E6,#E8,#E8,#F4,#00,#00,#00,#00	; @92E0 02DEE402E6E8E8F400000000

	;; Pellet table for maze 4

	db	#62,#01,#02,#01	; @92EC 62010201
	db	#01,#01,#01,#0F,#01,#01,#01,#02,#01,#04,#07,#0F,#06,#04,#07,#01	; @92F0 0101010F010101020104070F06040701
	db	#01,#01,#07,#01,#01,#01,#01,#01,#06,#04,#01,#01,#01,#01,#03,#03	; @9300 01010701010101010604010101010303
	db	#07,#05,#03,#01,#01,#01,#04,#04,#03,#03,#07,#05,#03,#03,#04,#04	; @9310 07050301010104040303070503030404
	db	#01,#01,#01,#03,#01,#01,#01,#01,#01,#01,#01,#01,#01,#03,#01,#01	; @9320 01010103010101010101010101030101
	db	#01,#03,#04,#04,#0F,#03,#06,#04,#04,#0F,#03,#06,#04,#01,#01,#01	; @9330 010304040F030604040F030604010101
	db	#01,#01,#01,#01,#0C,#01,#01,#01,#01,#01,#01,#03,#04,#07,#12,#03	; @9340 010101010C0101010101010304071203
	db	#04,#07,#12,#03,#04,#03,#01,#01,#01,#01,#12,#01,#01,#01,#04,#03	; @9350 04071203040301010101120101010403
	db	#16,#07,#03,#16,#07,#03,#01,#01,#01,#01,#12,#01,#01,#01,#04,#07	; @9360 16070316070301010101120101010407
	db	#12,#03,#04,#07,#12,#03,#04,#01,#01,#01,#01,#01,#01,#01,#0C,#01	; @9370 12030407120304010101010101010C01
	db	#01,#01,#01,#01,#01,#03,#04,#04,#0F,#03,#06,#04,#04,#0F,#03,#06	; @9380 01010101010304040F030604040F0306
	db	#04,#04,#01,#01,#01,#03,#01,#01,#01,#01,#01,#01,#01,#01,#01,#03	; @9390 04040101010301010101010101010103
	db	#01,#01,#01,#03,#04,#04,#03,#03,#07,#05,#03,#03,#04,#01,#01,#01	; @93A0 01010103040403030705030304010101
	db	#01,#03,#03,#07,#05,#03,#01,#01,#01,#04,#07,#01,#01,#01,#07,#01	; @93B0 01030307050301010104070101010701
	db	#01,#01,#01,#01,#06,#04,#07,#0F,#06,#04,#01,#02,#01,#01,#01,#01	; @93C0 010101010604070F0604010201010101
	db	#0F,#01,#01,#01,#02,#01,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @93D0 0F010101020100000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00	; @93E0 00000000000000000000000000000000
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00	; @93F0 000000000000000000

	;; number of pellets to eat for maze 4

	db	#EE	; @93F9 EE  EE = 238 decimal

	;; Power Pellet Table for maze 4
  
	db	#64,#40	; @93FA 6440  #4064
	db	#7C,#40	; @93FC 7C40  #407C
	db	#84,#43	; @93FE 8443  #4384
	db	#9C,#43	; @9400 9C43  #439C

	;; destination table for maze 4

	db	#1D,#22	; @9402 1D22  column 22, row 1D (top right)
	db	#40,#20	; @9404 4020  column 20, row 40 (bottom right)
	db	#1D,#39	; @9406 1D39  column 39, row 1D (top left)
	db	#40,#3B	; @9408 403B  column 3B, row 40 (bottom left)

	;; entrance fruit paths for maze 4:  #940A - #943B

	db	#1E,#94	; @940A 1E94  #941E
	db	#14,#8C,#0C	; @940C 148C0C
	db	#23,#94	; @940F 2394  #9423
	db	#1D,#8C,#F4	; @9411 1D8CF4
	db	#2B,#94	; @9414 2B94  #942B
	db	#2A,#74,#F4	; @9416 2A74F4
	db	#36,#94	; @9419 3694  #9436
	db	#15,#74,#0C	; @941B 15740C
	db	#80,#AA,#BE,#FA,#AA	; @941E 80AABEFAAA
	db	#00,#50,#FD,#55,#F5,#D5,#57,#55	; @9423 0050FD55F5D55755
	db	#EA,#FF,#57,#D5,#5F,#FD,#15,#50,#01,#50,#55	; @942B EAFF57D55FFD1550015055
	db	#EA,#AF,#FE,#2A,#A8,#AA	; @9436 EAAFFE2AA8AA


	;; exit fruit paths for maze 4

	db	#50,#94	; @943C 5094  #9450
	db	#15,#00,#00	; @943E 150000
	db	#56,#94	; @9441 5694  #9456
	db	#18,#00,#00	; @9443 180000
	db	#5C,#94	; @9446 5C94  #945C
	db	#19,#00,#00	; @9448 190000
	db	#63,#94	; @944B 6394  #9463
	db	#1C,#00,#00	; @944D 1C0000

	db	#55,#50,#41,#55,#FD,#AA	; @9450 55504155FDAA
	db	#AA,#A0,#82,#AA,#FE,#AA	; @9456 AAA082AAFEAA
	db	#AA,#AF,#02,#2A,#A0,#AA,#AA	; @945C AAAF022AA0AAAA
	db	#55,#5F,#01,#00,#50,#55,#BF	; @9463 555F01005055BF


	; select the proper maze
	; called from #241C
	

j_946a:
	ld      hl,#9474		; @946A 217494  load HL with address of maze table number
	call    j_94bd		; @946D CDBD94  load BC based on the maze
	ld      hl,#4000		; @9470 210040  load HL with start of video RAM
	ret		; @9473 C9  return

	; maze reference table

	db	#C1,#88	; @9474 C188  #88C1 for maze 1
	db	#AE,#8B	; @9476 AE8B  #8BAE for maze 2
	db	#A8,#8E	; @9478 A88E  #8EA8 for maze 3
	db	#79,#91	; @947A 7991  #9179 for maze 4


	; pellet crossreference routine patch
	; arrive from #244b

j_947c:
	ld      hl,#2453		; @947C 215324  load HL with return address
	jr      j_9484		; @947F 1803  skip next step

	; arrive here from #248A

j_9481:
	ld      hl,#2492		; @9481 219224  load HL with return address

j_9484:
	push    hl		; @9484 E5  push HL to stack for return address (either #2453 or #2492)
	ld      hl,#9499		; @9485 219994  load HL with pellet map lookup table address
	call    j_94bd		; @9488 CDBD94  load BC with value based on the level
	ld      iy,#0000		; @948B FD210000  IY = #0000
	add     iy,bc		; @948F FD09  add BC into IY
	ld      hl,#4000		; @9491 210040  load HL with start of video RAM
	ld ix,pill_bitmap		; @9494 DD21164E  load IX with pellet entries
	ret		; @9498 C9  return (returns to either #2453 or #2492)

	; Pellet map lookup table

	db	#3B,#8A	; @9499 3B8A  #8A3B	; pellets for maze 1
	; ;; gap-fill from golden boots $949B-$949B
	db	#27		; @949B
	db	#8D,#18		; @949C 278D  #8D27	; pellets for maze 2
;	db	#18,#90	; @949D 1890  #9018	; pellets for maze 3
	; ;; gap-fill from golden boots $949E-$949E
	db	#90		; @949E
	db	#EC,#92	; @949F EC92  #92EC	; pellets for maze 4

	;; check the number of pellets to see if the board is cleared

;	push    bc		; @94A0 C5  junk ?

j_94a1:
	push 	bc		; @94A1 C5  save BC
	ld      hl,#94b5		; @94A2 21B594  load HL with pellet count table
	call    j_94bd		; @94A5 CDBD94  load BC based on board #
	ld      a,(bc)		; @94A8 0A  load A with number of pellets needed to eat
	ld      b,a		; @94A9 47  copy to B
	ld      a,(dots_eaten)		; @94AA 3A0E4E  load A with # of pellets eaten
	cp      b		; @94AD B8  is the board done ?
	pop     bc		; @94AE C1  restore BC
	jp      nz,j_08eb		; @94AF C2EB08  if not done, return to the game loop
	jp      j_08e5		; @94B2 C3E508  else return to the program and signal end of level

	; lookup table for pellet count information

	db	#2C,#8B	; @94B5 2C8B  #8B2C holds number of pellets for maze 1
	db	#17,#8E	; @94B7 178E  #8E17 holds number of pellets for maze 2
;	db	#09,#91	; @94B8 0991  #9109 holds number of pellets for maze 3
	; ;; gap-fill from golden boots $94B9-$94BA
	db	#09,#91		; @94B9
	db	#F9,#93	; @94BB F993  #93F9 holds number of pellets for maze 4

; Used to determine which maze to draw and other things
; load BC with a value based on the level and the value already loaded into HL.
; This keeps the game cycling between the 3rd and 4th mazes, which appear on levels 6 through 14.

j_94bd:
	LD	A,(level_number)		; @94BD 3A134E  Load A with level number
	PUSH	HL		; @94C0 E5  Save HL
	CP	#0D		; @94C1 FE0D  Is level number > #0D (13 decimal) ?
	JP	P,j_94d4		; @94C3 F2D494  Yes, jump to subroutine to makes the result in A become between 0 and #0D [Bug, should be JP NC, not JP P]
j_94c6:
	LD	HL,#94DF		; @94C6 21DF94  No, load HL with map order table
	RST	#10		; @94C9 D7  A now contains the map number
	POP	HL		; @94CA E1  Get HL that was saved earlier 
	ADD	A,A		; @94CB 87  A := A*2
	LD	C,A		; @94CC 4F  Load C with A
	LD	B,#00		; @94CD 0600  Load B with #00
	ADD	HL,BC		; @94CF 09  Add this value into HL
	LD	C,(HL)		; @94D0 4E  Load C with table value from HL
	INC	HL		; @94D1 23  Next table value
	LD	B,(HL)		; @94D2 46  Load B with table value from HL
	RET		; @94D3 C9  Return

j_94d4:
	SUB 	#0D		; @94D4 D60D  Subtract #0D (13 decimal) from A
j_94d6:
	SUB 	#08		; @94D6 D608  Subtract #08 from A. Is A > 0 ?
	JP 	P,j_94d6		; @94D8 F2D694  Yes, then repeat previous subtraction [Bug, should be JP NC, not JP P]
	ADD 	A,#0D		; @94DB C60D  No, add #0D (13 decimal) back into A
	JR 	j_94c6		; @94DD 18E7  Return to program

	;; map order table.  order that boards are played, used in subroutine above at #94C6

	db	#00,#00	; @94DF 0000  1st & 2nd boards use maze 1
	db	#01,#01,#01	; @94E1 010101  3rd, 4th, 5th boards use maze 2
	db	#02,#02,#02,#02	; @94E4 02020202  boards 6 through 9 use maze 3
	db	#03,#03,#03,#03	; @94E8 03030303  boards 10 through 13 use maze 4

	;; draw routine for the ms-pac power pellets
	; arrive from #2472

j_94ec:
	ld      hl,#951c		; @94EC 211C95  load HL with power pellet lookup table
	call    j_94bd		; @94EF CDBD94  load BC with value based on level from the table
	ld de,power_pill_data		; @94F2 11344E  load DE with pellet graphic table data
	ld      l,c		; @94F5 69
	ld      h,b		; @94F6 60  HL now has BC = table start

j_94f7:
	ld      c,(hl)		; @94F7 4E  load C with first data
	inc     hl		; @94F8 23  next location
	ld      b,(hl)		; @94F9 46  load B with second data.  BC now has screen location to draw power pellet
	inc     hl		; @94FA 23  next location
	ld      a,(de)		; @94FB 1A  load A with pellet graphic data (should always be #14)
	ld      (bc),a		; @94FC 02  draw the power pellet onscreen
	inc     de		; @94FD 13  next location
	ld      a,#03		; @94FE 3E03  A := #03
	and     e		; @9500 A3  mask with E
	jr      nz,j_94f7		; @9501 20F4  if not zero, loop again
	ret		; @9503 C9  return

	; ms pac man patch for pellet routine
	; jumped from #24b4
	; arrive here after ms. pac has died
	; this sub is identical to subroutine above, except it saves the power pellets instead of drawing them

j_9504:
	ld      hl,#951c		; @9504 211C95  load HL with power pellet lookup table
	call    j_94bd		; @9507 CDBD94  load BC with value based on level from the table
	ld de,power_pill_data		; @950A 11344E  load DE with pellet graphic table data
	ld      l,c		; @950D 69
	ld      h,b		; @950E 60  HL now has BC = table start

j_950f:
	ld      c,(hl)		; @950F 4E
	inc     hl		; @9510 23
	ld      b,(hl)		; @9511 46  BC now has screen loaciton of power pellet
	inc     hl		; @9512 23
	ld      a,(bc)		; @9513 0A  load A with power pellet from screen
	ld      (de),a		; @9514 12  save into DE
	inc     de		; @9515 13  next location
	ld      a,#03		; @9516 3E03  A := #03
	and     e		; @9518 A3  mask with E
	jr      nz,j_950f		; @9519 20F4  if not zero, loop again
	ret		; @951B C9  return (to #0915)

	; power pellet lookup table per map

	db	#35,#8B	; @951C 358B  #8B35	; maze 1 power pellet address table
	db	#20,#8E	; @951E 208E  #8E20	; maze 2 power pellet address table
	db	#12,#91	; @9520 1291  #9112	; maze 3 power pellet address table
	db	#FA,#93	; @9522 FA93  #93FA	; maze 4 power pellet address table

; this subroutine flashes the power pellets
; arrive from #0C21

j_9524:
	push    bc		; @9524 C5  save BC
	push    de		; @9525 D5  save DE
	ld      hl,#951c		; @9526 211C95  load HL with power pellet lookup table start
	call    j_94bd		; @9529 CDBD94  load BC with address of power pellet table based on map played
	ld      h,b		; @952C 60
	ld      l,c		; @952D 69  load HL with BC
	ld      e,(hl)		; @952E 5E
	inc     hl		; @952F 23
	ld      d,(hl)		; @9530 56  load DE with the screen location of the first power pellet
	ex      de,hl		; @9531 EB  Copy to HL
	set     2,h		; @9532 CBD4  convert the screen address to a color address

	ld      a,(#447e)		; @9534 3A7E44  load A with the graphic for power pellets
	cp      (hl)		; @9537 BE  compare with value in HL
	jr      nz,j_953c		; @9538 2002  if not zero then skip next step
	ld      a,#00		; @953A 3E00  else A := #00 (used for clearing the power pellets every other time)

j_953c:
	ld      (hl),a		; @953C 77  flash the power pellet
	ex      de,hl		; @953D EB
	inc     hl		; @953E 23
	ld      e,(hl)		; @953F 5E
	inc     hl		; @9540 23
	ld      d,(hl)		; @9541 56
	set     2,d		; @9542 CBD2
	ld      (de),a		; @9544 12  flash the power pellet
	inc     hl		; @9545 23
	ld      e,(hl)		; @9546 5E
	inc     hl		; @9547 23
	ld      d,(hl)		; @9548 56
	set     2,d		; @9549 CBD2
	ld      (de),a		; @954B 12  flash the power pellet
	inc     hl		; @954C 23
	ld      e,(hl)		; @954D 5E
	inc     hl		; @954E 23
	ld      d,(hl)		; @954F 56
	set     2,d		; @9550 CBD2
	ld      (de),a		; @9552 12  flash the power pellet
	pop     de		; @9553 D1  restore DE
	pop     bc		; @9554 C1  restore BC
	ld      a,#10		; @9555 3E10  A := #10
	cp      (hl)		; @9557 BE
	ret		; @9558 C9  return (to #0906)

; arrive here for blue ghost logic when random mode enabled from #27BB

j_9559:
	ld      a,(blue_dir)		; @9559 3A2E4D  load A with blue ghost (inky) orientation
	jr      j_9561		; @955C 1803  skip ahead to pick a destination

; arrive here for orange ghost logic when random mode enabled from #2803

j_955e:
	ld      a,(orange_dir)		; @955E 3A2F4D  load A with orange ghost direction

	;; pick a quadrant for the destination of a ghost, saved into DE

j_9561:
	push    af		; @9561 F5  save AF
	push    bc		; @9562 C5  save BC
	push    hl		; @9563 E5  save HL
	ld      hl,#9578		; @9564 217895  load HL with ghost destination table
	call    j_94bd		; @9567 CDBD94  load BC based on level and HL
	ld      l,c		; @956A 69
	ld      h,b		; @956B 60  load HL with BC
	ld      a,r		; @956C ED5F  load A with random number from refresh register
	and     #06		; @956E E606  mask bits.  result is either 0,2,4, or 6
	rst     #10		; @9570 D7  HL := HL + A, A := HL.  loads first value from table
	ld      e,a		; @9571 5F  store into E
	inc     hl		; @9572 23  next table entry
	ld      d,(hl)		; @9573 56  load D with this value
	pop     hl		; @9574 E1  restore HL
	pop     bc		; @9575 C1  restore BC
	pop     af		; @9576 F1  restore AF
	ret		; @9577 C9  return

	; ghost destination table

	db	#2D,#8B	; @9578 2D8B  #8B2D	; 1st maze
	db	#18,#8E	; @957A 188E  #8E18	; 2nd maze
	db	#0A,#91	; @957C 0A91  #910A	; 3rd maze
	db	#02,#94	; @957E 0294  #9402	; 4th maze

	; maze color code (jump from 24dd)

j_9580:
	jp      z,j_24e1		; @9580 CAE124  if zero then return immediately, used for color white flashing at end of level
	ld      a,(game_mode_sub1)		; @9583 3A024E  load A with main routine 1, subroutine #
	and     a		; @9586 A7  == #00 ?  
	jr      z,j_9590		; @9587 2807  yes, skip ahead to select the color to use based on the board number
	cp      #10		; @9589 FE10  == #10 ?  Is the game in the demo maze ?
	ld      a,#01		; @958B 3E01  load A with 1.  used to properly color the midway logo
	jp      nz,j_24e1		; @958D C2E124  no, return to program

; controls the color of the mazes

j_9590:
	LD 	A,(level_number)		; @9590 3A134E  Load A with board number
	CP 	#15		; @9593 FE15  Is this board > #15 (21 decimal) ?
	JP 	P,j_95a3		; @9595 F2A395  Yes, go and bring it back down to a number between #5 and #15 [Bug.  should JP NC, not JP P]
j_9598:
	LD 	C,A		; @9598 4F  Load C with A
	LD 	B,#00		; @9599 0600  Load B with zero
	LD 	HL,#95AE		; @959B 21AE95  load HL with map color table
	ADD 	HL,BC		; @959E 09  Add the offset computed from level
	LD 	A,(HL)		; @959F 7E  A now contains the maze color
	JP 	j_24e1		; @95A0 C3E124  Jump back to program

j_95a3:
	SUB 	#15		; @95A3 D615  Subtract #15 from A
j_95a5:
	SUB 	#10		; @95A5 D610  Subtract #10 from A
	JP 	P,j_95a5		; @95A7 F2A595  Did we just go negative? No, go back and subtract another 10.  [Bug.  should be JP NC, not JP P]
	ADD 	A,#15		; @95AA C615  Yes, Add #15 back into A
	JR 	j_9598		; @95AC 18EA  Return


	;; color palette table for the first 21 mazes

	db	#1D,#1D	; @95AE 1D1D  color code for levels 1 and 2
	db	#16,#16,#16	; @95B0 161616  color code for levels 3, 4, 5
	db	#14,#14,#14,#14	; @95B3 14141414  color code for levels 6 - 9
	db	#07,#07,#07,#07	; @95B7 07070707  color code for levels 10 - 13
	db	#18,#18,#18,#18	; @95BB 18181818  color code for levels 14 - 17
	db	#1D,#1D,#1D,#1D	; @95BF 1D1D1D1D  color code for levels 18 - 21


; sets bit 6 in the color grid of certain screen locations on the first three levels.
; This color bit is ignored when actually coloring the grid, so it is invisible onscreen.
; When a ghost encounters one of these specially painted areas, he slows down.
; This is used to slow down the ghosts when they use the tunnels on these levels. 
; called from #24F9

j_95c3:
	LD 	A,(level_number)		; @95C3 3A134E  Load A with current level number
	CP 	#03		; @95C6 FE03  Is A < #03 ?
	JP 	P,j_2534		; @95C8 F23425  No, jump back to program [bug.  should be JP NC, not JP P.]
	LD 	HL,#95DF		; @95CB 21DF95  Yes, load HL with start of table data address
	CALL 	j_94bd		; @95CE CDBD94  Load BC with either #95DF or #95E1 depending on the level
	LD 	HL,#4400		; @95D1 210044  Load HL with start of color memory
j_95d4:
	LD 	A,(BC)		; @95D4 0A  Load A with the table data
	INC 	BC		; @95D5 03  Set BC to next value in table
	AND 	A		; @95D6 A7  Is A == 0 ?
	JP 	Z,j_2534		; @95D7 CA3425  Yes, jump back to program
	RST 	#10		; @95DA D7  No, load A with table value of (HL + A) and load HL with HL + A
	SET 	6,(HL)		; @95DB CBF6  Sets bit 6 of HL - MAKE tunnel slow for ghosts
	JR 	j_95d4		; @95DD 18F5  Loop back and do again

	db	#3D,#8B	; @95DF 3D8B  #83BD Pointer to table for tunnel data for levels 1 and 2
	db	#28,#8E	; @95E1 288E  #8E28 Pointer to table for tunnel data for level 3


	; called from #23A7 for task = #1C
	; prints text or graphics based on parameter loaded into B

	ld	a,b		; @95E3 78  load A with parameter
	cp	#0A		; @95E4 FE0A  == #0A ?
	call    z,j_960b		; @95E6 CC0B96  Yes, draw the MS PAC MAN graphic which appears between "ADDITIONAL" and "AT 10,000 pts"
	cp      #0b		; @95E9 FE0B  == #0B ?
	call    z,j_95f6		; @95EB CCF695  yes, draw midway logo and copyright text
	cp      #06		; @95EE FE06  == #06 ?   ( code for "READY!" )
	call    z,j_963c		; @95F0 CC3C96  yes, clear the intermission indicator
	jp      j_2c5e		; @95F3 C35E2C  jump to print routine

	
j_95f6:
	push    bc		; @95F6 C5  save BC
	push    hl		; @95F7 E5  save HL
	call    j_9642		; @95F8 CD4296  draw the midway logo and copyright text for the 'press start' screen
	pop     hl		; @95FB E1  restore HL
	pop     bc		; @95FC C1  resore BC

	; check for dip switch settings if there are extra lives awarded

	ld      a,(DSW1)		; @95FD 3A8050  load A with Dip switches
	and     #30		; @9600 E630  mask bits
	cp      #30		; @9602 FE30  are bits 4 and 5 on ?   This happens when there is no bonus life awarded.
	ld      a,b		; @9604 78  A := B
	ret     nz		; @9605 C0  no, return

	ld      a,#20		; @9606 3E20  yes, A := #20
	ld      b,#20		; @9608 0620  B := #20
	ret		; @960A C9  return (to #95EE)

	; table subroutine

j_960b:
	push    bc		; @960B C5  save BC
	push    hl		; @960C E5  save HL
	ld      hl,#9616		; @960D 211696  load HL with start of table data
	call    j_9627		; @9610 CD2796  draws the MS PAC MAN graphic which appears between "ADDITIONAL" and "AT 10,000 pts" 
	pop     hl		; @9613 E1  restore HL
	pop     bc		; @9614 C1  restore BC
	ret		; @9615 C9  return

	; table data, used in sub below to draw MS PAC graphic
	; first byte is color, 2nd byte is graphic code, third & fourth are screen locations

	db	#09,#20,#F5,#41	; @9616 0920F541  screen location #41F5
	db	#09,#21,#15,#42	; @961A 09211542  screen location #4215
	db	#09,#22,#F6,#41	; @961E 0922F641  screen location #41F6
	db	#09,#23,#16,#42	; @9622 09231642  screen location #4216
	db	#FF	; @9626 FF

	; subroutine for start button press
	; called from #9610
	; draws the MS PAC MAN which appears between "ADDITIONAL" and "AT 10,000 pts"

j_9627:
	ld      a,(hl)		; @9627 7E  load A with table data
	cp      #FF		; @9628 FEFF  are we done?
	jr      z,j_963b		; @962A 280F  yes, return
	ld      b,a		; @962C 47  else load B with this first data byte
	inc     hl		; @962D 23  next table entry
	ld      a,(hl)		; @962E 7E  load A with next data
	inc     hl		; @962F 23  next table entry
	ld      e,(hl)		; @9630 5E  load E with next data
	inc     hl		; @9631 23  next table entry
	ld      d,(hl)		; @9632 56  load D with next data
	ld      (de),a		; @9633 12  Draws element to screen
	ld      a,b		; @9634 78  load A with B
	set     2,d		; @9635 CBD2  set bit 2 of D.  changes DE to color grid
	ld      (de),a		; @9637 12  store A into color grid
	inc     hl		; @9638 23  next table entry
	jr      j_9627		; @9639 18EC  loop again
j_963b:
	ret		; @963B C9  return

	; called from #95F0.  clears intermission indicator

j_963c:
	ld      a,#00		; @963C 3E00  A := #00
	ld      (intermission_flag),a		; @963E 32004F  clear the intermission indicator
	ret		; @9641 C9  return

    ; draws title screen logo and text (sets as tasks).  called from #95F8

	; this on pac draws the ghost (logo) and CLYDE" text
j_9642:
	rst     #28		; @9642 EF  insert task to draw text "(C) MIDWAY MFG CO"	
	db	#1C,#13	; @9643 1C13

	rst     #28		; @9645 EF  insert task to draw text "1980/1981"
	db	#1C,#35	; @9646 1C35

    ; draws vertical strips of the midway logo starting with the rightmost

	LD	HL,#429A		; @9648 219A42  load HL with start of screen location
	ld      a,#BF		; @964B 3EBF  A := BF = 1st code for midway logo graphic
	and     a		; @964D A7  clear the carry flag
	ld      de,#001d		; @964E 111D00  load DE with offset for each strip
	ld      bc,#0400		; @9651 010004  load BC with offset for color grid

j_9654:
	ld      (hl),a		; @9654 77  draw first element
	add     hl,bc		; @9655 09  add color offset
	ld      (hl),#01		; @9656 3601  color first element
	sbc     hl,bc		; @9658 ED42  remove color offset
	inc     hl		; @965A 23  next location
	sub     #04		; @965B D604  next element
	ld      (hl),a		; @965D 77  draw 2nd element
	add     hl,bc		; @965E 09  add color offset
	ld      (hl),#01		; @965F 3601  color 2nd element
	sbc     hl,bc		; @9661 ED42  remove color offset
	inc     hl		; @9663 23  next location
	sub     #04		; @9664 D604  next element
	ld      (hl),a		; @9666 77  draw 3rd element
	add     hl,bc		; @9667 09  add color offset		
	ld      (hl),#01		; @9668 3601  color 3rd element
	sbc     hl,bc		; @966A ED42  remove color offset
	inc     hl		; @966C 23  next location
	sub     #04		; @966D D604  next element
	ld      (hl),a		; @966F 77  draw 4th element
	add     hl,bc		; @9670 09  add color offset
	ld      (hl),#01		; @9671 3601  color 4th element
	sbc     hl,bc		; @9673 ED42  remove color offset
	add     hl,de		; @9675 19  next strip
	add     a,#0b		; @9676 C60B  add offset
	cp      #BB		; @9678 FEBB  are we done?
	jr      nz,j_9654		; @967A 20D8  No, loop again
	ret		; @967C C9  return

        ;;
        ;; Song pointers. When selecting one song,
        ;; use channels 1 and 2.
        ;;
        ;; song 0x01 : start
        ;; song 0x02 : act 1
        ;; song 0x04 : act 2
        ;; song 0x08 : act 3
        ;;

        ;; channel 2 : jump table to song data

	db	#95,#96	; @967D 9596  #9695	; startup song
	db	#D6,#96	; @967F D696  #96D6	; act 1 song
	db	#58,#3C	; @9681 583C  #3C58	; act 2 song
	db	#4F,#97	; @9683 4F97  #974F	; act 3 song

        ;; channel 1 : jump table to song data

	db	#B6,#96	; @9685 B696  #96B6	; startup song
	db	#19,#97	; @9687 1997  #9719	; act 1 song
	db	#D4,#3B	; @9689 D43B  #3BD4	; act 2 song
	db	#72,#97	; @968B 7297  #9772	; act 3 song

        ;; channel 3 : jump table to song data (nothing here, 9796 = 0xff)

	db	#96,#97,#96,#97,#96,#97,#96,#97	; @968D 9697969796979697

        ;; songs data
        

;; songs data
; if '1' = 0 & '2' = MELODY
; MELODY = 0
; HARMONY = 1

; startup song
;!    !    IF '1' = 0 & '2' = MELODY

;!    TITLE!    "SONATA FOR UNACCOMPANIED VIDEO GAME"

	db	#F1,#00,#F2,#02,#F3,#0A,#F4,#00,#41,#43,#45,#86,#8A,#88,#8B,#6A	; @9695 F100F202F30AF400414345868A888B6A
	db	#6B,#71,#6A,#88,#8B,#6A,#6B,#71,#6A,#6B,#71,#73,#75,#96,#95,#96	; @96A5 6B716A888B6A6B716A6B717375969596
	db	#FF	; @96B5 FF

;.org 0x9695
;	db	#F1,#00,#F2,#02,#F3,#0A,#F4,#00
;	db	#41,#43,#45
;	db	#86,#8A,#88,#8B
;	db	#6A,#6B,#71,#6A,#88,#8B
;	db	#6A,#6B,#71,#6A,#6B,#71,#73,#75
;	db	#96,#95,#96,#FF


; startup song

	db	#F1,#02,#F2,#03,#F3,#0A,#F4,#02,#50,#70,#86,#90,#81,#90,#86,#90	; @96B6 F102F203F30AF4025070869081908690
	db	#68,#6A,#6B,#68,#6A,#68,#66,#6A,#68,#66,#65,#68,#86,#81,#86,#FF	; @96C6 686A6B686A68666A68666568868186FF

; act 1 song

	db	#F1,#00,#F2,#02,#F3,#0A,#F4,#00,#69,#6B,#69,#86,#61,#64,#65,#86	; @96D6 F100F202F30AF400696B698661646586
	db	#86,#64,#66,#64,#61,#69,#6B,#69,#86,#61,#64,#64,#A1,#70,#71,#74	; @96E6 8664666461696B6986616464A1707174
	db	#75,#35,#76,#30,#50,#35,#76,#30,#50,#54,#56,#54,#51,#6B,#69,#6B	; @96F6 753576305035763050545654516B696B
	db	#69,#6B,#91,#6B,#69,#66,#F2,#01,#74,#76,#74,#71,#74,#71,#6B,#69	; @9706 696B916B6966F2017476747174716B69
	db	#A6,#A6,#FF	; @9716 A6A6FF

; act 1 song

	db	#F1,#03,#F2,#03,#F3,#0A,#F4,#02,#70,#66,#70,#46,#50,#86,#90,#70	; @9719 F103F203F30AF4027066704650869070
	db	#66,#70,#46,#50,#86,#90,#70,#66,#70,#46,#50,#86,#90,#70,#61,#70	; @9729 66704650869070667046508690706170
	db	#41,#50,#81,#90,#F4,#00,#A6,#A4,#A2,#A1,#F4,#01,#86,#89,#8B,#81	; @9739 41508190F400A6A4A2A1F40186898B81
	db	#74,#71,#6B,#69,#A6,#FF	; @9749 74716B69A6FF

; act 3 song

	db	#F1,#00,#F2,#02,#F3,#0A,#F4,#00,#65,#64,#65,#88,#67,#88,#61,#63	; @974F F100F202F30AF4006564658867886163
	db	#64,#85,#64,#85,#6A,#69,#6A,#8C,#75,#93,#90,#91,#90,#91,#70,#8A	; @975F 648564856A696A8C759390919091708A
	db	#68,#71,#FF	; @976F 6871FF

; act 3 song

	db	#F1,#02,#F2,#03,#F3,#0A,#F4,#02,#65,#90,#68,#70,#68,#67,#66,#65	; @9772 F102F203F30AF4026590687068676665
	db	#90,#61,#70,#61,#65,#68,#66,#90,#63,#90,#86,#90,#85,#90,#85,#70	; @9782 90617061656866906390869085908570
	db	#86,#68,#65,#FF	; @9792 866865FF

	db	#FF	; @9796 FF


	; something with sprites for cocktail?
	; jump here from #2CC1

j_9797:
	ld      a,(intermission_flag)		; @9797 3A004F  load A with intermission indicator
	cp      #00		; @979A FE00  is an intermission running ?
	jr      z,j_97a9		; @979C 280B  no, skip next 4 steps

	ld de,spr_red_code		; @979E 11024C  yes, load destination DE := #4C02
	ld      hl,#4f50		; @97A1 21504F  load source HL := #4F50
	ld      bc,#000c		; @97A4 010C00  set byte counter to #0C
	ldir		; @97A7 EDB0  copy

j_97a9:
	ld      a,(player_number)		; @97A9 3A094E  load A with current player number:  0=P1, 1=P2
	ld hl,dip_cocktail		; @97AC 21724E  load HL with cocktail mode (0=no, 1=yes)
	and     (hl)		; @97AF A6  mix together.  Is this 2 player and cocktail mode ?
	jr      z,j_97be		; @97B0 280C  no, skip ahead

	ld      a,(spr_pac_code)		; @97B2 3A0A4C  yes, load A with mspac sprite number
	cp      #3f		; @97B5 FE3F  == #3F ?  - end of death animation?
	jr      nz,j_97be		; @97B7 2005  no, skip ahead

	ld      a,#FF		; @97B9 3EFF  yes, A := FF
	ld      (spr_pac_code),a		; @97BB 320A4C  store into mspac sprite number

j_97be:
	ld hl,SONG_TABLE_1		; @97BE 218596  HL := #9685
	jp      j_2cc4		; @97C1 C3C42C  jump back to program


	; unused?

	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF	; @97C4 FFFFFFFFFFFFFFFFFFFFFFFF


; 

; offset    0  1  2  3   4  5  6  7   8  9  a  b   c  d  e  f  0123456789abcdef
;000097d0  47 45 4e 45  52 41 4c 20  43 4f 4d 50  55 54 45 52  GENERAL COMPUTER
;000097e0  20 20 43 4f  52 50 4f 52  41 54 49 4f  4e 20 20 20    CORPORATION
;000097f0  48 65 6c 6c  6f 2c 20 4e  61 6b 61 6d  75 72 61 21  Hello, Nakamura!

; above is the easter egg that GCC put into the rom.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;;  9800 - 9fff is not used
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


	;; unknown / unused
	; this seems to be a copy of the code from #8800-8840

	; ;; gap-fill from golden boots $97D0-$97FF
	db	#47,#45,#4E,#45,#52,#41,#4C,#20,#43,#4F,#4D,#50,#55,#54,#45,#52		; @97D0
	db	#20,#20,#43,#4F,#52,#50,#4F,#52,#41,#54,#49,#4F,#4E,#20,#20,#20		; @97E0
	db	#48,#65,#6C,#6C,#6F,#2C,#20,#4E,#61,#6B,#61,#6D,#75,#72,#61,#21		; @97F0
	add  a,d		; @9800 82
	adc  a,e		; @9801 8B
	ld   (hl),e		; @9802 73
	adc  a,(hl)		; @9803 8E
	ld   b,d		; @9804 42
	sub  c		; @9805 91
	inc  a		; @9806 3C
	sub  h		; @9807 94
	jp   m,j_55ff		; @9808 FAFF55
	ld   d,l		; @980B 55
	ld   bc,#AA80		; @980C 0180AA
	ld   (bc),a		; @980F 02
	ld   a,#00		; @9810 3E00
	ld   (spr_fruit_color),a		; @9812 320D4C
	jp   $1000		; @9815 C30010

	push af		; @9818 F5
	ld   de,(fruit_pos_lo)		; @9819 ED5BD24D
	ld   a,h		; @981D 7C
	sub  d		; @981E 92
	add  a,#03		; @981F C603
	cp   #06		; @9821 FE06
	jr   nc,j_983d		; @9823 3018

	ld   a,l		; @9825 7D
	sub  e		; @9826 93
	add  a,#03		; @9827 C603
	cp   #06		; @9829 FE06
	jr   nc,j_983d		; @982B 3010

	ld   a,#01		; @982D 3E01
	ld   (spr_fruit_color),a		; @982F 320D4C
	pop  af		; @9832 F1
	add  a,#02		; @9833 C602
	ld   (spr_fruit_code),a		; @9835 320C4C
	sub  #02		; @9838 D602
	jp   j_19b2		; @983A C3B219

j_983d:
	pop  af		; @983D F1
	jp   j_19cd		; @983E C3CD19

	
;	................		; @9841 FFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
;	................		; @9850 FFFFFF0000FFFF000000000100000001
;	................		; @9860 000000FFFE000000FF0000FFFE000000
;	................		; @9870 FF000000FF000000FF000001FF01FF00
;	................		; @9880 0000000000FF00000000010000FF0000
;	................		; @9890 00000100000001000000010000010101
;	................		; @98A0 01000001000100010001000100010001
;	................		; @98B0 000100010001000100FFFFFFFF0000FF
;	.@..............		; @98C0 FF40FCD0D2D2D2D2D4FCDA02DCFCFCFC
;	................		; @98D0 FCFCFCDA02DCFCFCFCD0D2D2D2D2D2D2
;	................		; @98E0 D2D4FCDA05DCFCDA02DCFCFCFCFCFCFC
;	................		; @98F0 DA02DCFCFCFCDA08DCFCDA02E6EA02E7
;	................		; @9900 D2EB02E7D2D2D2D2D2D2EB02E7D2D2D2
;	................		; @9910 EB02E6E8E8E8EA02DCFCDA02DEE415DE
;	................		; @9920 C0C0C0E402DCFCDA02DEE402E6E8E8E8
;	................		; @9930 E8EA02E6E8E8E8EA02E6EA02E6EA02DE
;	................		; @9940 C0C0C0E402DCFCDA02E7EB02E7E9E9E9
;	................		; @9950 F5E402DEF3E9E9EB02DEE402DEE402E7
;	................		; @9960 E9E9E9EB02DCFCDA09DEE402DEE405DE
;	................		; @9970 E402DEE408DCFCFAE8E8EA02E6E8EA02
;	................		; @9980 DEE402DEE402E6E8E8F4E402DEE402E6
;	................		; @9990 E8E8E8EA02DCFCFBE9E9EB02DEC0E402
;	................		; @99A0 E7EB02E7EB02E7E9E9F5E402E7EB02DE
;	................		; @99B0 F3E9E9EB02DCFCDA05DEC0E40BDEE405
;	................		; @99C0 DEE405DCFCDA02E6EA02DEC0E402E6EA
;	................		; @99D0 02ECD3D3D3EE02DEE402E6EA02DEE402
;	................		; @99E0 E6EA02DCFCDA02DEE402E7E9EB02DEE4
;	................		; @99F0 02DCFCFCFCDA02E7EB02DEE402E7EB02
;	................		; @9A00 DEE402DCFCDA02DEE406DEE402F0FCFC
;	................		; @9A10 FCDA05DEE405DEE402DCFCDA02DEE402
;	................		; @9A20 E6E8E8E8F4E402CEFCFCFCDA02E6E8E8
;	...........b....		; @9A30 F4E402E6E8E8F4E402DC006202011301
;	................		; @9A40 01010201040313060403010101010101
;	................		; @9A50 01010101010101010101010101060403
;	................		; @9A60 10030604031003060401010101010101
;	................		; @9A70 0C0301010101010107040C030607040C
;	................		; @9A80 030604010101040C0101010301010104
;	................		; @9A90 03040F03030403040F03030403010101
;	................		; @9AA0 010F0101010304031904031904030101
;	................		; @9AB0 01010F010101030403040F0303040304
;	................		; @9AC0 0F030304010101040C01010103010101
;	................		; @9AD0 07040C030607040C0306040101010101
;	................		; @9AE0 01010C03010101010101040310030604
;	................		; @9AF0 03100306040301010101010101010101
;	................		; @9B00 01010101010101010106040313060402
;	................		; @9B10 01130101010201000000000000000000
;	..............".		; @9B20 000000000000000000000000E01D221D
	; ;; gap-fill from golden boots $9841-$9B2F
	db	#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF,#FF		; @9841
	db	#FF,#FF,#00,#00,#FF,#FF,#00,#00,#00,#00,#01,#00,#00,#00,#01,#00		; @9851
	db	#00,#00,#FF,#FE,#00,#00,#00,#FF,#00,#00,#FF,#FE,#00,#00,#00,#FF		; @9861
	db	#00,#00,#00,#FF,#00,#00,#00,#FF,#00,#00,#01,#FF,#01,#FF,#00,#00		; @9871
	db	#00,#00,#00,#00,#FF,#00,#00,#00,#00,#01,#00,#00,#FF,#00,#00,#00		; @9881
	db	#00,#01,#00,#00,#00,#01,#00,#00,#00,#01,#00,#00,#01,#01,#01,#01		; @9891
	db	#00,#00,#01,#00,#01,#00,#01,#00,#01,#00,#01,#00,#01,#00,#01,#00		; @98A1
	db	#01,#00,#01,#00,#01,#00,#01,#00,#FF,#FF,#FF,#FF,#00,#00,#FF,#FF		; @98B1
	db	#40,#FC,#D0,#D2,#D2,#D2,#D2,#D4,#FC,#DA,#02,#DC,#FC,#FC,#FC,#FC		; @98C1
	db	#FC,#FC,#DA,#02,#DC,#FC,#FC,#FC,#D0,#D2,#D2,#D2,#D2,#D2,#D2,#D2		; @98D1
	db	#D4,#FC,#DA,#05,#DC,#FC,#DA,#02,#DC,#FC,#FC,#FC,#FC,#FC,#FC,#DA		; @98E1
	db	#02,#DC,#FC,#FC,#FC,#DA,#08,#DC,#FC,#DA,#02,#E6,#EA,#02,#E7,#D2		; @98F1
	db	#EB,#02,#E7,#D2,#D2,#D2,#D2,#D2,#D2,#EB,#02,#E7,#D2,#D2,#D2,#EB		; @9901
	db	#02,#E6,#E8,#E8,#E8,#EA,#02,#DC,#FC,#DA,#02,#DE,#E4,#15,#DE,#C0		; @9911
	db	#C0,#C0,#E4,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#E6,#E8,#E8,#E8,#E8		; @9921
	db	#EA,#02,#E6,#E8,#E8,#E8,#EA,#02,#E6,#EA,#02,#E6,#EA,#02,#DE,#C0		; @9931
	db	#C0,#C0,#E4,#02,#DC,#FC,#DA,#02,#E7,#EB,#02,#E7,#E9,#E9,#E9,#F5		; @9941
	db	#E4,#02,#DE,#F3,#E9,#E9,#EB,#02,#DE,#E4,#02,#DE,#E4,#02,#E7,#E9		; @9951
	db	#E9,#E9,#EB,#02,#DC,#FC,#DA,#09,#DE,#E4,#02,#DE,#E4,#05,#DE,#E4		; @9961
	db	#02,#DE,#E4,#08,#DC,#FC,#FA,#E8,#E8,#EA,#02,#E6,#E8,#EA,#02,#DE		; @9971
	db	#E4,#02,#DE,#E4,#02,#E6,#E8,#E8,#F4,#E4,#02,#DE,#E4,#02,#E6,#E8		; @9981
	db	#E8,#E8,#EA,#02,#DC,#FC,#FB,#E9,#E9,#EB,#02,#DE,#C0,#E4,#02,#E7		; @9991
	db	#EB,#02,#E7,#EB,#02,#E7,#E9,#E9,#F5,#E4,#02,#E7,#EB,#02,#DE,#F3		; @99A1
	db	#E9,#E9,#EB,#02,#DC,#FC,#DA,#05,#DE,#C0,#E4,#0B,#DE,#E4,#05,#DE		; @99B1
	db	#E4,#05,#DC,#FC,#DA,#02,#E6,#EA,#02,#DE,#C0,#E4,#02,#E6,#EA,#02		; @99C1
	db	#EC,#D3,#D3,#D3,#EE,#02,#DE,#E4,#02,#E6,#EA,#02,#DE,#E4,#02,#E6		; @99D1
	db	#EA,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#E7,#E9,#EB,#02,#DE,#E4,#02		; @99E1
	db	#DC,#FC,#FC,#FC,#DA,#02,#E7,#EB,#02,#DE,#E4,#02,#E7,#EB,#02,#DE		; @99F1
	db	#E4,#02,#DC,#FC,#DA,#02,#DE,#E4,#06,#DE,#E4,#02,#F0,#FC,#FC,#FC		; @9A01
	db	#DA,#05,#DE,#E4,#05,#DE,#E4,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#E6		; @9A11
	db	#E8,#E8,#E8,#F4,#E4,#02,#CE,#FC,#FC,#FC,#DA,#02,#E6,#E8,#E8,#F4		; @9A21
	db	#E4,#02,#E6,#E8,#E8,#F4,#E4,#02,#DC,#00,#62,#02,#01,#13,#01,#01		; @9A31
	db	#01,#02,#01,#04,#03,#13,#06,#04,#03,#01,#01,#01,#01,#01,#01,#01		; @9A41
	db	#01,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01,#06,#04,#03,#10		; @9A51
	db	#03,#06,#04,#03,#10,#03,#06,#04,#01,#01,#01,#01,#01,#01,#01,#0C		; @9A61
	db	#03,#01,#01,#01,#01,#01,#01,#07,#04,#0C,#03,#06,#07,#04,#0C,#03		; @9A71
	db	#06,#04,#01,#01,#01,#04,#0C,#01,#01,#01,#03,#01,#01,#01,#04,#03		; @9A81
	db	#04,#0F,#03,#03,#04,#03,#04,#0F,#03,#03,#04,#03,#01,#01,#01,#01		; @9A91
	db	#0F,#01,#01,#01,#03,#04,#03,#19,#04,#03,#19,#04,#03,#01,#01,#01		; @9AA1
	db	#01,#0F,#01,#01,#01,#03,#04,#03,#04,#0F,#03,#03,#04,#03,#04,#0F		; @9AB1
	db	#03,#03,#04,#01,#01,#01,#04,#0C,#01,#01,#01,#03,#01,#01,#01,#07		; @9AC1
	db	#04,#0C,#03,#06,#07,#04,#0C,#03,#06,#04,#01,#01,#01,#01,#01,#01		; @9AD1
	db	#01,#0C,#03,#01,#01,#01,#01,#01,#01,#04,#03,#10,#03,#06,#04,#03		; @9AE1
	db	#10,#03,#06,#04,#03,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01		; @9AF1
	db	#01,#01,#01,#01,#01,#01,#01,#01,#06,#04,#03,#13,#06,#04,#02,#01		; @9B01
	db	#13,#01,#01,#01,#02,#01,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00		; @9B11
	db	#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#00,#E0,#1D,#22,#1D		; @9B21
	db	#39,#40,#20,#40,#3B,#63,#40,#7C,#40,#83,#43,#9C,#43,#49,#09,#17		; @9B30 394020403B63407C4083439C43490917  9@ @;c@|@.C.CI..
;	.......).......c		; @9B40 0917090EE0E0E0290917091709000063
;	....h."..q.'L.{.		; @9B50 8B13940C688B2294F4718B274CF47B8B
;	.L........TUUU._		; @9B60 1C4C0C80AAAABFAA800A54555555FF5F
;	U..WU.W..@U.....		; @9B70 55EAFF5755F557FF154055EAAF02EAFF
;	................		; @9B80 FFAA948B140000998B1700009F8B1A00
;	....U@UU........		; @9B90 00A68B1D55405555BFAA80AAAABFAAAA
;	......U...UU..@.		; @9BA0 80AA0280AAAA550000005555FDAA40FC
;	................		; @9BB0 DA02DED8D2D2D2D2D2D2D2D6D8D2D2D2
;	................		; @9BC0 D2D4FCFCFCFCDA02DED8D2D2D2D2D4FC
;	................		; @9BD0 DA02DEE408DEE405DCFCFCFCFCDA02DE
;	................		; @9BE0 E405DCFCDA02DEE402E6E8E8E8EA02DE
;	................		; @9BF0 E402E6EA02E7D2D2D2D2EB02E7EB02E6
;	................		; @9C00 EA02DCFCDA02DEE402DEF3E9E9EB02DE
;	................		; @9C10 E402DEE40CDEE402DCFCDA02DEE402DE
;	................		; @9C20 E405DEE402DEF2E8E8E8EA02E6EA02E6
;	................		; @9C30 E8E8F4E402DCFCDA02E7EB02DEE402E6
;	................		; @9C40 EA02E7EB02E7E9E9E9E9EB02DEE402E7
;	................		; @9C50 E9E9E9EB02DCFCDA05DEE402DEE40CDE
;	................		; @9C60 E408DCFCFAE8E8EA02DEE402DEF2E8E8
;	................		; @9C70 E8E8EA02E6E8E8EA02DEF2E8E8EA02E6
;	................		; @9C80 EA02DCFCFBE9E9EB02E7EB02E7E9E9E9
;	................		; @9C90 E9E9EB02E7E9F5E402DEF3E9E9EB02DE
;	................		; @9CA0 E402DCFCDA12DEE402DEE405DEE402DC
;	................		; @9CB0 FCDA02E6EA02E6E8E8E8E8EA02ECD3D3
;	................		; @9CC0 D3EE02E7EB02E7EB02E6EA02DEE402DC
;	................		; @9CD0 FCDA02DEE402E7E9E9E9F5E402DCFCFC
;	................		; @9CE0 FCDA08DEE402E7EB02DCFCDA02DEE406
;	................		; @9CF0 DEE402F0FCFCFCDA02E6E8E8E8EA02DE
;	................		; @9D00 E405DCFCDA02DEF2E8E8E8EA02DEE402
;	................		; @9D10 CEFCFCFCDA02DEC0C0C0E402DEF2E8E8
;	.......f........		; @9D20 EA02DC00000000660101010101030101
;	................		; @9D30 010B0101070603030A03070603030101
;	................		; @9D40 01010101010101010307030101010307
;	................		; @9D50 03060703030307030607030301010101
;	................		; @9D60 0101010101010301010101010107030D
;	................		; @9D70 060307030D0603040101010101010D03
;	................		; @9D80 01010103040310030303040310010101
;	................		; @9D90 03030403010101011201010104071504
;	................		; @9DA0 07150403010101011201010104031001
;	................		; @9DB0 01010303040310030303040101010101
;	................		; @9DC0 010D030101010307030D060307030D06
;	................		; @9DD0 03070303010101010101010101010301
;	................		; @9DE0 01010101010703030307030607030101
;	................		; @9DF0 01030703060706030301010101010101
;	................		; @9E00 01010103070603030A03080101010101
;	.........".9@ @;		; @9E10 030101010B0101F41D221D394020403B
;	e@{@.C.CB......		; @9E20 65407B4085439B4342160A160A160A20
;	.."    .......		; @9E30 2020DEE02220202020160A160A160000
;	T....Y....a.&..k		; @9E40 548E13C40C598E1EC4F4618E2614F46B
;	........*.@UU.P		; @9E50 8E1D140C02AAAA802A0240557F551550
;	...WU..WU......		; @9E60 05EAFF5755F5FF577F5505EAFFFFFFEA
;	...............!		; @9E70 AFAA02878E1200008C8E1D0000948E21
;	....,..UU.....*		; @9E80 00009D8E2C0000557F55D5FFAABFAA2A
;	.....*.......U..		; @9E90 A0EAFFFFAA2AA0020000A0AA025515A0
;	*.T...U.@.......		; @9EA0 2A005405000055FD40FCD0D2D2D2D2D2
;	................		; @9EB0 D2D6E402E7D2D2D2D2D2D2D2D2D2D2D6
;	................		; @9EC0 D8D2D2D2D2D2D2D2D4FCDA07DEE40DDE
;	................		; @9ED0 E408DCFCDA02E6E8E8EA02DEE402E6E8
;	................		; @9EE0 E8EA02E6E8E8E8EA02E7EB02E6EA02E6
;	................		; @9EF0 EA02DCFCDA02DEF3E9EB02E7EB02E7E9
;	................		; @9F00 F5E402E7E9E9F5E405DEE402DEE402DC
;	................		; @9F10 FCDA02DEE409DEE405DEE402E6E8E8F4
;	................		; @9F20 E402DEE402DCFCDA02DEE402E6E8E8E8
;	................		; @9F30 E8EA02E7EB02E6EA02E7EB02E7E9E9E9
;	................		; @9F40 EB02E7EB02DCFCDA02DEE402E7E9E9E9
;	................		; @9F50 F5E405DEE40EDCFCDA02DEE406DEE402
;	................		; @9F60 E6E8E8F4E402E6E8E8E8EA02E6E8E8E8
;	................		; @9F70 E8E8F4FCDA02E7EB02E6E8EA02E7EB02
;	................		; @9F80 E7E9E9E9EB02DEF3E9E9EB02DEF3E9E9
;	................		; @9F90 E9E9F5FCDA05DEC0E40BDEE405DEE405
;	................		; @9FA0 DCFCFAE8E8EA02DEC0E402E6EA02ECD3
;	................		; @9FB0 D3D3EE02DEE402E6EA02DEE402E6EA02
;	................		; @9FC0 DCFCFBE9E9EB02E7E9EB02DEE402DCFC
;	................		; @9FD0 FCFCDA02E7EB02DEE402E7EB02DEE402
;	................		; @9FE0 DCFCDA09DEE402F0FCFCFCDA05DEE405
;	................		; @9FF0 DEE402DCFCDA02E6E8E8E8E8EA02DEE4
	; ;; gap-fill from golden boots $9B40-$9FFF
	db	#09,#17,#09,#0E,#E0,#E0,#E0,#29,#09,#17,#09,#17,#09,#00,#00,#63		; @9B40
	db	#8B,#13,#94,#0C,#68,#8B,#22,#94,#F4,#71,#8B,#27,#4C,#F4,#7B,#8B		; @9B50
	db	#1C,#4C,#0C,#80,#AA,#AA,#BF,#AA,#80,#0A,#54,#55,#55,#55,#FF,#5F		; @9B60
	db	#55,#EA,#FF,#57,#55,#F5,#57,#FF,#15,#40,#55,#EA,#AF,#02,#EA,#FF		; @9B70
	db	#FF,#AA,#94,#8B,#14,#00,#00,#99,#8B,#17,#00,#00,#9F,#8B,#1A,#00		; @9B80
	db	#00,#A6,#8B,#1D,#55,#40,#55,#55,#BF,#AA,#80,#AA,#AA,#BF,#AA,#AA		; @9B90
	db	#80,#AA,#02,#80,#AA,#AA,#55,#00,#00,#00,#55,#55,#FD,#AA,#40,#FC		; @9BA0
	db	#DA,#02,#DE,#D8,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D6,#D8,#D2,#D2,#D2		; @9BB0
	db	#D2,#D4,#FC,#FC,#FC,#FC,#DA,#02,#DE,#D8,#D2,#D2,#D2,#D2,#D4,#FC		; @9BC0
	db	#DA,#02,#DE,#E4,#08,#DE,#E4,#05,#DC,#FC,#FC,#FC,#FC,#DA,#02,#DE		; @9BD0
	db	#E4,#05,#DC,#FC,#DA,#02,#DE,#E4,#02,#E6,#E8,#E8,#E8,#EA,#02,#DE		; @9BE0
	db	#E4,#02,#E6,#EA,#02,#E7,#D2,#D2,#D2,#D2,#EB,#02,#E7,#EB,#02,#E6		; @9BF0
	db	#EA,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#DE,#F3,#E9,#E9,#EB,#02,#DE		; @9C00
	db	#E4,#02,#DE,#E4,#0C,#DE,#E4,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#DE		; @9C10
	db	#E4,#05,#DE,#E4,#02,#DE,#F2,#E8,#E8,#E8,#EA,#02,#E6,#EA,#02,#E6		; @9C20
	db	#E8,#E8,#F4,#E4,#02,#DC,#FC,#DA,#02,#E7,#EB,#02,#DE,#E4,#02,#E6		; @9C30
	db	#EA,#02,#E7,#EB,#02,#E7,#E9,#E9,#E9,#E9,#EB,#02,#DE,#E4,#02,#E7		; @9C40
	db	#E9,#E9,#E9,#EB,#02,#DC,#FC,#DA,#05,#DE,#E4,#02,#DE,#E4,#0C,#DE		; @9C50
	db	#E4,#08,#DC,#FC,#FA,#E8,#E8,#EA,#02,#DE,#E4,#02,#DE,#F2,#E8,#E8		; @9C60
	db	#E8,#E8,#EA,#02,#E6,#E8,#E8,#EA,#02,#DE,#F2,#E8,#E8,#EA,#02,#E6		; @9C70
	db	#EA,#02,#DC,#FC,#FB,#E9,#E9,#EB,#02,#E7,#EB,#02,#E7,#E9,#E9,#E9		; @9C80
	db	#E9,#E9,#EB,#02,#E7,#E9,#F5,#E4,#02,#DE,#F3,#E9,#E9,#EB,#02,#DE		; @9C90
	db	#E4,#02,#DC,#FC,#DA,#12,#DE,#E4,#02,#DE,#E4,#05,#DE,#E4,#02,#DC		; @9CA0
	db	#FC,#DA,#02,#E6,#EA,#02,#E6,#E8,#E8,#E8,#E8,#EA,#02,#EC,#D3,#D3		; @9CB0
	db	#D3,#EE,#02,#E7,#EB,#02,#E7,#EB,#02,#E6,#EA,#02,#DE,#E4,#02,#DC		; @9CC0
	db	#FC,#DA,#02,#DE,#E4,#02,#E7,#E9,#E9,#E9,#F5,#E4,#02,#DC,#FC,#FC		; @9CD0
	db	#FC,#DA,#08,#DE,#E4,#02,#E7,#EB,#02,#DC,#FC,#DA,#02,#DE,#E4,#06		; @9CE0
	db	#DE,#E4,#02,#F0,#FC,#FC,#FC,#DA,#02,#E6,#E8,#E8,#E8,#EA,#02,#DE		; @9CF0
	db	#E4,#05,#DC,#FC,#DA,#02,#DE,#F2,#E8,#E8,#E8,#EA,#02,#DE,#E4,#02		; @9D00
	db	#CE,#FC,#FC,#FC,#DA,#02,#DE,#C0,#C0,#C0,#E4,#02,#DE,#F2,#E8,#E8		; @9D10
	db	#EA,#02,#DC,#00,#00,#00,#00,#66,#01,#01,#01,#01,#01,#03,#01,#01		; @9D20
	db	#01,#0B,#01,#01,#07,#06,#03,#03,#0A,#03,#07,#06,#03,#03,#01,#01		; @9D30
	db	#01,#01,#01,#01,#01,#01,#01,#01,#03,#07,#03,#01,#01,#01,#03,#07		; @9D40
	db	#03,#06,#07,#03,#03,#03,#07,#03,#06,#07,#03,#03,#01,#01,#01,#01		; @9D50
	db	#01,#01,#01,#01,#01,#01,#03,#01,#01,#01,#01,#01,#01,#07,#03,#0D		; @9D60
	db	#06,#03,#07,#03,#0D,#06,#03,#04,#01,#01,#01,#01,#01,#01,#0D,#03		; @9D70
	db	#01,#01,#01,#03,#04,#03,#10,#03,#03,#03,#04,#03,#10,#01,#01,#01		; @9D80
	db	#03,#03,#04,#03,#01,#01,#01,#01,#12,#01,#01,#01,#04,#07,#15,#04		; @9D90
	db	#07,#15,#04,#03,#01,#01,#01,#01,#12,#01,#01,#01,#04,#03,#10,#01		; @9DA0
	db	#01,#01,#03,#03,#04,#03,#10,#03,#03,#03,#04,#01,#01,#01,#01,#01		; @9DB0
	db	#01,#0D,#03,#01,#01,#01,#03,#07,#03,#0D,#06,#03,#07,#03,#0D,#06		; @9DC0
	db	#03,#07,#03,#03,#01,#01,#01,#01,#01,#01,#01,#01,#01,#01,#03,#01		; @9DD0
	db	#01,#01,#01,#01,#01,#07,#03,#03,#03,#07,#03,#06,#07,#03,#01,#01		; @9DE0
	db	#01,#03,#07,#03,#06,#07,#06,#03,#03,#01,#01,#01,#01,#01,#01,#01		; @9DF0
	db	#01,#01,#01,#03,#07,#06,#03,#03,#0A,#03,#08,#01,#01,#01,#01,#01		; @9E00
	db	#03,#01,#01,#01,#0B,#01,#01,#F4,#1D,#22,#1D,#39,#40,#20,#40,#3B		; @9E10
	db	#65,#40,#7B,#40,#85,#43,#9B,#43,#42,#16,#0A,#16,#0A,#16,#0A,#20		; @9E20
	db	#20,#20,#DE,#E0,#22,#20,#20,#20,#20,#16,#0A,#16,#0A,#16,#00,#00		; @9E30
	db	#54,#8E,#13,#C4,#0C,#59,#8E,#1E,#C4,#F4,#61,#8E,#26,#14,#F4,#6B		; @9E40
	db	#8E,#1D,#14,#0C,#02,#AA,#AA,#80,#2A,#02,#40,#55,#7F,#55,#15,#50		; @9E50
	db	#05,#EA,#FF,#57,#55,#F5,#FF,#57,#7F,#55,#05,#EA,#FF,#FF,#FF,#EA		; @9E60
	db	#AF,#AA,#02,#87,#8E,#12,#00,#00,#8C,#8E,#1D,#00,#00,#94,#8E,#21		; @9E70
	db	#00,#00,#9D,#8E,#2C,#00,#00,#55,#7F,#55,#D5,#FF,#AA,#BF,#AA,#2A		; @9E80
	db	#A0,#EA,#FF,#FF,#AA,#2A,#A0,#02,#00,#00,#A0,#AA,#02,#55,#15,#A0		; @9E90
	db	#2A,#00,#54,#05,#00,#00,#55,#FD,#40,#FC,#D0,#D2,#D2,#D2,#D2,#D2		; @9EA0
	db	#D2,#D6,#E4,#02,#E7,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D6		; @9EB0
	db	#D8,#D2,#D2,#D2,#D2,#D2,#D2,#D2,#D4,#FC,#DA,#07,#DE,#E4,#0D,#DE		; @9EC0
	db	#E4,#08,#DC,#FC,#DA,#02,#E6,#E8,#E8,#EA,#02,#DE,#E4,#02,#E6,#E8		; @9ED0
	db	#E8,#EA,#02,#E6,#E8,#E8,#E8,#EA,#02,#E7,#EB,#02,#E6,#EA,#02,#E6		; @9EE0
	db	#EA,#02,#DC,#FC,#DA,#02,#DE,#F3,#E9,#EB,#02,#E7,#EB,#02,#E7,#E9		; @9EF0
	db	#F5,#E4,#02,#E7,#E9,#E9,#F5,#E4,#05,#DE,#E4,#02,#DE,#E4,#02,#DC		; @9F00
	db	#FC,#DA,#02,#DE,#E4,#09,#DE,#E4,#05,#DE,#E4,#02,#E6,#E8,#E8,#F4		; @9F10
	db	#E4,#02,#DE,#E4,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#E6,#E8,#E8,#E8		; @9F20
	db	#E8,#EA,#02,#E7,#EB,#02,#E6,#EA,#02,#E7,#EB,#02,#E7,#E9,#E9,#E9		; @9F30
	db	#EB,#02,#E7,#EB,#02,#DC,#FC,#DA,#02,#DE,#E4,#02,#E7,#E9,#E9,#E9		; @9F40
	db	#F5,#E4,#05,#DE,#E4,#0E,#DC,#FC,#DA,#02,#DE,#E4,#06,#DE,#E4,#02		; @9F50
	db	#E6,#E8,#E8,#F4,#E4,#02,#E6,#E8,#E8,#E8,#EA,#02,#E6,#E8,#E8,#E8		; @9F60
	db	#E8,#E8,#F4,#FC,#DA,#02,#E7,#EB,#02,#E6,#E8,#EA,#02,#E7,#EB,#02		; @9F70
	db	#E7,#E9,#E9,#E9,#EB,#02,#DE,#F3,#E9,#E9,#EB,#02,#DE,#F3,#E9,#E9		; @9F80
	db	#E9,#E9,#F5,#FC,#DA,#05,#DE,#C0,#E4,#0B,#DE,#E4,#05,#DE,#E4,#05		; @9F90
	db	#DC,#FC,#FA,#E8,#E8,#EA,#02,#DE,#C0,#E4,#02,#E6,#EA,#02,#EC,#D3		; @9FA0
	db	#D3,#D3,#EE,#02,#DE,#E4,#02,#E6,#EA,#02,#DE,#E4,#02,#E6,#EA,#02		; @9FB0
	db	#DC,#FC,#FB,#E9,#E9,#EB,#02,#E7,#E9,#EB,#02,#DE,#E4,#02,#DC,#FC		; @9FC0
	db	#FC,#FC,#DA,#02,#E7,#EB,#02,#DE,#E4,#02,#E7,#EB,#02,#DE,#E4,#02		; @9FD0
	db	#DC,#FC,#DA,#09,#DE,#E4,#02,#F0,#FC,#FC,#FC,#DA,#05,#DE,#E4,#05		; @9FE0
	db	#DE,#E4,#02,#DC,#FC,#DA,#02,#E6,#E8,#E8,#E8,#E8,#EA,#02,#DE,#E4		; @9FF0
