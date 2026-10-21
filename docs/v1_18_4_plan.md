# The combat and progression batch before 1.19 (Zach, 2026-10-21)

## What it is
One batch between 1.18.3 and 1.19 (1.19 starts once this is done; **assumed** to ship as 1.18.4). Six things:
the skill points and skill menu reworked (one shared Combat pool, one Adventure pool, everything bought, a lighter menu);
the five new weapon kinds finished (icons, a polish pass on their techniques, two new techniques each); the drawn
flipbook awakening for every weapon that lacks one; a mastered guard per weapon; the air step redone as One Piece's
air walk; a tumble after a long freefall, with Acrobatics nodes to recover in mid-air; the fists redone as
Garp/Koby-style punching.

## Decided (2026-10-21)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Combat points | **One shared Combat pool, earned from Captain levels.** Spent on any weapon tree, so a point goes to the katana *or* the pistol. Mastery still rises only by using a weapon and **gates** what you can buy in its tree (a node needs its mastery level). **Replaces** the 1.18.2 redesign's per-weapon mastery points and its "Captain levels give no points" | Zach: too many point types; spending should be a choice between weapons | Preview (below) |
| Nothing free | **Everything in a weapon tree costs Combat points**: moves, techniques, mechanics, passives, the element, the ultimate and the stat steps. Mastery level only unlocks the right to buy. **Replaces** "big nodes come by themselves" (progression_plan.md, Redesign) | Zach: no automatically levelling skills | Preview |
| Adventure points | **One shared Adventure pool**, a point for each level any Adventure tree gains (sailing, swimming, cooking, fishing, acrobatics, defense, stealth, tinkering); spent in any Adventure tree, each node gated by its own tree's level, all of it bought like the weapon trees | Two point types in all | Preview |
| Preview first | The progression agent's **first piece is a number table** (points per Captain level against the level curve, each weapon tree's node costs and mastery gates, what a level-20 and a level-40 captain can afford, the Adventure pool's flow) for Zach's OK **before any code** (CLAUDE.md "Feel systems get a preview first") | The 1.18 rework built from picked options felt wrong | — |
| Old saves | **assumed:** every point spent under the old scheme refunded into the new pools once (owned nodes kept only if the migration can price them; otherwise refunded) | No progress lost | Preview |
| Notifications | Fix the stale prompts (a "+N points (K)" or "points to spend" line when nothing is left to spend): one short line **only when the pool really has unspent points**; none for a tree's mastery level-up alone | Zach's report | — |
| Skill menu | **Locked trees hidden entirely** (not in the tab strip or the tree list), so the unlocked weapons have room. Trees show **icons and names only**; descriptions, numbers, costs and gates go in **one detail panel on select**, and more in **hover tooltips/modals** wherever the info suits it | Zach: each page has too much to take in | Play |
| New weapons' finish | Polearm, hammer, twin axes, greatsword, black-leg: **icons** for every technique; a **katana-pass polish** of their existing techniques (animation, timing, hit reliability, effects); **two new techniques each**, each pitched to Zach in one line before it's built | Zach: polish + new abilities | Play |
| Awakenings | The drawn flipbook awakening (the cutlass's water / katana's petals standard: plain drawn crescents on the swing path, the awakened element, the blade aura) for **every weapon without one**, one at a time: axe (resume its pass, docs/axe_polish_plan.md), daggers, dual swords, twin daggers, corsair, pistol, fists, then the five new kinds | Zach: every weapon | After the axe |
| Mastered guard | Per weapon, a **big node at about mastery 15** that unlocks a second guard: its own stance, idle, carry, moves flowing out of it. Once owned, **toggle between the two guards** (no lockouts). Emperor's Bearing and Nonchalance stay as calm poses on top. The guards shown as posebench pictures for Zach's OK before they're wired | Zach: "whole new guard" | Play |
| Air step | Geppo's double jump redone as **One Piece's air walk**: an upright, slightly exaggerated step (knee high, foot stamped down on the air, a small puff under it), **no flip**; Sky Walk's chained steps the same | Zach's reference | Play |
| Freefall tumble | **~3.5 s of freefall** (no ability, attack or air step in that time) and the body goes limp and tumbles (Ragdoll). An air step, ability or attack resets the timer; **an air step pulls you out** of the tumble. Landing in it: the usual get-up, the usual fall damage | Zach's pick | Tune in play |
| Air recovery | Acrobatics **Breakfall at ~12**: press jump while knocked airborne by a heavy blow to right yourself (ends the knockback ragdoll/tumble). Acrobatics **Skyward Dash at ~18**: after a recovery, an air dash plus extra air steps, enough to get back to the deck after being hit off the ship. Bought with Adventure points. (The old "Breakfall" step gets another name) | Zach's idea: a late-game captain knocked off their ship recovers and dashes back | Play |
| Fists | **Garp/Koby-style punching**: jabs, hooks, uppercuts, a huge overhand haymaker for the heavy, Garp-style big-fist techniques. The wrestling moves go (Suplex, Giant Swing), **keeping one throw (Shoulder Throw) as a counter**. The Grapple branch becomes a power-punch branch | Zach: the grappling/jiu-jitsu look is sloppy | Play |
| Order | **Parallel by area**, then the weapons in series: (1) progression and menus (preview first); (2) the air step, freefall tumble and air recovery moves; (3) the fist rework. Once those land: the new weapons' finish, then awakenings and mastered guards weapon by weapon | Separate areas in parallel; the weapon passes share files | — |
| Co-op | Standing rule: guests see and do all of it (the tumble and air recovery on puppets, guards synced, points per captain) | CLAUDE.md | — |

### Open / deferred
- The Captain-level point rate, node prices and mastery gates: **in the preview**, then tuned in play.
- **assumed:** the fists' power-punch branch and new big-fist techniques are pitched to Zach as one-liners before they're built (like the new weapons' techniques).
- **assumed:** Breakfall and Skyward Dash count for the air-step agent; their tree entries go through the progression agent's data.
- **assumed:** the mastered guard is the same node pattern on every weapon; the first one (on the axe, with its awakening) is checked by Zach before the rest.
- 1.19 (docs/v1_19_plan.md) starts after this batch.
