# IIgs logic port checklist

Thin status map for the **game** build (`make iigs-game` → `build/iigs/game.bin`). Behavioral truth: locked [`src/mspac.asm`](../src/mspac.asm). Approach: semantic 65816 + structural Z80 anchors ([`IIgs-Design.md`](IIgs-Design.md) §6).

| Z80 anchor | IIgs file / symbol | Status |
|------------|-------------------|--------|
| VBL logic after publish | `game_tick.s` `LogicTick` / `FrameTick` | live |
| `j_06be` level_state | `level_fsm.s` `LevelFsm` | maze-only (play/death/clear) |
| `j_08eb` | `play_tick.s` `PlayTick` | live |
| `j_1017` ×2 | `play_tick.s` `ActorTick` | live |
| `j_1806` | `mspac_move.s` `MsPacMove` | live (simplified tunnel) |
| `j_1b36`…`j_1df9` | `ghost_move.s` | live (dot-count release) |
| `j_2966` | `ghost_ai.s` `Pathfind2966` | live |
| `j_171d` / `j_1789` | `collide.s` | live |
| `j_0ead` / `j_86ee` | `fruit.s` `FruitTick` | simplified sit+timer |
| `j_08de` / `j_94a1` | `maze_state.s` `CheckBoardClear` | maze1 = 224 |
| `j_253d` spawn | `game_init.s` `InitArcadeActors` | live |
| ISR sprite publish | `actor_publish.s` | live |
| `IN0` | `input_adapt.s` `HandleKey` + `STICK_IN0` | latched keys |
| Attract / credit / acts | — | stubbed |
| Sound / WSG | — | stub (`SirenStub`) |

Demo build (`make iigs`) is independent: `demo_tick.s` + `rails_body.s` — do not gut for game work.
