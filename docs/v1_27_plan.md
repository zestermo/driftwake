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

## Decided: the cities pass, first in 1.27 (Zach, 2026-10-29)
Zach's notes: the capital and canal city feel empty and vast: a few big lanes, no interiors, the market circle reused,
wrong storefront signs, nothing to do, and no reason to meet the Queen. They get fleshed out before strongholds.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Placement | **First in 1.27**: the cities are the first unstable steps, then the stronghold and fruits | The stronghold's leads (the Queen, the informant) start in the cities | - |
| Layout | **Fixed landmarks, rolled streets**: palace/Doge's palace, harbour, main plaza and the set pieces stay put; the street and alley network between them (varied widths, dead ends, stairs, covered passages, courtyards), the blocks and where shops, interiors and people go are rolled from the seed | Recognisable but different each world | - |
| Market | **No market circle** in either city (it's the villages' piece); markets fit the street plan (a market street, a loggia, a bridge market) | - | - |
| Buildings | Denser, with **second and third storeys**, balconies, arcades and sight pieces you can see across the city | Height and density instead of empty width | - |
| Interiors | **Every shop and service, about a third of the houses**, workshops, several taverns and every set piece. Some with stairs to upper floors, balconies and roof access | Lots of places to go in and look round | - |
| Signs | Every storefront carries **the right sign for what's sold inside** (VendorMarks' trade signs on the building) | Zach: signs didn't match the shops | - |
| Things to do | **Investigations** (clue trails through interiors and alleys: a thief, a missing person, a smuggling ring, ending in a fight or a find), **rooftops and hidden spots** (routes, courtyards, caches), **city jobs** (deliveries, guard bounties on wanted thugs, errands), **games and dens** (gambling dens, cards and dice, arm-wrestling) | Zach picked all four | Pools sized in the preview |
| The informant | **One recurring hooded figure** in both cities' high places (the capital's bell tower, the canal city's campanile). Sells leads to Driftfruits, legendary gear and later the stronghold, for gold or a favour. Who they are stays a mystery | A thread to pull across the chain | - |
| The Queen | **The raid patron + royal favour**: the audience opens a royal quest line that ends at the Admiralty stronghold (she wants something from its vault: its location, a writ, a reward), and a standing with the Crown (royal shops, a title, palace access, discounts) | Zach picked both | - |
| Canal ruler | **The Doge of the lagoon**: elected, in a palace on the grand canal, ruling with the shipwrights' and merchants' guilds (Master Grane among them). The Doge's line leads to the great-power pirate's hideout (the pirate preys on the lagoon's ships) | The canal city's purpose, mirroring the Queen's | - |
| Capital set pieces | **Bell tower** (the informant), **cathedral with crypt**, **grand library** (lore, a hidden room), **theatre / opera house**, **royal gardens with a maze**, **the undercity** (sewers under the streets) | Zach picked all | - |
| Canal set pieces | **Campanile** (the informant), **the Doge's palace**, **a shop-lined bridge** over the grand canal, **a working glassworks**, **a covered fish loggia**, **the undercity** (flooded cellars, smugglers' tunnels) | Zach picked all | - |

