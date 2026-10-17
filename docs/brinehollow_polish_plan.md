# Brinehollow fidelity and growth pass (plan, 2026-10-17)

## What it is
Brinehollow (`scripts/island/starter_island.gd`, hand-made, the kit's reference) gets a polish and growth pass
so it matches the newer chain islands: more land, a denser and more finished town (proper doors and steps, fixed
roofs and textures, a real market street, a shrine-terrace upper district, more buildings), farmland and new wild
places in the new land, and more life (townsfolk on routines, chimney smoke, night lights and street sound, a
busier harbour). Brinehollow stays the reference, so the islanddump changes on purpose and fidelity.gd's
Brinehollow numbers rise (generated islands' ratios drop; fidelitytest is report-only until Phase 3).

## Decided (2026-10-17)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Island size | Grow LAND_R 305 -> ~400 m (the jungle's top range); EXTENT grows to fit | Matches the newer islands without turning walks into treks | Play-test: walks feel long or empty |
| Core | Village, quay, market, training yard, den, ruins, cove, camps, cave keep their coordinates | Story, quests and the world suites keep holding | - |
| Town growth | The quay-to-plaza run becomes a market street lined with shopfronts, stalls and awnings; a second row of houses climbs the hill behind the village; plus a new upper district | Zach: denser, more alive | - |
| Upper district | A **shrine / temple terrace** on the hill: a shrine on a terrace with lanterns and a long stair, houses and teahouse-style shops along it, linked to the market street by stairs and a switchback lane | Zach's pick | - |
| Outer ring (305-400 m) | Farmland on the gentle side (fields, an orchard, a windmill hamlet) and 2-3 new wild places on the far side (a waterfall pool, a wreck on the rocks, a second cove) | Walks out of town have things to find | - |
| Doors | Every building gets a proper closed, framed, panelled door with steps or a stoop, built in the shared house builder (`Buildings.house`, tavern, smithy, chapel...), so chain-island houses gain them too | Shared builder = every island improves | Openable doors / new interiors (later, own pass) |
| Roofs and textures | The agent renders every building and street from several angles and fixes what's wrong (seams, stretched or wrong textures, roof gaps and overhangs, z-fighting, floating or sunk pieces); Zach adds his own finds as F12 captures or notes | Zach's pick | Zach's list arrives |
| Life | More townsfolk on daily routines (shopkeepers, kids, porters, fishers; the market by day, the tavern at night) with barks; chimney smoke, more lit windows and lanterns, a market murmur and street sound; a busier harbour (more boats moored and coming and going, cargo loading, fishers on the piers) | Zach's picks (small animals not chosen) | - |
| Co-op | Everything seeded from Brinehollow's fixed SEEDS (guests build it themselves); people's positions a function of Weather.hour() | Standing rule | - |
| Budget | Brinehollow is the perf target (bench <= ~10 ms mean; v1.14 9.2 ms): every piece benches before/after; new dressing as MultiMesh/merged meshes, lights from the budget (LIGHTS), NPCs asleep when far | Standing rule | - |

### Order (agents, separate files)
1. **Buildings** (`scripts/props/buildings.gd`, building textures): doors and steps on every building kind, the roof
   and texture audit and fixes. Lands first; every island's houses change.
2. **Layout** (`scripts/island/starter_island.gd`, the kit modules it calls): the land to ~400 m with the core fixed,
   the market street, the second row of houses, the shrine terrace, the farms and windmill hamlet, the wild places.
3. **Life** (`scripts/island/brinehollow_cast.gd`, KitLife, ambience, harbour traffic), after the layout's town
   pieces have landed, so the people live in the new streets.

### Open / deferred
- Openable doors and new walk-in interiors (later; touches co-op).
- Small animals (cats, chickens, gulls on roofs): not chosen this pass.
- **assumed:** the farmland side is the island's gentle south-west, away from the den's cliffs; the agent may pick
  another side if the land reads better, and says so.
- **assumed:** new wild places get their own chests (fixed names, bare save keys) and a quest hook only if one
  fits the existing story; no new boss.
