# The road to 2.0: the First Sea (Zach, 2026-10-15)

Version 2.0 is Driftwake's first official release: a complete First Sea chain from Brinehollow to a big final boss.
The phases run roughly in order; within a phase, work runs in parallel where the areas don't overlap (CLAUDE.md batch
rules). Details for each item live in docs/todo.md and the per-feature plans.

## 1. The First Sea's islands (the building blocks)
- **Theme plumbing first:** island themes register from their own files (style table, terrain shaping, vegetation
  and creature pools, music, weather, chain weights), so themes can be built in parallel. The jungle moves onto it
  unchanged (fidelity / islanddump checks). This is step 2 of docs/dev_process_plan.md. **Done 2026-10-15**
  (`scripts/island/themes/`: ThemeDef, IslandThemes, JungleTheme; the recipe is the islands skill's "Adding a theme").
- **Four island types:** jungle (done), snow (docs/snow_island_plan.md), desert (docs/desert_island_plan.md), and a
  temperate forest (to plan).
- **Two cities** for variety, each its own kind of place to arrive at: a **royal capital / grand port** (palace, big
  markets, the city arena) and a **canal city with shipyards** (water taxis, dry docks, the shipwright's big upgrades).
- The island fidelity Phase 3 work (district planner, far LOD, fidelitytest as a gate) folds in here where it helps.

## 2. The sea between them
- More ocean encounters: the Kraken at shipwrecks, sea monsters, merchant and treasure ships, storms and whirlpools
  with purpose, floating loot and events. (Sky islands via the knock-up stream come after 2.0.)

## 3. Progression and feel
- **Economy:** gold that means something, rare-gear merchants, treasure uses, crafting and quests, one price curve.
- **Levels and abilities:** even pacing, the skill-tree carousel with discovery and fog of war, weapon families,
  balance; new weapon kinds (polearms first) on the moveset template.
- **Devil Fruits back:** polished to the weapons' level (own moves, effects and tree, the sea's weakness, co-op
  rescues) and back in the world, before 2.0 (Zach, 2026-10-15). Design: docs/devil_fruits_plan.md (why not to eat
  one, the Seafarer tree, saving fruit users from the sea).
- **Effects:** the flipbook rollout across the game's FX, then hero passes.
- **Polish:** whatever play-testing turns up.

## 4. Enemies
- A few more mob variations for the shared pool, used by any island whose theme they fit (so every island gets more
  variety, not just the new ones).

## 5. Player customization
- Gear upgrading and customizing (blue rarity and up: upgrades, effects, abilities, renaming), more clothing and
  looks.
- **Ships to work toward** (Zach, 2026-10-15), bought at the canal city's shipyard and moored at harbours (switch
  between them; each keeps its own upgrades):
  - the starting sloop stays as it is, a little slower; a fast caravel (Going Merry-style); a brigantine/brig (more
    guns and crew jobs); a galleon (two gun decks, room for four); and an oddball submarine (Heart Pirates-style: dives
    under storms and Marines, explores wrecks and sunken ruins, keeps fruit users safe).
  - **Many small upgrades per ship, each one visible:** sails and rigging (+speed/turning, new cloth and colours),
    hull plating and copper bottom, paint, more or heavier cannons and bow chasers, a tangerine grove (small heal/food),
    a crow's-nest cabin, lanterns, railings, flags, figureheads, galley, bunks, a bigger storage chest. Small numbers
    (~5%), big visual identity.
  - **A Seamanship skill tree:** trim efficiency, faster turns, storm handling, reload and broadside aim, faster
    repairs, reading the log pose further, co-op crew-station bonuses.

## 6. The Marines and bounties
- Bounties that grow, wanted posters, Marine patrols and pursuit, named Marine captains hunting you; the Marine
  fortress as a place.

## 7. The First Sea finale
- The first big, heavy boss fight at the end of the First Sea chain.

## Then: version 2.0, the first official release.

## Decided (2026-10-15)
- Devil Fruits come back before 2.0 (phase 3). Sky islands come after 2.0. The cities are a royal capital and a canal
  city. The public website roadmap stays as it is for now (this plan is internal).

## Decided (2026-10-17)
- The fourth island type is an **autumn woodland** forest with a lumber town and a folklore bestiary
  (docs/forest_island_plan.md), built alongside a Brinehollow growth and polish pass (docs/brinehollow_polish_plan.md).
- The katana's animations and effects are redone in the drawn flipbook style (docs/katana_polish_plan.md); the other weapons' awakenings follow one at a time.
- Ship upgrades come as tiered, visible lines bought at Tackett's yard for gold + salvage, with a per-captain Seamanship tree; the extra ship classes wait for the canal city (docs/ship_upgrades_plan.md).
- The drawn-awakening series goes weapon by weapon: katana, then the axe (fire and embers, + Skyfall Smash and War Cry; docs/axe_polish_plan.md), after the katana lands.

