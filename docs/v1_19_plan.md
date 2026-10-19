# v1.19 (Zach, 2026-10-19)

## What it is
**Marines and rival crews** (Zach, 2026-10-19, revised): rival pirate crews (docs/rival_crews_plan.md) and the
Marines with bounties (roadmap phase 6). A tooling window comes first. The perf pass and fishing moved into 1.18,
and gear upgrading waits for a later release. The table below is the earlier draft, kept as a record.

## Decided (2026-10-19)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Order | (1) A tooling window: the crew_lib deps-file race, a lint for autoload names in static funcs (todo.md), no agents running. (2) **A perf pass**: Brinehollow back toward the 9.4 ms target with the market's CROWD back on, then the perf gate's baseline. (3) The features. | The perf gate has failed since v1.17 (13.4 ms), and 1.18 adds more. Batch rule 2. | — |
| Headline | **Rival crews** in three pieces: the cutscene system, AI that fights like a captain (the player's own states and skills), the crews themselves (persistent, matchups, lines, retreat/plunder, scaling). The AI starts first. | docs/rival_crews_plan.md. | — |
| Bounties | **Bounties + wanted posters**: beating rival crews (and other big fights) raises the captain's bounty, posters show it, and rivals' lines react to it. Marine patrols and pursuit wait for 1.20. | Gives the rival fights a growing, visible reward. | — |
| Gear upgrading | Smiths (and treasure merchants) **upgrade blue-and-up weapons**, re-roll or name their trait (todo.md "Gear upgrading and customizing"), paid with treasure and materials. | Builds on 1.18's traits; a rival captain's weapon is the prize. | — |
| Fishing | A **fishing minigame** (rod, cast, bite, reel) at rails, piers and shores, feeding the Fishing life skill, its perks and the fish-tagged ingredients. Lane F's downtime fishing stays as the idle version. | The fishing perks and fish ingredients already exist. | — |

### Open / deferred (grill before the batch)
- How cutscenes are skipped and shared in co-op, and the rivals' first crew roster and look: at the rival crews grill.
- How a bounty is calculated, and what it changes (prices, who attacks you): at the bounty grill.
- Gear-upgrade costs, caps and how renaming shows in co-op: in the economy's numbers, tuned in play.
