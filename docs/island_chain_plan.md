# Island chain plan (roguelike hybrid)

Brinehollow is fixed: reach level 5, get the ship, beat Captain Morrow at Redtide Rock and get
the **log pose**. Past that, every new game generates a chain of islands from its seed.

## Decisions (Q&A, 2026-10-08)

**Run shape**
- No run reset: death works as it does now. "Roguelike" means the chain is generated per game.
- Finite **seas** that chain: about 9 islands per sea, ending in a sea-boss island, then a harder sea.
- Continuous sailing (no loading screens or voyage cuts). The next island builds as you leave the current one, and the one behind is freed.
- One-way: once you leave an island it's gone.
- Brinehollow, Redtide Rock and the sea features around them stay as the "tutorial sea". The 6 placeholder islands go. The chain starts past Redtide.

**Log pose and forks**
- It sets after a while on the island, or right away when you beat the island's boss.
- It points at the next island. At a fork it shows two needles, and each one tells you the theme and a danger level.
- Forks split for 1-2 islands, then rejoin (usually at a city), in a map shaped like Slay the Spire's.
- Legs vary in length: some short hops, some long voyages. The two sides of a fork can differ in distance.
- At sea between islands: enemy ships scaled to the next island's level, hazards (reefs, fog, whirlpools, storms), Sea Kings and monsters, and small finds (wrecks, bottles, islets with a chest).

**Islands**
- Regular islands are 600-900 m across. Cities are bigger, about 900-1200 m.
- Each island has a level: Brinehollow (with Redtide) is 1-5, the first chain island 6-7, and each island adds about 2-3. Enemies, bosses and loot tiers scale with it.
- First-sea themes: **jungle, snow/ice, desert, temperate forest**. Later: swamp, rocky sky-cliffs, volcanic, ancient ruins, haunted.
- Enemies: humans everywhere (pirates, Marines, bandits, dressed for the theme) plus 1-2 native beasts per theme.
- A regular island has:
  - 2-3 encounters from: a camp with a named captain, a beast lair, an ambush or event (road ambush, patrol, village raid), a rival wanderer who challenges you.
  - Points of interest from: ruins or a shrine with loot, caves and small dungeons, vistas and secrets (peaks, waterfalls, beached wrecks, treasure maps), NPC stops (hermit, castaway, trader camp).
  - At least one outpost village, not always on the coast: a trader and food, an inn to rest, heal and save, quests and rumours (the boss, the fork ahead), and buildings and people dressed for the theme.
  - A main boss drawn from a pool of handmade bosses, each tied to themes.
- **City islands**, about every 3rd island:
  - Mostly for trade: shipyard upgrades past Tackett's, full markets, services (trainer/respec, doctor, bounty board, bank) and crew recruits.
  - Light fighting: enemies outside, a slum with ruffians, sometimes a boss.
  - The layout changes with the theme (desert walled city, icy fortress-town, jungle canopy city...).

## Technical shape (to settle in step 1)

- **Chain graph** (`scripts/world/chain.gd`): built from the world seed. Each node has a theme, a role (regular, city or sea boss), a level, its own seed and its links. Saved: the current node, the path taken, the log pose state and the current island's flags.
- **Island builder**: generalise Brinehollow's approach (its own 3 m heightfield chunk, coast by bearing, flat zones, paths, splat paint) into a themed builder. A **ThemeDef** data table holds the ground textures, vegetation set, rocks, weather table and fog, music, enemy roster, building style and boss pool.
- **Streaming**:
  - Build the next island(s) across several frames when the log pose sets, so there's no hitch.
  - Free the old island once the ship is well clear of it.
  - Per-island updates: the shallows map (`Ocean.shoal_fine` is a single rect today), navmesh zones, `EnemyShip.no_go`, fleet zones on the leg, SeaFeatures along the leg.
- **Distance from the origin**: 9 islands at 1-3 km each is 10-25 km out, where floats start to jitter. We'll probably need an origin shift at each arrival. The waves use world position, so `Ocean.clock()` and the wave offset need care.
- **Co-op**: the host picks at a fork, and guests build the same island from the node seed. The chain node and log pose state go in the join world state.
- **UI**: a log pose item plus needles on the compass strip; the sea chart centred on the current island, with the chain's next nodes shown.
- **Weather**: snow and sandstorm are new to the Weather autoload. Each theme gets its own weather table.

## Milestone 1: chain + one theme (jungle) end to end

1. Strip the 6 placeholder islands. The Redtide victory gives the log pose, gated to level 5 (was 10). **Done.**
2. Chain graph and save: seas, nodes, forks, levels, roles. **Done.**
3. Log pose: the item, compass needles, the set rule (time or boss), the fork pick with theme and danger, and co-op sync.
4. Generic island builder plus ThemeDef, ported from StarterIsland's terrain, splat, paths and vegetation code. Jungle theme first. **Done (GenIsland, IslandTheme; built on a worker thread).**
5. Streaming: build ahead, free behind, shallows, navmesh, no-go areas and the origin shift.
6. Jungle island content:
   - Layout planner: dock, village, 2-3 encounter sites, POIs, boss arena, paths between them.
   - Village: themed huts, trader, inn, quest giver.
   - Encounters: a pirate camp with a named captain (reuses the den/GruntCamp) and a beast lair (bugs/spitters).
   - POIs: ruins with a chest, a cave, a vista.
   - A new handmade jungle boss.
7. Sea legs: a scaled fleet zone and hazards along each leg.
8. Level scaling: enemy HP and damage, XP and loot tier by island level.
9. Tests (chaintest: graph, save, log pose, streaming; a co-op nettest step) and a render tool (islandshot for generated islands).

**Later milestones:** snow, desert and forest themes (terrain, weather, beasts, village style, bosses), city islands (first one themed), the sea-boss island, ambush and rival encounters, NPC stops and quests, crew recruits, more seas.

## Milestone 1 picks (2026-10-08)

- The jungle boss is a beast.
- The log pose is a small spherical compass like in the show: a glass ball on a wristband with a floating needle. While you hold it, a 2D icon in the same style pops up on screen, with its needle(s) turning toward the next island(s).
- It sets after 15 real minutes on the island (15 in-game hours; one tunable constant), or right away when the boss falls.
