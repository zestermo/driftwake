# Driftwake to-do

**The plan of record is [docs/roadmap_v2.md](roadmap_v2.md)** (2026-10-15): the First Sea's islands, the sea between
them, progression and effects, enemies, customization, the Marines, the finale boss, then version 2.0. This file holds
the details of each item; the roadmap sets the order.

Zach's list of planned work, in order. Nothing here is started unless it says so. Reviewed with Zach
2026-10-13: the next round is polish and quality of life, then Phase 3 of the islands. Platform: the desktop
download (co-op by hosted / forwarded address) is the way to play; nothing web or store-related is planned.

## Now: v1.12, light, music and a living sea (started 2026-10-14)

Three agents, one worktree each:
- **Lighting:** nights are too dark to play. A brighter moonlit night (ambient floor, moonlight), real lights on
  the ships (deck and stern lanterns, the cabin, enemy ships too), more light in towns and buildings (windows,
  doorways, street lamps, the den and the rest that only glow today), on the light budget (few shadowed lights,
  distance fades). A **belt lantern** on every captain: hangs from the belt with swing physics, takes no hand
  slot, lit at dusk on its own, a key to toggle, seen by crewmates.
- **Music:** new, theme-appropriate tracks for the title screen, the open sea, island background, villages and
  exploring; longer forms (2-3 minutes) instead of the one-minute loops; day/night variants where they fit
  (`docs/audio_audit.md` proposals 1, 2, 4).
- **A living sea and sky:** more spray and particles on the water (bow and hull spray, crests breaking, surf on
  rocks, splashes), better ocean sound (layered swell, surf by distance, the hull's wash), and birds in the sky:
  flocks over islands, gulls round ships and harbours, by time of day.

## Next: polish and quality of life (after v1.10)

**Animations** (driftwake-animation skill; animsheet / posebench to check)
- Jump variations (standing, running, sprinting jumps read differently), a redone dash, a double jump of its own.
- Eat and drink animations for quick-slot items (see Healing).
- The log pose animation (L) is wrong: fix how it's held and raised.
- Sitting: interact to sit on any bench, stool, log or chair (villages, the inn, the ship), and sit on the
  ground anywhere (from the emote wheel).
- Crouch-walk / sneak: a crouch you can move in, lower and quieter; enemies notice you later (a light stealth
  mechanic, not only a pose). Works for guests.
- Talk and interact gestures: hands while talking to NPCs, reaching for chests, levers and doors, handing over items.
- Weapon-specific sheathe / unsheathe: an animation and a sound per weapon kind (katana draw from the
  scabbard, axe off the back, pistol holstered, daggers...).

**Emotes** (co-op)
- An emote wheel on a key: wave, point, salute, laugh, cheer, dance, sit, shrug, bow and a few more;
  mirrored to crewmates (humanoid_sync) with their sounds.

**Clothing and armour**
- Fix clipping between pieces (`outfitgrid` / `armorshot` sheets find it).
- More clothing and armour pieces at every tier. Long coats, capes and long hair stay as they are (no cloth
  simulation for now).

**Audio**: finish the sound and music pass (`docs/audio_audit.md`): music for each theme and town,
longer tracks, layered combat music, day/night themes, ducking music under big sounds, per-island motifs,
impact sounds by weapon type, a full UI sound set, and the new sheathe/emote/creature sounds.

**UI**: every menu to the new inventory's level (crisp pixel fonts at native size, clean layout, hover feel,
tooltips, ornate borders, no clutter): pause menu, options, skill map, character creator, shops, the yard,
dialogue boxes, the chart, the title screen, and the HUD (bars, skill bar, prompts, boss bars).

**Healing** (decided 2026-10-13): quick-slot items (food, rum, potions) with a short shared cooldown and an
eat/drink animation you can be hit out of; the ship's galley refills them as now.

**Economy** (all four problems, 2026-10-13)
- Too much gold too easily: tighten drops, chest gold and sale prices.
- Nothing worth buying: better and rarer stock, upgrades and things to spend on.
- Treasure gets uses: **rare-gear merchants** (special traders, one per city / island tier, who take only
  treasure, for rare weapons, armour and cosmetics) and **quests and crafting** (villagers' turn-ins, and
  upgrading or crafting gear with treasure as the material).
- One coherent price curve across tiers, island levels and buy/sell.

**Gear upgrading and customizing** (idea 2026-10-14): weapons and armour above blue rarity are good enough to
work on. Upgrade their stats, add effects (burn, bleed, lifesteal, knockback...) and abilities, and rename or
restyle them (name, colours, engraving). Treasure and materials pay for it, at a smith or rare-gear merchant.
Ties into the economy's "treasure gets uses" and crafting above. Custom names and looks show to crewmates.

