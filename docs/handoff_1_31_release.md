# 1.31 release: handoff (2026-11-10)

Everything for 1.31 is built and committed on main (docs/v1_31_feel_plan.md, dev_notes 2026-11-09/10). The release
text is committed too (6da82b8d): version 1.31, What's new, the releases page's unstable v1.31 section, the roadmap.
**1.31 ships unstable** (Zach): keep `tools/release/UNSTABLE`. Nothing is pushed or tagged yet.

## Where the release run stands

`prepush.ps1 -NoPush` ran once (log: tools/dev/out/prepush_131.log). Fixed since: leveltest and netclient (stale crew
health x1.15 / +0.7 a captain from 1bb8d0b9: netclient divided by 110 x 1.3), qoltest (the capstan's "anchor" work
pose). Passing on rerun: powertest, qoltest, t/stronghold/gate, t/stronghold/marrow, t/island/build_budget_same,
t/quests/arc_hidden. Still to do, in order:

1. **Rerun** leveltest and `nettest.ps1` (all modes: net, net-board, net-jam, net-rival, net-five, net-three). The
   watcher's "1 puppets" was the client quitting early on the stale scaling check.
2. **Three island suites hang on quit** after RESULT OK (runner: "Stalled (no output for 150 s)"):
   t/island/volcanic_town, t/island/crowd_size, t/quests/island_tracker. Suspect f8903659 (Humanoid._build's
   main-thread turn vs worker body builds) deadlocking at exit, not the 1.31 feel work. Time-box ~20-30 min;
   check whether they hang on the commit before f8903659 (a detached worktree) before digging.
3. **Read and fix** (check each against the diff: stale test or bug):
   - invtest "click wears gloves": `_use` on gloves right after the inventory opens (1.31 plays `gesture_bag` on open;
     the item-wheel commit c7edaee1 also touched the bag/belt).
   - decktest "thrown over the rail the root follows the body overboard (max gap 0.95 m)".
   - chartest "a body is at most 24 draws ... worst 25" (a body one draw over: something added a surface).
   - t/capital/caches "opened (gone), its X clears".
   - t/will/tempo "...dodge pressed: out of it into a dodge (LightAttack)": Cancel out of a light attack's recovery
     (light_attack_state's dash_cancel branch is unchanged; 1.31 added the turn-in and the omni aim there).
   - Known: t/weapons/rapier_tree (balestra 0 damage) fails on main from before 1.31; rival_personality flakes.
4. **Perf:** `perf_baseline.txt` is from 2026-10-24 (stale, memory perf-baseline-stale): `perf_gate.ps1 -Update` on
   the v1.30.3 tag (a detached worktree) first, then `prepush.ps1 -Release` on main.
5. **Tag v1.31 and push** (prepush pushes main when green; the tag publishes the pre-release build). Check the
   releases page after the build (node tools/dev/build_feeds.mjs parses it).

## Update (2026-11-10, second release session; stopped for usage)

Fixed (stale tests, committed): invtest (gloves/bandana: the captain's rebuild waits a frame while a worker is
mid-body since f96ee258, so the check reads the composed look; the wolf check waits past the chest's 0.9 s
gesture_bag), chartest (draw budget 25: the 1.30.3 hakama + pack, same on the v1.30.3 tag; creator Done checked a
frame later, same rebuild deferral), t/capital/caches (marks the cache opened: since 02af4e24 the X only clears
when opened), t/will/tempo (the swing's first mastery finds the tree and clears the stats cache give() wrote).
Passed: leveltest, invtest, t/capital/caches, t/will/tempo; nettest net, net-jam, and two later modes OK.
chartest's rerun with the creator fix was stopped unfinished.

Still blocking prepush (not started: perf_gate -Update, prepush -Release, tag):
- decktest "thrown over the rail": fails the same on the v1.30.3 tag (pre-1.31). The blast's ragdoll stops at
  the rail (from 1.5 m) or barely moves (from 2.5 m); not found in ~20 min. Game or test: undecided.
- t/weapons/rapier_tree balestra 0 damage: fails on v1.30.3 too. Likely: the dash (17 m/s from 0.16 s) carries
  the captain ~0.8 m past the dummy by the 0.36 s cone, which skips foes behind (>0.6 m). Move the cone earlier
  or let it hit what the dash passed through.
- net-board "the boarder's swing hits us here" failed once; rerun alone to tell flake from bug.
- ~~The three island suites still hang on quit after RESULT OK~~ **Fixed 2026-11-10** (dev_notes "quitting while
  bodies build on a worker"): all three pass and exit.
- A detached v1.30.3 worktree is at C:\GD\dw_v1303 (for the perf baseline; remove with unwork/git worktree remove).
