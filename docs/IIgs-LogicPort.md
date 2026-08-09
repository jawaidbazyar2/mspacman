# IIgs logic port checklist

Thin status map for the **game** build (`make iigs-game` → `build/iigs/game.bin`). Behavioral truth: locked [`src/mspac.asm`](../src/mspac.asm). Approach: semantic 65816 + structural Z80 anchors ([`IIgs-Design.md`](IIgs-Design.md) §6).

| Z80 anchor | IIgs file / symbol | Status |
|------------|-------------------|--------|
| VBL logic after publish | `game_tick.s` `LogicTick` / `FrameTick` | live |
| `j_06be` level_state | `level_fsm.s` `LevelFsm` | maze-only (play/death/clear) |
| `j_08eb` | `play_tick.s` `PlayTick` | live |
| `j_0e36` scatter→chase | `play_tick.s` `GhostOrientTick` | live (Ms. Pac forces idx=1) |
| `j_1017` ×2 | `play_tick.s` `ActorTick` | live (eat-freeze early-out) |
| `j_1066` | `play_tick.s` `ApplyKillGhost` | live |
| `j_1094`…`j_10b4` | `play_tick.s` `EyesTick` + `ghost_move.s` STATE=1 | live (eyes→door→home; no teleport) |
| `j_1235` / `j_1277` | `play_tick.s` `EatGhostAnimTick` + `actor_publish.s` `EatGhostPublish` | live ($4A freeze, points $28–$2B) |
| `j_13dd` | `leave_house.s` `GhostHouse` | live (idle release) |
| `j_0c42` | `leave_house.s` `LeaveHouse` | live |
| `j_1b08` / `j_2069`…`j_20d1` | `leave_house.s` release helpers | live (level1 limits) |
| `j_1806` | `mspac_move.s` `MsPacMove` | live (simplified tunnel) |
| `j_1b36`…`j_1df9` | `ghost_move.s` | live (maze when substate==1) |
| `j_2966` | `ghost_ai.s` `Pathfind2966` | live |
| `j_171d` / `j_1789` / `j_1763` | `collide.s` | live (pending + score ladder) |
| `#2B17` ghost scores | `hud_body.s` `ScoreAddBCD` / `GhostScoreTab` | live 200/400/800/1600 |
| `j_0ead` / `j_86ee` | `fruit.s` `FruitTick` | simplified sit+timer |
| `j_08de` / `j_94a1` | `maze_state.s` `CheckBoardClear` | maze1 = 224 |
| `j_253d` spawn | `game_init.s` `InitArcadeActors` | live |
| ISR sprite publish | `actor_publish.s` | live |
| `IN0` | `input_adapt.s` `HandleKey` + `STICK_IN0` | latched keys |
| Attract / credit / acts | — | stubbed |
| Sound / WSG | — | stub (`SirenStub`, `EatGhostSoundStub`, `EyesSoundStub`) |

Demo build (`make iigs`) is independent: `demo_tick.s` + `rails_body.s` — do not gut for game work.
