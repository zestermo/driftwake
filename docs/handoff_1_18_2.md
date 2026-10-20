# Handoff: the 1.18.2 perf release (2026-10-20, ~19:10)

Zach asked the lead session to stop before shipping 1.18.2 and hand over to another session. Nothing has been
pushed since v1.18.1 (main is ~24 commits ahead of origin/main, including the progression-redesign docs from the
other session).

## On main (done, checked)
- **Bench refresh** (c57982f + the stutter hunt's tooling): 16 route stops + brawl, naval, isles, bwalk, cwalk;
  `crowd` arg; hitch counts (h33/h50) and hitch lines with their causes; the bench in an exported build
  (`tools/dev/export_bench.ps1`, `bench.ps1 -Exe`, `-ColdShaders`). See the driftwake-perf skill.
- **Threaded rendering: tried and dropped.** No gain (12.39 -> 12.09 ms, within noise) and the main thread hung at
  the fight stop. Not in the project settings.
- **Stutter hunt** (e0298f1, 2069d6e, cd0bb05): islands that are let go are freed a slice a frame (one 150-270 ms frame
  before); `FX.warm_up` draws every effect once behind the loading card (a cold cache's 400-700 ms freezes at a
  fight's start are gone; one ~70 ms frame left); blood splats pooled. perf.log is no longer written by tool runs and
  keeps 5 sessions, with a line per hitch naming its cause.
- **Island builds off the main thread** (1d594d4..8a4d3a0): beast and creature scripts loaded on the worker, 16 beast
  kinds' models built ahead, DrawLOD folding from build data (~0.8 s saved per island), sliced steps. The isles stop:
  frames >33 ms 26 -> 13, >50 ms 5 -> 1, worst 87 -> 60 ms; main-thread build time about halved. Islanddumps identical.
  Left (dev_notes): 10-30 ms steps (village houses, caves, the boss arena, landmarks, terrain upload, ground colliders,
  the serpent/mantis/sandworm/scorpion models) and one unexplained 60 ms frame at a build's end.
- nettest basic and chain passed after the island-freeing change.

## In flight at the handoff
- **Occlusion culling + the long tail**: branch `worktree-agent-af6c47ca638b7badf` (3 commits: occluders in the
  capital's walls/towers/houses/massing and every Buildings.house and desert house, `use_occlusion_culling` on; sky
  birds and sea spray write their MultiMeshes in one buffer a frame, foam heights a third a frame). The agent was told
  to land it with land.ps1 and report. **Check whether it reached main** (`git log main`, `land.ps1 -List`); if not,
  land it from the main checkout: `.\tools\dev\land.ps1 worktree-agent-af6c47ca638b7badf`.
  Its full benches, back to back: ALL 15.89 -> 14.20 ms (-11%), Brinehollow plaza 17.37 -> 14.67 (-16%), capital plaza
  16.21 -> 13.70 (-15%), old eight 15.46 -> 13.44 (-13%) (the after run's machine was busier: calib 27.14 vs 25.39).
  Not yet verified: popping around corners with the occluders (renders/walks).

## To ship 1.18.2 (Zach's rules: docs/v1_19_plan.md "Ships as 1.18.2")
1. The occlusion branch on main (above); a look for occluder popping.
2. `prepush.ps1 -NoPush` (the stale suites + nettest modes; harbourtest/harbourkindstest can time out at 330 s under
   5-way load: a known load issue).
3. **Re-baseline the perf gate on the min-spec PC** (this machine): `perf_gate.ps1 -Update` against a fresh full
   bench. The old baseline is v1.14's laptop run, so the gate fails here regardless. **Needs Zach's OK.**
4. Release, simple and short: **no blog/news post**; a brief entry in web/site/releases/index.html and the README
   history; on the roadmap timeline **fold 1.18.2 into the 1.18.1 card** (an "added" line for the performance work)
   instead of a card of its own; `project.godot` version 1.18.2; a one-line what's new; then push main, tag
   `v1.18.2`, push the tag.

## Queued after 1.18.2
- **The capital grill** and **services after Brinehollow** (a shipwright in the capital and/or harbour vendors with
  one upgrade tree each on chain islands): docs/capital_plan.md "Next".
- **The progression redesign** (Zach's other session: docs/progression_plan.md and the redesign docs on main).
- **1.19**: docs/v1_19_plan.md (the Admiralty + rival crews, the intro, fighting in the water; a tooling window first:
  docs/todo.md "Tooling window").
- Leftover empty worktree folders under .claude/worktrees/ (locked by exited processes): `tools/dev/unwork.ps1 <name>`
  once nothing holds them.
