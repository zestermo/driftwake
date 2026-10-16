---
name: driftwake-grill
description: >
  Settle a Driftwake feature's open design decisions with Zach before anyone designs or builds it:
  batched rounds of numbered questions, scope first, each with a recommended answer, then a decision
  record in the feature's plan doc that the build brief is written from. Covers what to ask (intent,
  feel, taste, priorities, co-op, variety, budgets) and what never to ask (facts in the code, the
  docs or CLAUDE.md), the Driftwake decision tree, the off-ramp, and handing off to a
  driftwake-feature agent. Use when Zach says "grill me", "ask me first", "let's plan X", "what do you
  need from me", or brings a new system, island theme, boss, weapon kind, ship, mechanic or big
  change with open choices. Not for bug fixes, tuning, or a request that already says exactly what to
  build.
---

# Grilling a Driftwake feature

The grill gets Zach's decisions, not a design. Its output is a short decision record a feature agent can
build from without coming back to ask. Zach is the only one who can answer these; everything else you
find out yourself.

## 1. Decisions, not facts

- **Ask** only what Zach alone knows: intent, feel and look, priorities, taste, what it's for in the game,
  what he'd cut. "Should the sandworm be a fight you can lose the ship in?" is a decision.
- **Never ask facts.** How a system works today, which file owns it, what the island kit already does, what a
  Godot API can do: grep `docs/dev_notes.md` for the system, read the code and the skills, and record what you
  found. "Does the island kit support per-theme terrain?" is a fact (it does: ThemeDef hooks).
- **Architecture follows from his answers.** Don't ask "a Resource or a Dictionary?". Ask what it has to
  support ("will islands of the same theme need different bosses?") and choose yourself, saying what you chose.
- **Standing rules are already decided** and are never re-asked: CLAUDE.md (feel numbers, PS1 look, co-op
  authority, game time, performance rules, batch rules), the memory's feedback (the island subtype standard:
  big pools, nothing guaranteed, dense life, fights in the terrain), `docs/roadmap_v2.md` "Decided".

## 2. Before round 1: read what's settled

In this order, and note every decision you find so you never ask it again:
1. `docs/roadmap_v2.md` (the plan of record and its "Decided" section) and the item in `docs/todo.md`.
2. The feature's plan doc if one exists (`docs/<feature>_plan.md`: desert, snow, devil fruits, multiplayer...).
3. `docs/dev_notes.md` for the systems it touches (grep, don't read it all).
4. The skills for its area (islands, fx, coop, ship, abilities, animation, modeling).

## 3. The Driftwake decision tree (a seed, not a script)

Roots (no prerequisites; skip any the request or the docs already answer):
- **Scope:** the first piece that lands on its own vs the whole thing; what's explicitly out (and later).
- **Player's view:** what the captain does with it and what it should feel like (shonen, readable, punchy; a
  reference from One Piece or another game if he has one).
- **Where it lives:** an island theme, the sea between islands, the ship, combat, progression, UI, a city.
- **Co-op:** does a guest see it, do it, own it? (The host simulates the world; the question is only what
  players experience: shared, per-captain, or host-only.)

Branches, opened by those answers:
- Variety: how many kinds, rolled from what, how rare (pools, never guaranteed, per island or per sea).
- Progression and economy: what it gives, costs, unlocks; where it sits in the level curve.
- Persistence: saved or not; what happens on rebuild, death, leaving the island.
- Difficulty and failure: what losing means, how it's telegraphed.
- Look and sound: palette, scale against the captain, music or sound identity, effects' weight.
- Budget: where it's allowed to cost (a set piece may spend; something everywhere must be near free).
- Order: what lands first, what waits for another system (weather pass, flipbook library, Marines...).

Prune hard: a cosmetic piece needs no progression branch; a solo-only debug tool needs no co-op branch.

## 4. Rounds

- The **frontier** is every open decision whose prerequisites are answered. Ask the whole frontier at once.
- **Round 1 is small and settles scope** (and usually the player's view and co-op).
- **In this app, ask with AskUserQuestion:** up to 4 questions per call, 2-4 options each, the recommended
  option first with "(Recommended)" in its label and the reason in its description. A frontier over 4 goes in
  two calls in the same round. Without the tool, one numbered message:

  **1. Title.** The question, options a / b / c.
  ➡️ Recommended: b, because <one clause>.

- Ask nothing outside the numbered questions, then stop and wait.
- After each round recompute the frontier. An answer that contradicts something recorded: say so and ask
  whether to reopen it; never overwrite a record quietly.
- Keep it short: Zach plays the build to judge feel, so leave tuning numbers to play-testing instead of
  asking them (record "tune in play" as the decision).

## 5. Ending

- **The frontier is empty:** write the record, then one message confirming the shared picture (what it is, the
  first piece, what's out) and wait for his yes before briefing anyone.
- **The off-ramp**, at any point ("just build it", "skip the questions", "you decide"): stop asking, list
  every open decision with the choice you're assuming (marked **assumed**), write the record, and go
  straight to the hand-off with no further gate.
- **Hand-off:** a feature is briefed to a `driftwake-feature` agent; the brief quotes the decision table and
  links the record. A change to one known system goes to that area's skill instead.

## 6. The decision record

- **Where:** the feature's plan doc, `docs/<feature>_plan.md`, in a `## Decided (YYYY-MM-DD)` section (the
  roadmap's own pattern). No plan doc yet: create one with a short "What it is" paragraph and that section.
  A decision that changes the roadmap's order also gets a line in `docs/roadmap_v2.md` "Decided".
- **Shape:** a table, then the deferred list.

  | Decision | Choice | Why | Revisit when |
  |---|---|---|---|

  `### Open / deferred`: each with **assumed** where you chose for him on the off-ramp.
- Commit it on main alone (`git add -- docs/<feature>_plan.md`), docs only, so feature agents see it at once.

## Don't

- One question per message, or questions without a recommendation.
- Asking a fact, a standing rule or something already recorded.
- Grilling a bug fix, a tuning tweak or a request that already spells out what to build.
- Briefing an agent or writing code before the confirmation (unless he took the off-ramp).

## Checklist
1. Read the roadmap, todo, plan doc, dev notes and skills; list what's settled.
2. Round 1: scope, the player's view, co-op.
3. Each round: the whole frontier, numbered, a recommendation each, then wait.
4. Off-ramp: assumptions listed, record written, straight to the brief.
5. Record in `docs/<feature>_plan.md` "Decided", committed alone.
6. Confirm the picture, then brief a `driftwake-feature` agent from the record.
