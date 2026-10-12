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

**Phase 2: build out** (parallel agents)
- [x] **Harbours that vary by island:** each island rolls one type (stilt fishing port with
  boardwalks, boats and net racks; smugglers' cove; timber trading wharf with warehouses and a moored
  merchant ship; ruined jetty). Gap today: a bare plank pier against Brinehollow's harbour
  district of 13 buildings and 33 props. (Done 2026-10-12: GenHarbour, see dev_notes; harbour
  people still to come: `GenHarbour.spots` says where they'd work.)
- [ ] **Village streets and dressing:** lanes off the plaza with houses along them; dressing passes
  (laundry, gardens, handcarts, crates, planters, signs) to Brinehollow's ~47 props/ha and ~3 props
  per 50 m of lane (today 8.5/ha); more building kinds (workshop, shrine or chapel, storehouse,
  two-storey house; today all huts); lit windows and NightLights to Brinehollow's levels (today
  3 lights vs 11, ~40 lit windows vs 180); worn or paved paths.
- [ ] **Interiors:** caves and small dungeons from a pool (bug tunnels, smugglers' grotto,
  flooded ruin) with a reward at the end; enterable shops and a few houses; a multi-room ruined
  temple as a bigger set piece on some islands. (The inn interior isn't a priority.)
- [ ] **Landmarks** (rolled per island, visible from the sea): waterfall with a swimmable pool;
  beached wreck to explore, with loot; a climbable giant tree with platforms and rope bridges; a
  stone idol or stepped temple top above the canopy. Fix the summit tower being buried in
  trees (clear round it or raise it).
- [ ] **A signature set piece per island:** one unique piece (sunken village, volcano vent, giant
  skeleton...) from a pool that never repeats within a sea.
- [x] **People:** 15-20 villagers per island with routines (work spots, market, inn at night).
  (2026-10-12: IslandLife + Villager, 18-19 people, 12-13 on routines; see dev_notes.) Left: people
  on the harbour's decks (walk_height doesn't know them), escort quests.
- [x] **Named characters:** a few per island with real dialogue trees and rumours about the chain
  and the beast. (3 per island, 4 trees with the elder's.)
- [x] **Island quests:** 2-3 small quests per island drawn from its POIs (lost item in the ruins,
  clear the lair, escort...), beyond the job board. (lost, scout, deliver, fetch, clear.)
- [ ] **Jungle theme style table:** materials, prop set, NPC looks, barks, ambience and music.

**Phase 3: assemble and gate**
- [ ] District planner: harbour, village core, outskirts and wilds (4-6 POIs + the beast's ground +
  the signature piece), all seeded so co-op guests build the same island (`nettest.ps1 chain`).
- [ ] Far-LOD for the islands ahead (props culled, NPCs asleep, visibility ranges). Three islands
  at Brinehollow's density would be ~300 MB.
- [ ] Turn fidelitytest into a gate: >= 80% of Brinehollow on every metric over 10 seeds, within the
  build-time and draw-call budgets.

**Phase 4: polish loop**
- [ ] Zach plays seeds and sends F12 captures; agents fill what reads as sparse.

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
- **Next themes:** snow, desert and forest islands, once the kit exists.
- **A one-off crash** in co-op (signal 11, "wrong RID" building the silverback's body on a guest),
  seen once in ~5 chain runs.

## Performance (done 2026-10-07, see dev_notes; left: measure on the other PC with F8 / user://perf.log)

Late-session slowdown: ~35 fps and stutters about 50 min into an exported build on another
machine, after returning to Brinehollow. From a code audit (nothing measured yet): some
things pile up over a session, and the base cost is already high (full-resolution 3D, no
distance culling/LOD anywhere).

**Phase 0: measure (do first)**
- A perf readout that works in exported builds (toggle key + setting): fps, frame/process/
  physics ms, draw calls, node count, enemies alive, swimmers. Write a line to
  `user://perf.log` every 30 s, so a long session leaves a record.
- A soak tool that runs fights, boardings and the boss reset loop, logging the same numbers.
- Note the test machine: GPU, window resolution, PSX preset.

**Phase 1: things that grow over a session (the "50 minutes in" part)**
- Pirates in open water swim forever: `pirate_grunt.gd` `_swim_update`/`_find_shore` (no
  timeout; 112 down-rays + line rays every 1.5 s; `_bad_shores` only grows and is scanned per
  ray). Boarders and deck crew are parented to the fleet, so they outlive their sunk ship
  (`enemy_ship.gd:610`). Fix: drown/despawn after a while far from land, free crew with the ship.
- Boarders whose home point was the deck of a moving ship walk "home" into the sea forever
  (`pirate_grunt.gd:850`, `_avoid_water` ~19 rays/tick). Fix: give up and despawn.
- Redtide boss: each reset + re-engage calls 3–5 more phase-2 crew; old ones never cleaned
  (`pirate_boss.gd:129`, `redtide_fort.gd:329`). Fix: free the crew on reset, call once per fight.
- Loot bags never expire (camp respawns every 120 s keep dropping them; floating ones process
  forever). Fix: lifetime (a few minutes), cache weapon meshes.
- Coins skip their lifetime while pulled toward a full bag; burned thornbrush keeps its light.

**Phase 2: big steady wins**
- 3D renders at full window size, then is pixelated to 960x540 (preset 4, `psx_settings.gd:100`).
  Set `scaling_3d_scale` to match the preset: about 4x fewer pixels at 1080p. Highest leverage.
- Ocean wake foam: 39-point loop for most of the visible sea because far enemy-ship trails
  widen `wake_box`. Fix: only trails within ~150 m, one box per trail.
- Distance LOD for humanoids (~50 rigs, all posed every frame, `lower_body`/`arm_body` even
  when hidden): hide beyond ~100 m, pose at a lower rate past ~30 m.
- Far AI sleep: grunts, scuttlebugs and enemy ships far from every captain stop thinking;
  enemy-ship splashes and wakes only near the camera.
- Visibility ranges and a shorter camera far plane (~1200 m; fog ends at 820 m): islands,
  fog banks, reef rocks, Redtide. Shadows off for bushes, distant islands, chain links.

**Phase 3: CPU trims**
- Grunt `_separation`/`_guns_free` scan the whole enemies group per grunt per tick (O(N²)).
- Clouds: sort + rebuild of ~670 puffs' buffer every frame; throttle or sort less often.
- FX: each burst makes a new particles node + Curve + Gradient + QuadMesh; share/pool them.
- HUD: skill bar redraws every frame (polygon clipping, skill dict copies, `progression.stat()`
  rescans every owned skill several times a frame).
- Ocean/sky: send unchanged shader params only on change; sky radiance re-renders each frame
  though reflections are off (`AT_CUBEMAP_PASS` early-out).

**Phase 4: hitches**
- Navmesh parse on the main thread when first nearing each island (`nav_baker.gd:64`).
- Respawns build whole crews/camps in one frame (`grunt_camp`, `enemy_fleet`); spread them out.
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
  (The canvas is 640x360; check what scale the new art needs.)

## Items

- Rework how healing and consumable items work (design to be decided).

## Lighting (Brinehollow's village done 2026-10-08: NightLight, 9 lights; left: ships, the den, other islands)

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
  polished") The dual-wield moveset for sword + sword, sword + axe and sword + dagger. Left:
  there's no dagger item yet (the off-hand dagger's stab and numbers are keyed on a
  "dagger" model, ready for the dagger round).
- Dagger and dual-dagger movesets (dagger + dagger keeps its own set).
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
