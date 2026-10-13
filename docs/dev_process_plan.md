# Faster, calmer feature batches (plan, 2026-10-13)

The phase-2 island batch (nine features, nine agents) cost more in merging, bug-fixing and testing than in
building. What went wrong, and what we change.

## What went wrong
- **Hub files everyone edits:** `gen_island.gd`, `fidelity.gd`, `kit_style.gd`, `island_village.gd` and the test lists
  were changed by 5-7 agents at once: constant conflicts, and quiet breakage (the theme re-skinned a village the
  village agent had just rewritten).
- **Loose data between features:** features passed Dictionaries and read each other's fields. A rename or a missing
  key (`taken`, `huts`, the board's `p`, a hamlet at INF) only showed as a runtime error deep in an island build.
- **Late, blind integration:** merged compile-only at the end; random chain seeds made failures come and go;
  frame-timed checks failed under load.

## The plan
1. **Island smoke test on every merge** (first, cheapest)
   - `smoketest`: builds 5-6 fixed chain seeds' islands headless and fails on any SCRIPT ERROR, non-finite transform
     or missing service; ~30-60 s. `land.ps1` runs it even with `-NoTests`.
   - **Fixed seeds everywhere:** every suite picks its seed explicitly and prints it on failure; a failing run can be
     rerun with the same seed (`run_tests.ps1 bosstest -Seed 1234`), and the Tests pane gets a "rerun this seed" button.
   - **Physics ticks, not frames:** a shared `wait_ticks()` helper for tests; frame-timed checks move to it.
2. **Island feature registry + typed contracts** (the big one)
   - `IslandFeatures.add(name, plan, steps)`: a feature registers itself; `GenIsland.prepare`/`finish_steps` walk the
     list in declared order. New features add a file, not lines in `gen_island.gd`.
   - The same for the other hubs: each kit declares its fidelity names and its style keys in its own file.
   - Cross-feature data as small typed classes (`VillagePlan`, `LifeSpot`, `PoiInfo`, `HarbourPlan`...) instead of
     Dictionaries, so a rename or a missing field fails the compile check on save (the edit hook), not 40 minutes later.
3. **Process, skills and mods**
   - **Contracts first:** before a batch starts, the lead commits the contract classes (empty) on main; agents build
     behind them and never edit another feature's file.
   - **Merge as you go:** the lead lands each agent's first coherent piece straight away; agents rebase onto main every
     hour or two. No end-of-batch merge.
   - **At most 3 agents** (already the rule), and fewer, larger, sequential features where they share a hub.
   - **Skill: feature brief template:** ownership, contracts used, testing tiers, report format, so every spawn is
     short and consistent.
   - **Skill: integrator:** the merge routine (squash, rebase, keep both sides, import, compile, smoke).
   - **Agent wall: overlap alarm** at function level (two agents in the same function), so work gets sequenced early.
   - **Tests pane: flake tracker:** failures per check across runs, to tell real bugs from load flakes and back
     `flaky.txt` entries with evidence.

## Order
After the coastlines and housekeeping branches land: 1, then 2 (one agent; it touches every island file, so nothing
else on islands meanwhile), then 3's skills and mods alongside the next feature batch.