### Cities build order (unstable 1.26.x steps, before the stronghold)
C1. **Capital layout:** the rolled street/alley network round fixed landmarks, denser taller blocks, the market circle
    gone, the right signs, shops and homes enterable (the kit's rooms, stairs and roofs).
C1b. **Rooftops (Zach, 2026-10-29: "players will reach the roofs; make it polished, walkable, detailed"):** flat roofs and
    terraces you can walk on (parapets, chimneys, water tanks, laundry, potted plants, skylights, pigeons), planks and
    small bridges between neighbouring roofs, ladders, outside stairs and drainpipes up from lanes and courtyards,
    pitched roofs with walkable ridges where they meet flat ones; a rooftop route across each district.
C2. **Capital set pieces:** bell tower + the informant, cathedral and crypt, library, theatre, gardens and maze, the
    undercity.
C3. **Canal city layout and set pieces:** the same treatment on the lagoon (rolled calli and bridges), the Doge's
    palace, campanile, the bridge market, glassworks, fish loggia, flooded cellars.
C4. **Things to do:** investigations, rooftop routes and caches, city jobs, gambling dens and games, in both cities.
C5. **The rulers:** the Queen's royal line and Crown standing, the Doge's line (both pointing at 1.27's raids).
Each step is rendered at eye height (day and dusk) for Zach's look before it lands, and checked against the
2026-10-24 city detail bar (docs/v1_21_plan.md): warm, cluttered, lived in, not large and empty.

### Cities: open / deferred
- **Preview before building:** a street plan mock for each city (two seeds side by side), the interior list, the
  investigation and job pools, the Queen's and the Doge's quest steps and rewards, the informant's prices.
- Interior budget and streaming (many interiors in one city): built per block as you near it (**assumed**), perf
  checked at the batch's bench.

## Build order (each an unstable 1.26.x step, after the cities)
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

## Status (2026-10-29, night)
Built on main (not pushed, not released):
- **C1 capital layout:** rolled lanes, alleys and courtyards from the world's seed; the right trade sign on every shop;
  a quarter of lane houses shops; walls over leftover gaps read as house sides; far stand-ins so the skyline stays full.
- **C1b rooftops (both cities):** flat roofs walkable and dressed, pitched roofs walkable, planks across lanes, ladders.
- **C1c interiors (both cities):** ~36 rooms in the capital, ~70 in the canal city (shops, homes, workshops).
- **C2 capital set pieces:** the bell tower climbed with the Hooded Stranger in its belfry; the cathedral (forecourt,
  portal, nave, altar); the library (with its hidden room behind the back shelf); the theatre.
- **C3 canal city (first pass):** rolled campi and calli; interiors and rooftops; far fronts; the campanile climbed
  (the Stranger again); the Doge's palace (council chamber, the Doge on the dais); the glassworks; the fish loggia.
Still to do in the cities pass: the palace gardens and maze (needs a flat terrace cut into the hill), the undercities,
the shop-lined bridge, stairs to upper floors, C4 activities (investigations, rooftop caches, city jobs, dens), C5 the
Queen's and the Doge's lines and the Stranger's leads (with the strongholds and fruits), and the previews owed for those.

## Preview for Zach's OK: C4 things to do, C5 the rulers (2026-10-30; nothing here is built yet)
Every pool is rolled per world from the city's seed, repeats drop out once done, and each city holds 2-3 of each kind at
a time (refilled after a rest, like the island loop's leads). Rewards on the island loop's scale (quest XP by level,
gold ~ a chain island's bandit camp), so a city is worth an evening, not a shortcut.

### Investigations (3-5 clue steps through interiors, alleys and roofs; end in a fight or a find)
| # | Name | Clues (where) | Ends | Reward |
|---|---|---|---|---|
| 1 | The rooftop thief | a torn sleeve on a parapet, footprints on a plank, a stash on a hatch roof | chase over the roofs, fight 2 thieves | 1x quest XP, the stolen ring (sell or return: +gold or Crown/Doge favour) |
| 2 | The missing apprentice | the master's shop, a note in a workshop, the dens | found locked in a cellar room behind a den | 1x XP, a discount at the master's shop |
| 3 | The smuggling ring | marked crates in 3 courtyards, a boatman's word, the fish loggia | the ring's room behind the glassworks/a warehouse; 4 smugglers | 1.5x XP, a contraband cache |
| 4 | The forged seal | the library's hidden room, the guild hall, the theatre's back | unmask the forger (theatre) | 1.5x XP, royal favour |
| 5 | The drowned bell (canal) | the campanile, a fisherman, a sunken crate (dive) | the bell's clapper returned | 1x XP, the Doge's favour |

### City jobs (one step, quick; a job board by each city's inn)
Deliveries (a parcel across the city before a dusk deadline), a wanted thug (a named tough in a lane or on a roof),
a lost cat on the roofs (climb and fetch), debt collection (talk or fight), an errand for a shop (fetch 3 of an item).
Reward 0.3-0.6x quest XP, small gold; 5 of each kind in the pool.

### Games and dens
A dice den (the capital's slum, the canal's back calli), a card table (an inn back room), arm-wrestling (a tavern
corner, the docks). Stakes 10-200 gold, won by the island loop's tavern-game rules.

### Hidden caches
8-12 per city: on hatch roofs, in courtyards behind crates, in the library's hidden room, the theatre's flies, the
canal's rooftops; a chest each (a chain island's chest tier), marked on the map once found.

### The Queen (capital) and the Doge (canal)
| | Queen Ilsabet (raid patron + royal favour) | Doge Benedetto Vael |
|---|---|---|
| Opens | after the audience (today's petition, signet, audience) | an audience asked at the palace door |
| Line | 3 steps: a Crown errand in the city (C4 investigation 4), a writ to carry to the stronghold's chain island, "bring me what the Admiralty keeps in its vault" (the stronghold, 1.27 build step 2) | 3 steps: clear a smugglers' den (investigation 3), escort a convoy past the pirate's ships, the great power's hideout (build step 6) |
| Favour ranks | Known, Trusted, Champion of the Crown: royal shops' stock (Trusted), 10% off in the capital, a title on your captain card, palace rooms opened (Champion) | Friend of the Lagoon, Citizen, Gondolier of the Republic: the arsenal's rare upgrades, free water taxis, a title |

### The Hooded Stranger's leads (prices)
| Lead | Price | Where it points |
|---|---|---|
| A cache in this city | 300 gold | one hidden cache on the map |
| A legendary weapon | 2,000 gold or a favour | the island where a named legendary lies (a boss's hoard or a vault) |
| The stronghold's way in | 1,500 gold | a weak point (the sea gate, a wall, a sewer) marked on its chart |
| A Driftfruit | 5,000 gold, or a favour from the Queen/Doge | the island or enemy that holds one (once fruits land) |
One lead at a time per captain; the Stranger moves between the two cities' belfries at dusk.

## Status (2026-10-30, C4 under way)
Built since the preview (on main, tested, not pushed): the hidden caches (9 + 7), KitQuests steps at their own places,
the rooftop thief (capital board), the Watch's three odd jobs (capital board), the Stranger's cache leads (300 gold,
both cities), dice dens (a capital courtyard, a canal campo). Next: a canal investigation and jobs (no board there
yet: offered by its people), the other three investigations (missing apprentice, smuggling ring, forged seal; the
drowned bell needs diving), then C5 (the Queen's and the Doge's lines, favour ranks). Known red: t/island/beast_moves.

## Status (2026-10-30, C4 done)
C4 is complete on main (tested, not pushed): caches (9 + 7), the Stranger's cache leads, all five investigations (the
rooftop thief, the missing apprentice, the forged seal; the smuggling ring, the drowned bell), the capital's board
(the thief, Black Ned's bounty, three Watch jobs), the canal's jobs from its people (three), dice dens in both cities.
**Next: C5.** Favour ranks with each ruler (Crown: Known 3 / Trusted 6 / Champion 9 capital quests done; Lagoon: Friend
3 / Citizen 5 / Gondolier 7 canal quests) with their perks (Trusted / Citizen: 10% off that city's traders via
Journal.perks discount; Champion / Gondolier: a title), shown when you talk to the Queen / the Doge (the Doge needs a
talk: today barks only). Then each ruler's line's first step in the city (the Queen after the audience: a Crown errand =
the forged seal; the Doge: an audience, then the smuggling ring); their later steps wait for the stronghold and the
hideout (1.27 build steps 2 and 6).

## Status (2026-10-30, the cities pass done)
C1-C5 are on main, tested and not pushed. C5 adds city favour (CityFavour: the Crown's Known 3 / Trusted 6 / Champion 9 and
the Lagoon's Friend 3 / Citizen 5 / Gondolier 7. The Queen and the Doge tell you where you stand; the second rank takes
10% off the city's traders) and the rulers' lines' first steps. The Queen sets you on the forged seal after the
audience, and the Doge sends you after Grane's smugglers. Each thanks you once (400 gold and a level's XP share) and
names the next step: the Admiralty's vault, then the pirate prince's convoys. Those steps wait for build steps 2 and 6.
Deferred: the undercities, stairs to upper floors, the rank perks beyond the discount (royal stock, titles on the
captain card, water taxis). Known: "CapitalModels: no material beam" errors print in every capital test (it doesn't
fail them), and t/island/beast_moves is red. **Next:** the strongholds and Driftfruits previews in
docs/v1_27_raids_fruits_plan.md, for Zach's OK.

## Status (2026-10-30, evening): the palace stair, and a pause to switch machines
The palace hill is now terraces with a grand stair (dev notes). Zach's order from here: the undercities, stairs to upper
floors, the cities' night life, then the stronghold and Driftfruit-rework discussion (his direction is in
docs/v1_27_raids_fruits_plan.md). How to resume: docs/handoff_1_27_raids.md.
