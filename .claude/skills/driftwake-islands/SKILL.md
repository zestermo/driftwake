---
name: driftwake-islands
description: >
  Build settlements and places on Driftwake's islands with the island kit (scripts/island/kit/):
  the island context (KitContext: ground, reserves, paths, seeded rng per piece, the style table,
  the light budget, save keys), the kit modules (harbour/quay/waterfront, village houses and
  dressing passes, market, paving, landmarks, camps/den/training yard, caves and the inn,
  NPCs and life, night lights), how to author a new kit piece (data plan vs build step, seeding,
  styles, budgets, MultiMesh vs nodes, visibility ranges, colliders, nav zones), co-op
  determinism, Brinehollow as the reference that must stay identical (islanddump), and the
  fidelity loop (fidelity.gd, fidelityshot, fidelitytest). Use when adding or changing anything
  built on an island (a harbour, houses, dressing, a landmark, a camp, a cave, villagers),
  when working on GenIsland's content or the district planner, when touching starter_island.gd,
  or when Zach says an island "feels empty", "sparse", "not like Brinehollow".
---

# Driftwake islands: the kit

Brinehollow (`scripts/island/starter_island.gd`) is hand-made and is **the reference**: every
generated island should read as dense and lived in. Its settlement is built from **kit pieces**
(`scripts/island/kit/`), and `starter_island.gd` is only its land, its paths, its plants, its
bugs and loot, and its **layout**: where each kit piece goes, with Brinehollow's own numbers and
fixed seeds. Generated islands (`GenIsland`, `IslandContent`, `IslandVillage`) assemble the same
pieces. Plan and phases: `docs/island_fidelity_plan.md`; the numbers: `docs/island_fidelity_baseline.md`.

Read first: `driftwake-modeling` for making the models themselves, `driftwake-coop` before
anything a guest builds or changes. Grep `docs/dev_notes.md` for "kit" and the piece you touch.

## The island context (KitContext)

`KitContext.make(island, seed, style_name, light_budget, build_ms)`; `ctx.under(site_node)` is the
same island with nodes going under a site node (GenIsland's `Site_<name>`). Everything is in
**island space** (Vector2 x/z, -z north); `ctx.place` converts to the parent's space.

| Call | What | Thread |
|---|---|---|
| `hv(p)`, `ground_max(c, r)`, `ground_min(c, r)` | walk height (Brinehollow: the quay counts), highest/lowest under a footprint | data |
| `reserve(p, r)`, `excluded(p, pad, under)` | keep ground clear / is it taken (only reserves smaller than `under` count) | data |
| `path_dist(p)`, `isl.paths` | distance to the nearest path's edge; the smoothed paths (`paths[0]` = the main road) | data |
| `rng(salt, fixed)` | a piece's own stream: `hash([seed, salt])`, or a fixed seed (Brinehollow's `SEEDS`) | data |
| `save_key(name)` | the name in the save (Brinehollow: the name itself; GenIsland: `isle<id>_<name>`) | data |
| `take_light()` | one NightLight from the budget, false once spent | data |
| `plan_place(plan, make, p, yaw, footprint, y_off, then)` | a placement worked out now (height, reserve), made later | data |
| `place(node, p, yaw, footprint, y_off)` | on the ground; footprint > 0 = on the highest point under it, reserves footprint + 1.5 | main |
| `put(node, Vector3, yaw)`, `add(mesh_in_island_coords)` | exact position / a merged mesh built in island coordinates | main |
| `house(spec, p, face, stilts)` | `Buildings.house` with its footing to the lowest ground (or stilts); `lamp_light` uses the budget | main |
| `build_list(plan)` | makes a `plan_place` list in order (`then(node)` after each, e.g. its light) | main |
| `marker_point/marker_face/marker_y(node, "Vendor")`, `local_point(node, v3)` | spots inside placed buildings | main |
| `timed(piece, fn)` | adds the ms to `build_ms[piece]` | main |
| `style` | the style table (KitStyle) | data |
| `paved` | Callable: ground already paved (Brinehollow's quay), skipped by KitPaving | data |
| `own_reserves`, `taken` | occupancy of its own instead of the island's reserves (a built GenIsland, whose reserves are its sites' tree clearings) | data |

