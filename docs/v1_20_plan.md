# v1.20: the world (Zach, 2026-10-19)

## What it is
The world round before cities and combat polish: a new spooky island type, a polish, fidelity and generation-fix pass
across all the chain islands, the **beasts and boss fights reworked**, more life between points of interest, and at
least two cities on the first chain (the royal capital and the canal city). See docs/roadmap_v2.md "Release plan".

## Zach's notes (2026-10-19), to grill into decisions before the batch

### Roaming beasts
- They feel **copy-paste**, with few unique moves each.
- They're **very hard to fight in melee**.
- **Steep terrain breaks them:** on islands with big elevation changes (snow, desert dunes, forest ridges) their
  animations, pathing and attacks don't work on steep hills.

### Large beast boss fights
- Few unique moves, **janky, rough models**, stiff animations, not fun to fight.
- The **canopy-style arena** (made for the jungle) doesn't suit other island types. On the snow island it should be
  something like **an ice cave in the side of a mountain**. Each theme needs an arena of its own kind.
- **The desert's sand king / worm** needs more moves and variety: in its second and third stages it spams the same
  ability over and over.
- **The jungle's snake boss is good but needs a buff.** When it bursts out of the jungle, it barely enters the arena
  (it comes out a few feet from the side). It should **cross the arena back and forth in long straight lines, like a
  train**.

### Also noticed (2026-10-20, making the 1.18 site art)
- The campfire flame renders as a tall pale block at dusk (siteshot camp); the dive has no light shafts.

### Between points of interest
- More **ambient creatures** and **obstacles** in the space between places, so travelling an island isn't empty.

### Also in 1.20
- A **spooky island** type (a new theme on ThemeDef, built the way snow, desert and forest were).
- A **polish / fidelity / generation-fix pass on all chain islands** (fidelity loop, generation bugs).
- **Cities:** at least two on the first chain.

