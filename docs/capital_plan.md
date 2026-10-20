# The royal capital (Zach, 2026-10-20): a 1.18.1 sneak peek

## What it is
The First Sea's first city: a royal capital and grand port, the busiest place in the game. 1.18.1 is a small
test/sneak release of its arrival and core district; the rest of the city fills in during 1.20, alongside the second
city (the canal city, docs/roadmap_v2.md).

Today a "city" in the chain (scripts/world/chain.gd: `CITY_LAYERS`, role "city", names like "Port X") is only a name:
it builds as an ordinary generated island. The capital is the first real one.

## Decided (2026-10-20)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Which city | **The royal capital** first: a grand port, a palace on the heights, big markets, the arena later. | The more iconic arrival, and it shows off 1.18's shops and quests. The canal city needs ship classes that don't exist yet. | — |
| Sneak scope | **The arrival and one core district**: a grand harbour to sail into, the city gate, the main market street and plaza, the palace seen up on the heights, crowds, shops, quests. The rest of the city is walled off or a backdrop until 1.20. | A real, dense slice beats a big empty one. | 1.20 |
| Built how | **Hand-built and fixed**, like Brinehollow, with the island kit: the same capital in every world. | Dense and memorable; generated cities come later if ever. | — |
| Style | **Its own grand style**: white stone and terracotta, towers and walls, a palace on a hill above the harbour. Not themed by the island type. | It must read as THE big city. | — |
| Name | **Rolled per world from the world seed**: Port Solenne, Highcrown or Meridian (more can join the list). Original names (docs/originality_plan.md). | Zach likes all three. | — |
| Where | **The chain's first city stop, after two chain islands**: Brinehollow, island, island, then the capital (Zach: "layer 4 if we count Brinehollow as 1"). Adjust `CITY_LAYERS` / the fork rules in chain.gd so the first city comes after exactly two islands on every path. A debug key jumps there for testing. | The first real destination of the voyage. | — |
| District contents | All four: the **grand market + shops** (the 1.18 trades, with a treasure merchant whose stock beats the islands'); the **inn, a bounty/notice board and quests** (an inn to rest and save, city people with their own lines, a few city quests through the journal); the **palace gate + arena teaser** (a guarded palace gate you can't pass yet, the arena's outer walls); a **slum alley with ruffians** (light fighting, the city's dangerous edge). | — | 1.20 adds the rest |
| Crowds | **Busy, inside the perf gate**: visibly the busiest place, but built cheap from the start (crowds at lower update rates with distance, far people as simple figures/MultiMesh, the city's far parts culled, the light budget). The budget is planned before the build. | The market crowd is still off in Brinehollow for cost; the capital can't repeat that. | — |
| Co-op | Standard: the host simulates the city's people and fights; shops' daily stock and the ruffians are the same on every screen (seeded). | CLAUDE.md co-op rules. | — |

### Open / deferred
- The second city (the canal city), the rest of the capital's districts, the arena itself, the palace interior, the
  trainer/respec, doctor and bank services: 1.20.
- The capital's music: **assumed** a new town track for it if there's time, otherwise Brinehollow's town music.
- The ruffians' look and the city guards: **assumed** existing pirate grunts restyled as ruffians, guards as dressed
  townsfolk (no new enemy kinds for the sneak peek).
