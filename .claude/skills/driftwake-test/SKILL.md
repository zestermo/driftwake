---
name: driftwake-test
description: >
  Test Driftwake changes the project's way: pick the tests a change needs (-Changed -Light, by name,
  affected.ps1 -Explain), run them through the runners in the exact command forms the guard hook
  starts without asking, write a new atomic test on the light stage or a world suite (TK seeds,
  physics-tick waits, check names, registering it in suites.txt / test_map.txt / README), and read a
  failure (the log, the seed and its rerun line, stopped suites, flaky retries, "is it mine or main's").
  Also test_status, run_needed, nettest's co-op modes and the landing's tests. Use whenever you run,
  write, fix or explain a Driftwake test, a suite fails or stops, or Zach asks "did it pass", "what's
  failing", "write a test for X". The policy (three tiers, when the full run happens) is CLAUDE.md's
  "Testing strategy"; this is the how.
---

# Testing Driftwake

Driftwake writes and runs tests (it overrides Zach's global "never test" rule: CLAUDE.md, Testing strategy).
Every test goes through the runners; they share the machine's test slots, cache passes by the contents of
everything a test loads, wait for a run already in flight and show in the Tests pane (`/tests`, `/crew`).

## Run commands the hook allows (copy these forms)

`tools/dev/hooks/guard.ps1` starts these without a permission prompt. Keep each to **one plain command**,
optionally piped into a reader (`Select-Object`, `Select-String`, `Sort-Object`, `Measure-Object`,
`Format-*`, `Out-String`; in Bash `head`, `tail`, `grep`, `wc`) or chained with `;` / `&&` to another allowed
command. Anything else (a redirect to a file, `$(...)`, a script block `{ }`, a quoted script path) prompts.

PowerShell tool:
```powershell
.\tools\dev\run_tests.ps1 -Changed -Light
.\tools\dev\run_tests.ps1 daggertest t/combat
.\tools\dev\run_tests.ps1 isletest -Seed 1234
.\tools\dev\nettest.ps1 chain
.\tools\dev\test_status.ps1
.\tools\dev\affected.ps1 -Explain
& $env:GODOT --path . --script res://tools/dev/flipshot.gd
```
Bash tool:
```bash
powershell -NoProfile -ExecutionPolicy Bypass -File tools/dev/run_tests.ps1 t/fx
```
Allowed scripts: run_tests, nettest, test_status, affected, run_needed, suite_times, crew, land, bench,
bench_compare, perf_gate; Godot only with `--script res://tools/dev/<tool>.gd` (suites still go through
run_tests: the guard refuses them straight through Godot); `py tools/texture_gen/<gen>.py`. Never allowed
without asking: prepush.ps1 and ci.ps1 (they push), unwork.ps1 (deletes), anything outside tools/dev.

Long runs (a whole group, a world suite, nettest) go in the background (`run_in_background`); you're told when
they end. No sleep loops, no polling.

## Picking what to run

- **While building:** `run_tests.ps1 -Changed -Light` (the tests whose recorded loads include a changed file,
  plus what `test_map.txt` says the file is about), or the covering tests by name. `affected.ps1 -Explain` says
  why each was picked.
- **Don't rerun a pass "to be sure":** a pass is cached under the exact contents of what it loaded; a rerun
  with nothing changed is skipped. `-Force` only when you need a fresh run (a flake you're chasing, a render).
- `-Seed N` runs are never cached or shared: use them to reproduce, then fix and run normally.
- **Co-op** (`nettest.ps1`, modes: default, late, three, hostquit, water, board, chain, jam, duel) is the push
  gate's job; run a mode yourself only when you changed network code and the brief asks.
- **Landing** (`land.ps1`) runs the compile check, smoketest and the branch's affected light tests itself.

## Writing a test

**An atomic test** (one behaviour, ~11 s, the default choice): copy `tools/dev/t/_template.gd` to
`tools/dev/t/<group>/<behaviour>.gd`.
- `TK.seed_of(self)` and `stage = TK.stage(self, opts)` in `_initialize`; wait for `stage.up` before step 0.
  Stage opts (`tools/dev/stage.gd` header): `hud`, `dummy`, `grunts`, `weapon`, `npc`, `bench`, `chest`,
  `storage`, `water`, `ship`, `weather`, `crew` (stand-in crewmates). Ask only for what the test needs.
- A step machine in `_process`: each step sets `until = TK.wait_ticks(n)` or `TK.wait_secs(s)`, and the top of
  `_process` returns while `TK.ticking(until)`. Physics ticks, never frames or process seconds (they stretch
  under load).
- `TK.act("action")` taps an input; `TK.press` / `TK.release` hold one.
- `check(name, cond)` prints `PASS name` / `FAIL name`; finish with `return TK.done(fails)`.
- The group's line in `tools/dev/test_map.txt` already covers a new file in an existing group; a new group
  needs `tools/dev/t/<group>/*  t/<group>`. Add the test to its group's line in `tools/dev/README.md`.

**A world suite** only when it needs the world (Brinehollow's places, generated islands, the real sea): copy
the newest `tools/dev/rNtest.gd`. Add it on its own line in `tools/dev/suites.txt`, its group's line in
`tools/dev/suite_groups.txt`, a `test_map.txt` line for the files it's about, `tools/dev/heavy.txt` if it
takes minutes, and a README line. Island suites loop a small fixed list with `TK.seeds_of([...])`.

**Rules that bite:**
- Don't statically type project classes that touch autoloads (a `--script` compiles before the autoloads).
- Nodes added in `_initialize()` aren't in the tree yet.
- Clamp `lerp(a, b, k * delta)` weights.
- A check's name must not contain "script error" (the runner stops on that text).
- Assert behaviour the player sees ("a scorpion's sting poisons"), not internals that a refactor renames.
- A new `class_name` needs `& $env:GODOT --headless --import` once (run_tests does it when one's missing).

## Reading a failure

- **The runner prints the first FAIL whole**, with the stack, the seed and the line to rerun it. A suite stops
  at its first failure; fix that and rerun the suite.
- **Logs:** `tools/dev/out/logs/<test>.log` in the checkout that ran it (an atomic test as
  `t.<group>.<name>.log`). In a worktree, that worktree's `tools/dev/out/logs/`.
- **Stopped, not failed:** stalled (150 s with no output), scripts that don't parse, a flood of script errors, a
  log past 25 MB. Each is a real problem to look at, never a rerun.
- **Flaky:** `tools/dev/flaky.txt` lists checks proven to flake on timing or load; a failure made only of those
  is retried once automatically. Add a line only with evidence it's load, never to hide a failure.
- **Is it mine?** In a worktree a failure is this tree's code or main's, never another session's uncommitted
  work. `test_status.ps1` on main says whether main has the same failure; if a file someone else is changing
  is involved, say so.
- **Godot crashes** (signal 11 in a mesh commit while an island prepares): a known open item in
  `docs/todo.md` ("Mesh-commit crash"); note it with the test and seed, don't chase it inside a feature.

## Status

- `test_status.ps1`: every test's state against this checkout (ok, stale with the files that changed,
  failing with why, never run). `-Stale` prints just the names.
- `run_needed.ps1`: runs everything stale, failing or never run (the Tests pane's "Run needed").
- `prepush.ps1 -CI`: the push gate on GitHub. Lead only, after a batch; it pushes.
