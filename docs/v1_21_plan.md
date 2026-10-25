# v1.21: the cities (Zach, 2026-10-24)

## What it is
The First Sea's two cities, done properly: the royal capital (its shell, core district, crowd and people landed in
1.18.1, docs/capital_plan.md) opened up and filled, and the canal city built from scratch as the chain's second
city. With them: the capital's arena (a one-on-one ladder), the canal city's shipyard and the first ship to buy (the
caravel), and Brinehollow's services on the chain at last (the cities, and vendors at some chain harbours).

What exists (2026-10-24): `scripts/island/capital_*.gd` (CapitalIsland, CapitalPlan, CapitalShell, CapitalDistrict,
CapitalLife, CapitalCrowd, CapitalModels, CapitalStyle), t/capital (placement, shell, district, life, debug_jump,
occluders). `Chain.CITY_LAYERS = [3, 6]`: layer 3 is the capital (Lv ~10-11), layer 6 a city by role only (an
ordinary generated island named "Port X", Lv ~16-17): the canal city takes it. One ship today (the sloop: ShipLines
upgrades at Tackett's yard, Seamanship). Driftfruits are out of the world (DevilFruits.IN_WORLD false) until 1.23.

## Decided (2026-10-24): the grill

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | **Both cities, full**: the capital's other districts opened and filled, the canal city built as the chain's second city (layer 6). | Zach. | - |
| Capital districts | **All four**: the palace (through the gate: courtyard, throne hall, the crown's people, a quest line), the arena quarter (the arena, stands and crowd, the fighters' yard, the arena master), the noble quarter (villas and gardens on the heights, rich people, a rare-gear merchant), the docks and warehouses (the working port, smugglers, a black market). | Zach. | - |
| The arena | **A one-on-one ladder, playable in 1.21**: nonlethal bouts with wooden weapons in front of a crowd, against captain-style AI (the rival duel system: CaptainBrain, RivalDuel). Team battles and free-for-alls later. | Zach. | The team mode |
| Arena prizes | **Ranks, gold and a champion's prize**: a ladder of named fighters, a purse per win, beating the champion gives a unique trophy weapon and a title, then title defences for smaller purses. **A rare Driftfruit slot in the champion's prize, wired now, paying out only once fruits are back in the world (1.23)**; till then that roll gives the trophy weapon. Purses: the table below, for Zach's OK before the build. | Zach (the fruit: reopened the fruits-out rule only as a 1.23 hook). | Play |
| Arena co-op | **Each captain's own bouts**; the crew watches from the stands (cheers, groans). | Zach. | The team mode |
| Canal city look | **Lagoon shipbuilders**: built out on a lagoon, tall narrow brick and timber houses in faded colours, arched bridges, mooring posts, the great shipyards (hulls on slipways, cranes) at its edge. Working and busy: the opposite of the capital's white stone. Hand-built and fixed like the capital, its name rolled per world. | Zach (built-how and name follow the capital's decided pattern). | - |
| Getting around | **Bridges and water taxis**: walk the streets and bridges; boatmen at landings row you along the canals to other landings. Your ship moors at the outer harbour. | Zach. | - |
| Ships | **One new ship: the caravel**, sold at the canal city's shipyard, done properly: bought, moored at harbours, switch between your ships, each keeps its own upgrades. The brig, galleon and submarine later on the same system. | Zach. | Each later ship |
| The caravel | **A sidegrade: fast and nimble** (faster, quicker to turn, a little more hold, the same or fewer guns: the explorer's ship; the brig and galleon later are the gun ships). Numbers and price: the table below, for Zach's OK before the build. | Zach; the feel-systems rule. | Play |
| Services | **The cities carry the full set** (shipwright, trainer/respec, storage, inn, the rest of Brinehollow's), the canal city's shipwright the big one; **and some chain islands' harbours get one vendor each** (one upgrade line or service per port). | Zach. | - |
| Releases | **Unstable pieces, then stable**: each finished piece a 1.20.x pre-release, then the stable 1.21 with its news post. Claude tags and releases each (Zach, 2026-10-24: "fully complete, tag and release it"). | Zach. | - |
| Perf | **Ship anyway if the gate fails at the end**, like 1.20, and note it; the cities still get crowd and draw budgets planned up front (the capital's crowd pattern: far people as MultiMesh, rates by distance, districts culled and asleep when far). | Zach. | The perf pass |
| Co-op | Standard: the host simulates the cities' people, the arena's bouts and the taxis; shops' stock seeded; a ship bought is the crew's (the buyer pays). | CLAUDE.md. | - |

### Number tables (for Zach's OK before those pieces are built)

**The caravel against the sloop** (the sloop's numbers from ship.gd; upgrades stack on both the same way):

| | Sloop | Caravel |
|---|---|---|
| Top speed | 11.0 m/s | 13.0 (+18%) |
| Turn rate | 0.55 | 0.68 (+24%) |
| Acceleration | 2.6 | 3.1 |
| Hull | 400 | 340 (-15%) |
| Guns | 2 a side (+ the quarterdeck pair, bought) | 2 a side, no quarterdeck pair; a bow chaser fitted |
| Hold | as now | +4 slots |
| Price | (yours) | **1,400 gold + 12 salvage** (a full sloop line costs ~950 at the yard) |

**The arena ladder** (the capital is Lv ~10-11; a beast boss there pays ~310 gold):

| Rank | Fighter | Purse |
|---|---|---|
| 1 | a rookie (one weapon, no skills) | 40 |
| 2 | a brawler | 60 |
| 3 | a duellist (skills) | 90 |
| 4 | a veteran | 130 |
| 5 | the champion's second (an ultimate) | 180 |
| 6 | **the champion** | 300 + the trophy weapon + the title "Champion of <city>" (+ the Driftfruit slot from 1.23) |
| Defence | a challenger, repeatable once a day | 80 |

### Open / deferred (**assumed**: chosen for Zach, to review in play)
- The order and pieces (each a 1.20.x pre-release): **1.20.1** the capital's services, docks and noble quarter;
  **1.20.2** the palace and its quest line; **1.20.3** the arena and its ladder; **1.20.4** the canal city (shell,
  districts, people, water taxis, services); **1.20.5** the shipyard, owning ships and the caravel; **1.20.6** the
  harbour vendors. Then the stable 1.21. **assumed**
- Harbour vendors: about half the chain's regular islands (seeded), each one line (sails, guns, hull, a ship
  service or a trainer). **assumed**
- The palace quest line: three or four quests for the crown's people, ending in an audience. **assumed**
- Each city gets its own town music (the audio generator), the canal city's a lagoon/shanty feel. **assumed**
- The canal city's names (rolled per world, original): Saltmere, Lantern Reach or Brackwater. **assumed**
- The arena's wooden weapons: every weapon kind's mesh in plain wood, no trait effects; bouts end at a knockdown
  below 10% health (nonlethal). **assumed**
- Team battles, free-for-alls, the brig, galleon and submarine: later releases.
