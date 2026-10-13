# Driftwake to-do

Zach's list of planned work. Nothing here is started unless it says so.

## Island fidelity: generated islands at Brinehollow's level (planned 2026-10-09)

From the phase-0 fidelity report (`docs/island_fidelity_baseline.md`, `tools/dev/fidelity.gd`) and
Zach's answers. The plan and workflow: `docs/island_fidelity_plan.md`. Phase 0 (measure) is done.

**Decisions**
- **Size:** keep 600-900 m islands; pack Brinehollow-level detail into districts (harbour,
  village, POIs) with real wilderness between. Don't spread it evenly: generated islands have 2-4×
  Brinehollow's land (20-40 ha vs 8.8).
- **Town style:** the theme's own look (jungle: stilts, thatch, rope) at Brinehollow's density.
- **Performance target:** Zach's PC (RTX 4060 laptop) at 60 fps. The browser build may drop detail.
- **Order after phase 1:** parallel. Settlement, adventure and life agents at once, each in its own
  worktree with crew claims.

**Phase 1: the kit** (one agent, serial; done 2026-10-11, see dev_notes)
- [x] Extract Brinehollow's builders into `scripts/island/kit/` modules (harbour/quay/waterfront,
  village houses + dressing passes, market, paving, landmarks, camps/den/training yard, cave +
  interior, NPCs + life, night lights). Each takes an island context instead of Brinehollow's
  constants and fixed seeds. The grouping and what each depends on are in the baseline doc.
- [x] Rebuild Brinehollow from the kit: same look (islandshot before/after), same play (its suites),
  the same fidelity numbers, and the same save ids and story node names (islanddump: identical).
- [x] Each kit module reports its own build ms. Brinehollow's 6.6-7 s single-frame build gets a breakdown.
- [x] Write the `driftwake-islands` skill: how to author a kit piece, the island context API,
  seeding, performance rules and the fidelity check.
- [ ] Left for phase 2-3: per-item seeds for the pieces whose rng is drawn while meshing (bunting,
  laundry, garden, wares, quay coping) so they can split into a worker plan (changes Brinehollow's
  look slightly: Zach's call); `Props.straw_dummy_mesh` is unseeded (differs per build and per co-op screen).

**Phase 2: build out** (done 2026-10-12, merged and bug-passed 2026-10-13; see dev_notes)
- [x] Harbours that vary by island (GenHarbour: stilts, cove, wharf, ruins, landing).
- [x] Village layouts, streets and dressing (town, hamlets, walled post, stilt village, ruins + survivors).
- [x] Interiors: caves and small dungeons from a pool of 7, the ruined temple on ~40% of islands.
- [x] Landmarks (11 in the pool) and a signature set piece per island (10, never twice down a route).
- [x] People, named characters and island quests (IslandLife, Villager, KitQuests).
- [x] Jungle theme style table and tropical jungle vegetation (canopy giants, thickets, canopy arenas).
- [ ] Left from phase 2:
  - Coastlines (in progress in its own worktree).
  - People on the harbour's decks (walk_height doesn't know them; `GenHarbour.spots` says where
    they'd work) and escort quests.
  - Theme styling not carried into the new village: the layouts' stalls (`stall` style), the
    workshop/shrine/storehouse/ruin/palisade/decks, GenHarbour's `harbour_roof` (still "thatch"),
    IslandLife's villagers (`IslandVillage._villager_look`, not the style's folk looks); the
    village ctx is hardwired to "jungle".

**Phase 3: assemble and gate**
- [ ] District planner: harbour, village core, outskirts and wilds (4-6 POIs + the beast's ground +
  the signature piece), all seeded so co-op guests build the same island (`nettest.ps1 chain`).
- [ ] Far-LOD for the islands ahead (props culled, NPCs asleep, visibility ranges). Three islands
  at Brinehollow's density would be ~300 MB.
- [ ] Turn fidelitytest into a gate: >= 80% of Brinehollow on every metric over 10 seeds, within the
  build-time and draw-call budgets.

**Phase 4: polish loop**
- [ ] Zach plays seeds and sends F12 captures; agents fill what reads as sparse.

## Jungle bosses (2026-10-12; see dev_notes "jungle bosses")
- [x] The Silverback takes to the trees (phase 2+): canopy run, boulders down, the crash down; shot out of the tree.
- [x] Boss pool per island from the chain (BeastPool): ape, serpent (Strangler), stalker (Shade), mantis (Mantis Queen); never the one before.
- [x] Arena under a closed canopy ringed by giant trees, brush to hide in, dressed per beast; `_ground()` is the swap point for the theme's canopy-arena request.
- [x] Miniboss: the alpha boar at the ruins. Roaming beast: the Thornback grazing the island. POIs for quests (BeastPool.pois).
- [x] BeastArena takes its ring from the boss site's canopy arena (GenIsland.arena_ring; 2026-10-13).
- [ ] The bosses' AlphaBoar and the fauna Boar overlap (two boars). The arena giants' crowns no longer
  sway when a beast shakes them (they're the vegetation's MultiMesh): leaves and the rustle only.
