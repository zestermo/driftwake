# Driftwake to-do

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

**Experience and skills** (2026-10-13)
- Uneven pace: some trees and weapons fill fast, others crawl; even out mastery gain and node costs.
- Skill map readability: what a node does, what's next, what a tree is for.
- Balance: some skills and ultimates are much stronger than others; a pass with numbers (DPS tables like
  wieldtest's) and Zach's feel.

## Then: the dev process plan, step 2 (`docs/dev_process_plan.md`)
- Island feature registry (`IslandFeatures.add(name, plan, steps)`) and typed contracts between features
  (`VillagePlan`, `LifeSpot`, `PoiInfo`, `HarbourPlan`...), each kit declaring its own fidelity names and style
  keys. One agent, nothing else on islands meanwhile. Step 1 (smoketest, fixed seeds, wait_ticks) is done.
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
    ruin/palisade/decks, GenHarbour's `harbour_roof`, IslandLife's villagers' looks; the village ctx is
    hardwired to "jungle".
  - Jungle bosses: the bosses' AlphaBoar and the fauna Boar overlap; arena crowns don't sway (MultiMesh);
    minibosses and the roamer stay dead until the island is rebuilt; bossshot review of the serpent,
    stalker and mantis.
  - Island build hitches: in a running world the beast and boss steps still read 150-200 ms (competing with
    the next islands' prepare on the workers); the temple step and vegetation colliders are ~50 ms.
  - Brinehollow's den: check the tower and flag tops aren't visible from far off at the training yard.

## Later (kept, not scheduled)
- **Combat expansion:** dual axes (own moveset and tree), two-handed hammer, ability tiers and mastery
  (top tiers change how a skill works: a shadow-step dodge, Observation Haki dodging on its own), each new
  weapon its own tree; more minibosses (pirate warlord at a camp, bat swarm-mother, carnivorous plant titan
  in a swamp, which needs a swamp site).
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
