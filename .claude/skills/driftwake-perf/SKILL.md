---
name: driftwake-perf
description: >
  Measure and keep Driftwake's performance: the target (the laptop's Brinehollow bench at ~10 ms mean
  frame = the min-spec PC at 60 fps), the bench (tools/dev/bench.ps1: labels, quick / gate / nosleep,
  the eight stops, frame vs frame1t, calib), comparing two runs (bench_compare.ps1), the release gate
  (perf_gate.ps1, perf_baseline.txt, -Update, prepush.ps1 -Release), benching fairly on a busy machine
  (back to back, other Godots), and the rules that keep frames cheap: ActorSleep (add / sleep_ok),
  island LOD (FaunaSpawner, DrawLOD), timers over per-frame work, visibility ranges, no shadows on small
  meshes, MultiMesh, shared PSXMat materials (tint_mul copies only for flashes), Area3D monitoring, the
  light budget (KitLights, FX.flash_light), island build budgets (build_ms, prepare on a worker /
  finish a step a frame). Also the F8 overlay and user://perf.log, and perftest / t/world/actor_sleep.
  Use when the lead benches a batch (once at its start, once at prepush; feature agents never bench), Zach says "fps", "slow", "stutter", "hitch",
  "lag", reports F8 numbers or a perf.log, before tagging a release, or when adding anything that
  runs every frame, spawns many nodes, meshes or lights, or builds on an island. The generic method
  is performance-optimization; this is Driftwake's tools and numbers.
---

# Driftwake performance

**Read first:** grep `docs/dev_notes.md` for "bench", "perf gate", "ActorSleep" and the system you're
touching. The v1.14 sections (2026-10-15: "the Brinehollow benchmark", areas A/B/C, "lessons locked in")
are the history: v1.13 ran 42 ms a frame in Brinehollow, v1.14 9.2 ms.

## The target

- The min-spec PC (Ryzen 5 5600G + RTX 3080) at 60 fps in Brinehollow = the laptop's Brinehollow bench
  (i7-14700HX + RTX 4060, d3d12) at **<= ~10 ms mean frame** (CLAUDE.md, Performance rules).
- The game is **CPU-bound**: driver (d3d12 vs Vulkan) and pixelation made no difference; GPU is ~2 ms.
  Costs are scripts, Jolt, transform notifications ("tail") and main-thread draw submission.
- **The physics spiral:** each physics tick costs its ms once per tick, and a slow frame runs more ticks
  (24 fps = 2.5 ticks a frame). `frame = (frame1t - tick) / (1 - tick / 16.7)`. Keep ticks/frame < 0.8
  (the gate's line); `max_physics_steps_per_frame=4` bounds the worst case.

## The bench: tools/dev/bench.ps1

```powershell
.\tools\dev\bench.ps1 label=myfeat_before                 # ~10 min, the whole route, a real window, 1920x1080, vsync off
.\tools\dev\bench.ps1 label=myfeat_after hour=21 wx=clear
.\tools\dev\bench.ps1 label=q quick                        # base phase only, the old eight (~2 min)
.\tools\dev\bench.ps1 label=q quick stops=plaza,atsea      # chosen stops and groups
.\tools\dev\bench.ps1 label=c crowd stops=old              # Brinehollow's market crowd on
```

- Always through bench.ps1, never Godot directly: it takes **every test slot** first (other sessions'
  suites finish their current one, then wait), refreshes a stale import cache (a missing `class_name`
  breaks the world and hangs the bench) and keeps the whole log.
- Args (after the script, `key=value`): `label=` (the result name), `hour=13`, `wx=clear|cloudy|rain|storm`,
  `pix=1|0`, `size=WxH`, `warm=20` (s after the chain islands are built), `cwarm=10` (s after the capital is
  up, before its stops), `seed=4242`, `stops=` (names and groups, below); modes `quick` (settle + base;
  alone it runs `old`), `gate` (+ probe: the summary and scripts table, what perf_gate uses),
  default = everything incl. ablations (`far` actors past 120 m disabled, `sun` shadows off, `lshadow`,
  `lights` off); `nosleep` turns ActorSleep off (a before/after of sleep on the same code); `crowd` turns
  Brinehollow's market crowd on (BrinehollowCast.CROWD, a const the bench recompiles before the world loads; off
  as the game ships). `-Driver vulkan` goes before the args.