- [ ] More minibosses: pirate warlord at the camp (needs a PirateGrunt hook), bat swarm-mother in the lair.
- [ ] Carnivorous plant titan in a swamp (needs a swamp site).
- [ ] Minibosses and the roamer respawn (they stay dead until the island is rebuilt).
- [ ] Render review: bossshot sheets for the serpent, stalker and mantis (models built, not yet looked at).

## Left after the 2026-10-12 merge's bug pass
- **Island build hitches:** finish steps on the main thread measured at 100-270 ms: village houses
  (3 a step), beasts (~160 ms, one step), dungeons (100-190 ms a step).
- **harbourtest:** a "Lambda capture at index 0 was freed" error in its log (a callable outliving a
  freed island).

## Open from the 2026-10-09 session (not yet prioritised)
- **Save keys repeat across worlds:** chest, job and beast flags (`isle<id>_*`, `leg<x>_<y>_*`) are
  keyed by island number, which repeats across chain seeds, so a guest's opened chest counts on the
  host's same-numbered island. Fix: put the chain seed in the key, with a save migration.
- **Web build:** a 2-5 s freeze when the next islands build (single-threaded, so the island prep
  needs slicing); the sea is brighter and more cyan in the web renderer; no limiter (loud moments
  clip).
- **Audio proposals** (`docs/audio_audit.md`): style samples into the sea and town themes, longer
  tracks, layered combat music, day/night themes, ducking music under big sounds, per-island
  motifs, impact sounds by weapon type, a full UI sound set.
- **Devil Fruits:** polish them to the rest of the game's level, then switch
  `DevilFruits.IN_WORLD` back on. Off since 2026-10-09.
- **Browser co-op:** WebRTC plus a small signalling server (`docs/web_build.md`).
- **Code signing** for the Windows build (SmartScreen warns today).
- **Next themes:** snow, desert and forest islands (a KitStyle table each; jungle is the model).
- **A one-off crash** in co-op (signal 11, "wrong RID" building the silverback's body on a guest),
  seen once in ~5 chain runs.

## Performance (pass done 2026-10-07, see dev_notes "performance pass")
- Measure on the other PC (where the late-session slowdown was seen) with F8 / `user://perf.log`.
- Autosave every 120 s: measure; move work off the frame if it shows.
- Try Vulkan vs the forced D3D12 driver on the test machine.

## Bugs


- (fix in, 2026-10-07: confirm in play) Stuck sprinting: in several different fights the character kept sprinting on its own.
  Seen in the exported build. Only pressing sprint again clears it, so the game missed a
  Shift key-up. There's already a workaround for this in `player.gd` `_input` (Windows
  swallows Shift's key-up on Ctrl+Shift, its keyboard-layout hotkey, and sprint + dodge is
  exactly that). It releases sprint when an event reports Shift up, which only works if
  Godot's own modifier state isn't stuck too, so it seems not to catch every case. Fix
  candidates: re-check Shift from the OS each tick while sprinting, or move dodge off Ctrl.

