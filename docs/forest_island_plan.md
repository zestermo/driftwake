# The forest island type (plan, 2026-10-17)

## What it is
The fourth First Sea island type (docs/roadmap_v2.md phase 1): a temperate **autumn woodland**, built to the
jungle's standard on the island kit like snow and desert (docs/snow_island_plan.md, docs/desert_island_plan.md),
as a new theme in its own files (`scripts/island/themes/forest_theme.gd` + its life, places, plants, props,
creatures, textures; the recipe is the islands skill's "Adding a theme"). Rolling hills of oak, maple, birch and
beech in reds, oranges and golds, leaf litter, rivers and waterfalls, misty mornings, a lumber town on a river,
and a folklore bestiary: spirits, treants, will-o'-wisps, cursed hunters.

## Decided (2026-10-17)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Kind | **Autumn woodland**: deciduous hills (oak, maple, birch, beech), reds/oranges/golds, leaf litter, rivers, waterfalls, mist | Most distinct from jungle, snow and desert at a glance | - |
| Forest variety | Each island rolls one of the theme's `forests` (autumn maple, birch-and-pine, ancient oak grove, misty firs), as the jungle does | The subtype standard: big pools, nothing guaranteed | - |
| Town | **Lumber town on a river**: log and timber-framed houses with steep shingle roofs, a water-wheel sawmill, log piles and a log flume, charcoal burners and hunters' lodges in the woods | Zach's pick | - |
| Bestiary tone | **Folklore-heavy**: spirits, treants, will-o'-wisps and cursed hunters are the main draw, with ordinary woodland animals around them | Zach's pick | - |
| Set pieces (pool, nothing guaranteed) | A **hollow giant tree** (climbable, a dungeon in its trunk and roots), a **ruined castle in the woods** (overgrown keep, a boss or bandit lair), a **waterfall gorge** (big falls, a cave behind, rope bridges) | Zach's picks | - |
| Co-op | Every piece seeded from the island's seed; the host runs creatures and bosses | Standing rule | - |
| Subtype standard | Big seeded pools, nothing guaranteed, dense life, fights in the terrain (in the trees, the gorge, the castle), a creature pool, a roaming beast, several bosses | Standing rule | - |

### Order (one agent, its own files)
1. Foundations: forest_theme.gd registered (its line in IslandThemes.SCRIPTS), the KitStyle "forest" table,
   terrain (rolling hills, river valleys, gorges), autumn textures and palette, coasts, the autumn trees and ground
   cover (`scripts/props/forest_plants.gd`). Lands on its own, the theme rolling in the chain.
2. The lumber town (style table, log/shingle houses through Buildings.house spec keys and the theme's own models,
   the sawmill and flume as the theme's props), harbour styling, the people's text (forest_life.gd).
3. Life: fauna and folklore creatures, people and clothing, ActorSleep.
4. Bosses and set pieces: the boss pool, the hollow tree dungeon, the ruined castle, the waterfall gorge.
5. Music, ambience and weather odds; fidelity and perf against Brinehollow; co-op (`nettest.ps1 chain`).

### Open / deferred
- **assumed:** the bestiary pool. Bosses: an elder treant, an antlered forest spirit (the stag king), a cursed
  huntsman (humanoid, with hounds). Minibosses: a will-o'-wisp mother, a moss golem, a hornet queen. Roamer: the
  wild hunt's rider at night. Fauna: deer, boar, foxes, owls, crows, wisps (floor/canopy zones); cave fauna from
  the jungle's bat/mite set plus a forest kind. The agent may change names and kinds; it says so in the report.
- **assumed:** weather odds: more cloud and rain than the jungle, morning mist (haze), falling-leaf particles left as
  a hook for the shared weather/ground pass (not built in the theme).
- **assumed:** size in the jungle's range (radius ~340-460 m); hills break the eyeline like snow's pines.
- **assumed:** a `forest` and `forest_night` track and a woodland bed (birdsong by day, owls and wind at night) via
  the driftwake-audio generators.
- Anything that needs a new option in `scripts/props/buildings.gd` or a kit module is requested through the lead
  (the Brinehollow buildings agent owns buildings.gd this batch).
