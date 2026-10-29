# 1.27: Strongholds and Driftfruits (planning started 2026-10-29)

## What it is
The public roadmap's 1.27: Driftfruits come back into the world, polished to the weapons' standard, and the big set
pieces that guard them, Admiralty strongholds and pirate great-power hideouts, run as raids. Enemies can hold
fruits from one world pool. Built after 1.26 stable ships.

Builds on: docs/devil_fruits_plan.md (why not eat one, the sea's weakness, rescues, the Seafarer tree: agreed
2026-10-15) and docs/strongholds_plan.md (the raid concept, 2026-10-19, its "Open" list). Today: `DevilFruits.IN_WORLD`
is false (since 2026-10-09); the Ember, Wolf and Vine fruits and the fruit tab exist; 1.19's captain-style AI (rivals,
Admiralty officers), the Admiralty's patrols/blockades and 1.25.5's hideouts and pickets are the parts a raid reuses.

## Carried in from 1.26
- Previews owed (1.26 "Open / deferred"): the weapon variants list, the Brinehollow step list, the island-completion
  reward. Zach's 1.26 playtest notes go in as they come.
- Godot 4.8 trial (docs/todo.md), timed for 4.8's release candidate.
- Not in 1.27: the internal id rename (rainy day).

## Decided (2026-10-29)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | Both: Admiralty strongholds + one pirate great power's hideout, and Driftfruits back | Raids give fruits a source worth chasing; fruits give raids a prize | - |
| Order | **Stronghold first** (its prize is loot and bounty until fruits land), then fruits, then the hideout | Zach's pick | - |
| Releases | Unstable 1.26.x steps (GitHub pre-releases for beta updaters) as pieces land, then 1.27 stable | Same as 1.26: each piece playable early | - |
| Raid shape | **Open fortress**: no fixed stages; break in any way (main gate, walls, sea gate, sneaking) | Zach's pick: a place, not a corridor | If it plays aimless: add soft goals (keys, the vault's route) |
| Alarm | Stealth optional (crouch, smoke, quiet kills); being seen raises the alarm, which escalates: reinforcement waves, the inner gates shut, and if it runs long the Vice Admiral comes down to you | Both styles work; loud has a cost | Tune in play |
| Wipe | The whole crew down = **thrown in the stronghold's brig**, kit kept; break out (1.25's arrest/brig) and carry on, the fortress now on alert | Failure becomes a new scene, not a reload | - |
| Top boss | A **Vice Admiral** is the real, winnable fight. At high level an **Admiral** can turn up: a set piece, grab the prize and run to the ship (beatable after 2.0) | A threat bigger than you, without a wall | Level thresholds tune in play |
| Finding it | **Captured orders** (beaten officers, patrols, blockades can drop them; they mark it on the chart) and **rumours** (taverns, elders, a journal lead) | Ties it to the Admiralty fights 1.19-1.26 built | - |
| Prize | A **named legendary weapon** with a trait from the armoury vault, and a **big bounty jump**. Once fruits land, a stronghold vault may hold a legendary fruit | - | - |
| Strongholds | **One per chain**, an island of its own on the chart | - | - |
| Its name | **A proper name per chain** (an Enies Lobby-style named fortress, e.g. "Gallowmere Bastion") | - | Names previewed |
| Great powers | **One** named, persistent great-power captain in 1.27, with a hideout island, crew, look and fighting style. Beating them changes the sea (bounty, they stop raiding, their waters open) | Done thoroughly first; more later | - |
| Fruit count | **6**: Ember, Wolf and Vine reworked to the weapons' standard + **3 new** (1 joke, 1 solid, 1 legendary) | Enough for the pool to matter, deep enough to feel like weapons | - |
| World pool | **Each fruit once per save.** An enemy user who dies frees it: it reappears elsewhere and a rumour points toward it | The source's feel; a fruit you saw used becomes one you hunt | - |
| Sources | **Tiered:** joke fruits from rare chests, merchants, quests; solid from island bosses and hideout vaults; legendary only from strongholds and great powers | Rarity reads from where it came from | - |
| Enemy users | **Yes, from the pool:** some officers, the great power and rival captains eat a fruit and fight with the players' fruit moves (1.19's captain-style AI). Beat them and it's free again | - | - |
| Co-op claim | **It's an item:** whoever opens the vault gets it in their bag; trade, sell or eat like any loot | No new UI; the crew sorts it out | - |
| Costs + no-fruit build | **All of docs/devil_fruits_plan.md ships:** sinking in the sea, slowed and powerless in deep standing water, co-op rescues (dive + grab, life ring, rope), solo: death with the bag washed ashore, a life buoy item; the **Seafarer tree** for captains without a fruit | Without the costs, eating is always right | - |
| Fruit progression | **Like a weapon's tree:** mastery by use, skills, two ultimates (one equipped), a crew technique, alternates: 1.26's plumbing | Players already know it | - |

## Build order (each an unstable 1.26.x step)
1. **The stronghold, the place:** a fortress island per chain (walls, gates, sea gate, yards, keep, armoury vault,
   brig), its proper name, found through captured orders and rumours; garrisons on patrol routes.
2. **The raid:** stealth vs alarm and its escalation (waves, gates shutting, the Vice Admiral coming down), the brig on
   a wipe, the Vice Admiral fight, the Admiral's grab-and-run at high level, the vault's legendary + bounty jump.
3. **Fruits back:** `DevilFruits.IN_WORLD` on, the world pool (once per save, freed fruits reappear with a rumour),
   tiered sources, fruits as items; Ember, Wolf and Vine reworked onto the weapon-tree plumbing.
4. **The costs:** the sea and deep-water weakness, co-op rescues, life ring/rope, the life buoy, the washed-up bag,
   the Seafarer tree.
5. **The 3 new fruits** and **enemy fruit users** (officers, rivals; the stronghold vault's legendary fruit).
6. **The great power's hideout:** the named captain, their island, crew and fight, and what beating them changes.
7. **1.27 stable:** the release check, What's new, the site (roadmap, releases, a news post).

## Open / deferred
- **Preview before building** (feel systems get numbers or a mock first): the 3 new fruits (concepts, moves, tier),
  the 6 fruit trees' node lists over the mastery curve, the Seafarer tree's nodes, the stronghold names, the great
  power's look and style, the alarm's escalation numbers.
- How a wipe in the brig differs in solo (**assumed**: the same, solo).
- Raid scaling for 1-5 captains (**assumed**: by crew size, like the other fights).
- Where a freed fruit reappears (**assumed**: a random chain island's rare chest or a merchant, rumour-led).