- Sea looks opaque and white/grey on screen, but the F12 images of those moments show a
  normal sea (Zach, 2026-10-08, e.g. the 7 Oct 18:09-18:11 captures). The game's state
  and the frame Godot drew are both normal, so it happens after the frame: the driver /
  Windows compositor (D3D12, forced since the first commit, on an RTX 4060 Laptop GPU),
  or a flicker between frames that one grabbed frame misses. F12 now also saves
  <capture>_screen.png (the screen's own pixels over the window) and a "## Display"
  section (screen vs frame brightness, 6 frames in a row). Next: F12 while it's
  happening and compare; try the Vulkan driver (also a perf item above).
  (Not the 6 Oct pale sheets: that capture did show it, the sun's reflection at rough
  0.5, fixed in 30fa68c.)

## UI

- Tooltips on item hover with the item's details (tier, stats, worth...).
- Redo most of the UI and menus. Today they're large, blocky and primitive. Wanted:
  - better scaling;
  - higher-fidelity, detailed pixel art;
  - opaque panel backgrounds with ornate borders.
  (The canvas is 800x450, `PSX.UI_SIZE`; check what scale the new art needs.)

## Items

- Rework how healing and consumable items work (design to be decided).

## Lighting (Brinehollow's village done 2026-10-08, generated villages/harbours/caves on budgets 2026-10-12; left: ships, the den)

- Real lights on the things that glow today: ship lanterns, town and window lights, torches
  and the like (they're emissive only now). Do it after the performance pass and budget it:
  few shadowed lights, distance fades, so it doesn't undo that work.

## Gameplay loop (done 2026-10-07, see dev_notes "Step 2b"; left: play it and tune the cooldown, the restock cap and the rest rules)

- Re-evaluate respawning (where and how you come back).
- A way to get back to your ship, or summon it.
- Rework banking resources and item storage on ships, plus other core mechanics.
- Death: your whole inventory drops on a gravestone where you died (not on the ship).
  You carry only your inventory; banking happens in the ship's storage (see the crew cabin).
- Decided (2026-10-07):
  - Respawn in the crew cabin, next to the bed.
  - Summoning the ship: it fades into existence out of nothing and slowly sails up to the
    shore closest to you. Only works near water ("Cannot summon ship" otherwise).
  - Die again before reaching your gravestone: the old one shakes, then slowly sinks into
    the ground and is gone (its loot with it).
  - The cabin storage is shared by the whole crew in co-op.
  - Ships about 1.5x bigger (enemy ships too).
  - Kitchen: a free refill of your quick-slot consumables up to a cap (raisable later).
  - Gravestone holds your bag (gold, treasure, items, spare weapons); worn gear and equipped
    weapons stay on you.
  - Summon: hold a key near the shore, short cooldown, any captain in co-op.

## Ships (done 2026-10-07 except "other improvements": cabin, 1.5x hulls, crow's nest, rigging, ropes)

- A small crew cabin under the raised captain's deck at the stern, with stairs down on
  both sides. Inside:
  - a bed: rest to regenerate health;
  - a small kitchen: refill your consumable items;
  - storage: where you "bank" resources (otherwise you only have your inventory).
- Scale up the player ship and the enemy ships: taller, larger and longer hulls (decks,
  cannon spots, the capstan and chain, crew posts, boarding and the Sea King's attacks
  all need to follow the new size).
- A crow's nest you can climb up to.
- Climbable rigging.
- Ropes you can swing from (the swing state exists for vines).
- Other improvements to the player ship.

## Combat

- (Built 2026-10-11, waiting for Zach's play-through; dev_notes "sword and pistol") Sword +
  pistol moveset: cutlass in the main hand, pistol in the off hand, with its own combo,
  right click and jump attack, and its own Corsair tree.
- (Built 2026-10-11, waiting for Zach's play-through; dev_notes "dual wield, fixed and
  polished") The dual-wield moveset for sword + sword, sword + axe and sword + dagger.
- (Built 2026-10-12, waiting for Zach's play-through; dev_notes "the daggers") Daggers: the
  item in six designs at every tier, sheathed on the hip, the one-dagger and two-dagger
  movesets and trees (Dagger, Twin Daggers), bleeding wounds and backstabs; an off-hand
  dagger is held reversed (Zach's pick), the main hand's in the normal grip.
- Dual-axe moveset (axe + axe gets its own set), with its own dual-axe skill tree.
- Two-handed hammer moveset.
- Each new weapon gets its own skill tree (see the skills refactor).

## Co-op

- Rescuing a Devil Fruit crewmate who falls in the sea: today they sink (the fruit-user
  sinking is built) and nobody can get them out. A captain should be able to dive in and haul
  them up (needs to work for a guest too).

## Skills refactor (steps 1-2 done 2026-10-07, see dev_notes: tabs per tree, weapon mastery, moveset unlocks, tiers for Soru/Tekkai/Coat/Foresight; 19-22 node weapon trees with 26 new techniques and an ultimate each, grapples and martial arts, bullet deflection, 17 more base passives, Conqueror's Haki; left: tiers for the new techniques and fruit skills, co-op grab carry for guests)

- Decided (2026-10-07): weapon trees are paid for with that weapon's mastery (earned by fighting
  with it); Base/Haki and Fruit use level skill points. A tier opens after enough uses, then
  costs points. One tab per tree. Old saves get every point refunded.
- Decided (2026-10-07, step 2): one R slot holds any learned ultimate (weapon ults need their
  weapon in hand); grapples are bar skills on a light enemy in front, upgraded by passives.

- **Weapon skill trees:** each weapon (cutlass/sword, katana, axe, pistol, sword + pistol,
  dual swords...) gets its own tree.
- **Base/haki tree:** holds every skill and ability that isn't tied to a weapon.
- **Movesets gated behind unlocks:** parts of a weapon's base moveset are unlocked in its
  tree. Example: the katana right click's second charge level is a katana-tree unlock.
- **A web of passives:** each tree is a large web of passive skills, and paths through it
  lead to several different abilities.
- **Ability tiers:** abilities have levels that upgrade them.
- **Unarmed tree:** a martial-arts tree of passive upgrades and abilities for fighting with
  bare hands.
- **Mastering abilities:** many abilities level up, and at their top tiers they change how
  they work, often becoming passive or automatic. Examples:
  - Observation haki at tier 3–4 can be switched on as a passive that dodges a set number
    of attacks per second by itself.
  - A dodge upgrade that shadow-steps: you vanish (invisible) for about a second when you dodge.
  - The idea is mastering individual abilities, so the tiers should feel like real changes,
    not just bigger numbers.
- Existing code: `scripts/progression/` (skill map, styles, fruits). Saves will need a
  migration for skills already owned.
