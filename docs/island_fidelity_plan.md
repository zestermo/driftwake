# Island fidelity plan: every generated island at Brinehollow's level

Brinehollow stays the hand-made starter island and becomes **the reference**: every island
the chain generates should feel as detailed, lived-in and dense as it does. (Zach, 2026-10-09.)

## Where we are

| | Brinehollow (`starter_island.gd` + brood_cave, redtide) | A generated island (`gen_island.gd` + island_content, island_village, beast_arena) |
|---|---|---|
| Size | land radius 305 m | radius 300-450 m (about the same) |
| Code | ~2,650 lines, every district hand-placed | ~1,600 lines, a handful of sites |
| Settlement | harbour town (quay, piers, waterfront houses, harbour front and booths, boats on stocks), village (dressed houses, furnished tavern, market, cobbled plaza, smithy, chapel), paved paths, bunting, laundry, gardens, handcarts, notice board, lit at night | one village: stilt huts round a plaza, an inn, two stalls, a job board |
| Places | lighthouse, ruins, cove, beach camp, smugglers' camp, training yard, forest, pirate den, brood cave (an interior) | camp, bug lair, ruins (pillar ring + chest), summit lookout, the beast's ground |
| People | ~20 named NPCs with dialogue, quests, story barks | elder, innkeeper, trader, cook, 2-3 villagers |
| Ground | splat paint, paving, path wear, dressed shoreline | splat paint, paths |

The gap isn't the terrain or the vegetation (the builder ports those). It's **set dressing,
settlements, landmarks, interiors and life**, which Brinehollow has by hand and the generator
lacks.

## The approach: Brinehollow's pieces become a kit; the generator assembles the kit

1. **Measure "Brinehollow level"** so it's a target, not a vibe. That's a fidelity tool and test
   that score any island on the same metrics: props and dressing per hectare of settled land,
   buildings (and how many are dressed), distinct landmarks, points of interest and the walking
   time between them, NPCs (with dialogue), light sources at night, paved/worn path coverage,
   vegetation variety, interiors, and the cost (draw calls, triangles, main-thread build time).
   Plus matched renders: the same camera recipes (harbour approach, village plaza, a street, a
   landmark, night) for Brinehollow and for any seed, side by side on one sheet.
2. **Extract Brinehollow's builders into reusable kit modules** (`scripts/island/kit/`): harbour,
   quay and piers, waterfront row, village houses and dressing passes (laundry, gardens, bunting,
   handcarts, notice boards), market and stalls, plaza paving, path paving and wear, lighthouse,
   ruins, camps, den, cave mouth and interior, training yard, NPC placement with routines and
   barks, night lights. Each takes an island context (height fn, `place`/`reserve`, rng, theme)
   instead of Brinehollow's constants. **Brinehollow is rebuilt from the same kits** and must look
   and play the same (its tests, plus islandshot before/after), so it stays the reference and the
   kits stay honest.
3. **Theme the kits.** IslandTheme grows from a land and plant table into a full style: building
   style (jungle stilt and thatch vs Brinehollow's timber and stone), material palette, prop set,
   NPC looks, bark and dialogue pools, ambience and music, weather table. Jungle first; the same
   kit later builds snow, desert and forest towns.
4. **Plan districts, not sites.** The generator's site planner becomes a district planner with
   Brinehollow's layout grammar:
   - **harbour district** at the dock (quay or stilt pier, waterfront, boats, booths);
   - **village core** off it (plaza, market, houses along the streets, then the dressing passes);
   - **outskirts** (farms, gardens, a shrine or chapel);
   - **wilds** with 4-6 POIs from a growing pool (camps, lairs, ruins, caves and small dungeons,
     wrecks, lookouts, a hermit), plus the beast's ground.

   Every choice is seeded, so co-op guests build the same island. It keeps the current
   performance shape: data prepared on the worker thread, put into the world a step a frame,
   props in MultiMeshes, visibility ranges, and NPCs prebuilt off-thread.
5. **Life.** Villagers with simple routines (work spots, the inn at night), ambient barks from the
   theme, the job board and elder as now, plus small quests drawn from the island's POIs.
6. **Gate it.** fidelitytest fails a generated island scoring under ~80% of Brinehollow on any
   metric, or over the performance budget. Every landing is checked against it and the side-by-side
   renders.

## The workflow (parallel agents, one worktree each)

Each phase lands before the next starts. Inside a phase, agents claim disjoint areas with
`tools/dev/crew.ps1 claim`.

| Phase | Agents (parallel) | Lands when |
|---|---|---|
| 0. Measure | 1: fidelity metrics tool + matched-camera render sheet + fidelitytest (report only at first) + Brinehollow's baseline numbers | the baseline numbers and sheets are in `docs/island_fidelity_baseline.md` |
| 1. Extract the kit | 1 (serial: it rewrites starter_island.gd): kit modules + Brinehollow rebuilt from them | Brinehollow's suites pass, islandshot before/after match, metrics unchanged |
| 2. Build the kits out | 3-4 at once, each owning kit files: **harbour + waterfront**, **village + market + dressing passes**, **wilds POIs + caves/interiors**, **life (NPC routines, barks, quests)**; plus **theme** (jungle style table) | each kit has its own render sheet; a generated island using it scores higher |
| 3. District planner | 1: the planner assembling the kits, the performance budget, co-op determinism (nettest chain) | fidelitytest passes at >= 80% on 10 seeds; the build-time and draw-call budgets hold |
| 4. Polish loop | rounds of: Zach plays a seed, F12 captures, agents fix what reads as sparse | Zach signs off |

Skill: a `driftwake-islands` skill (written in phase 1, grown in 2-3): how to author a kit piece,
the island context API, seeding, the performance rules, and the fidelity check, so every later
island feature is built to the bar by default.

## Decided (Zach, 2026-10-09)
- **Settlement style: the theme's own.** Brinehollow's density and dressing, built in each
  theme's look (jungle stilts, thatch and rope piers first).
- **Interiors: yes, a few per island**, from a pool: the inn and at least one cave or small
  dungeon per island. They're part of phase 2's wilds/interiors kit.

## Still open
- **Phase 0 runs first,** on its own. Phase 1 starts once Zach has seen the baseline numbers and
  sheets.
- **Performance budget:** up to three islands can stand at once (the one you're on plus the next
  one or two). At Brinehollow's density that's real memory and draw calls, so a far-LOD (props
  culled, NPCs asleep) for the islands ahead is part of phase 3.
- **Every island the same density, or cities denser?** City islands are planned at about every 3rd
  layer.
