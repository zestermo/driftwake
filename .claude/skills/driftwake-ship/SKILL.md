---
name: driftwake-ship
description: >
  Work on Driftwake's ships as systems: the shared hull layout (HullBuilder constants, ship-local
  coordinates), the crew's sloop (Ship: its own sailing sim, place(), swell, riders on the deck,
  anchor, sails and wind, helm), hull damage and the crew's deck jobs (holes, fires, flooding,
  pump, capstan), cannons and broadsides, the cabin (bunk, galley, storage chest, respawn),
  ladders, rigging, the crow's nest and rope swings, summoning the ship, enemy ships (kinds,
  states, crews, boarding, sinking, prizes, the fleet), the Sea King and wrecks, ship co-op sync,
  and the ship tests. Use when Zach asks for anything that sails, floats, is aboard a ship or
  happens on a deck: a new ship feature or fitting, resizing ships, sailing feel, naval combat,
  boarding, a ship bug ("fell through the deck", "flew off the ship", "ship jitters").
  For how hull meshes are modelled (MeshBuilder, UVs, textures) see driftwake-modeling.
---

# Driftwake ships

Two kinds of ship share one layout: the crew's sloop (`scripts/ship/ship.gd`, `Ship`) and the
pirates' (`scripts/ship/enemy_ship.gd`, `EnemyShip`). `HullBuilder` (`scripts/ship/hull_builder.gd`)
owns the shape: constants, the mesh (`hull()`, `build()`), collision (`collide()`) and helpers.
Wrecks use the same hull without the rig.

**Read first:** grep `docs/dev_notes.md` for the system (the 2026-10-07 sections cover the 1.5x
ships, the cabin, climbing and the gameplay loop), then the code below.

## Ship-local space