- **Stops** (always run in this order, whatever order `stops=` lists them). The old eight, v1.14's (group
  `old`): beach (where you wake), plaza, market, quay, dock, den (foot of Grell's den), yard (training yard),
  aboard (the moored sloop). The new eight, v1.19's (group `new`): terrace (Brinehollow's shrine terrace),
  farm (the windmill hamlet), fight (the smugglers' camp: its five grunts alerted on the captain, whose health
  is kept full), sea (the sloop under full sail on open water out from Brinehollow, the captain on deck), storm
  (the same water and course in wx=storm), village (the first generated chain island's: standing there makes the
  crew arrive, which frees the other island ahead, so it comes after the sea), cplaza and cmarket (the royal
  capital's plaza by the fountain and its market street). The capital comes last: the bench
  makes Alt+F10's jump (`Player.debug_to_capital`), which frees the chain islands round Brinehollow, and waits
  until the capital and its neighbours are up and manned plus `cwarm`. Other groups: `town` (terrace farm
  village cplaza cmarket), `atsea` (sea storm), `capital` (cplaza cmarket), `all` (the default).
  The camera pans a full turn per phase at each.
- Output in `tools/dev/out/bench/`: `brinehollow_<label>.txt` (results), `.log` (the whole Godot log),
  `brinehollow_<label>_<stop>.png` (one screenshot per stop, taken after its base sample so the save never
  lands in a measured frame: check the world looked right).
- **Columns** (the `== summary` table, per stop and ALL; `ALL_OLD` / `ALL_NEW` too when both groups ran: compare
  ALL_OLD with a pre-v1.19 run's ALL): `frame` (mean ms), `p95`, `worst`, `h33` / `h50` (base frames over 33 /
  50 ms: hitches, a count; ALL sums them), **`frame1t`**
  (the frame with exactly one physics tick: the stable one), `phys_scr` / `phys_eng` (scripts / Jolt over
  all ticks), `proc_scr` (the process pass), `tail` (timers, tweens, transform notifications, deferred
  calls), `draw` (RenderingServer.draw on the main thread), `ticks` (per frame), `rcpu` / `gpu`,
  `draws` / `sh_draws` (visible / shadow pass), `nodes`. Below: per-stop top scripts, visible geometry by
  piece (surfaces, no visibility range, casting shadows), collision by owner, `== scripts` (each script's
  proc + phys ms, by distance band from the captain: a big `>250` column = something far isn't sleeping).
- Header line 3 has **`calib`**: a fixed GDScript workload's ms (best of 5), the machine's state right now
  (power plan, heat, load). Same code, calib 15% higher = the numbers aren't comparable.

## Benching fairly

Noise on the laptop: `frame` swings ~10% run to run, `frame1t` ~5%, and the machine's state far more over
hours (v1.13 measured 42 ms one morning and 25 ms later the same day on the same code).

1. **Back to back:** before and after within minutes of each other, same args. Never compare with a run
   from earlier in the day or with the baseline file.
2. **Before = main's code:** bench in this worktree before your change (or in the main checkout), then
   after. For a switchable feature, bench both settings on the same build.
3. **Compare `frame1t`** first; `frame` only once ticks match.
4. **Check calib** in both headers; more than a few % apart, rerun the pair.
5. **Other Godots:** bench.ps1 holds the test slots but can't stop an editor, a render tool or another
   agent's bench; it prints `bench: N other Godot process(es) running outside the test slots`. With N > 0
   expect noise: the flipbook rollout's plaza stop read +27% from a physics-script spike in the same window
   ("load, not FX"), and a first after-run against a morning before-run showed a GPU rise that the
   back-to-back pair put on the other processes. Say in the report that other Godots were running.
6. A stop that jumps alone while the rest hold is usually noise: look at whether the scripts that grew are
   yours. Rerun that pair if it matters, with `stops=<that one>`.

## Reading bench_compare.ps1

```powershell
.\tools\dev\bench_compare.ps1 myfeat_before myfeat_after       # labels or paths; -Top 25 scripts
```

Prints both headers (check calib), then per stop three rows: `A`, `B` and `d%` for frame, frame1t, p95, worst,
h33, h50 (their change as a count), phys_scr, phys_eng, proc_scr, tail, draw, rcpu, gpu, tot_draws, nodes; stops
only one side ran are listed below it. Then the scripts table: A, B, B-A ms
(sorted by the bigger cost). Read it as: is the ALL `frame` / `frame1t` change bigger than the noise above;
which column moved (scripts? Jolt? tail = moving transforms? draw = draw calls?); which script grew (your
file at the top of B-A is the cost; a script you didn't touch growing is load). `tot_draws` and `nodes` are
deterministic: a change there is real even when ms is noise.

## What a feature agent reports

Bench before and after back to back (`label=<feature>_before`, `label=<feature>_after`), then in the report
(the shape; the numbers are illustrative):

```
Perf (bench, 13:00 clear, back to back, calib 23.7 / 23.9, no other Godots):
ALL frame 9.41 -> 9.52 ms, frame1t 10.36 -> 10.44, ticks 0.57 -> 0.57, draws 714+490 -> 722+490
per stop frame1t: beach 9.76->9.80 plaza 11.15->11.30 ... aboard 9.01->9.05
top script change: my_feature.gd +0.08 ms
```

If the route never exercises the feature (an ultimate, an effect no stop fires, another island), say so and
measure what the feature costs on its own instead (counts: nodes, draws, particles, lights, ms in a probe),
as the flipbook and ultimate rounds did.

## The release gate: perf_gate.ps1

- `prepush.ps1 -Release` runs it after the tests, before tagging a version. Alone: `.\tools\dev\perf_gate.ps1`.
- Benches each light in `tools/dev/perf_baseline.txt` (13:00 and 21:00 clear) in `gate` mode, `-Runs` 2
  times, keeps each stop's best (interference only adds). ~10 min a light.
- **Fails** (exit 1) when, against the baseline: the mean of the stops' `frame` or `frame1t` is >15% worse;
  one stop's `frame1t` is >35% worse; or mean ticks/frame > 0.8. Only the baseline's stops are judged (today's
  baseline has the old eight; ALL = their mean); the route's other stops are printed under them, not gated,
  until `-Update` writes a baseline with them. The scripts it compares are the old route's (`== scripts_old`)
  when the run has more stops. A confirm benches the baseline's commit on the baseline's stops only. Prints each stop (base, now, d%, ticks,
  draws+shadow; red over the line, yellow over 10%), the scripts that grew most, and a note when mean frame
  is over the 10 ms target.
- A fail, or calib >15% off the baseline's, is **confirmed back to back**: it checks out the baseline's commit
  in `%TEMP%\driftwake_perfref_<sha>`, benches it now and judges against that. `-NoConfirm` skips it.
- **`-Update`** after an intended change (a feature that's worth its ms, a new baseline machine state):
  commit the game change first (the baseline names HEAD), run it on a quiet machine, commit the new
  `perf_baseline.txt`. Never update it to make a regression pass. Other flags: `-Hours 13`, `-Runs`,
  `-Label`, `-BenchArgs stops=beach,dock` (to both sides of a confirm).

## Rules that keep the frame cheap

- **Far actors sleep: ActorSleep** (`scripts/world/actor_sleep.gd`). An actor that thinks every tick calls
  `ActorSleep.add(self)` in `_ready` (`ActorSleep.add(self, ActorSleep.SHIP)` for ships) and defines
  `sleep_ok()` (true when idle: not fighting, not boarding, no ragdoll, not talking). Asleep =
  `PROCESS_MODE_DISABLED`: no AI, no move_and_slide, body and hurtbox out of physics, timers frozen; it wakes
  where it was. People sleep past 160 m from every captain, wake within 120, hide past 230; ships 420 / 340.
  The host decides in co-op (asleep = `net_idle`). `set_meta("no_sleep", true)` keeps one awake. This one
  rule was 25.7 -> 10.7 ms.
- **Island LOD:** fauna by distance through FaunaSpawner (`_update_lod`: `Creature.LOD_RANGE` 30 / 70 / 110 m
  = full, low (every 3rd frame), sleep, hidden). Rigs pose at a rate by distance (`Humanoid.lod`; your own
  rig every frame). Something new and island-wide follows one of these, not its own per-frame loop.
- **Lowest rate that looks right:** per-frame work on a timer or a frame slice (CoastProbe every 0.07 s,
  Weather's look every 0.1 s, PuffClouds' sort 0.15 s, HUD text 0.25 s, SkyBirds one frame in three). A
  screen that's closed doesn't process. Game time only (delta, ticks, `Ocean.clock()`), never the wall clock.
- **Meshes:** a visibility range on everything (`DrawLOD.apply` / `.steps` gives one to whatever a built
  place set none: 130 m per metre of size, min 45, glow x3); small things (< 0.9 m) cast no shadow; ground
  huggers none; repeats are one MultiMesh in cells with a range and no shadow (vegetation); one merged mesh
  per kind of dressing. `tools/dev/drawcount.gd` (headless: `world`, `bodies`) counts draws per piece.
- **Materials:** cached `PSXMat.lit(...)` shared by everything; tints fold into vertex colours (one surface
  per texture). An object's own copy only when it flashes (`tint_mul`); psx_lit has no instance uniforms.
- **Areas:** `monitoring` only when something reads that area's overlaps (hitboxes while active; hurtboxes
  and interactables never). Brinehollow went 394 -> 6 monitoring areas.
- **Lights:** a real light is expensive, a glow material isn't. Island lamps through `KitLights.post` /
  `light` (or a house's `lamp_light`), which take from the island's budget (`KitContext.take_light`;
  Brinehollow `LIGHTS` 22, a generated village 16, harbour 6, landmarks 5, temple 4, dungeon 3): once
  spent, lamps stay dark but still glow. Brief effect light only via `FX.flash_light` (a pool of
  `FLASH_CAP` 6 shadowless omnis, none past 90 m; nested calls merge). No new shadowed local lights.
- **Effects:** FX bursts past 160 m aren't made; one burst = one draw; count particles (driftwake-fx).

## Build-time budgets (islands, hitches)

- A chain island is prepared on a worker (`GenIsland.prepare` via WorkerThreadPool: data only, no nodes,
  no servers, no PSXMat) and put in the world **a step a frame** (`finish_steps`). A step is a hitch if it's
  long: split big ones (DrawLOD.steps runs in ~12 ms slices). Plan as data in prepare, build in steps
  (driftwake-islands).
- world_generator logs each island: `GenIsland: <name> ... ready in X ms; on the main thread Y ms over N
  frames, the most Z ms {build_ms}`. Z is the worst hitch; `build_ms` has each piece's ms (wrap a new piece
  in `ctx.timed("piece", fn)`). isletest and chaintest print it too. Report the worst step for island work.
- Bodies are built ahead on a worker (`Humanoid.prebuild`), so a spawn costs ~nothing on the main thread.
- Build timing is the wall clock's allowed use (`tools/dev/wallclock_allow.txt`); gameplay never.

## In the game and in the tests

- **F8** (any build): the overlay (fps, process/physics ms, render CPU/GPU, draws, prims, nodes, enemies
  awake / asleep). Its PROCESS is the worst of the last second and includes the draw, so ~frame time says
  little about scripts: use the bench to attribute. In the world, `user://perf.log` gets a line every 30 s
  (fps, 1% low, worst ms, hitches > 50 ms, process, physics, gpu, draws, nodes, enemies (awake), loot,
  position); the previous session is `perf_prev.log`. Ask Zach for it when he reports a slowdown.
- **perftest** (heavy suite): swimmers drown, left-behind boarders go, drops expire, rig LOD (a far villager
  poses only some frames), 3D at the grid's scale, prebuilt bodies, shared weapon meshes, far FX skipped,
  the perf log, chunked terrain. **t/world/actor_sleep**: sleep at 650 m, frozen, the 120/160 hysteresis,
  wake in place with clocks where they stopped, hurtbox out/in, net_idle, hide/show, boarders never sleep,
  `enabled` off. Also chartest (draws per body), t/fx/blocks and t/fx/flash_lights (effect costs).
- A new sleeper: add it to t/world/actor_sleep's cast. A new cost cap: an atomic test that asserts the count
  (nodes, draws, particles, lights), not the ms (ms flake; counts don't).
- **Older tools:** `perfbench.gd` (five fixed views, `probe` / `probe:<view>` times every script), and
  `hitchprobe.gd` / `buildprobe.gd` for one-off jobs and body build stages.
