# The desert island type (plan, 2026-10-15)

Zach's pick for the next island type after the jungle, inspired by One Piece's sand kingdom (Alabasta). Built to the
jungle's standard (docs/island_fidelity_plan.md, the island subtype standard: big variety pools, nothing guaranteed,
rich life and bosses), on the island kit (KitStyle tables, GenIsland steps, KitLife, KitDungeons/KitTemple, the beast
pool, FaunaSpawner).

## References (Zach's, in `tools/dev/out/refs/`, git-ignored: One Piece art, internal reference only)
- `desert_buried_town.webp`: rolling dunes swallowing a town. Pastel houses (lilac, cream, white) half-buried to the
  windows, arched doorways and windows, broken arcades, toppled stone slabs, a lone palm, dark rock outcrops.
- `desert_ruined_skyline.jpg`: a ruined skyline across the dunes. Cracked whitewashed blocks, domes (green, blue, a
  caved-in one showing its ribs), minarets, palms, a dead tree, stone slabs and rubble in the sand, a dry sky.
- `desert_royal_city.jpg`: the living capital. Packed flat-roofed boxes (salmon, cream, blue-grey, mint), onion domes
  (gold, green, blue, pink), minarets with balconies, small square windows, awnings, sand hills behind.
- `desert_island_map.webp`: the island from above. Big, sand-yellow, ridged mountains and canyons, a raised centre
  (the city), a dry riverbed splitting it, sand winds swirling round the coast.

## Look and size
- **The largest island type by default** (no trees to break the eyeline): roughly 1.5-2x a jungle island's radius,
  inside the build-time and draw budgets (Performance rules in CLAUDE.md: visibility ranges by size, MultiMesh for
  repeats, ActorSleep, the perf gate).
- **Terrain:** long dune fields with sharp crests and soft lee sides, rock ridges and mesas, a canyon or two, a dry
  riverbed (wadi) from the highlands to the sea, a raised central plateau, and salt flats. Sand-coloured palette with
  warm shadow tones; rock in ochre and rust. Coasts: beaches and rock cliffs (coast.gd), with the new shore-aware
  water.
- **Sky and light:** a hot, hazy, pale-blue sky by day, heat shimmer near the ground at midday, deep orange
  sunsets, very clear starry nights.

## Places (districts and set pieces, all from pools, nothing guaranteed)
- **The capital or a walled oasis town** (the royal-city ref): flat-roofed box houses in pastel plaster, onion domes,
  minarets, arcades, a souk with awnings, a palace on the plateau. Its own KitStyle table ("desert"): materials
  (plaster colours, sandstone, tiles), house shapes (flat roofs, parapets, domes), stalls (striped canvas), props
  (urns, rugs, water jars, camel tack), lamps (brass lanterns).
- **Buried towns** (the buried-town ref): ruins half-swallowed by dunes, rooftops and arches poking out, loot inside.
- **A ruined skyline** (the ruined-skyline ref): a dead city far off; broken domes, a caved-in dome, toppled towers.
- **An oasis** with palms, a pool (InlandPool) and a camp; dry wells; nomad tents; a caravanserai.
- **Interiors/dungeons:** tomb or temple ruins under the sand, a sunken palace, a sandworm's tunnels.
- **The harbour:** a sandstone quay town or a bare landing with a fallen lighthouse.

## Life
- **Vegetation (sparse on purpose):** date palms (oases, the capital), cacti, dry scrub and tumbleweed, dead trees,
  reeds at water. The emptiness is part of the look; detail comes from dunes, rocks, ruins and wind.
- **Creatures:** scorpions, sand crabs, giant lizards, vultures (SkyBirds style), desert foxes, a roaming beast.
- **Bosses and minibosses** (BeastPool, the jungle bosses' pattern): a sandworm or sand-king that tunnels and
  erupts, a giant scorpion, a desert lizard boss, a bandit chief at a camp.
- **People:** desert villagers and merchants (KitLife routines), headscarves and robes (clothing pieces), a palace
  guard.

## Weather, sound, effects
- **Sandstorms** instead of rain (Weather + RainFX's place): blowing sand, low visibility, wind, lanterns lit.
  Heat haze. No rain on desert islands (or very rare).
- **Effects:** sand bursts, dune spray off crests, sandstorm streaks, heat shimmer, all on the flipbook library once
  it lands (see docs/todo.md, Flipbook effects).
- **Music:** a desert theme for the island (gen_psx_music.py, a day and night version), plus the town's own.
- **Sound:** wind over dunes, sand footsteps (exist), the souk's murmur.

## Order (agents in separate areas; start on a green main)
1. **Foundations:** the desert KitStyle table, terrain generator (dunes, ridges, wadi, plateau), size, sand
   palette and textures (gen_psx_textures.py), coasts. Alongside: the effects library (fx.gd), a separate agent.
2. **Towns:** the capital/oasis town and buried towns, harbour styling.
3. **Life:** vegetation pools, creatures, people and clothing, ActorSleep.
4. **Bosses, dungeons and set pieces:** the sandworm/scorpion/lizard pool, tombs, the ruined skyline.
5. **Weather, effects and music:** sandstorms and heat haze (after the flipbook library), the desert music.
6. **Fidelity and perf pass:** fidelityshot against the references, the perf gate, co-op (nettest chain).

Co-op: every piece seeded from the island's seed so guests build the same island.