## Decided (2026-10-19)
- Phase 3's progression core goes first: fewer, bigger skill nodes (a shared tree on level points, weapon trees by use, mastery carried over within a family), life skills learned by doing, a tighter economy with trait weapons and per-captain loot, food healing + galley buffs, specialist shops and artisans (docs/progression_plan.md). The minimap, journal/quests, NPC encounters and swimming depth get their own grills after it.
- v1.18 holds the progression core, the held map with fog of war, the crew journal and quests, NPC encounters and deeper swimming (docs/v1_18_plan.md). **Rival pirate crews** (matched One Piece-style duels, recurring and scaling, cutscene intros) are the headline of v1.19 (docs/rival_crews_plan.md).
- **Strongholds and the Devil Fruits' return** (concept, 1.20 or later; docs/strongholds_plan.md): Marine strongholds (Enies Lobby-style raids up to an Admiral) and Warlord/Emperor hideouts are where Devil Fruits come from; player-style AI enemies can be fruit users, drawn from one world pool of fruits that frees a fruit again when its user dies. Builds on 1.19's Marines, cutscenes and captain AI; to be grilled before it's built.

## Decided (2026-10-23)
- **1.20 is the world, the cities come next** (docs/v1_20_plan.md "Decided"): 1.20 reworks the beasts and bosses (an
  arena per island type), adds the fog isle, life between places, the polish pass and the names. The capital's full
  build and the canal city move to their own release right after (1.20.x or 1.21), each with its own grill; combat
  and gear and the strongholds move back one step to follow it.

## Release plan (Zach, 2026-10-19)
The core gameplay loop and world progression come before the big fruit update, so players always have real things
to work toward.
- **1.18** (shipping now): the progression core, held map and fog, crew journal and quests, NPC encounters, deeper
  swimming, sailing downtime, fishing, and a perf pass (docs/v1_18_plan.md).
- **1.19: the Marines + rival crews**, plus a **new intro sequence** built on 1.19's cutscene system. The intro shows
  what's out there (the Marines, rival crews, the sea's great powers, the end of the First Sea) and gives the
  captain a reason to get strong and see it all. Today you don't know what the game's goal is
  (docs/v1_19_plan.md, docs/rival_crews_plan.md). Also an interactive timeline roadmap on the website, filled in
  with every version so far.
- **1.20: the world.** One more island type (**a spooky island**). A polish, fidelity and generation-fix pass across
  all the chain islands. **Cities**: at least two on the first chain (the royal capital and the canal city, phase 1).
  **Driftwake's own names**: the One Piece terms players see (Devil Fruit, Haki, Log Pose, Sea King, Marines,
  Soru/Tekkai...) become Driftwake's own, display text only, ids kept, and the same goes back over everything
  already published: the site, every news post, the GitHub release notes v1.8+ (docs/originality_plan.md).
- **1.21: combat and gear.** A weapon animation and skill polish pass, the redesigned flipbook FX pass, the remaining
  weapons (polearms, dual axes, hammer...), new armour and clothes, and a **stat system for armour and clothing**.
- **1.22: strongholds and Devil Fruits**: Marine strongholds and pirate hideouts as raids, Devil Fruits brought back
  properly, fruit-user enemies, the world fruit pool (docs/strongholds_plan.md).
- Then on toward 2.0: the remaining roadmap phases (more sea encounters, enemies, the First Sea finale).

## Decided (2026-10-24)
- **1.21 is the cities** (docs/v1_21_plan.md "Decided"): the capital opened and filled (palace, arena quarter with a
  one-on-one ladder, noble quarter, docks), the canal city as the chain's second city, its shipyard selling the caravel
  (owning and switching ships), Brinehollow's services in the cities and at some chain harbours. Combat and gear is 1.22,
  strongholds and Driftfruits 1.23.
- **1.22 is crews and parties** (Zach, 2026-10-24): crews of up to **5** captains (today 4: Net.MAX_CLIENTS 3), a real
  crew/party system and UI, quests and markers that play well with a full party (the journal is already the crew's
  own, synced by the host), and polish on the maps and quest markers. Its own grill and a UI mock for Zach's OK first.
  Combat and gear moves to 1.23, strongholds and Driftfruits to 1.24. (The site's roadmap is renumbered with 1.21.)

## Decided (2026-10-26)
- **1.23 is the Playtest pass** (docs/v1_23_plan.md), after a 2 h co-op playtest of 1.22: a bug pass, a poise meter and
  smarter enemies, weapon points per tree, the beast motion and spectacle pass, sea pursuit and the Marines' response,
  a story arc per island, and the bounty made visible. Combat & gear moves to 1.24, strongholds and Driftfruits to 1.25 (then 1.26: 1.25 became Edy, the Captain page and a content pass; Zach, 2026-10-28).
- **Stay on Godot** (Zach asked about Unity/Unreal, 2026-10-26): the frames are CPU-bound by our own scripts, so 1.23
  gets a perf track instead (spike logger first, time-sliced builds, AI/animation LOD, native C++ for measured hot
  paths); docs/v1_23_plan.md "Performance track".
