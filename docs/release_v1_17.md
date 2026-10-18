# v1.17 "Timber and Tide" (release plan, 2026-10-17; the axe dropped the same day)

Zach, 2026-10-17: package the current batch as **v1.17 "Timber and Tide"** once it's finished.

## What's in it
- **The forest island type** (docs/forest_island_plan.md): autumn woodland, the lumber town and sawmill on its
  river, deer, foxes and folklore (wisps, wood sprites, treantlings), the Stag King, the Elder Treant, the moss
  golem, the Cursed Huntsman and his hounds, the Wild Hunt at night, the hollow giant tree, the ruined castle,
  the waterfall gorge; its music and ambience.
- **Ship upgrades** (docs/ship_upgrades_plan.md): Tackett's refits as tiered lines, every level visible; new lines
  (copper bottom, bow chaser, crow's nest, lanterns, railings, tangerine grove, galley and bunks, the hold);
  salvage from sunk ships, wrecks and chests; any captain chips in; each captain's Seamanship tree (the SEA tab).
- **Brinehollow** (docs/brinehollow_polish_plan.md): the land to ~400 m, the market street and second row, the
  shrine terrace, the windmill hamlet and farmland, the falls, the wreck and the second cove; doors and walkable
  steps on every building kind, the roof fixes; the shop moves (Haldor's Forge, Corin's music shop, Vey armour
  only, Gus food and drink); townsfolk on routines, smoke and night lights, a busier harbour.
- **The katana** (docs/katana_polish_plan.md): the combo on its real swing paths, drawn steel slashes, the
  petal-cloud awakening, the five abilities reworked.
- ~~**The axe**~~: **out of v1.17** (Zach, 2026-10-17: paused to stay in scope; its WIP stays on its branch, docs/axe_polish_plan.md).
- Also: test and render windows no longer go fullscreen or on top.

## Steps (once every agent has landed and been checked)
1. **The full local run** on main: `prepush.ps1 -NoPush` (the Tests panel's "Run push set"), never on GitHub; one
   fix pass on what fails (the agents' expected-affected lists first: qoltest's blade sale to Haldor,
   katanatest/techtest/powertest/wieldtest/balancetest, yardtest/shiptest/decktest/savetest, storytest/villagetest/
   the r-suites/fidelitytest, isletest/chaintest/smoketest rolls with a fourth theme), then nettest's modes.
2. **The perf gate:** `perf_gate.ps1` (as `prepush.ps1 -Release` runs it). **Decided: if Brinehollow fails it, fix it
   before release** (a perf pass on the new districts: merging, visibility ranges, sleep distances) until it's within
   the gate; no baseline update to wave it through. Only an intended, accepted change gets `-Update`.
3. **The release commit**, like v1.16's (b29d8a4): `project.godot` version 1.17, `scripts/ui/whats_new.gd`,
   README, `web/site/news/v1-17-timber-and-tide/index.html` + the news index, `web/site/releases/index.html`,
   `web/site/roadmap/index.html`, site images from `themewxshot.gd` with `TWX_SITE` (1600x900 + 640 JPEGs: the forest,
   the lumber town, Brinehollow's terrace and market street, the upgraded sloop, the katana's petals).
   Show Zach the what's-new text and the news post before tagging.
4. **Push main, then tag `v1.17` and push the tag** (the tag starts build-windows.yml; deploy-web on main's push).
   Zach asked for this release: confirm with him once at this point, since a tag and a public post can't be quietly
   taken back.

## State at 2026-10-17 ~19:30 (for a session picking this up)
- On main and checked: buildings (doors, steps, roofs), katana pass, ship upgrades + Seamanship, forest island (+ its
  music, d5bd0ad), Brinehollow layout (land, market street, second row, shrine terrace, farm, wild places), Brinehollow
  life pieces 1-5 (shops, townsfolk, sound/lanterns/smoke, harbour, terrace/farm/cove people), the woods round
  Brinehollow piece 1. The axe is reverted out (037d9bd); its work is on branch worktree-agent-afa189ebe4af75f8f.
- Still running when this was written: the woods agent's piece 2 (farmland surroundings, south-east) and the life
  agent's final bench. Check `git log main` and `crew.ps1` for whether they landed; nothing else is needed from them.
- No world suite or nettest has run on this batch (Zach's rule: suites once, after everything's in).
- **Usage-limited plan (Zach, 2026-10-17):** if there's no budget for the full run + fix pass, the minimum before
  tagging is `run_tests.ps1 savetest storytest` and `nettest.ps1` (basic mode), in the background; fix only what
  breaks saves, the story or co-op joining. Then the release commit (step 3) and the tag (step 4, ask Zach first).
  The full suite and the perf gate then wait for 1.17.1.
- Known bug: a big quadruped beast can lift a standing captain onto its back (docs/todo.md).

## Released (2026-10-17, ~20:35)
Tagged v1.17 at 17f233e and pushed; Build Windows (tag and main) and Deploy web build all green. Shipped with
savetest/storytest/nettest passing and the perf gate failing (Brinehollow 13.4 ms mean vs v1.16's 9.4 on the min-spec
PC; the market street's customers/porters/kids are off behind CROWD in brinehollow_cast.gd).
**For 1.17.1:** the full local suite + fix pass (nothing else ran), a Brinehollow perf pass (then CROWD back on), the
big-beast lift bug, and the follow-ups in docs/todo.md. The axe pass resumes from branch worktree-agent-afa189ebe4af75f8f.
