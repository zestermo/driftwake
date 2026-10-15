# The road to 2.0: the First Sea (Zach, 2026-10-15)

Version 2.0 is Driftwake's first official release: a complete First Sea chain from Brinehollow to a big final boss.
The phases run roughly in order; within a phase, work runs in parallel where the areas don't overlap (CLAUDE.md batch
rules). Details for each item live in docs/todo.md and the per-feature plans.

## 1. The First Sea's islands (the building blocks)
- **Theme plumbing first:** island themes register from their own files (style table, terrain shaping, vegetation
  and creature pools, music, weather, chain weights), so themes can be built in parallel. The jungle moves onto it
  unchanged (fidelity / islanddump checks). This is step 2 of docs/dev_process_plan.md.
- **Four island types:** jungle (done), snow (docs/snow_island_plan.md), desert (docs/desert_island_plan.md), and a
  temperate forest (to plan).
- **Two cities** for variety, each its own kind of place to arrive at (to plan: e.g. a grand port or royal capital,
  and a canal/shipyard city), home to the bigger shops, the shipwright's upgrades and the city arenas.
- The island fidelity Phase 3 work (district planner, far LOD, fidelitytest as a gate) folds in here where it helps.

## 2. The sea between them
- More ocean encounters: the Kraken at shipwrecks, sea monsters, merchant and treasure ships, storms and whirlpools
  with purpose, floating loot and events. (Sky islands via the knock-up stream: decide whether they're part of 2.0.)

## 3. Progression and feel
- **Economy:** gold that means something, rare-gear merchants, treasure uses, crafting and quests, one price curve.
- **Levels and abilities:** even pacing, the skill-tree carousel with discovery and fog of war, weapon families,
  balance; new weapon kinds (polearms first) on the moveset template.
- **Effects:** the flipbook rollout across the game's FX, then hero passes.
- **Polish:** whatever play-testing turns up.

## 4. Enemies
- A few more mob variations for the shared pool, used by any island whose theme they fit (so every island gets more
  variety, not just the new ones).

## 5. Player customization
- Gear upgrading and customizing (blue rarity and up: upgrades, effects, abilities, renaming), more clothing and
  looks, ship customization.

## 6. The Marines and bounties
- Bounties that grow, wanted posters, Marine patrols and pursuit, named Marine captains hunting you; the Marine
  fortress as a place.

## 7. The First Sea finale
- The first big, heavy boss fight at the end of the First Sea chain.

## Then: version 2.0, the first official release.

## Open questions
- **Devil Fruits:** they aren't placed yet. Before 2.0 (they're the heart of the fantasy) or after?
- **Sky islands:** part of 2.0's sea encounters, or after?
- **City arenas:** with the cities in phase 1, or with customization/progression?
