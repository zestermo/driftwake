---
name: driftwake-lead
description: >
  Run a Driftwake feature batch as the lead session: get main green and the session into Bypass first,
  pick features in separate areas, commit the contracts, brief driftwake-feature agents from a short
  template (claim and areas, who else is working, the spec, Zach's bars, pieces in order, tests, docs,
  report), watch the crew board and the landing queue, relay cross-agent changes, resume stopped agents,
  verify each report on main before passing it on, clean up landed worktrees, then the one-pass-after
  shared work, prepush.ps1 -CI, the fix pass and the push. Use when Zach says "start the batch", "spawn
  agents for X and Y", "run these in parallel", after a driftwake-grill hands off a decided feature, or
  whenever this session is coordinating more than one feature agent. Not for building a feature yourself
  (that's the agent's job) or a single narrow fix (brief one driftwake-fixer).
---

# Leading a Driftwake batch

The lead plans, briefs, relays and verifies; agents build and land their own branches. The rules are
CLAUDE.md's ("Parallel sessions", "Batch rules", "Testing strategy"); this is the routine.

## 1. Before the batch

- **Main is green.** `.\tools\dev\test_status.ps1` from the main checkout: anything failing or stale on main
  is cleared first (a `driftwake-fixer` per failure, or `run_needed.ps1` for stale passes). Feature agents start
  only once it's clean; a red main makes every agent stop to ask "is this mine?" (batch rule 1).
- **No tooling window open.** Test kit, runner flags, crew/landing scripts and CI change only in a quiet window with
  no feature agents running, then a full run (batch rule 2). A tooling idea that comes up mid-batch goes to
  docs/todo.md for after.
- **Separate areas.** Map each feature to the files it will change. Two features in the same system (two combat
  features, two island themes touching the same kit module) go one after the other (batch rule 3). Check the board:
  `.\tools\dev\crew.ps1` (and `crew.ps1 overlap`) for worktrees still claiming those files.
- **Decisions settled.** A feature with open choices goes through driftwake-grill first; the brief is written from
  its `## Decided` table in `docs/<feature>_plan.md`.
- **Contracts first** (docs/dev_process_plan.md step 3). Where two features meet (a registry entry, a typed plan class
  like `VillagePlan`/`PoiInfo`, a ThemeDef hook, a style key, a music key), commit the empty class or hook on main
  before spawning, and say in each brief who owns which member. Agents build behind the contract and never edit
  another feature's file. Hub files that several agents would touch get one owner, named in the briefs.
- **Permission mode.** Agents inherit this session's mode; in auto they prompt Zach. Check
  `get_session "self"` -> permissionMode and, if it isn't bypass, `set_session_permission_mode("self",
  "bypassPermissions")` (one approval card) before the first spawn.
- **Bench baseline** if the batch touches frame cost: agents bench before/after themselves, but note main's last
  bench so the batch total can be judged.

## 2. The brief

Spawn with the Agent tool, `subagent_type: "driftwake-feature"` (worktree isolation, background). The agent file
already carries the working rules, file tools, co-op, performance, tier-1 testing, the main-moved merge, dev
notes, landing and the report format: never repeat those. The brief is only what's particular to this feature:

```
Feature: <name>, one paragraph of what it is and what the captain does with it.
Spec: read docs/<feature>_plan.md (the "Decided" table is binding; anything marked assumed you may revisit,
  say so in the report). Skills: driftwake-<area> (+ driftwake-fx / -coop if it has effects or shared state).
