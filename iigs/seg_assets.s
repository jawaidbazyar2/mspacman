*
* GS/OS OMF data segment — injected gfx (same layout as static bank $03).
*
	rel
	ent	AST_TILES,AST_SPR_EVEN,AST_MSK_EVEN
	ent	AST_SPR_ODD,AST_MSK_ODD,AST_MAZE,AST_MAZE_CELLS

AST_TILES
	putbin	../build/gfx/tiles6.bin
AST_SPR_EVEN
	putbin	../build/gfx/sprites14x12.bin
AST_MSK_EVEN
	putbin	../build/gfx/sprites14x12.mask.bin
AST_SPR_ODD
	putbin	../build/gfx/sprites14x12.odd.bin
AST_MSK_ODD
	putbin	../build/gfx/sprites14x12.odd.mask.bin
AST_MAZE
	putbin	../build/gfx/maze1_28x31.bin
AST_MAZE_CELLS
	putbin	../build/gfx/maze1_cells.bin
