# 1.28 and after: polish, workflows, the ocean and performance (ideas for Zach's pick)

Written 2026-10-31 after shipping 1.27. A menu, not a plan: pick what you want and we grill the picks into a plan doc
(driftwake-grill), then build in small playable pieces (feel systems get a preview first). Grounded in what the code and
the 1.27 bench show today; numbers are this checkout's.

## The shortlist (what I'd do first)
1. **A playtest-and-tune pass on 1.27** before anything new: ten fruits' numbers are first guesses, the stronghold has
   never been played start to finish by a person, and co-op has had no live two-player run of the new systems.
2. **Per-power icons for the ~70 fruit powers** (they show their fruit's icon now) and a skill-map pass so the fruit
   trees read at a glance.
3. **The ocean's three cheap big wins:** shoreline foam, the ship's wake, and a sun-glint path (section 4).
4. **Performance: draw calls first.** The bench's draw budget is the worst over (4.44 ms of 3.5); see section 5.
5. **Test hygiene:** a shared "calm foe" helper in the test kit (the fruit tests' load flakes were all a grunt doing
   something mid-check) and fix the one long-red test (t/island/beast_moves).

## 1. Feel and completeness
- **Fruit tuning with real play.** A debug-menu tab to set any power's damage, reach and cooldown live, and an F12
  capture that records the last 10 casts and what they hit, so tuning is minutes, not rebuilds.
- **Hit feel consistency.** Every fruit power through one impact recipe (FruitFX.impact does this for the new ones):
  audit the weapon techniques against it, hit-stop on heavy fruit hits, a camera punch on ultimates' strike frame.
- **Readable enemy tells everywhere.** Grunts have red wind-ups; bosses, beasts and the Admiral should share the same
  language (a red glint, a telegraph decal on the ground for AoEs: FX.telegraph exists).
- **Onboarding for fruits.** The first fruit eaten opens a short tutorial card: V for the fruit stance, how forms grow,
  Wolf/Bear Form as its own power.
- **Feedback for forms.** A small flash and the power's name when a Reflex or Nature fires (it shows a float text now);
  a toast the first time a power reaches Reflex/Nature, and the skill map showing each power's form progress.
- **Quality of life.** Loadout presets per weapon/fruit, a "compare" tooltip on gear, quick-stack in storage, a map
  marker you can place, and the debug menu's warp list (islands, the stronghold, the capital) for testing.
- **The stronghold, second pass.** Varied layouts per seed (district order, room kinds), a second legendary pool,
  and an "elite" re-run once beaten (the Admiralty rebuilds; harder garrison, new vault roll).
- **Endgame shape.** What a level 30+ captain does weekly: bounty contracts, the Admiral hunting a Dreaded captain at
  sea, rare world events (a Sea King migration, a Marines armada), and fruit-user rivals (1.28's own plan).
- **Audio polish.** A mix pass (combat SFX vs music ducking), distinct cast sounds per fruit (FruitFX.SOUND reuses
  generic ones), and footsteps for the beast forms (heavy pads for the bear, light for the wolf).

## 2. Game structure
- **Chain pacing.** A difficulty curve check across a generated chain: islands' levels vs the captain's typical
  level on arrival (a sim run through the chain gives the numbers).
- **Economy sinks.** Gold piles up late; sinks that feel good: ship upgrades, crew hires, cosmetic dyes, fruit
  respec at a cost, the Crown's favour perks.
- **Content cadence.** Each island theme with one signature set piece (the snow theme's avalanche, the desert's
  sandstorm) so islands are remembered by an event, not only a look.
- **Retire the web build** (decided 2026-10-31): drop the "Deploy web build" workflow and the site's /play/ page; one less
  thing every push builds.

## 3. Asset workflows (better animations, models, icons, music, textures)
- **Animations.**
  - A *pose review gallery*: every action's animsheet published as one artifact page per batch, with comments, so you
    can mark "too stiff" on a frame and I fix that key (animsheet exists; the gallery is the missing piece).
  - *Foot IK for planted feet* on slopes and decks (the procedural rig floats feet on uneven ground), and *root-motion
    curves* for dashes and leaps so the body leads the move.
  - *Reference capture*: you record a short phone clip of a move; I pull frames at the beat times and key the pose
    against them (a rough motion reference beats inventing poses blind).
- **Models.**
  - A *kitbash library* of the best existing pieces (MeshBuilder recipes) with a contact sheet, so new props start from
    parts, not boxes.
  - *Silhouette checks*: modelshot renders a black-on-white silhouette at game distance; if it doesn't read there, it
    doesn't ship. The beast forms' paws were the example: blocks that only read up close.
  - Real quadruped bodies for the full beasts (a rig with four legs), and fruit 3D models with their own shapes, not
    one fruit mesh re-skinned.
- **Icons.** A generator with a *shape grammar* per fruit (storm: bolts; gust: swirls; iron: plates; echo: rings) so 70
  power icons come out consistent and distinct; a 2x preview sheet for review; the same for item and gear icons.
- **Music.** *Adaptive layers*: each area track with a combat stem that fades in with fighting (Music has places;
  layers are new), a *leitmotif per boss* (Kesh, Marrow, Vane, the Admiral) quoted in their fights, and stingers for a
  stronghold seal taken or the Scouring's start.
- **Textures.** A *palette lock* (every generated texture quantised to one shared PSX palette per theme) so new assets
  sit with the old; a *tiling checker* (renders 3x3 repeats) and an *atlas pass* to cut material count (helps draws).
- **Review loop.** Every asset batch ends in one artifact page (like the codex) with before/after and your comments read
  back by me: faster than describing screenshots in chat.

## 4. The ocean (OceanManager.WAVES + ocean.gdshader; both change together)
- **Shoreline foam:** a depth-based foam band where water meets land (the shader can read the terrain height or a baked
  depth texture per island); breaking-wave lines on beaches.
- **The ship's wake:** a trail mesh of foam and a V of displaced water behind the hull, stronger with speed; bow spray on
  crests (FX.splash exists; a ribbon trail is new).
- **Sun glint path:** a specular streak on the water toward the sun, PSX-dithered; the moon's at night.
- **Crest foam and whitecaps** keyed to wave steepness, more in storms (Weather's wind already drives the waves).
- **Depth colour:** shallows turquoise over sand, deep water darker; reefs showing through (the stronghold's reefs would
  read far better).
- **Underwater:** fog and a caustic shimmer when swimming or diving; the surface seen from below.
- **Far water:** a horizon band that matches the sky haze so the sea doesn't end in a seam; cheaper waves past a range.
- **Floating life:** drifting debris, gull flocks over shoals, fish jumping (all host-synced or seeded from Ocean.clock).

## 5. Performance (bench, 1.27: mean 12.31 ms against the ~10 ms min-spec target)
The 21:00 budgets (ms a frame): **draw 4.44 / 3.5 (over)**, **world 1.45 / 1.2 (over)**, **ai 0.93 / 0.8 (over)**, anim
0.85 / 2.0, player 0.40 / 0.5, ui 0.11, other 0.17. Grew most since the baseline: breakable.gd (+0.044 ms), npc.gd,
will_powers.gd, rimeback.gd.
- **Draw calls:** an audit per stop (the bench prints nodes; add draw-call counts) and fold repeated props into
  MultiMesh; atlas textures to share materials; cull small props sooner (visibility ranges per size class); check the
  new FruitFX layers spawn GPU particles, not CPU ones, and cap concurrent effects.
- **World scripts:** breakable.gd's new per-frame cost (+0.044 ms at the stops: it should sleep when far, ActorSleep);
  timers instead of per-frame checks in the stronghold scripts (garrison, officers, boss ticks run every 0.25 s already;
  audit the rest).
- **AI:** grunt brains on a staggered tick (every other physics tick for far ones), and navigation queries cached.
- **Native hot paths:** driftwake_native exists; move the heaviest GDScript loops there (wave sampling for floating
  things, the spring chains already are).
- **Hitches over means:** a hitch hunter that logs any frame over 33 ms with the scripts and nodes that ran (the bench's
  hitch line is the start), and a pre-warmed shader cache for the fruit effects' materials (first casts may hitch).
- **Island builds:** budget per frame (build_ms exists) and more on worker threads.

## 6. Development workflow
- **Test kit:** `TK.calm(grunt)` (pause, fresh poise, idle, face north) and `TK.cast_wait(id)` so effect tests don't each
  reinvent it; a lint that flags tests checking a knockdown without a calm foe.
- **Faster release gate:** prepush ran hundreds of stale tests; group by what changed more tightly, and run the perf
  gate in parallel with the suites when slots allow.
- **Release notes from commits:** a script drafting the releases page section and What's new from the version's commits,
  for you to edit (the post stays hand-written).
- **Playtest captures:** F12 already dumps state; a "playtest mode" that auto-captures on death, a boss phase or a frame
  hitch, then one artifact page of the session's moments.
- **The updater:** verify the patch path end to end on a real install before each release (the 1.27 build is the first
  with the fixed patch export).
