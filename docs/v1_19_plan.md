# v1.19 (Zach, 2026-10-19)

## What it is
**Marines and rival crews** (Zach, 2026-10-19, revised): rival pirate crews (docs/rival_crews_plan.md) and the
Marines with bounties (roadmap phase 6), plus a new interactive timeline roadmap on the website (below). A tooling window comes first. The perf pass and fishing moved into 1.18,
and gear upgrading waits for a later release. The table below is the earlier draft, kept as a record.

## Decided (2026-10-23): the full grill
Zach settled the whole version in one grill so it can be built in one go. This section is the plan of record and
**overrides the 2026-10-19 table below** where they differ (marked "reopened").

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Scope | **Rival crews** (captain-style AI, cutscene system, crews) + **the Admiralty, full roadmap phase 6** (bounties, wanted posters, patrol ships at sea, named hunters) + **the intro redesign** + **fighting in the water** + **the weapons' enemy pass**. Out: two/three-sword katana (later), gear upgrading (later), the Admiralty fortress (1.22 strongholds). | Zach: finish the whole version. | — |
| Admiralty at sea (**reopened**: was "patrols and pursuit wait for 1.20") | Patrol ships in busier waters that come about when they spot a wanted captain, built on today's enemy ships and boarding; named hunters past bounty thresholds. | Zach chose full phase 6. | After play |
| Carried over from 1.18.4 | Greatsword finish, black-leg finish, corsair/pistol guards, the web roadmap timeline: **already done** (Zach). | — | — |
| Opening | The tooling window first (crew_lib deps-file race, autoload-name lint); **the perf pass counts as done** (the 2026-10-22/23 combat perf work and skinned bodies piece 1). | Zach. | Prepush bench |
| Rival roster | **Authored captains**: 3-4 hand-written signature crews per chain (captain personality, theme, flag, signature weapon, lines) crewed by seeded members from pools. | Rivals you get to know; members vary per save. | — |
| First meeting | **Placed first, then rolled**: the first meeting is set on an early chain island after the intro sets them up; then crews turn up on rolled islands every few islands, scaled to their level. | — | After play |
| Captain-style AI | **Fair but sharp**: sees only what a player could (your tells, your spacing), blocks, dodges and parries some of the time, punishes whiffs, saves its ultimate for an opening. Skill per member (a rookie vs the captain). Used by rivals, Admiralty officers and hunters. Numbers tuned in play. | "Fought by seemingly other players." | After play |
| Cutscene skip (co-op) | **Everyone presses skip**: a "waiting for N more" chip; it skips for all when the last captain presses (or it ends). | Nobody misses a scene they wanted. | — |
| Bounty (co-op) | **Each captain's own** bounty and poster, raised by what they did; the ship draws patrols by the crew's total. | — | — |
| What a bounty changes | **All four:** Admiralty heat (patrols, ships coming about, named hunters past thresholds, tougher as it climbs); **townsfolk react** (recognition lines, whispers, some flee; posters on boards; Admiralty-friendly shops charge more or refuse, shady ones give a better rate); **rivals react** (lines and respect follow it; bigger bounties draw stronger crews); **bounty hunters** (civilian ambushes on islands, apart from the Admiralty). | Zach. | Economy pass |
| Losing to the Admiralty | **Arrested, then escape**: you wake in their ship's brig or an outpost cell, gear in a chest nearby, and break out (a short escape run); a share of gold is confiscated. | Stings, and its own little scene. | After play |
| Arrest in co-op | **Only if all captains go down**; then everyone wakes in the cells together. While one stands, the downed get revived as usual. | Zach. | — |
| Named hunters | **Persistent**, built like the rival crews: a named officer (look, weapon, voice, lines), remembers wins and losses, returns scaled and better equipped, tracks your ship down the chain and waits at harbours. | — | — |
| The Admiralty's look | **Grey ironclad**: slate grey and steel, armoured officers, darker ships; oppressive. | Zach. | — |
| Intro: motive | **Legend + personal spark**: a legendary prize past the end of the First Sea that the great powers want, and a personal spark on day one (the Admiralty strikes at the captain's home or mentor) so they set out to get strong enough to reach it and answer them. | Gives the game a goal. | — |
| Intro: form | **Cutscene + short play**: a ~60-90 s skippable cutscene (the Admiralty, rival crews, the great powers, the sea's end), then the personal spark as a short playable moment, then Brinehollow as today. | — | — |
| Fighting in the water | **Your own weapon**: a swimmer fights with what they carry, slowed, with water versions of a few moves (no separate diving knife or harpoon). Sharks and morays become fightable in the sea; the captain AI can follow you into the water. | Zach. | After play |
| Weapons' enemy pass | As recorded below (grunt roles for spear, hammer, twin axes, greatsword, black-leg; readable cut-down movesets; they drop their weapon), fielded by rivals and the Admiralty too. | — | — |
| Names and lines | **Claude writes, Zach reviews**: original Driftwake names (the legendary prize, the great powers, Admiralty ranks, the rival crews and captains) and lines, no One Piece terms (docs/originality_plan.md); listed in this doc for review. | — | Zach's review |
| Build order | Tooling, the captain-style AI (on a debug duel key), the cutscene system, rival crews, bounties and posters, the Admiralty at sea and hunters, arrest and escape, the intro, fighting in the water, the enemy pass. Each lands in playable pieces. | The AI is the root the rest builds on. | — |
| Unknowns while building | **Decide, note, keep going**: the option that fits this record, marked **assumed** in "Assumed while building" below, for Zach's review. | Uninterrupted build. | Zach's review |

### Assumed while building
(Filled in as the build goes.)

## Decided (2026-10-19)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Order | (1) A tooling window: the crew_lib deps-file race, a lint for autoload names in static funcs (todo.md), no agents running. (2) **A perf pass**: Brinehollow back toward the 9.4 ms target with the market's CROWD back on, then the perf gate's baseline. (3) The features. | The perf gate has failed since v1.17 (13.4 ms), and 1.18 adds more. Batch rule 2. | — |
| Headline | **Rival crews** in three pieces: the cutscene system, AI that fights like a captain (the player's own states and skills), the crews themselves (persistent, matchups, lines, retreat/plunder, scaling). The AI starts first. | docs/rival_crews_plan.md. | — |
| Bounties | **Bounties + wanted posters**: beating rival crews (and other big fights) raises the captain's bounty, posters show it, and rivals' lines react to it. Marine patrols and pursuit wait for 1.20. | Gives the rival fights a growing, visible reward. | — |
| Gear upgrading | Smiths (and treasure merchants) **upgrade blue-and-up weapons**, re-roll or name their trait (todo.md "Gear upgrading and customizing"), paid with treasure and materials. | Builds on 1.18's traits; a rival captain's weapon is the prize. | — |
| Fishing | A **fishing minigame** (rod, cast, bite, reel) at rails, piers and shores, feeding the Fishing life skill, its perks and the fish-tagged ingredients. Lane F's downtime fishing stays as the idle version. | The fishing perks and fish ingredients already exist. | — |

## Carried over from 1.18.4 (Zach, 2026-10-22)
1.18.4 ships with what was built when the batch paused (docs/v1_18_4_plan.md "Paused 2026-10-22"), as an unstable
build **with the perf gate waived** (Zach): Brinehollow 9.66 -> 13.34 ms mean frame at noon (+38%), plaza frame1t +44%,
against the 2026-10-15 baseline; the perf pass above is 1.19's first step. Moved here:
- **Greatsword finish:** Updraft and Gatekeeper, Guardbreaker's and Crescent Gale's polish (the handover in the 1.18.4
  plan has the details and patterns).
- **Black-leg finish:** icons, a katana-pass polish, two new techniques (pitched in one line each first).
- **Corsair and pistol mastered guards** (pictures for Zach's pick first).
- **How 1.19 is worked** (Zach, 2026-10-22, to save usage): one feature at a time in the main session, no subagents
  or parallel feature agents unless Zach asks; atomic tests while building, the suites once at the end.

## The web roadmap timeline (Zach, 2026-10-19)
Replace `web/site/roadmap/` with an **interactive scrolling timeline**: every version Driftwake has shipped and every
one planned, as **floating, clickable cards** strung along a timeline line.
- **The timeline:** one long track you scroll along, from the first build to 2.0. Shipped versions on one side of a
  "you are here" marker (the latest release), planned ones past it, looking unfinished (dimmer, dashed, "planned").
  Cards bob gently and lift on hover; scrolling moves through the versions smoothly (wheel and drag on desktop, swipe
  on phones, arrow keys).
- **The cards:** version number, name ("Timber and Tide"), date, a one-line headline and a small screenshot. A click
  opens the card into a detail panel: everything that version added, a screenshot or clip, and links to its news post
  and GitHub release. Planned cards open to what's planned and its status.
- **Content: everything built so far.** Every version from the first builds to 1.18 filled in from the releases page,
  the GitHub release notes, the news posts and `docs/dev_notes.md`; then 1.19 to 1.22 and the road to 2.0 from
  `docs/roadmap_v2.md`. Written with **Driftwake's own names** (docs/originality_plan.md): this is new content, so it
  never needs the 1.20 rewrite.
- **Built like the rest of the site:** static HTML, CSS and plain JS, the site's `style.css`, pixel fonts and PS1 look,
  no framework or build step. The versions live in **one data file** (`web/site/roadmap/roadmap.json`), so each
  release updates the roadmap by adding or editing one entry. Works at phone width (the track turns vertical), with
  keyboard focus on the cards and `prefers-reduced-motion` stopping the floating.
- **Keeping it current:** each release's checklist (`docs/release_*.md`) gains a step: move "you are here", fill in the
  version's card.
- **When:** it touches only `web/site/`, so it can be built alongside any feature batch (batch rule 3).

### Open / deferred (grill before the batch)
- How cutscenes are skipped and shared in co-op, and the rivals' first crew roster and look: at the rival crews grill.
- How a bounty is calculated, and what it changes (prices, who attacks you): at the bounty grill.
- Gear-upgrade costs, caps and how renaming shows in co-op: in the economy's numbers, tuned in play.
- **The intro sequence is redesigned in 1.19** (Zach, 2026-10-19), on the cutscene system the rival crews need: it
  sets up the world (the Marines, rival crews, the sea's great powers, the First Sea's end) and the captain's goal
  and motivation. Grill it with the rest of 1.19.
- **Fighting in the water** (Zach, 2026-10-19): swimmers get an attack (a knife stab, a short harpoon or similar,
  plus diving moves), so a captain can fight back against sharks and morays (a shark's break-off at half health
  comes sooner) and fight in the sea at all. Built with 1.19's captain-style AI so the **rivals and the Admiralty can
  fight underwater too** (chasing a captain who dives, duels in the shallows). It's the root of the Seafarer tree's
  "fighting underwater" (docs/devil_fruits_plan.md). Today a swimmer sheathes their weapon (swim_state.gd) and sea
  threats can only be hit from the deck or the shore.
- **The weapons' enemy pass** (Zach, 2026-10-21; moved out of 1.18.3): grunt roles for the kinds built in 1.18.3
  (spearman, hammer brute, twin-axe berserker, greatsword, black-leg fighter), each a cut-down moveset you learn to
  read, dropping its weapon. Built alongside 1.19's captain-style AI, so the Admiralty and rival crews can field them
  too (docs/weapons_plan.md).

- **Two- and three-sword style for the katana** (Zach, 2026-10-21): a late katana passive lets the off hand carry a
  second katana (two-sword style becomes the katana's default pattern once owned); a very late passive adds a third
  slot only for three-sword style (the third blade held in the mouth). Three-sword style is **not** a new default
  pattern: you fight two-sword until you toggle it on; while on it drains energy, buffs you slightly and swaps in a
  few move variants, and a few katana skills need it on to use. Design it with the katana's mastered guard (1.18.4)
  and preview the numbers first (gates, drain, buff, which skills need it). New tech: a mouth attach point, its guard
  and carry, the variants' poses, the toggle synced in co-op.

## Perf session before 1.19 (Zach, 2026-10-20)
After 1.18.1 ships, before the 1.19 batch, in order, each with a before/after bench by the lead:
1. **Refresh the bench** (a tooling window, no agents running): new stops (Brinehollow's terrace and farmland, the
   capital's plaza and market street, a chain island village, at sea and in a storm, a crowded fight), CROWD measured,
   no screenshot in the first sample, hitch counts; re-baseline on the min-spec PC.
2. **Threaded rendering** (rendering/driver/threads/thread_model): move the render CPU (the bench's "draw", ~35% of
   the frame) off the main thread; check stability (co-op, island builds, the held map's viewport).
3. **Occlusion culling in towns** (occluders from the kit's buildings, the capital first) + **a shadow-caster audit**
   (small props off the sun's shadow pass: 613 of 1,556 draws; shadow distance/cascades).
4. **Far actors fully off** past a range (processing and bodies off, not only asleep: the "far" ablation's ~1.2 ms).
5. **The long tail** (quick GDScript wins found in the v1181_before probe): sky_birds.gd 0.38 ms, sea_spray.gd 0.29 ms,
   dev_capture.gd 0.12 ms/tick (make sure it does nothing in release builds), and whatever else the refreshed probe
   shows at 0.1-0.4 ms for little visible effect.
Bar: no visible loss of detail; GPU has headroom (1.45 ms), the frame is CPU-bound. **Not now** (Zach, 2026-10-20): a
   GDExtension; the animator + skinning is only ~2 ms of a ~20 ms frame, and C++ would slow development (toolchain, the
   web build, native crashes). Revisit only if one pure-maths kernel dominates after the session. Later, if still needed: central
update managers, and the hottest per-frame code (animator, spring chains, wave sampling) as a GDExtension.
**Ships as 1.18.2** (Zach, 2026-10-20): a simple, short release: no blog/news post; a brief entry in the release
notes and the README history; on the roadmap timeline, fold it into the 1.18.1 card (one card for 1.18.1-1.18.2, an
"added" line for the performance work) rather than a card of its own; version 1.18.2, what's new one line; tag and push.
