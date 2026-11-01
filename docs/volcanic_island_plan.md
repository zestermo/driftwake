# The volcanic isle (1.28)

The theme's own plan under docs/v1_28_plan.md ("Islands": the volcanic isle row is binding). A black island round a
living volcano, its town a forge town. Built in six pieces, each landed on its own.

## The land
- **The cone:** one smoking volcano near the island's middle (radius ~0.4-0.5 of the island's), its rim 70-95 m up,
  a **caldera** inside (floor 25-35 m under the rim) where the boss lives. The rim is **breached** on the side facing
  the village: a gully climbs from the foot up through the breach onto the caldera floor at a walkable grade, so the
  boss path goes up it. The summit's lookout stands on the rim beside the breach.
- **Lava flows:** 3-5 tongues of lava from side vents on the cone's flanks down to near its foot, each ending in a
  cooled black lobe. Fixed hazards: a lava surface (an emissive flow shader, no lights) that burns whoever stands in
  it (damage + thrown out, the local captain only, like the vent set piece). Where a path crosses a flow the lava
  has crusted over: a dark basalt crossing you can walk. Flows that would run at the village or the breach are
  cold (crust only). A crescent of lava in the back of the caldera (the salamander's).
- **Ground:** ash (grey, the "grass" layer), black sand beaches, cinder/scorched earth for paths and towns, basalt
  for rock and cliffs, the cone's upper flanks bare rock and ash.
- **Plants:** sparse and hardy: charred dead trees, ash-grey pines low on the flanks, fire-lily tufts and wiry
  grass, ash shrubs, obsidian and pumice rocks, fumarole crusts (sulphur yellow) for the "bamboo" slot. No canopy
  giants worth the name (scorched ones, few). The forests (per island): ash barrens, scorched woods, cinder fields,
  obsidian shore, fumarole flats.

## The forge town (the village)
Basalt-and-timber houses under dark iron and slate roofs, chimneys on most; a smithy row with lava-fed forges
glowing (emissive troughs, a light or two from the budget), bellows, anvils, quench barrels; ore carts and slag
heaps. Shops: a **smith** (weapons), a **parts dealer** (gadget parts), the inn, the store. The **master tinkerer**
at his own forge with a gadget **Workbench** (Workbench.place(..., {"style": "forge"})) who teaches a blueprint you
don't know for gold (Gadgets.teach; "Come back when..." while there's nothing to teach). Harbour kinds: wharf and
cove (a stone quay of basalt). Folk in leather aprons, soot, goggles where CharacterLook has them.

## Encounters and places
- Places (the theme's own kinds for the chain's): a **smoking vent field** (fumaroles, sulphur, a chest), an
  **obsidian quarry** (cut faces, a crane, quarrymen or bandits), a **collapsed lava tube** (a cave kind), a
  **smugglers' den** in the black cliffs.
- Encounters (volcanic text over the shared kinds): a stranded ore-hauler, a pilgrim to the fire, an ambush of
  slag-pickers, a forge festival, a lost child near the flows, a hermit who reads the rumbles, a burned lookout.

## Creatures and beasts
- Creature pool (rolled per island, nothing guaranteed): monitor lizards, crabs on the black sand, bats, scorpions,
  mites, plus the theme's own: **ember beetles** (glow-backed, burst when struck) and **ash hounds** (packs).
- The **roaming beast**: the **Cinderhorn**, a great horned lava-backed lizard-ox grazing ash; slow, a charge and a
  burning stomp.
- **Minibosses** (1-2 per island): the **obsidian golem** at the ruins (the moss golem's brain on obsidian, a
  shard ring), the **ash hound alpha** at the lair (pack leader).
- **Boss:** the **magma salamander** in the caldera arena (its own BeastArena dressing: basalt walls, the lava
  crescent). It dives into the lava and swims under it (only a glowing wake and bubbles), surfaces under you
  (telegraphed glow), spits magma, tail-sweeps; at 2/3 and 1/3 health it **erupts**: the caldera's vents burst and
  lava bombs rain in red circles. Second pick in the pool: the jungle's serpent as an ash coil.

## The set piece: rumbles and bursts
Every few minutes (seeded from the island's seed and the shared wave clock, so every screen agrees) the volcano
rumbles: a camera shake and a deep rumble for everyone on the island, smoke pours from the cone, then a burst of
**lava bombs** falls on one part of the island (a seeded sector, never the town or the harbour): each bomb's red
ground circle appears ~1.6 s before it lands, a burning splash on impact (damage only inside the circle). The host
runs the event and sends it through Net.fx; each machine hurts only its own captain.

## Sound
- Music: `volcanic` (wilds: low drums, a drone in a dark mode, a slow menacing pulse) and `volcanic_town` (the forge
  town: anvil hits on the beat, a work song), night arrangements of both on the same form.
- Ambience bed: `volcanic` (a low rumble, hiss of vents, distant crackle). Sounds: the quake rumble, a bomb's
  whistle and splash, forge hammering in town.

## Numbers (first guesses, tuned in play)
- Chain: rolled apart like the fog isle (weight 0.22 on a regular island), never before layer 4 (levels 12+).
- Island radius 340-440. Cone: rim 70-95 m, crater depth 25-35, floor r 40-46.
- Lava: 15 damage a touch (the vent's), thrown 7 m/s out and 9 up; bombs 22 damage in a 3 m circle.
- Rumbles: every 150-260 s while a captain is on the island; 10-16 bombs over 6 s in a 45 m sector.
