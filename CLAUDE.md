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
- Commit when a request is done (clear message). Push to `main` when asked
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
F6 cycle weather, F7 +2 hours, F9 level up, F10 knock yourself down, F2 pixelation on/off,
F3 dither, Ctrl+F9 Morrow's log pose, Ctrl+F10 the ship and you to the next chain island's pier.

## Running things (PowerShell, from the repo root)

`GODOT` must point at the **console** build (the plain exe prints nothing to the terminal).
Zach sets it once as a user environment variable:
`setx GODOT "C:\path\to\Godot_v4.7-stable_win64_console.exe"` (new shells pick it up).
From bash (Claude Code's shell on Windows) call the scripts through PowerShell:
`powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/run_tests.ps1 r10test`.

```powershell
.\tools\dev\run_tests.ps1 -Changed -Light        # the tests your uncommitted changes affect, by what each loads (normal use)
.\tools\dev\run_tests.ps1 r10test swimtest        # specific suites
.\tools\dev\run_tests.ps1 t/player/dodge t/ship   # an atomic test (tools/dev/t/<group>/<name>.gd), a whole group
.\tools\dev\run_tests.ps1                         # every test, 5 at a time (-Jobs 1: one at a time)
.\tools\dev\run_tests.ps1 isletest -Seed 1234     # on that seed instead of the suite's own (a failure prints this line)
.\tools\dev\nettest.ps1                           # co-op: host + client on localhost (also: water, three, late, hostquit)
& $env:GODOT --path . --script res://tools/dev/weathershot.gd -- res://tools/dev/out/wx   # renders (GPU, opens a window)
```

- run_tests.ps1 compiles every script first (`tools/dev/compilecheck.gd`, ~6 s) and runs
  nothing if one is broken or calls the wall clock in game code.
- **Dependencies:** every passing run records each project file it loaded (`.git/crew/deps/<test>.txt`;
  `scripts/game/dep_record.gd`, started by Settings when the runner sets `DRIFTWAKE_DEPS_OUT`). A pass is
  cached under the hash of those files' contents (plus project.godot, the autoloads and the test's own script),
  so it stays good whatever else changes; test_status calls a test stale only when a file it loads changed.
  Every test loads most of the game (a world suite ~500 files; the autoloads' class references alone are 343,
  atomic tests included), so `-Changed` picks a test only for a changed test-side file it loads or one
  `tools/dev/test_map.txt` says it's about (a suite's name, or `t`, `t/<group>` for atomic tests: keep adding
  map lines), and `-Wide` picks every test that loads a changed file. `affected.ps1 -Explain` says why each test was picked. A test with nothing
  recorded yet falls back to the map. A file read without the resource loader (FileAccess, a listed folder)
  needs `preload("res://scripts/game/dep_record.gd").note_dep(path)` where it's read.
- A hook (`.claude/settings.json`) compiles every .gd you edit and hands errors back right away;
  if you're mid-way through a multi-edit change, finish it before reacting.
- Other hooks there: `guard.ps1` refuses a suite run straight through Godot (use the runner) and
  `git add -A` / `git add .` in the main checkout, and starts the runners and tools without a permission
  prompt in any mode (the command forms are in the driftwake-test skill). `finish.ps1` stops an agent in a worktree from finishing
  with uncommitted changes or a branch that doesn't compile as a whole (it blocks once; a second stop goes
  through). The shared permissions (runners, git, Godot, the generators) are in the same file, so worktree
  agents get them; tags, force pushes and hard resets still ask.
- A new `class_name` script needs `& $env:GODOT --headless --import` once before tests see it.
- Logs: `tools/dev/out/logs/<test>.log` (an atomic test's as `t.<group>.<name>.log`). Screenshots: `tools/dev/out/` (gitignored and
  `.gdignore`d). Read the PNGs to check visuals.
- `tools/dev/README.md` lists every test and tool with a one-line description.
- Known flaky checks live in `tools/dev/flaky.txt` (suite | FAIL text). A failure made only of
  those is **retried once automatically**, so don't rerun by hand. Add a line only for a check
  that's proven to flake on timing or load, never to hide a real failure.

### Testing strategy (every session and agent)

