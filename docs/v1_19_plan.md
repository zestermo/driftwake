# v1.19 (Zach, 2026-10-19)

## What it is
**Marines and rival crews** (Zach, 2026-10-19, revised): rival pirate crews (docs/rival_crews_plan.md) and the
Marines with bounties (roadmap phase 6), plus a new interactive timeline roadmap on the website (below). A tooling window comes first. The perf pass and fishing moved into 1.18,
and gear upgrading waits for a later release. The table below is the earlier draft, kept as a record.

## Decided (2026-10-19)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Order | (1) A tooling window: the crew_lib deps-file race, a lint for autoload names in static funcs (todo.md), no agents running. (2) **A perf pass**: Brinehollow back toward the 9.4 ms target with the market's CROWD back on, then the perf gate's baseline. (3) The features. | The perf gate has failed since v1.17 (13.4 ms), and 1.18 adds more. Batch rule 2. | — |
| Headline | **Rival crews** in three pieces: the cutscene system, AI that fights like a captain (the player's own states and skills), the crews themselves (persistent, matchups, lines, retreat/plunder, scaling). The AI starts first. | docs/rival_crews_plan.md. | — |
| Bounties | **Bounties + wanted posters**: beating rival crews (and other big fights) raises the captain's bounty, posters show it, and rivals' lines react to it. Marine patrols and pursuit wait for 1.20. | Gives the rival fights a growing, visible reward. | — |
| Gear upgrading | Smiths (and treasure merchants) **upgrade blue-and-up weapons**, re-roll or name their trait (todo.md "Gear upgrading and customizing"), paid with treasure and materials. | Builds on 1.18's traits; a rival captain's weapon is the prize. | — |
| Fishing | A **fishing minigame** (rod, cast, bite, reel) at rails, piers and shores, feeding the Fishing life skill, its perks and the fish-tagged ingredients. Lane F's downtime fishing stays as the idle version. | The fishing perks and fish ingredients already exist. | — |

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
