# Driftwake — guide for Claude

Zach's personal game: a One Piece-inspired pirate action RPG (sailing, islands, melee
+ guns + Devil Fruit powers, 1-4 player co-op) with a PS1/PSX look. Godot **4.7**
(Forward+, GDScript, Jolt physics), Windows. Repo github.com/zestermo/driftwake,
active branch **`multiplayer`**. Everything is procedural: bodies, props, islands,
textures (tools/texture_gen/*.py), music and SFX. There are very few hand-made assets.

## How Zach wants to work

- **Fast iterations.** Make the change, run only the tests that cover it, and check visuals
  with one render tool. Run the full suite only before a push of a big change or when asked.
  Don't spend 30+ minutes verifying a small tweak; say what you checked.
- Zach plays the build himself to judge feel. Tell him what to try in-game (keys, places)
  so he can check it in the editor.
- Keep replies short: what changed, how to try it, anything left open.
- Commit when a request is done (clear message). Push to `multiplayer` when asked
  or when Zach says he's done testing.
- **Feel/style:** precise, responsive movement (velocity = input x speed every tick;
  walk 6, sprint 9, combat stance x0.8; turn_speed 20). Shonen look and animation:
  readable, punchy, not cartoony or arcade. PS1 rendering (vertex snap, dither,
  640x360-style pixel grid), not "retro filter on a modern game".

## Zach's in-game captures (F12)

While playing a debug build (any run from the editor), **F12** saves exactly what's on
screen plus a state dump to `tools/dev/out/captures/`: `last.png` + `last.txt` are always
the newest, and each capture is also kept as `cap_<date>_<time>.png/.txt`. When Zach says
"look at my last capture" (or names one), read both files. The .txt has the player
(position, state, HP/stamina/energy, stance/action/ragdoll, water depth, the last 5 s
of movement with state changes), camera, time/weather/sea, ship, co-op peers, enemies
within 60 m and the tail of the Godot log (errors/warnings). Code: `scripts/game/dev_capture.gd`
(autoload DevCapture; `capture()` can also be called from a test). Other debug keys:
F6 cycle weather, F7 +2 hours, F9 level up, F10 knock yourself down, F2 PSX preset,
F3 dither.

## Running things (PowerShell, from the repo root)

`GODOT` must point at the **console** build (the plain exe prints nothing to the terminal).
Zach sets it once as a user environment variable:
`setx GODOT "C:\path\to\Godot_v4.7-stable_win64_console.exe"` (new shells pick it up).
From bash (Claude Code's shell on Windows) call the scripts through PowerShell:
`powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/run_tests.ps1 r10test`.

```powershell
.\tools\dev\run_tests.ps1 r10test swimtest        # specific suites (normal use)
.\tools\dev\run_tests.ps1 -Jobs 4                 # all 24 suites, 4 at a time (faster, a bit flakier)
.\tools\dev\nettest.ps1                           # co-op: host + client on localhost (also: water, three, late, hostquit)
& $env:GODOT --path . --script res://tools/dev/weathershot.gd -- res://tools/dev/out/wx   # renders (GPU, opens a window)
```

- A new `class_name` script needs `& $env:GODOT --headless --import` once before tests see it.
- Logs: `tools/dev/out/logs/<suite>.log`. Screenshots: `tools/dev/out/` (gitignored and
  `.gdignore`d). Read the PNGs to check visuals.
- `tools/dev/README.md` lists every test and tool with a one-line description.
- Known flaky checks (rerun before digging in): swimtest "head still above water while
  swimming", vinetest "aiming at the big bug" on 4.7, grunttest can hang waiting for a
  circling grunt under heavy CPU load, and fixtest under load. `-Jobs` > 1 makes these more
  likely.
- Writing a test: copy the newest `tools/dev/rNtest.gd` pattern (step machine in `_process`,
  `check(name, cond)`, final `RESULT OK`/`RESULT FAILED (n)`). Don't statically type project
  classes that touch autoloads; nodes added in `_initialize()` aren't in the tree yet.
  Clamp `lerp(a, b, k * delta)` weights (frame times vary).
- Exports: exclude `tools/*` and `docs/*` in the export preset.

## Where things are

Autoloads (project.godot): Settings, FX, CombatManager, Ocean, GameManager, PSX, Dialogue,
GameMenu, Net, Music, Weather, DevCapture.

| Area | Files |
|---|---|
| Player + states | `scenes/player/player.gd`, `scripts/player_states/*_state.gd` (state machine; Move/Idle/Jump/Dodge/Swim/Downed/Swing/Cannon/Helm...) |
| Body + animation | `scripts/npc/humanoid.gd` (procedural rig + locomotion + actions), `body_builder.gd`, `character_look.gd`, `face_painter.gd`, `spring_chains.gd` (hair/cloth) |
| Combat | `scenes/combat/hitbox.gd` + `hurtbox.gd`, `scripts/combat/` (HitData, health, ragdoll.gd), `scripts/enemies/` (pirate_grunt, pirate_boss, scuttlebug) |
| Powers / progression | `scripts/powers/`, `scripts/progression/` (skill map, styles, fruits) |
| World | `scripts/island/world_generator.gd` + islands in `scripts/island/`, `scripts/world/weather.gd` (day/night, weather, sky, rain, lightning, fog/haze), `cloud_spawner.gd` (PuffClouds 3D clouds) |
| Sea + ships | `scripts/ocean/ocean_manager.gd` (wave table, graded sea mesh, wave clock), `scenes/ocean/ocean.gdshader`, `scripts/ship/` |
| Co-op | `scripts/net/network_manager.gd` (Net), `humanoid_sync.gd` |
| PSX rendering | `scripts/psx/` (PSX settings, PSXMat, MeshBuilder, Props), `shaders/psx/` |
| UI | `scripts/ui/`, `scenes/ui/` (HUD, menus, inventory, creator, title) |
| Saves | `scripts/game/save_game.gd`; settings `scripts/game/settings.gd` (VERSION migrations) |

## Rules that bite if forgotten

- **Waves:** `OceanManager.WAVES` is the single wave table. `get_wave_height()` (CPU: swimmers,
  ship, enemies, floating loot) and `ocean.gdshader` must compute the same thing. Change
  both together. Always use `Ocean.clock()` for wave time (physics-ticked, host-synced in co-op).
- **Co-op:** the host simulates enemies, spawns and the world. RPCs live on `/root/Net`.
  Node identity is `Net.key_of/node_of` (path from the world scene). Effects and sounds go
  through `Net.fx(...)`. "Everyone does it" calls use `Net.everyone("_all_*")`. The local
  player is `get_first_node_in_group("player")`; all captains are in group "players".
  Anything that changes world state must work for a guest. Run `nettest.ps1`.
- **psx_lit has no instance uniforms** (they cap at ~256 instances in compatibility).
  Use per-object material copies (`tint_mul`) for flashes.
- PSX vertex snap must skip the shadow pass (`if (!IN_SHADOW_PASS)`).
- Physics interpolation is on. Teleports call `reset_physics_interpolation()`. CPUParticles3D
  bursts need `local_coords = true`.
- **UI canvas is 640x360.** Size UI for that (Pixelify 12-16, Silkscreen 8).
- Humanoid joint conventions: arm/leg x+ = forward/up, shin x- = knee bend, `*_l` z- = out
  left, `*_r` z+ = out right, pivot x- = lean forward. The animator sets only rotations
  each frame, so anything that writes joint *global* transforms (ragdolls, IK) must restore
  local offsets/scale afterwards (see `Ragdoll.restore_rig`).
- Shader globals live in project.godot `[shader_globals]` (psx_snap_res, psx_affine,
  cloud_shadow, sky_haze). Add new ones there or shaders fail to compile.
- New textures: copy import settings from existing ones (mipmaps on, compress_to 0).

## History and plans

- `docs/dev_notes.md`: detailed notes from every round (systems, tunings, gotchas,
  test coverage). **grep it for a system before changing it.** Don't read it all.
- `docs/multiplayer_plan.md`: co-op design notes and the remaining roadmap.
- Add a short dated section to `docs/dev_notes.md` after a substantial change (what,
  where, why, how it's tested).