The island side is `Island`'s interface: `hv`, `walk_height`, `reserve`, `excluded(p, pad, under)`,
`path_dist`, `save_key`. StarterIsland and GenIsland override each (the base pushes an error).

## The modules

| File | Class | Pieces |
|---|---|---|
| `kit_context.gd` | KitContext | the context above |
| `kit_style.gd` | KitStyle | `BRINEHOLLOW` (timber and stone), `JUNGLE` (overrides); lamp colour/range, paving, quay stone, waterfront walls/roofs/awnings, pennants, washing, rugs, goods, tents, pirates' houses and flags |
| `kit_lights.gd` | KitLights | `post` (a lantern post, lit from the budget), `light` (a NightLight on any node) |
| `kit_harbour.gd` | KitHarbour | `plan` (the quay line, data, in a frame: `out` to sea, `along`, `inland`), `shape`/`earth`/`on_platform` (height, splat and walk hooks), `build_pier`, `build_quay`, `build_piers`, `build_longboats`, `plan_waterfront`/`build_waterfront`, `plan_dressing` (cargo, carts, lamps, stalls), `build_front` (booth, boat on the stocks, yard, net-mender's corner; `mirror`), models `booth_model`, `boat_on_stocks`, `workbench` |
| `kit_harbour_gen.gd` | GenHarbour | a generated island's harbour district at its pier: `plan(gi)` (data, in GenIsland.prepare before the vegetation; the kind rolled from the style's `harbour_kinds` (stilts / cove / wharf / ruins) or, with the village inland, `harbour_wild_kinds` (adds a bare landing); `force` for tools), `steps()` (GenIsland.finish_steps), `at(s, d)` (s along the shore, d in from the waterline), `waterfront()`, `spots` (where harbour people would work) |
| `kit_harbour_models.gd` | HarbourModels | `deck_strip` (a walkway deck along a polyline, mitred, boards across, its top into a collider builder), `piles`, `rope_rail`, `bollard`; models `canoe`, `net_rack`, `fish_traps`, `sacks`, `timber`, `contraband`, `warehouse`, `boathouse`, `ruined_hut`, `tower_stump` |
| `kit_village.gd` | KitVillage | `table_set`, `benches_round`, `pole`, `bunting_ring`, `bunting`, `laundry`, `garden`, `road_lamps`, models `notice_board`, `handcart`; `dress_houses` (the generic pass for any island's houses); `dress_generated_village` (phase 1's proof, tools only) |
| `kit_market.gd` | KitMarket | `build` (stalls in a horseshoe, planter, wares mesh, cargo) |
| `kit_paving.gd` | KitPaving | `plan_disk`, `plan_path` (quads, data), `build` (one mesh, no shadow) |
| `kit_landmarks.gd` | KitLandmarks | `lighthouse` (+ keeper's cottage), `ruins` (+ standing stone and its dialogue), `harbour_tower`, `crane`, `chapel`, model `lookout_tower`, `cyl_col`, `box_col` |
| `kit_camps.gd` | KitCamps | `campfire` (with its crackle), models `tent`, `log_seat`, `flag`; `log_by`, `seat_on`, `look_yaw`, `strongbox`, `castaway`, `pirate_camp` (GruntCamp), `den` (pier, sloop, shacks, tower, captain; GruntCamp), `training_yard` |
| `kit_cave.gd` | KitCave | `cave` (BroodCave: `shape_seed`, `hoard_id`, `title`), `inn` (Buildings.tavern_hall + its door kept clear) |
| `kit_dungeons.gd` | KitDungeons | a generated island's caves (pool of 7 kinds): `plan` (worker), `steps`, `poi`, `site_clear`, `land_clear`, `top`, `path_to`, `spots`, `room_of`, `loc` |
| `kit_temple.gd` | KitTemple | the ruined temple: `plan`, `build`, `populate` (hall, two lever shrines, a gated sanctum) |
| `cave_mesher.gd` | CaveMesher | rooms + tunnels as distance fields, meshed by surface nets (data only) |
| `kit_life.gd` | KitLife | `spawn(ctx, cast)` (cast = data: `{"cfg", "at", "face", "y"}`), `npc`, `at_marker`, `route`, `ring`, `look_for(name)` |

Brinehollow's cast is data in `scripts/island/brinehollow_cast.gd` (`dockhands`, `people`).

## Life on a generated island (IslandLife, Villager, KitQuests, LifePools)

A piece that gives people somewhere to be, or adventurers somewhere to go, **feeds `isl.life_spots`** as it
builds (before the "life" step, which runs after every site):
- work and gathering: `{"kind", "at": Vector2, "face": Vector2, "hub": the hamlet's plaza middle, "lane": island
  points from the spot to the hub's ring (KitLife.HUB_R), "y": a floor}` (lane and y optional; a missing lane is
  straight in to the ring). Kinds: plaza, inn, home, market, nets, forage, dock, boats, stall, or any new one (add
  its `where` and barks to LifePools). Any fed village spot replaces everything derived from today's IslandVillage.
- places for quests: `{"kind", "at", "poi": true, "name": "the bat roost", "r": its size, "clear": Callable (true once
  cleared: a "clear" quest), "verb": "Hunt"}`. A fed POI kind replaces the derived one (camp, lair, ruins, lookout, beast).
Nothing is guaranteed: no village spots means no people and no quests; quests take the seeded kinds the island
can give. Positions are a function of `Weather.hour()`, so guests see the same without messages. Bodies are
built on the worker in `IslandLife.plan`; anything unused is unstocked. Quest flags carry the island's seed.

### Interiors on generated islands (KitDungeons, KitTemple, CaveMesher, Dungeon)

- `KitDungeons.plan(isl)` runs in `GenIsland.prepare` (after the paths, before the terrain's paint and the
  vegetation): 1-3 caves from `POOL` (no kind twice) plus the temple on ~40%, each in a spot `site_clear`
  of the sites (`KEEP`) and `land_clear` (on land, off paths); it reserves the footprint and adds a path to
  the mouth (`path_to`). The result is `isl.interiors`; `KitDungeons.poi(e)` is what a planner, quest or
  creature placer reads (chambers with free `slots` {floor, roof}, `boss_slot`, `boss`, the `enemies` node path).
- `KitDungeons.steps(isl)` (appended to IslandContent.steps): shell (mesh + trimesh), dressing, population, a
  step each; the temple two. A `Dungeon` node runs it in the world (sleep, banner, boss, the temple's gate).
- **A cave of any shape:** `CaveMesher.make(rooms, segs, seed).mesh(cell, y_min)`: rooms (domes with flat
  floors) and tunnel segments as distance fields, hollowed out of a hull that follows them and runs down into
  the ground, meshed by surface nets (flat facets, projected UVs; surfaces floor/wall inside, turf/moss/rock
  outside), collider faces and flat ledges for plants. Pure data: build it on the worker. `ceiling` and `wall`
  find the rock for things hung from the roof or fixed to the walls. A floor must sit over every bit of ground
  under it (`KitDungeons.top`), or the terrain shows through.
- New cave kind: a `SHAPES` entry (rooms in order, side room, tunnels), `TITLES`, `LOOK`, `BOSS`, a dressing
  case in `_dress`/`_walls`/`_outside` and a population case in `_populate`.
- Tools that touch these: load the scripts once the world is up (`dungeonshot.gd`), never name the classes.

## Authoring a kit piece

1. **Signature:** `static func thing(ctx: KitContext, at: Vector2, <its own parameters>, rng)`. Positions,
   orientation (a facing Vector2, or a frame like KitHarbour's), counts and radii are parameters
   with the reference island's values as defaults. No island constants (`VILLAGE`...) inside a piece.
2. **Seeding:** take an rng from the caller (`ctx.rng(salt)`), never `randf()` or an unseeded
   `RandomNumberGenerator.new()`: guests build the island themselves. Draw from it in a fixed order.
   A model builder that wants variety takes a seed in its spec.
3. **Data plan vs build step.** GenIsland prepares on a worker (`prepare`) and builds a step a frame
   (`finish_steps`). Work out what you can as data first: positions, heights, reserves, specs
   (`plan_place` lists, KitHarbour.plan, plan_waterfront, plan_dressing, KitPaving.plan_*). Data calls
   touch no node, no server, no material (PSXMat's cache isn't thread-safe). Then a build step makes
   the nodes and meshes. Where a piece's rng is drawn inside mesh building (bunting, laundry, gardens,
   the market's wares, the quay's coping) the split would reorder the stream: those stay one build step
   until they take per-item seeds (which changes Brinehollow's look: ask Zach first).
4. **Style:** read materials and palettes from `ctx.style[...]`; add the key to `BRINEHOLLOW` with
   today's value (so Brinehollow is unchanged) and override it in a theme's table.
5. **Reserve** what you place (`place` with a footprint does) so vegetation and later pieces keep off;
   check `ctx.excluded(p, pad)` and `ctx.path_dist(p)` before placing clutter.
6. **Save keys and names:** chests and anything remembered use `ctx.save_key("name")` (Brinehollow's are
   bare names). Nodes another machine must find (camps, NPCs, chests) get fixed names, made in the
   same order everywhere (`Net.key_of` is a path).
7. **Lights:** lamps through `KitLights.post`/`light`, houses' `lamp_light` through `ctx.house`: both take
   from the budget (Brinehollow's `LIGHTS` 12, 10 used). A dark post still glows.
8. **Draw calls:** one merged mesh per kind of dressing (`mb.to_instance`) rather than many nodes; shade
   with vertex colour, not new tints. Many copies of one small thing: a MultiMesh in cells with
   `visibility_range_end` and no shadow (as the vegetation). Ground-hugging meshes (paving) cast no shadow.
9. **Colliders:** a box or cylinder per thing you bump into (`KitLandmarks.cyl_col/box_col`), trimesh only
   for big walk-on shells (the quay, the cave). Small dressing: none or one box.
10. **Nav zones:** a fight area on a generated island bakes its own zone (`NavBaker.add_zone(site, r)`,
    IslandContent._camp); Brinehollow's whole island is one zone (world_generator).
11. **Timing:** wrap each piece in `ctx.timed("piece", ...)`; the build ms land in `build_ms`.

## A district on a generated coast (GenHarbour's patterns)

- **Plan before the vegetation, adapt to the land rather than reshape it.** GenHarbour plans in
  `GenIsland._plan_dock` (after the heights, before `_scatter_vegetation`), so its reserves keep trees
  and rocks off; it needs no height hook: walkways stand on pilings over the beach and the shallows,
  houses go on stilts, and a deck that meets the rising beach just runs into it (terrain through a
  deck plane is a seamless step-off; a deck ending above sand needs a ramp: `_landing`).
- **A frame from the dock** (a bare `KitHarbour` filled by `_frame`: the waterline scanned per 2 m
  station, smoothed, s0/s1 where it stays straight) and `at(s, d)`: everything is laid out in shore
  coordinates, so one plan fits any coast. Validate every spot (`_ok_land`: ground, slope, reserves,
  path; `_ok_water`: depth) and try more candidates than you need; plan the big things first (their
  reserves push the small ones off, not the other way round: the cove's rocks ate its shacks).
- **Walkways as data**: `{"pts", "hw", "ys", "rails", ...}` dicts built into one body per ~60 m (one
  mesh, a trimesh of the deck tops). The deck strip shares its edges between segments (mitred), so a
  curved boardwalk has no wedge gaps; `ys` per point makes ramps.
- **Keep the ship's berth clear**: the ship lies at `GenIsland.mooring()` (pier side +along, 6 m off
  the axis, 17 m long); anything moored or built over the water goes on the other side or past s 16
  (harbourtest checks the hull's box).
- **Props in batches** (`_flush`: build_list chunks of 8 a step, visibility range 220 m); deck props
  keep their own spacing list (the walkway's reserve covers them).
- **Nothing guaranteed, big seeded pools** (Zach, 2026-10-12): a piece rolls its kind from a style
  pool (`harbour_kinds`, `harbour_wild_kinds` when the village is far from the dock: a bare `landing`
  is in it), so two islands in one sea can differ completely; what must always work (the berth, the
  pier, Board ship) is the same in every kind.
- Render with `tools/dev/harbourshot.gd` (each kind forced on several seeds: sea, above, pier, beach).

## Brinehollow stays identical (the check)

Any change to a kit piece Brinehollow uses must leave Brinehollow the same:

```powershell
# before your change (or from main), then after; diff
& $env:GODOT --headless --path . --script res://tools/dev/islanddump.gd -- "$PWD/tools/dev/out/kit/before.txt"
& $env:GODOT --headless --path . --script res://tools/dev/islanddump.gd -- "$PWD/tools/dev/out/kit/after.txt"
git diff --no-index tools/dev/out/kit/before.txt tools/dev/out/kit/after.txt
```

The dump is every node under a freshly built Brinehollow (transforms to the mm, vertex-position hashes,
materials, colliders, lights, NPC configs and routes, loot contents, save ids), the exclusion list, the
paths and the story anchors. Two runs of the same code differ only in the three training dummies'
sack heads (`Props.straw_dummy_mesh` uses an unseeded rng). Then the covering suites (storytest,
qoltest, foresttest, r6-r10, savetest, swimtest, grunttest, yardtest, looptest, `nettest.ps1`).

## The fidelity loop

- `tools/dev/fidelity.gd` (headless): the metrics for Brinehollow and chain seeds, with each island's
  build steps in ms. `FID_KIT=1` runs `KitVillage.dress_generated_village` on the generated islands first.
- `tools/dev/fidelityshot.gd` (GPU): the matched-camera sheet, Brinehollow left (`FID_KIT=1` too).
- `fidelitytest` (suite): report only until phase 3 makes it the >= 0.8 gate.
- Render your piece in place: `islandshot.gd` (island-local cameras, `ISHOT_HOUR=21`), and modelshot for
  its models.

## Gotchas

- **Float exactness.** Brinehollow is reproduced to the bit because the kit keeps its arithmetic: frame
  coordinates in scalar floats (`fx`/`fz`), radii passed as literals rather than derived (`6.2 - 0.8` is
  not the double `5.4`), `-0.0` avoided where it reaches `atan2` (`Vector2(-v.x + 0.0, ...)`).
- **rng order is the look.** Moving a draw from one step to another (or splitting plan from build)
  changes everything after it in that stream.
- **Reserves mean different things.** Brinehollow's are "something is here"; a GenIsland's sites are
  cleared with big disks for the trees. On a built GenIsland use `ctx.own_reserves` and seed `ctx.taken`
  with what's there (IslandVillage.taken).
- **The height hooks come first.** KitHarbour.plan runs before the heights, and the island's height
  function calls `harbour.shape`; anything else that reshapes ground must be planned the same way.
- Tools are SceneTree scripts: call kit statics through `load("res://scripts/island/kit/...").fn(...)`;
  naming Kit classes (or NPC, LootBag) statically there compiles before the autoloads exist.
- A new `class_name` needs `& $env:GODOT --headless --import` before tests see it.
