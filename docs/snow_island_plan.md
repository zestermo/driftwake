# The snow island type (plan, 2026-10-15)

Zach's references for a snow island, inspired by One Piece's winter island (Drum). Built to the jungle's standard on the
island kit, like the desert (docs/desert_island_plan.md). Order: after or alongside the desert, in separate areas.

## References (Zach's, in `tools/dev/out/refs/`, git-ignored: One Piece art, internal reference only)
- `snow_island_map.webp`: the island from above. Tall icy mountains (we use pointed peaks, not the map's flat-topped
  drums), a castle
  on the highest summit, clusters of glowing blue ice crystals, dense pine forests, mist, a frozen river or channel
  splitting the island, a red-roofed town in the middle, harbours and docks.
- `snow_village.webp`: a village street. Round red/pink brick houses with tall conical roofs in stacked, snow-dusted
  green tiers and little chimney finials; wooden fences; snowy pines; drum mountains towering behind; villagers in
  heavy coats; a big shaggy white beast of burden carrying cargo; falling snow. (The mountains behind are drums in
  the ref; ours are pointed peaks.)
- `snow_buried_town.jpg`: a ruined town on a slope, stone buildings and arches half-drowned in drifts, snow-laden
  trees, a castle on the hilltop.
- `snow_fields_ruins.jpg`: rolling snowfields with wind-carved ridges, ruined towers of stacked ice/stone blocks with
  barred windows, pines, blowing mist.

## Look and size
- **Terrain:** snowfields with wind-carved drifts, pine-forested valleys, frozen lakes and a frozen river, and
  **tall, icy, pointed mountain peaks** that dominate the skyline (Zach: traditional sharp peaks, not literal
  flat-topped drum columns), climbable at a few routes, with a summit castle on the tallest. Ice-crystal clusters (glowing blue at night) on slopes and in caves. Coasts: snowy
  beaches, ice shelves and black-rock cliffs.
- **Size:** medium-large; the pine forests and peaks break the eyeline, so it needn't be as big as the desert.
- **Sky and light:** pale overcast days, low winter sun, long blue dusk, clear starry nights; the belt lantern, warm
  windows and campfires matter here.

## Places (pools, nothing guaranteed)
- **The village/town** (the village ref): round brick houses with tiered conical roofs, a KitStyle "snow" table
  (brick in reds and pinks, green tier roofs with snow caps, wooden fences, chimney smoke, lamp posts), an inn by a fire,
  a market under awnings heavy with snow.
- **A buried town** (the buried-town ref): ruins and arches drowned in drifts, loot inside.
- **Ice-block ruins** (the fields ref): stacked-block towers with barred windows.
- **The summit castle** on the tallest peak: a dungeon/boss lair reached by a climb or a cable lift.
- **Ice caves:** crystal caverns, frozen waterfalls; a frozen shipwreck in the pack ice.
- **The harbour:** wooden docks over icy water, ships with snow on their decks.

## Life
- **Vegetation:** snowy pines (dense forests, like the jungle's density but conifers), frozen shrubs, ice crystals.
- **Creatures:** wolves (packs), snow hares, a shaggy white beast of burden (village, tame), white bears or yeti-like
  brutes, ice-cave bugs, seals or walruses on the shore.
- **Bosses and minibosses** (the BeastPool pattern): a huge white bear or yeti king, a frost wolf alpha, an ice
  golem in the crystal caves, a castle lord.
- **People:** villagers in heavy coats and fur hats (clothing pieces: coats, fur hats, scarves, mittens).

## Weather, sound, effects
- **Zach's direction (2026-10-16):** a **white haze most of the time**, **constant light snowfall**, and **occasional
  heavy snow that obscures a lot**, the snow island's equivalent of the desert's sandstorm. A **soft, collision-free
  snow layer** on the ground (you wade through it, it doesn't block you) and **snow lying on things** (roofs, fences,
  pines, rocks, props, decks). **Footprints** left in it, with powder kicked up as particles. The same footprint and
  kick-up system serves the desert's sand (one shared ground system, built once in the weather pass).
- **Snowfall and blizzards** instead of rain (Weather + RainFX's place): falling snow, whiteouts, wind; snow settles on
  roofs and decks. Breath fog in the cold.
- **Footprints** in snow, snow footsteps (the audio audit's missing snow step sound), icy patches you slide on.
- **Effects** (on the flipbook library): snow puffs, powder kicked up by hits and sprints, blizzard streaks, ice
  shards, frost breath.
- **Music:** a snow theme, day and night (gen_psx_music.py), and the village's own; crackling fires, howling wind.

## Order (separate areas; green main first)
1. Foundations: the snow KitStyle table, terrain (drifts, valleys, icy peaks, frozen water), snow textures and
   palette, coasts.
2. Towns: the village (round tiered-roof houses), buried town, ice ruins, harbour styling.
3. Life: pine forests, creatures (wolves, bears, the beast of burden), people and clothing, ActorSleep.
4. Bosses, dungeons, set pieces: the summit castle, ice caves, the bear/yeti/golem pool.
5. Weather, effects and music: snowfall and blizzards, footprints, slides, the snow music.
6. Fidelity and perf pass against the references; co-op (nettest chain).

Co-op: every piece seeded from the island's seed so guests build the same island.