**This project overrides Zach's global "never write or run tests" rule:** in Driftwake you write and run tests as
described here (Zach's choice). Tests are how agents prove their work before it lands.

- **Only through the runners:** run_tests.ps1 and nettest.ps1, never a raw `godot --script` for
  a test. The runners share the machine's test slots, skip what already passed with the same contents of
  every file it loads, wait for a run of the same test already in flight, and show up live in Zach's
  **Tests** pane (`/tests`; it reads `.git/crew/live` and `status.json`, where each `t/<group>` folder is a group).
- **Three tiers, so a feature in progress never pays for the whole game's tests:**
  1. **While building (any agent, any worktree):** `run_tests.ps1 -Changed -Light` (the tests that load what
     you changed and that the map says it's about; passes are cached by dependencies, so most are skipped),
     or the tests that cover what you built by name
     (`run_tests.ps1 daggertest t/combat`). No nettest. The edit hook compiles each file.
  2. **Landing a branch** (`land.ps1`): the compile check and `smoketest` (the first islands of four
     fixed chain seeds built and run: script errors, non-finite transforms, missing services; even with
     `-NoTests`; `-Exact`, so never carried over the rebase), then the tests the branch affects minus the
     slow whole-world ones in `tools/dev/heavy.txt` and minus co-op (`run_tests -Changed -Light -Base main`).
  3. **After a batch of merges, before a push:** `tools/dev/prepush.ps1 -CI`. GitHub runs it all
     (`.github/workflows/tests.yml`: every suite, the heavy ones and the co-op modes, on ~20 Linux runners) on
     HEAD's commit pushed to `ci/<branch>`, and a green run pushes that commit (`-NoPush`: just check).
     `tools/dev/ci.ps1` alone just runs and reports. Local `prepush.ps1` runs every test test_status calls stale
     (a file it loads changed since its pass), failing or never run on this PC, atomic tests, heavy suites and
     co-op modes included; since every suite loads the whole game, after a batch that's most of them.
     This is the only place nettest and the chain/fidelity/perf suites run.
  Run the full suite only when Zach asks.
- **Don't rerun a test "to be sure":** a pass is cached against the exact contents of what it loads.
- **Landing re-tests only what the rebase could change:** a pass whose loads the rebase didn't change has
  the same key on the rebased branch, so it counts there.
- **A suite stops at its first failure** (a FAIL line or a script error): the runner prints that failure
  whole, stack included, and the Tests pane shows it in red. Fix it and rerun that suite.
- **The runners also stop a suite early** when it stalls (no output for 150 s), its scripts don't parse
  (it reports the first error), it floods script errors, or its log passes 25 MB. A stopped suite
  is a real problem to look at, not one to rerun.
- **Long runs go in the background** (Bash `run_in_background`); don't sit in a blocking wait loop.
- **Fixed seeds:** every suite picks its seed in `_initialize` (`tools/dev/test_kit.gd`: `seed_of(self)`
  seeds the global rng and the chain, default 4242; island suites loop a small fixed list with `seeds_of`).
  "SEED n" in the log names the seed in use; a failure prints it with the rerun line, and the live suite
  has a `seed` field. `-Seed N` runs (env `DRIFTWAKE_SEED`) are never cached or shared.
- Writing a test: a new test goes in `tools/dev/t/<group>/<behaviour>.gd` on the light stage (copy
  `tools/dev/t/_template.gd`: `TK.stage(self, opts)` gives flat ground, the captain, camera, HUD and only what
  you ask for, up in ~2 s; run it with `run_tests.ps1 t/<group>/<behaviour>` or the whole `t/<group>`), one
  behaviour per test, unless it needs the world (Brinehollow's places, generated islands, the real sea):
  then a world suite, copying the newest `tools/dev/rNtest.gd`. Either way: a step machine in `_process`,
  `check(name, cond)`, final `RESULT OK`/`RESULT FAILED (n)`, `TK.seed_of(self)` in `_initialize`.
  Wait in physics ticks, not frames or process seconds, where a check depends on timing
  (`until = TK.wait_ticks(n)` / `TK.wait_secs(s)`, then `if TK.ticking(until): return false`; frames
  under load run fewer ticks than seconds pass). Don't statically type project classes that touch
  autoloads; nodes added in `_initialize()` aren't in the tree yet. Clamp `lerp(a, b, k * delta)`
  weights (frame times vary). A check's name mustn't say "script error": the runner stops on that.
- Exports: exclude `tools/*` and `docs/*` in the export preset.

## Parallel sessions (one worktree each)

**More than 3 agents is fine when they're isolated** (Zach, 2026-10-15; was "at most 3" since 2026-10-12): each in
its own worktree, in separate areas/files. The landing queue lands one at a time and the test slots are shared
machine-wide, so runs queue instead of piling up. Two agents in the same files still go one after the other. Finish and merge before starting more. For a batch of features:
build them (each agent runs only its own suites), merge them all with a compile check and the smoke test (`land.ps1 -NoTests`),
then one full test run and one bug-fix pass on main, with known bugs from the agents' reports listed first.

**Batch rules** (Zach, 2026-10-15, after the v1.13 batch lost hours to a red main):
1. **Main is green before a batch starts.** Anything failing on main gets a `driftwake-fixer` first; feature agents
   start only once it's clear. A red main makes every agent stop to ask "is this mine?" and land with `-NoTests`.
2. **No test or tooling changes during a feature batch** (runner flags, test kit, crew/landing scripts, CI). Do them
   in their own quiet window with no feature agents running, then a full run, before the next batch.
3. **Parallel only across separate areas**: two features in the same system (two combat features, two
   island features) go one after the other.
4. **Small features, landed in pieces:** each agent lands its first coherent piece early, so problems show up in
   minutes, not after two hours.

**Agent types** (`.claude/agents/`): spawn feature work as `driftwake-feature` (worktree isolation; the rules,
test tiers, landing and report format are built in, so the brief is just the feature) and narrow fixes, failing
suites and mechanical changes as `driftwake-fixer` (Sonnet, cheaper).

Zach often runs several Claude sessions at once. Each should work in its own git worktree
so half-finished edits never break another session's tests or end up in its commits:

- Start one with `claude -w <name>` (from the repo root). It gets `.claude/worktrees/<name>/`
  on branch `worktree-<name>`, branched from local `main` (settings: `worktree.baseRef`
  "head"), with the Godot import cache copied in (`.worktreeinclude`). run_tests.ps1
  imports once by itself if a checkout has no cache.
- Commit on that branch as usual. **An agent lands its own branch** once its suites pass (unless
  told to leave it): `.\tools\dev\land.ps1` in its worktree (rebase onto main, compile + smoketest +
  covering tests, fast-forward main; it releases the claim, prints one line and never pushes). The
  lead can land any branch from the main checkout: `.\tools\dev\land.ps1 worktree-<name>`.
- **Keep in sync with main by merging:** a hook (`tools/dev/hooks/mainmoved.ps1`, in guard/crewcheck) says once per
  new main head that main moved and what landed. At your next clean point commit, `git merge main` (not a rebase
  mid-work), fix conflicts, rerun your covering tests. land.ps1 fast-forwards a branch that has main in it, merges
  main (not rebases) into one with merge commits, and takes in a main that moves during its tests: docs or files no
  test loads go straight through, anything else re-runs only the checks whose loads it changed.
- **One landing at a time** machine-wide: a second land.ps1 waits its turn and says whom for
  (`-List`, `crew.ps1` and the Tests pane's status.json show who's landing and who's waiting).
- **A conflict** stops a self-landing mid-rebase in its worktree: fix the files, `git add` them,
  `git rebase --continue` (mid-merge: `git commit`), run land again (from the main checkout it backs out instead and prints
  those steps for the branch's agent). It refuses while the main checkout has uncommitted changes
  in files the landing touches. `-Light` is accepted and ignored (landing always runs light).
- **Removing a landed worktree** (once its session is closed, from the main checkout):
  `.\tools\dev\unwork.ps1 <name>` (long paths: `git worktree remove` fails on Windows), or
  `land.ps1 worktree-<name> -Remove` to land and remove in one go.
- In a worktree session, Zach's F12 captures are still in the main checkout:
  `C:\Users\ZachStermon\Documents\driftwake\tools\dev\out\captures\`. Zach plays main in the
  editor, so he sees a session's work once it's landed (or by opening its worktree folder).
- Sharing the main checkout instead: commit only your own files (`git add -- <paths>`), never
  `git add -A`, and if a test fails in a file you didn't touch, it's probably another
  session's work in progress.

### Coordinating with the other sessions (tools/dev/crew.ps1)

- Every session starts with the **crew board** in its context (a SessionStart hook): each
  worktree's branch, its claimed task and areas, and the files it's changing. `crew.ps1`
  prints it any time; `crew.ps1 overlap` shows who else is in the files you're changing.
- **Claim your task** when you start one in a worktree:
  `.\tools\dev\crew.ps1 claim "sea legs" -Areas scripts/ship/enemy_fleet.gd,scripts/world/sea_legs.gd`.
  Landing releases it. After an edit to a file another session is changing or has claimed, a
  hook tells you who; keep that edit small and local, and tell Zach if the overlap is big.
- **Tests are shared machine-wide:** see "Testing strategy" above. There are `DRIFTWAKE_TEST_SLOTS`
  (default 5; the i7-14700HX and 32 GB take it) Godot slots across all sessions. Passes are cached by exact code (`-Force` reruns),
  and runs in flight are shared.
- In a worktree, a failing test is this tree's code (or main's), never another session's
  uncommitted work. If it's in a file someone else is changing on main, say so.
- run_tests.ps1 re-imports by itself when a `class_name` is missing from the import cache
  (a new script, or another branch's landed in).
- New suites go on their own line in `tools/dev/suites.txt`, and on their group's line in
  `tools/dev/suite_groups.txt` (the Tests pane's groups). Those, `test_map.txt` and
  `docs/dev_notes.md` merge by union (`.gitattributes`), so parallel branches adding lines
  don't conflict when they land.

## Python (asset generators only)

Python is only needed for `tools/texture_gen/*.py` (textures, SFX, music; numpy, scipy,
pillow). Nothing else in the project or the tests uses it. On Windows use the `py`
launcher (`py tools/texture_gen/gen_psx_audio.py`); `python` may hit the Microsoft Store
stub. Setup: `py -m pip install -r tools/texture_gen/requirements.txt`. The music generator
also wants `ffmpeg` on PATH for .ogg output (otherwise it keeps .wav). For one-off file
edits or data crunching, use the editing tools, PowerShell or a GDScript `--script`
instead of Python. If `py` isn't found, tell Zach rather than installing things.

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
  Anything that changes world state must work for a guest (prepush.ps1 runs nettest before a push).
- **psx_lit has no instance uniforms** (they cap at ~256 instances in compatibility).
  Use per-object material copies (`tint_mul`) for flashes.
- PSX vertex snap must skip the shadow pass (`if (!IN_SHADOW_PASS)`).
- Physics interpolation is on. Teleports call `reset_physics_interpolation()`. CPUParticles3D
  bursts need `local_coords = true`.
- **UI canvas is 800x450** (`PSX.UI_SIZE`, canvas_items stretch): laid out on 800x450 and drawn
  at the window's resolution, so the pixel fonts stay hard-edged but fine. The 3D's pixel grid is
  the PSX preset's (640x360 by default), laid on by the post pass. Size UI for 800x450
  (Pixelify 12, Silkscreen 8).
- Humanoid joint conventions: arm/leg x+ = forward/up, shin x- = knee bend, `*_l` z- = out
  left, `*_r` z+ = out right, pivot x- = lean forward. The animator sets only rotations
  each frame, so anything that writes joint *global* transforms (ragdolls, IK) must restore
  local offsets/scale afterwards (see `Ragdoll.restore_rig`).
- **Grab the mouse only through `Settings.capture_mouse()`**, never `Input.mouse_mode = MOUSE_MODE_CAPTURED`:
  a test or render tool (`Settings.tool_run()`) must never lock Zach's mouse, and tools run muted.
- Shader globals live in project.godot `[shader_globals]` (psx_snap_res, psx_affine,
  cloud_shadow, sky_haze). Add new ones there or shaders fail to compile.
- New textures: copy import settings from existing ones (mipmaps on, compress_to 0).
- **Game time, never the wall clock:** gameplay uses delta, physics ticks (`Engine.get_physics_frames()`,
  `PlayerState.now_s()`), timers, and `Ocean.clock()` / `Weather.world_time()` for shared clocks; never
  `Time.get_ticks_*`, unix or system time (waves, combo windows, reloads and the input buffer all broke on it).
  compilecheck (the edit hook, run_tests, land) fails on one in scripts/ or scenes/ unless
  `tools/dev/wallclock_allow.txt` lists it with its reason.

## Performance rules

- **The target:** the min-spec PC (Ryzen 5 5600G + RTX 3080) at 60 fps in Brinehollow = the laptop's
  Brinehollow bench (`tools/dev/bench.ps1`) at <= ~10 ms mean frame (v1.14: 9.2 ms; v1.13 was 42).
- **Every frame or physics tick:** anything that runs per frame or tick sleeps when far or out of sight
  (`ActorSleep.add(self)` + `sleep_ok()`, or the island's LOD like FaunaSpawner's) and updates at the lowest
  rate that looks right (a timer, not every frame).
- **New meshes:** a visibility range; small ones cast no shadow; repeated props are one MultiMesh; materials
  shared (cached `PSXMat`, tints folded into vertex colours; an object's own copy only for flashes).
- **Areas:** `monitoring` only when something reads that area's overlaps (hitboxes do; hurtboxes don't).
- **Report the cost:** a feature agent benches before and after, back to back (`bench.ps1 label=<x>_before`,
  `label=<x>_after`, `bench_compare.ps1`), and reports the ms at the stops.
- **Before tagging a version** Claude runs `tools/dev/prepush.ps1 -Release`: the tests, then
  `perf_gate.ps1` against `tools/dev/perf_baseline.txt` (fails at a mean frame or frame1t >15% worse, a stop's
  frame1t >35% worse, or >0.8 physics ticks a frame; `perf_gate.ps1 -Update` after an intended change).

## History and plans

- `docs/dev_notes.md`: detailed notes from every round (systems, tunings, gotchas,
  test coverage). **grep it for a system before changing it.** Don't read it all.
- `docs/multiplayer_plan.md`: co-op design notes and the remaining roadmap.
- Add a short dated section to `docs/dev_notes.md` after a substantial change (what,
  where, why, how it's tested).