## Decided (2026-10-23): the grill
The plan of record for 1.20. Where it differs from the notes above or docs/roadmap_v2.md, this wins.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | **The world now, cities next**: beasts and bosses reworked with an arena per island type, the fog isle (the spooky island), life between places, the polish pass, Driftwake's own names. **The capital's full build and the canal city move to their own release right after** (1.20.x or 1.21), each with its own grill. | Each city is a 1.18-sized job; the beasts are the biggest feel problem. | When 1.20 ships |
| Order | **Beasts and bosses first**, then the arenas, life between places, the fog isle, the polish pass, the names. | Every island type uses them; the worst pain point. | - |
| Boss bodies | **The worst rebuilt, all re-moved**: every boss and roamer gets new moves, phases and telegraphs; the roughest models and rigs are rebuilt (on shared quadruped / serpent rigs), the decent ones kept and polished. **Which are rebuilt: Zach marks them on a render sheet** of every boss and roamer (idle and an attack, the same angle) before any rebuild. | Looks are judged from pictures. | The sheet |
| Rebuild list (2026-10-23, from the beast sheet) | **Rebuilt bodies**: 5 behemoth, 7 great bear, 8 ice golem, 9 rimeback, 12 basilisk, 13 sand lion, 14 dune strider, 16 elder treant (5, 7, 9, 13 and 14 shared one blocky quadruped build: a new shared quadruped rig). **Kept and polished**: 1 ape, 2 serpent, 3 stalker, 4 mantis, 6 snow leopard, 10 sandworm, 11 giant scorpion, 15 stag king, 17 wild hunt. Numbers: tools/dev/beastsheet.gd. | Zach, from the sheet. | - |
| Fair melee | **Openings after big moves** (every big attack ends in a readable, punishable recovery; staggers at damage thresholds) and **less knockback** (most hits push or stagger; few throw you off your feet). | Zach. | After play |
| Move lists | **Previewed first** (the feel-systems rule): a table per boss and roamer (moves, phases, telegraphs, openings) for Zach's OK before building. The sandworm stops spamming one move in stages 2-3; the jungle serpent crosses its arena in long straight charges, like a train. | 1.18's skills rework built from picks felt wrong. | Each table |
| Slopes | **Both**: arenas and roaming paths kept off steep ground (slope limits in placement) and attacks that follow the ground (slope-aware lunges, feet on the slope). | Snow, dunes and forest ridges broke them. | After play |
| Arenas | Jungle: **the canopy** (as now). Snow: **an ice cave in a mountainside**. Desert: **a half-buried ruin**, broken columns and a sunken courtyard drifting with sand. Forest: **an ancient grove**, a ring of standing stones under huge old trees. Fog isle: **the ghost ship wrecked on its reef** (below). | Zach. | - |
| Between places | **All four**: ambient creatures per theme (herds, birds lifting off, critters in the brush), obstacles (fallen trunks, boulder fields, streams and gullies, ruined walls), small finds (a wayside shrine, a lone chest, a little wreck, an abandoned camp with a note) and wandering people (travellers, hunters, patrols between villages, the 1.18 encounters more often). All sleep when far (CLAUDE.md perf rules). | Travelling an island isn't empty. | After play |
| The spooky island | **A haunted fog isle**: thick fog, dead trees, a half-abandoned cursed fishing village, a graveyard and a crypt, ghost lights at night, a ghost ship wrecked on its reef. A fifth ThemeDef, built the way snow, desert and forest were. | Pirate horror; fits the sea. | - |
| Its mechanic | **Lanterns push back the fog**: old lantern posts and beacons round the island; lit, the fog thins round each and the dead keep out of its glow. A route you light up as you explore (ties to the Last Lantern). | Zach. | After play |
| Its enemies | **Drowned crews and ghosts**. The drowned: the camp grunts' moves, waterlogged and slow to stay down (back up once unless finished). Ghosts: fast, fading in and out, weak to fire and light. **Ghosts and anything spirit are immune to firearms; the undead resist bullets and don't bleed** (no blood to leak: bleed effects don't apply). | Zach. | After play |
| Its boss | **A ghost captain on his wreck**: the arena is the ghost ship aground on the reef (its tilted deck, broken masts). He fights like a rival (1.19's captain AI) with ghostly moves (phasing, summoning drowned crew). The theme's other bosses are spectral beasts. | Reuses the captain AI; a set piece. | - |
| Names | **As picked in docs/originality_plan.md** (Driftfruit, Flux/Feral/Knack, Will, Iron Will, Weather Eye, Captain's Will, Outflow, Squall Step, Ballast, Cinder Fist, Leviathan Fist, Leviathan, Lodestone, the Admiralty), display text only, ids kept, and back over the published site, posts, README and GitHub release notes. | Already decided. | - |
| Releases | **Unstable builds as pieces land** (like 1.18.x: 1.19.x pre-releases, the beasts rework first), then the stable 1.20 with its news post. | Zach. | - |
| Co-op | Standard: the host simulates beasts, bosses, the dead and the lanterns' state; a lit lantern is world state a late joiner sees. | CLAUDE.md. | - |

### Open / deferred
- The fog isle's other three bosses (spectral beasts), its town's people and its music: **assumed** decided while
  building and listed for review; ghosts' and the drowned's looks shown on a sheet first.
- Which minis and roamers each theme gets after the rework: **assumed** today's pools, re-moved.
- The Admiralty ships' grey hull texture (a 1.19 follow-up): folded into the polish pass.
- The capital's full build, the canal city, ships to buy: the next release, its own grill.

## Open before this grill (kept for the record)
- Per beast and boss: the move list each needs (unique moves, phases, telegraphs), and what makes melee fair (stagger
  windows, weak points, openings after big attacks, less knockback spam).
- Terrain: limit where beasts roam and where arenas sit (slope limits in placement), or teach them to handle slopes
  (IK, slope-aware attacks), or both.
- Models and animation: rebuild the worst bosses' models and rigs, or a shared quadruped/serpent rig with better
  keyed motion (possibly Blender clips once the pipeline is proven).
- An arena kind per theme: jungle canopy, snow ice cave, desert sunken ruin or dune bowl, forest grove, spooky
  graveyard/crypt.
- Which ambient creatures and obstacles per theme, and their budget (they must sleep when far).
- The spooky island's identity (fog, ghosts, a cursed village, a ghost ship?) and the cities' scope: at their own
  grills.
