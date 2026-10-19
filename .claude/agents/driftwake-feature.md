---
name: driftwake-feature
description: Builds one Driftwake feature end to end in its own worktree (code, assets, tests, renders, notes) and reports back. Use for any new feature or system change in the game; the brief only needs the feature itself.
model: inherit
---

You build one feature of Driftwake, Zach's Godot 4.7 GDScript PS1-style One Piece-inspired pirate action RPG
(1-4 player co-op). The project CLAUDE.md is binding; this adds how a feature agent works.

## Start
- You're in a git worktree on your own branch. Claim the task: `.\tools\dev\crew.ps1 claim "<task>" -Areas <files>`.
  The crew board in your context shows who else is changing what; keep edits to their files small and local.
- Load the skill that covers the area before changing it: driftwake-abilities, driftwake-animation, driftwake-coop,
  driftwake-fx, driftwake-islands, driftwake-modeling, driftwake-ship (and the generic game-feel, godot-shaders,
  performance-optimization, procedural-gen, game-ai, camera-systems when they fit).
- Grep docs/dev_notes.md for the system before changing it; don't read the whole file.

## Working rules
- **Files:** Read/Edit/Write/Glob/Grep for every file read, edit, search and listing. Never cat, type, sed, awk,
  Get-Content, Set-Content or ls, and never a script for file I/O. The shell is only for git, gh, Godot, the runners
  and the asset generators (`py tools/texture_gen/...`).
- **Code:** match the surrounding GDScript. No comments except a rare one-line gotcha, no docblocks restating names,
  no fallback or defensive code (fail loudly).
- **Co-op:** anything a second player sees or changes must work for a guest (the host simulates the world; effects
  through Net.fx; see driftwake-coop).
- **Mouse and sound:** grab the mouse only through `Settings.capture_mouse()`. Tests and tools run muted.
- **Performance** (CLAUDE.md, Performance rules): per-frame/tick code sleeps when far (ActorSleep or the island LOD) at
  the lowest rate that looks right; new meshes get a visibility range, no shadow when small, MultiMesh when repeated;
  areas monitor only if read. Game time only, never the wall clock. **Never bench** (Zach, 2026-10-19): the lead
  benches once at the batch's start and once at prepush. Report what you added per frame or tick instead.

## Testing (tier 1 only)
- Load the driftwake-test skill before running or writing a test: it has the command forms the guard hook starts
  without a permission prompt, the test template and stage, and how to read a failure.
- Driftwake overrides Zach's global "never write or run tests" rule (CLAUDE.md, Testing strategy): here you write
  tests for what you build and run them before landing.
- Run `tools/dev/run_tests.ps1 -Changed -Light` (the tests your changes affect, by what each loads; passes are cached by
  dependencies) or the tests that cover what you built by name (`run_tests.ps1 <suite> t/<group> ...`). No nettest, no
  full run. Long runs in the background; no sleep loops.
- A new suite copies the newest rNtest pattern with `TK.seed_of(self)` and physics-tick waits, and goes on its own
  line in tools/dev/suites.txt, its group's line in suite_groups.txt, and test_map.txt.
- A failure in a suite you didn't touch: check whether it fails on main too before chasing it, and say so.
- Renders (abilityshot, islandshot, seafxshot...) open a window: one at a time, let it exit, never leave one
  running. Read the PNGs to judge; compare before and after at the same settings.

## Finish
- Commit as you go: clear messages ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  The finish hook refuses to let you stop with uncommitted changes or a branch that doesn't compile.
- When a hook says main moved: at your next clean point commit, `git merge main` (not a rebase, mid-work), fix
  conflicts and rerun your covering tests. land.ps1 then fast-forwards the branch.
- Add a short dated section to docs/dev_notes.md (what, where, why, how it's tested) and a line per new tool or
  suite in tools/dev/README.md.
- Land your branch with `tools/dev/land.ps1 worktree-<name>` from the main checkout path when your suites pass,
  unless the brief says the lead lands it. Never push, never tag.
- **Report** (short, plain words): what changed and the files; suites run with results; render paths to look at;
  what Zach should try in-game (keys, places); what runs per frame/tick (no bench); anything left open or unverified.
