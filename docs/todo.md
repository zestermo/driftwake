# Driftwake to-do

Zach's list of planned work. Nothing here is started unless it says so.

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

- Sea goes pale grey and opaque after a while (capture cap_20261006_161506: Brinehollow's
  dock, clear, 10:45). It looks like the sandy seabed with no sea drawn over it. Not
  reproduced in renders (hours, weathers, small window, after manning a cannon). F12 now
  records the sea mesh and its shader inputs: press it the moment it happens.

## UI

- Tooltips on item hover with the item's details (tier, stats, worth...).
- Redo most of the UI and menus. Today they're large, blocky and primitive. Wanted:
  - better scaling;
  - higher-fidelity, detailed pixel art;
  - opaque panel backgrounds with ornate borders.
  (The canvas is 640x360; check what scale the new art needs.)

## Items

- Rework how healing and consumable items work (design to be decided).

## Lighting

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

- Sword + pistol moveset: cutlass in the main hand, pistol in the off hand, with its own
  combo, right click and jump attack (like the axe and dual-sword sets).
- Fix and polish the dual-sword moveset and make it the dual-wield moveset: it's used for
  sword + sword, sword + axe and sword + dagger. Its skills live in a dual-wield tree.
- Dagger and dual-dagger movesets (dagger + dagger keeps its own set).
- Dual-axe moveset (axe + axe gets its own set), with its own dual-axe skill tree.
- Two-handed hammer moveset.
- Each new weapon gets its own skill tree (see the skills refactor).

## Co-op

- Rescuing a Devil Fruit crewmate who falls in the sea: today they sink (the fruit-user
  sinking is built) and nobody can get them out. A captain should be able to dive in and haul
  them up (needs to work for a guest too).

## Skills refactor

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
