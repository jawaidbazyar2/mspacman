*
* GS/OS OMF data segment for the lowered game: the tile and sprite art.
* The lowered game draws the maze from video RAM, so the prototype's maze
* tables are empty labels; only its unused CopyMaze/DrawMaze name them.
* The Makefile copies the art from build/gfx into the staging directory.
*
	rel
	ent	AST_TILES,AST_SPR_EVEN,AST_MSK_EVEN
	ent	AST_SPR_ODD,AST_MSK_ODD,AST_MAZE,AST_MAZE_CELLS

AST_TILES
	putbin	tiles6.bin
AST_SPR_EVEN
	putbin	sprites14x12.bin
AST_MSK_EVEN
	putbin	sprites14x12.mask.bin
AST_SPR_ODD
	putbin	sprites14x12.odd.bin
AST_MSK_ODD
	putbin	sprites14x12.odd.mask.bin
AST_MAZE
AST_MAZE_CELLS
	ds	2