**Experience and skills** (2026-10-13)
- Uneven pace: some trees and weapons fill fast, others crawl; even out mastery gain and node costs.
- Skill map readability: what a node does, what's next, what a tree is for.
- Balance: some skills and ultimates are much stronger than others; a pass with numbers (DPS tables like
  wieldtest's) and Zach's feel.

**Arenas and dueling** (idea 2026-10-14)
- **City arenas:** small, nonlethal tournaments fought with wooden versions of every weapon, in front of big
  crowds of spectators, over many rounds:
  - one-on-one rounds;
  - team battles, where your team is the colour you wear;
  - free-for-alls.

  Captains can enter, and co-op crewmates can enter against each other. Losing downs you instead of killing
  you. Prizes go to the winners.
- **Interacting with another player:** stand right next to a crewmate and a menu opens with:
  - trade;
  - view their gear and what they have equipped;
  - challenge them to a duel.
- **Duels:** a light pseudo-fight. Your opponent's health shows at the top like a boss bar. The loser is downed
  instead of dying, and both stand back up on their own when the duel ends. The winner gets a tiny bit of XP.
  Duels have to work for guests (the host runs the fight).

**Instruments** (idea 2026-10-14, like Sea of Thieves)
- A few instruments (e.g. concertina, fiddle, hurdy-gurdy, drum, flute), one equipped at a time in its own
  slot. Never a starting item: bought from specific vendors.
- Played from the emote wheel. Each instrument plays one of a few tunes, picked at random, and every tune
  has a part for every instrument.
- **Jamming:** start playing near another captain who's already playing and you pick up their tune, fading in
  at the matching bar. Several instruments together make one cohesive song (the parts are rendered as stems in
  sync, the way the music generator already renders tracks). Works in co-op: the tune and its start time
  are synced on the host's clock.

## Right after v1.12: the process round (agreed 2026-10-14, one agent)
- **Tests on GitHub Actions:** the headless suites as a matrix on free Linux runners (public repo), nettest
  included; prepush becomes "push the branch, merge when it's green", and Zach's PC stays free. Renders stay local.
- **A Driftwake agent type** (`.claude/agents/driftwake-feature.md`): the rules, test tiers, report format and
  skills built in, so briefs are just the feature; a cheaper model for test-fixing and mechanical work.
- **Agents land themselves:** land.ps1 behind a queue/lock, run by the agent when its suites pass, so
  conflicts are fixed by the agent that wrote the code.
- Done 2026-10-14: shared permissions for worktree agents, the guard and finish hooks; the driftwake-feature and
  driftwake-fixer agent types; the landing queue (agents land themselves, unwork.ps1); tests on GitHub (opt-in,
  prepush -CI; not yet reliably green on the slower runners); the light test stage with 30 atomic tests in
  tools/dev/t/ (8 suites ported); passes keyed by the files each test loads; `--fixed-fps 60` for every test but co-op.
- **Lazy autoloads:** the autoloads (GameManager, Net, GameMenu, FX) name most of the game's classes, so every test
  boots ~8 s compiling 343 files and "tests that load the changed file" is every test. Load those classes lazily
  (by path) and both shrink: faster boots for every test, and -Changed picking by loads becomes precise.
  **Parked 2026-10-14** on branch `worktree-agent-ad4bf0ee149f348f2` (7 commits: the autoloads, player/HUD and Weather
  untangled, GameMenu screens built on first use, selection by loads, and a fix for the title -> world load hanging
  on the loader thread). Left: its full test run (progtest's empty-pistol reload failed), then rebase and land.
- **A private user:// per test process** (APPDATA / XDG_DATA_HOME per job in Start-GodotJob) would end the
  chartest/savetest races and allow 8-10 tests at once, but savetest then fails "world loaded from the title" (it
  leans on leftover user data: a saved look, settings or the what's-new seen file). Fix savetest first, then turn it on
  and measure 5/7/9/10 jobs.
- Port more small suites to the stage only when they're being changed anyway; ragtest stays a world suite (the downed
  body creeps 0.092 m/s on the flat stage vs its 0.08 limit).

## Then: the dev process plan, step 2 (`docs/dev_process_plan.md`)
- Island feature registry (`IslandFeatures.add(name, plan, steps)`) and typed contracts between features
  (`VillagePlan`, `LifeSpot`, `PoiInfo`, `HarbourPlan`...), each kit declaring its own fidelity names and style
  keys. One agent, nothing else on islands meanwhile. Step 1 (smoketest, fixed seeds, wait_ticks) is done; the
  theme part of step 2 is done (2026-10-15: `scripts/island/themes/`, ThemeDef / IslandThemes, a theme is its own
  file plus one registry line; the hubs read it).
- Step 3 alongside the next batch: the brief-template and integrator skills, merge as you go, the agent wall's
  overlap alarm, the Tests pane's flake tracker.

## Then: islands, Phase 3 (assemble and gate; plan in `docs/island_fidelity_plan.md`)
- District planner: harbour, village core, outskirts and wilds (4-6 POIs + the beast's ground + the signature
  piece), all seeded so co-op guests build the same island (`nettest.ps1 chain`).
- Far-LOD for the islands ahead (props culled, NPCs asleep, visibility ranges); three islands at Brinehollow's
  density would be ~300 MB.
- fidelitytest as a gate: >= 80% of Brinehollow on every metric over 10 seeds, within the build-time and
  draw-call budgets.
- Polish loop: Zach plays seeds and sends F12 captures; agents fill what reads as sparse.
- Left from phases 1-2:
  - Per-item seeds for Brinehollow's pieces drawn while meshing (bunting, laundry, garden, wares, quay coping)
    so they can move to a worker plan (changes its look slightly: Zach's call); `Props.straw_dummy_mesh` is
    unseeded (differs per build and per co-op screen).
  - People on the harbour's decks (walk_height doesn't know them; `GenHarbour.spots` says where they'd work)
    and escort quests.
  - Theme styling not carried into the new village: the layouts' stalls, the workshop/shrine/storehouse/
    ruin/palisade/decks, GenHarbour's `harbour_roof`, IslandLife's villagers' looks (the village, layout,
    dungeon and temple contexts take the island's theme since 2026-10-15).
  - Jungle bosses: the bosses' AlphaBoar and the fauna Boar overlap; arena crowns don't sway (MultiMesh);
    minibosses and the roamer stay dead until the island is rebuilt; bossshot review of the serpent,
    stalker and mantis.
  - Island build hitches: in a running world the beast and boss steps still read 150-200 ms (competing with
    the next islands' prepare on the workers); the temple step and vegetation colliders are ~50 ms.
  - Brinehollow's den: check the tower and flag tops aren't visible from far off at the training yard.

## Later (kept, not scheduled)
- **Lock hairstyles (parked 2026-10-17):** eight long anime-figure styles built from locks (`scripts/npc/hair_flow.gd`,
  renders with `tools/dev/hairstudio.gd`, test `t/player/flow_hair`) are on main but out of `CharacterLook.HAIR`.
  Zach: they need work; get his notes first. Also open: a lite version (7-10k tris, up to 86 bones a head) before NPC
  pools, and a creator picker for the `hair_tip` ombre.
- **Combat expansion:** dual axes (own moveset and tree), two-handed hammer, ability tiers and mastery
  (top tiers change how a skill works: a shadow-step dodge, Observation Haki dodging on its own), each new
  weapon its own tree; more minibosses (pirate warlord at a camp, bat swarm-mother, carnivorous plant titan
  in a swamp, which needs a swamp site).
- **Flipbook effects** (2026-10-15, instead of the Pixelpart plugin): add flipbook (animated sprite-sheet) particles
  to the FX autoload, keeping the PS1 treatment (snap, dither, palette) and Net.fx co-op. Then generate sheets in code
  (tools/texture_gen: smoke puffs, explosions, cannon blasts, splashes, sparks, dust, fire, magic bursts) and layer
  them into the existing effects (anticipation, impact, aftermath) with brief impact lights where they pay off. Hero
  effects (ultimates, the Kraken's ink, the knock-up stream) can later be designed in Pixelpart and exported as sprite
  sheets that drop into the same system; no runtime plugin.
- **The Kraken** (Zach, 2026-10-15): a rare encounter at some shipwrecks. Sail in to investigate and a huge
  kraken/squid rises and grabs the ship. Tentacles over the rails, on the deck and round the mast. Learn how it works
  and you can beat it off the ship and escape, or fight it and try to kill it. Co-op crews share the fight.
- **The knock-up stream and the sky islands** (Zach, 2026-10-15), Skypiea-inspired:
  - **Finding it:** clues at sea for those who know what to look for (strange currents, birds flying away, the sea
    bulging, a dark patch below). Sit on the spot long enough at the right moment and it erupts, launching the ship
    and crew into the sky.
  - **Going up:** a short loading cinematic, then the crew wakes on deck in the White-White Sea, a sea of clouds up
    in the sky.
  - **Up there:** up to two cloud islands to explore (their own theme: cloud ground, sky villages, sky creatures).
  - **Coming down:** find the way back to the Blue Sea, a second cinematic, and the ship comes down past the island
    you were heading to when you entered the stream.
  - Works in co-op (the whole crew goes, seeded so everyone sees the same sky islands).
- **Polearms** (Zach, 2026-10-14): one long-weapon kind with its own moveset and tree: spears, tridents, a
  naginata/bisento (the Whitebeard-style great poleaxe), halberds, a pitchfork, anything long. Reach, sweeps, thrusts,
  a vault and pole spins.
- **More weapon kinds to consider** (One Piece-flavoured, after polearms; see the list in the 2026-10-14 chat):
  three-sword style (a blade in the mouth, from dual swords), greatswords (a black great blade, a saw blade),
  kanabo and big clubs (merges with the planned hammer), the cane sword (a blade in a walking stick, iai), black-leg
  kicks (an unarmed kick style), the slingshot and ranged kit (musket, blunderbuss, hand cannon, harpoon gun, thrown
  chakrams), claws and wrist blades, jitte and tonfa (parry/disarm), a staff, a whip or chain, and off-hand shields.
- **Devil Fruits back:** polish them to the rest of the game's level, switch `DevilFruits.IN_WORLD` back on
  (off since 2026-10-09); a captain can dive in and haul up a fruit-user crewmate who falls in the sea (works
  for a guest).
- **Marines, bounties and pursuit** (on the public roadmap since 2026-10-13): a bounty that grows with what
  you sink, raid and beat, wanted posters in towns, Marine patrol ships in busier waters that come about when
  they spot a wanted captain, and past a bounty threshold named Marine captains who hunt you personally
  (tracking your ship down the chain, waiting at harbours), tougher hunters as the bounty climbs.
- **New island themes:** snow, desert and forest islands to the jungle's standard (a KitStyle table,
  vegetation, villages, creatures and bosses each), after Phase 3.

## Code signing (planned 2026-10-13)
- Sign the Windows build so a browser download opens on double-click with no SmartScreen block or "Unblock"
  step (today Windows silently refuses the unsigned exe from a download: its Zone.Identifier). Compare Azure
  Trusted Signing (~$10/month, needs eligibility) with an OV/EV certificate (~$100-400/yr); sign
  Driftwake.exe and Driftwake.console.exe in `.github/workflows/build-windows.yml` (secrets in the `live`
  environment). Then drop the unblock steps from the site and READ ME FIRST.txt.

## Small follow-ups from v1.11
- Sitting on a bench reuses the old seated-at-a-table pose (arms rest forward): give benches and stools their
  own hands-on-knees / leaning-back pose.
- There are no openable doors yet: the push gesture only plays at the chain-island inn's door.

## Open technical items
- **Save keys repeat across worlds:** chest, job and beast flags (`isle<id>_*`, `leg<x>_<y>_*`) are keyed by
  island number, which repeats across chain seeds, so a guest's opened chest counts on the host's
  same-numbered island. Fix: the chain seed in the key, with a save migration. (Quests already carry the seed.)
- **A one-off co-op crash** (signal 11, "wrong RID" building the Silverback's body on a guest), seen once in
  ~5 chain runs.
- **Mesh-commit crash while the next island prepares** (2026-10-14 bug pass): a segfault in
  `add_surface_from_arrays` (MeshBuilder.commit, from village dressing or a scuttlebug's model) on the main
  thread while a worker prepares the next chain island; 3 of ~10 headless seatest/nettest runs. Likely the same
  race as the crash above. Needs its own pass (is it headless-only?).
- chartest / savetest race on the shared `user://character.cfg` when two sessions run them at once
  ("Cannot get keys from nonexistent section look"): give the suites their own config path (e.g. an env or
  test-kit override of CharacterLook's save path).
- lifetest's "at nine in the evening" once got 11 of 13 on a Mosswater Atoll; not reproduced (the check
  prints who's late, with their walk).
- Performance: measure on the other PC (F8 / `user://perf.log`), the 120 s autosave, Vulkan vs D3D12.

## Ideas, not planned
- Browser co-op (WebRTC + signalling), a Steam / itch.io page, the web
  build's island freeze / brighter sea / audio limiter: the desktop download is enough for now.

## Waiting for Zach's play-through
- Sword + pistol (Corsair), dual wield, daggers (one and two, the reversed off hand), the v1.10 enemy pass
  (gap closers, poison puddles, the rifleman's tell, smarter dodging pirates), Brinehollow's clifftop den and
  its climb, the coastlines, the inventory refresh.

- Buildings follow-up (2026-10-17): on tall double doors the wall lantern sits close to the door hood's bracket; nudge it out.
