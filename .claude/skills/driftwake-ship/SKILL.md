---
name: driftwake-ship
description: >
  Work on Driftwake's ships as systems: the hull layout as data (HullLayout per class and cabin tier, ship-local
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

Two kinds of ship share one hull: the crew's sloop (`scripts/ship/ship.gd`, `Ship`) and the
pirates' (`scripts/ship/enemy_ship.gd`, `EnemyShip`). **`HullLayout`** (`scripts/ship/hull_layout.gd`, 1.29)
is the layout as data: one object per ship class and cabin tier. **`HullBuilder`** (`scripts/ship/hull_builder.gd`)
draws and collides a layout: the mesh (`hull(mb, m, rig, L)`, `build(parent, {"layout": L})`), collision
(`collide(body, rig, L)`); all default to `HullLayout.base()`. Wrecks use the same hull without the rig.

**Read first:** grep `docs/dev_notes.md` for the system (the 2026-10-07 sections cover the 1.5x
ships, the cabin, climbing and the gameplay loop; the 2026-11-02 1.29 'Shipshape' pieces 1-5 the layout, the
cabin rework, Quarters, the pantry and the looks), then the code below.

## Ship-local space and the layout

Everything on a ship is placed in **ship-local** metres: origin at the hull's centre line, **stern
+Z, bow -Z**, +X starboard, the main deck at `DECK_Y` 0.32. Build fittings, crew spots and
markers in this frame and parent them under the ship (`ship_model` for the crew's ship) so they
ride the hull.

**Which layout:** the crew's ship reads **`ship.layout`** (`HullLayout.for_kit(kit)` = `of(class, kit "quarters")`,
cached; set in `Ship._ready`, changed by `apply_kit`). Everything about the pirates', traders', wrecks' and islands'
hulls reads **`HullLayout.base()`** (the pre-1.29 numbers, frozen; `t/ship/layout_parity` fingerprints that hull).
Never read one ship's layout for another. The hull's shape stays as consts too (`HullLayout.RINGS`, `DECK_Y`,
`FREEBOARD`, `BOW_Z`, `STERN_Z`, `HALF_BEAM`) for const contexts; every 1.29 crew class shares that hull form.
`HullLayout` must not reference classes that touch autoloads (tests name it statically before they load).

| Field (layout) | base() | crew, Quarters 0 | What |
|---|---|---|---|
| `rings` | [z, top half-width, bottom half-width, top y, bottom y] | same | hull cross-sections, stern (9.9) to bow (-12.6); ~22.5 m long, 8.8 m beam |
| `deck_y` / `qd_y` | 0.32 / 2.72 | 0.32 / 2.72 (2.97 from Quarters 3) | main deck / quarterdeck floor |
| `cabin_y` | 0.32 | -0.08 (-0.28 at Quarters 4) | the cabin floor (steps down inside the door: `HullBuilder.step_count`, `steps_end`) |
| `qd_front`..`qd_back` | 5.0..9.9 | 4.4..9.9 (3.4 from Quarters 1) | quarterdeck (the cabin under it; HullBuilder `_segments` splits the hull there) |
| `cabin_hw`, `door_hw`, `door_h` | 3.95, 0.65, 2.05 | same | cabin walls, door |
| `stair_x0`, `stair_z0` | 2.75, 1.4 | 2.75, qd_front - 3.5 | stairs either side of the cabin front |
| `mast_z`, `mast_top`, `yard_y` | -1.8, 16.8, 13.8 | same | mast and yard |
| `nest_y`, `nest_r` | 15.0, 1.6 | same | crow's nest (room round the mast) |
| `rig_bottom` / `rig_top` | (3.75, 1.17, -1.8) / (1.5, 15.05, -1.8) | same | ratlines, +x side (port mirrors) |
| `ladder_z`, `ladder_len` | -2.9, 3.0 | -2.9, 1.83 (to the waterline; `Ladder.lean` lays it on the hull) | rope ladders down both sides |
| `helm_z`, `wheel_z` | 7.4, 6.6 | same | helmsman, wheel (quarterdeck; the helm marker and zone follow the layout) |
| `gun_spots` | [z, x, deck y] per pair | the third on `qd_y` | the gun pairs |
| `bed_at`, `stove_at`, `counter_at`, `storage_at`, `table_at`, `pantry_at` | | on `cabin_y` | the cabin's fittings (ShipCabin furnishes round them) |
| `lip` | 0.45 | same | bulwark above the hull's top edge |

Layout helpers: `half_width(z)`, `ring_at(z)`, `side_at(z, y)`, `aboard_local(l)`, `in_cabin(l)`,
`nest_rail()/nest_rail_at(a)`. Ship-side consts: `FREEBOARD`, `DECK_Y`, `ANCHOR_AT`, `CAPSTAN_AT`, `PUMP_AT`,
`PUDDLES`, `WATERLINE_Y`, `DECK_Z_MIN/MAX`, `DECK_X_MAX` (where holes and fires can appear).

**Cabin tiers (Quarters, ShipLines "quarters"):** `HullLayout._crew(t)` sets the numbers; `ShipCabin`
(`scripts/ship/ship_cabin.gd`) furnishes the room per tier (`build`, `solids`, `seats`, `table_at`, `lamp_at`);
`ShipParts._quarters` puts each level's outside on her. A new layout (`apply_kit` when `for_kit` changes) runs
`Ship._relayout()`: everything `_build_layout` made under `ShipModel/Layout`, the ladders and galley table, and the
collision in `_layout_shapes` are freed and built again; ShipParts rebuilds. Keep anything layout-dependent in
`_build_layout` (or reading `ship.layout` at build time) so it moves with the cabin. The cabin meshes and light hide
unless a camera is near (`_show_cabin`). The 1.30 brig and galleon are meant to be new `HullLayout` classes (their own
rings and decks), built by the same HullBuilder.

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
- Cannons: `ShipCannon` per `layout.gun_spots` pair (`_add_gun_pair(i)`, the third pair is the
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
  refits; `ShipKit`). 1.29: rails/spars/deck/stripe paint (`_repaint`, `_deck_tint`, `_stripe`), the jolly roger
  builder (kit skull/crossed/headpiece, ShipKit `_jolly_at`), `Figureheads` (ten, each with its `LEAN` along the
  stem), the wheel per Rudder & helm level (`fit_helm`, ShipWheel), the flag on `_flag_pivot` turning downwind.
- The galley pantry (1.29): `ship.pantry`, a hidden shared LootBag ("pantry", like the storage) on
  GameManager.pantry; `Food.picks` takes from it first; `pantry_slots()`.

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

Everything keys off the layout (HullLayout), but several things hold their own numbers. When the hull,
decks or rig move, check each of these:

- `Ship`: the layout's gun spots and cabin fittings, `ANCHOR_AT`, `CAPSTAN_AT`, `PUMP_AT`, `PUDDLES`,
  `WATERLINE_Y`, `DECK_Z_*`, rope `position` (inside the rail), ship camera distance,
  `ship.tscn` markers (HelmPosition, RespawnPoint, HelmZone).
- `EnemyShip`: `ALONGSIDE`, `CREW_SPOTS`, `KINDS` gun z, hurtbox size, ladders, prize bag spot.
- `sea_king.gd` bite spots / tail ring / `CIRCLE_R`; `sea_features.gd` wreck bag spot.
- Brinehollow's mooring (`starter_island.gd`, ship moored `side * 7.2` off the dock), the
  shipwright's camera (`shipwright_screen.gd`), `HullLayout.aboard_local` bounds.
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