Claim: .\tools\dev\crew.ps1 claim "<task>" -Areas <files and folders you own>
Others running now: <agent> owns <files>; <agent> owns <files>. Stay out of those; if you need a change there,
  stop and tell me what and why (I'll relay it). Hub file <x> is owned by <agent>; you only add <member>.
Contract: <class/hook on main>; you fill <members>, <other agent> fills <members>.
Bars: <the standing ones that apply, e.g. the island subtype standard: big seeded pools, nothing guaranteed,
  dense life, fights under the canopy / in the terrain, a creature pool, a roaming beast, several bosses>.
Pieces, land each with land.ps1 as it's done (re-claim after each landing, the landing releases it):
  1. <smallest coherent piece that lands on its own>  2. <...>  3. <...>
Tests: <suites / t/<group> that cover it, a new one for <behaviour>>; renders: <tool + what to film>.
Out of scope: <what waits for a later pass>, e.g. weather/ground effects: leave a hook, the weather pass fills it.
Report: as your agent file says, plus the commit of each landed piece.
```

- Small pieces, landed early (batch rule 4): the first piece should reach main within the first hour.
- Name the other agents' files explicitly, not "other areas": the crew hook warns after the fact, the brief warns
  before.
- Narrow work (a failing suite, a rename, call-site updates) goes to `driftwake-fixer` with the suite name and the
  log line, no template.

## 3. While it runs

- **The board:** `.\tools\dev\crew.ps1` shows each worktree's claim, the files it's changing and the test slots;
  `crew.ps1 overlap` when two agents look close. A big overlap is a sequencing call: pause one and tell Zach.
- **The landing queue:** one landing at a time machine-wide; `.\tools\dev\land.ps1 -List` (or the Tests pane's
  status.json `landing`) shows who's landing and who's waiting. A wait isn't a stall. A landing stopped on a conflict
  is the agent's to fix in its worktree (`git add`, `git rebase --continue` or `git commit`, land again).
- **Main moves:** the mainmoved hook tells each worktree once per new head; agents merge main at their next clean
  point. You don't need to relay ordinary landings.
- **Relay what changes another agent's work:** a landed hook or contract member another agent builds on, a renamed
  key, a new shared helper, a hub-file change. `SendMessage` to that agent's id: what landed (commit), what it means
  for their files, whether to merge main now. Requests to touch a file someone else owns come to you: decide, then
  relay to the owner or let the asker make a small local edit.
- **Resuming:** an agent that stops (finished a piece and asked, hit a limit, stopped on a question) is continued with
  `SendMessage` to its id, context intact; answer the question or say "carry on with piece N". A new Agent call starts
  from nothing, so use it only for a fresh brief. Never let an agent sit on an answered question.
- **Re-claiming:** a landing releases the claim. An agent going on to its next piece claims again (the brief says
  so); if the board shows a running agent with no claim, remind it.
- **Main stays green:** a red check on main mid-batch gets a fixer at once, and the agents are told it isn't theirs.

## 4. Checking a report

A report is the agent's account, not proof. Before telling Zach anything is done:
- `git log --oneline main -10` shows the landed commits it names; `git branch --merged main` lists its branch (or
  `land.ps1 -List` shows it 0 ahead). Not on main = not done, whatever the report says.
- `.\tools\dev\test_status.ps1` for the suites it says passed (up to date, not failing).
- Read the renders it names (the PNGs in tools/dev/out/...) and judge them against the spec and the bars yourself.
  No renders for something visual: ask for them before relaying.
- Then relay in Zach's terms: what landed, what to try in-game (keys, places, F-keys), what's open. Never relay a
  claim you didn't check; say "the agent reports X, not verified" if you couldn't.

## 5. Cleanup

- A landed worktree whose session is done: `.\tools\dev\unwork.ps1 <name>` from the main checkout (it refuses with
  unlanded commits or uncommitted changes; never `-Force` without looking at what it would drop). `land.ps1
  worktree-<name> -Remove` lands and removes in one go.
- **One pass after, for shared files.** Work that several features need from the same shared system (the weather
  and ground pass after desert and snow: Weather, one ground system for snow and sand footprints and kick-up, the
  footstep sounds) is not split across the feature agents. Each feature leaves a hook or a todo; after they've all
  landed, one agent does the shared pass alone in those files. Record the pass in docs/todo.md as the batch starts.

## 6. After the batch

- **The gate:** `.\tools\dev\prepush.ps1 -CI` from the main checkout: GitHub runs every suite, the heavy ones and
  the co-op modes on HEAD's commit (`ci/<branch>`), and a green run pushes that commit. `-NoPush` to just check.
  Local `prepush.ps1` is the fallback when CI is down.
- **The fix pass:** one `driftwake-fixer` per red suite (or a feature agent if it needs design), the known bugs from
  the agents' reports listed first in its brief. A red run keeps its ci/ branch for `gh run rerun --failed`.
- **The push** is prepush's own on green (standing OK to land and push finished work; never tags, force pushes or
  releases without asking; before a version tag, `prepush.ps1 -Release`).
- **Close out:** a dated section in docs/dev_notes.md for the batch if the agents' notes don't cover the whole,
  update the plan docs' status, prune leftover worktrees, and tell Zach what shipped and what to play.

## Don't

- Spawn before main is green, the contracts are on main and the session is in Bypass.
- Put two agents in the same system, or change test tooling while agents run.
- Repeat the agent file in a brief, or leave other agents' files unnamed.
- Relay an unverified report, or call a branch done before it's on main.
- Split one shared system's work across feature agents instead of one pass after.

## Checklist
1. test_status clean on main; tooling quiet; features in separate areas; decisions in the plan docs.
2. Contracts and hub owners committed on main; session in Bypass.
3. One brief per agent from the template; first piece small.
4. Watch the board and the queue; relay contract/hook changes; resume stopped agents; remind re-claims.
5. Verify each report on main (log, merged, test_status, renders) before relaying.
6. unwork.ps1 the landed worktrees; the one shared pass after.
7. prepush.ps1 -CI, the fix pass, the push; notes and what to play.
