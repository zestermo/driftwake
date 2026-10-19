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

### Between points of interest
- More **ambient creatures** and **obstacles** in the space between places, so travelling an island isn't empty.

### Also in 1.20
- A **spooky island** type (a new theme on ThemeDef, built the way snow, desert and forest were).
- A **polish / fidelity / generation-fix pass on all chain islands** (fidelity loop, generation bugs).
- **Cities:** at least two on the first chain.

## Open (to grill)
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