Everything on a ship is placed in **ship-local** metres: origin at the hull's centre line, **stern
+Z, bow -Z**, +X starboard, the main deck at `DECK_Y` 0.32. Build fittings, crew spots and
markers in this frame and parent them under the ship (`ship_model` for the crew's ship) so they
ride the hull.

| Constant (HullBuilder) | Value | What |
|---|---|---|
| `RINGS` | [z, top half-width, bottom half-width, top y, bottom y] | hull cross-sections, stern (9.9) to bow (-12.6); ~22.5 m long, 8.8 m beam |
| `DECK_Y` / `QD_Y` | 0.32 / 2.72 | main deck / quarterdeck floor |
| `QD_FRONT`..`QD_BACK` | 5.0..9.9 | quarterdeck (the cabin under it) |
| `CABIN_HW`, `DOOR_HW` | 3.95, 0.65 | cabin walls, door |
| `STAIR_X0`, `STAIR_Z0` | 2.75, 1.4 | stairs either side of the cabin front |
| `MAST_Z`, `MAST_TOP`, `YARD_Y` | -1.8, 16.8, 13.8 | mast and yard |
| `NEST_Y`, `NEST_R` | 15.0, 1.6 | crow's nest (room round the mast) |
| `RIG_BOTTOM` / `RIG_TOP` | (3.75, 1.17, MAST_Z) / (1.5, 15.05, MAST_Z) | ratlines, +x side (port mirrors) |
| `LADDER_Z`, `LADDER_LEN` | -2.9, 3.0 | rope ladders down both sides |
| `HELM_Z`, `WHEEL_Z` | 7.4, 6.6 | helmsman, wheel (quarterdeck) |
| `FREEBOARD` | 1.45 | origin above the mean sea: the deck stands ~1.8 m clear (level with the dock) |
| `LIP` | 0.45 | bulwark above the hull's top edge |

Helpers: `half_width(z)`, `aboard_local(l)` (inside the ship's bounds, rigging included),
`in_cabin(l)`, `nest_rail()/nest_rail_at(a)`. Ship-side positions on the crew's ship: `BED_AT`,
`STOVE_AT`, `STORAGE_AT`, `COUNTER_AT`, `TABLE_AT`, `ANCHOR_AT`, `CAPSTAN_AT`, `PUMP_AT`,
`GUN_SPOTS` ([z, x, deck y] per pair), `PUDDLES`, `WATERLINE_Y`, `DECK_Z_MIN/MAX`, `DECK_X_MAX`
(where holes and fires can appear).

## The crew's ship (Ship)

- An `AnimatableBody3D` (`sync_to_physics`) moved by **its own simulation**, not physics: `_pos`
  and `_heading` are the truth, `global_transform` is written from them every physics tick.
  **Move it only with `place(world_pos, yaw)`** (mooring, teleports, summon). Setting the
  transform is overwritten next tick.
- Sailing: `sail` in steps (`SAIL_STEPS` 3, W/S at the wheel), `speed` builds toward
  `MAX_SPEED * sail * wind_effect()` (point of sail vs `Weather` wind), `rudder` turns harder
  with flow, held S backs her when furled. Anchored = brought up short. Hull motion uses
  `test_move` and slides along shores and docks.
- Swell: the waves sampled under bow, stern, both sides and midships (`_wave` uses
  `Ocean.clock()`), eased with critically damped springs (`HEAVE_SCALE` 0.4: a 23 m hull rides
  over 8 m waves). Flooding settles her and lists her.
- Riders: in group `decks`; `deck_delta()` is this tick's motion. The player's `_ride_ship()`
  carries airborne captains (not in `NO_RIDE_STATES`), the floor carries standing ones. Knockdown
  ragdolls take `hull_velocity()`. `jolt(push)` rocks her (rams, the Sea King).
- Helm: `HelmZone` (reach 1.0) -> `HelmState`. Leaving the wheel in port drops the anchor by
  itself (`in_port()`, `PORT_REACH`).
- Damage: `hull_hit()` -> hull points (`MAX_HULL` 400, `crippled` at 0, slow repair), plus
  `breaches` (holes at the waterline, flooding), `fires` (spread, burn the crew),
  `flood`. Only the **host** runs `_damage_tick`; clients get `net_damage`. The crew's jobs are
  held F within `WORK_REACH` 1.3: patch, douse, pump (`PUMP_AT`), capstan (`CAPSTAN_AT`).
  While a job is in reach `local_job` is set and **interactables stand aside** (F is the job's).
- Cannons: `ShipCannon` per `GUN_SPOTS` pair (`_add_gun_pair(i)`, the third pair is the
  shipwright's refit). Manned through `Net.request_seat` (one captain each); the helmsman fires
  a broadside (`broadside(side, target, by)`). Balls carry `hull_velocity()`.
- The cabin: bunk (`GameManager.rest`), galley (`restock`), the storage chest (a persistent
  `LootBag`, the crew's bank, shared in co-op as bag "storage"), `respawn_point` by the bunk.
- Climbing: `ShipRigging` (one per side, ship-local; `hold(k)` is the climber's feet on the
  outboard side of the shrouds), `SwingRope` at each yard end (under `_rig`, turns with the
  brace), `Ladder` down each side (local frame: origin at the deck edge, +Z out over the water).
  `ClimbState` climbs by hand (F grab, W/S, Space jump off, F let go, one-handed blade).
- Interactables on a ship are **reach-limited** (`Interactable.reach`, ~0.75-1.1 m from the
  thing; ladders use `reach_test`). Prompts are plain verbs ("Man the cannon").
- Summon (hold B, `Player.try_summon`): `summon_spot(at)` searches rings round you for water at
  least `SUMMON_DEPTH` deep under the hull's footprint (`_fits`: depth probed from y 80, or hills
  read as water), she fades in (`psx_lit_fade` copies of her materials) 30 m out and sails up.
- Looks: `apply_kit(GameManager.ship_kit)` (the shipwright's paint, sails, flag, figurehead,
  refits; `ShipKit`).

## Enemy ships (EnemyShip, enemy_fleet.gd)

- `KINDS` (sloop, gunboat, brig, marine): speed, hull, guns (deck z per side), crew,
  broadside range, scatter, and whether it boards, rams, fires double broadsides, surrenders.
- States `S`: PATROL, HUNT, BROADSIDE, BOARD (`ALONGSIDE` 10.8 m, grapples, boarders leap
  across), HOLD, RAM, FLEE, SINK (heels over, burns, drops a floating chest), DECK (you boarded:
  its crew fights on its deck), PRIZE (struck colours, captain's chest).
- Crew on deck: `CREW_SPOTS` (ship-local; the helmsman's spot.y is the quarterdeck), shown within
  `CREW_SHOW`; boarders are ordinary pirate grunts (`look_for`, body takeover).
- Far away (`FAR` 350 m) it runs a cheap mode (no test_move, roll or wake).
- Co-op: the host sails it (group `net_sync`), others run `_puppet` from its snapshots;
  `net_event` for one-shots (fire, sink, strike).
- The Sea King (`scripts/enemies/sea_king.gd`): circles at `CIRCLE_R` 30, bites at spots scaled
  to the hull, tail slams (`jolt`). Wrecks: `sea_features.gd`, `HullBuilder.collide(body, false)`.

## Changing the size or layout

Everything keys off HullBuilder, but several things hold their own numbers. When the hull,
decks or rig move, check each of these:

- `Ship`: `GUN_SPOTS`, cabin fittings, `ANCHOR_AT`, `CAPSTAN_AT`, `PUMP_AT`, `PUDDLES`,
  `WATERLINE_Y`, `DECK_Z_*`, rope `position` (inside the rail), ship camera distance,
  `ship.tscn` markers (HelmPosition, RespawnPoint, HelmZone).
- `EnemyShip`: `ALONGSIDE`, `CREW_SPOTS`, `KINDS` gun z, hurtbox size, ladders, prize bag spot.
- `sea_king.gd` bite spots / tail ring / `CIRCLE_R`; `sea_features.gd` wreck bag spot.
- Brinehollow's mooring (`starter_island.gd`, ship moored `side * 7.2` off the dock), the
  shipwright's camera (`shipwright_screen.gd`), `HullBuilder.aboard_local` bounds.
- Test bounds: r8test, swimtest (ladder landing), seatest, riggingtest, decktest, looptest.

## Rules that bite

- Waves: `Ocean.get_wave_height()` and `ocean.gdshader` must agree; always `Ocean.clock()`.
- Teleporting anything onto a deck: `reset_physics_interpolation()` after.
- A model or collision change in HullBuilder changes **every** ship (ours, pirates', wrecks):
  render both (`bigshipshot`, an enemy alongside) before calling it done.
- Hull meshes must be closed from every side (outer faces up to the rail, the bow stem) and
  planks mapped by position (`_plank_uv`, `_side_uv`); see driftwake-modeling.
- Anything that changes the ship's world state must work for a co-op guest: go through Net
  (`Net.ship_anchor`, `Net.ship_work`, `Net.summon_ship`, seats, helm). See driftwake-coop.

## Tests and renders

- `shiptest` (sailing, helm, riding the deck, shores), `seatest` (naval combat, boarding, fleet,
  hazards, damage, Sea King), `riggingtest` (decks, prompts, climbing, rope, ladders),
  `r8test` (cannons, broadside, enemy ships, boarders), `decktest` (knockdowns under way),
  `looptest` (cabin, storage, graves, summon), `yardtest` (shipwright), `qoltest` (capstan).
  `.\tools\dev\run_tests.ps1 -Changed` picks them from what you touched.
- Renders: `bigshipshot` (outside, decks, cabin, nest, rigging, climbing, an enemy alongside;
  `psx` arg for the PS1 look), `cannonshot`, `helmshot`, `modelshot` for single parts.
