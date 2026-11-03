# 1.30: the playtest fixes, guidance, and bigger ships

**What it is.** The four-captain playtest of 1.29 (2026-11-02, docs/playtest_2026_11_02.md) found broken systems
(rivals unseen, ships that can't catch you, marines that let go, the vault, collision, Admiralty lag, the drills) and
a crew that kept asking "what now?". Zach's call: **everything goes into one 1.30**, alongside the brig and galleon
and the thin themes' creatures already planned there (docs/v1_29_plan.md). No 1.29.1.

## Decided (2026-11-03)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Release | **Everything in 1.30**: the playtest's bug fixes (playtest doc, groups A and B), the group C design work below, the brig and galleon, the creatures | Zach | - |
| Guidance | **A standing chain goal plus a journal rework.** When nothing else is tracked, the HUD box always shows the chain's next step ("Sail to Coralhaven: follow the log pose", then the island's warden, its arc, its boss) with the gold marker. The capital's lines (the Queen's forger, the writ) and the stronghold become real journal quests | The objective box was blank for ~2h20m of the playtest; the journal held 4 quests in 3h22m | Play |
| Journal rework | **Mock first, for Zach's OK** (his rule for feel systems). What it has to fix, all four of: **too many places to look** (journal, map, HUD box and toasts each hold part of "what next"), **missable notifications** (lost mid-fight or stacked), **unclear map marks** (what a mark is, whose quest, where next), **co-op confusion** (who took what, who tracks what, what's shared) | Zach, from the playtest | After the mock |
| Rival crews | **A visible ship and a clear arrival**: their ship really sails in and anchors off the harbour, a named banner and a music sting announce the crew, and their captain calls you out by name. Never in the capital or the stronghold (the role check fixed). **Meeting them at sea and boarding stays later** | The meetings happened on land and nobody noticed; the warning promised a ship that never came | After 1.30 |
| Driftfruit | **On, with the vault's fruit only**: `IN_WORLD` on; the stronghold vault gives its legendary fruit (one per save, the pool's rules). The wider pool (chests, merchants, boss hoards, officers) waits for the fruit tree pass | The trees are thin (10-15 nodes against a weapon's ~44) | The tree pass |
| Boss phases | **On each new phase a boss leaps back to the arena's centre** and lands with a shockwave that pushes everyone out (low damage), then a ~1.5 s roar it can't be hurt in, then the new phase's moveset and sequence | Zach: bosses should reset for their new phase | Play |
| Boss space | **A clearing move for every beast boss**: a roar or stomp ring (a big push, low damage), or a leap back to the centre, when captains crowd it for ~4 s or land many hits fast | Captains sat pinned in corners for 2 minutes | Play |
| Redtide arena | **A natural mountain round Morrow's arena**, bigger, so it reads as part of a rock rising from the sea, not a lone arena (Zach's report). Open only on the stair; the island's clearance and no-go radii grow with it | Zach | Renders |
| Boss scaling (assumed, from the trace) | HP 1 + 0.85 x (captains - 1); poise scales; the stronghold bosses scale too | Bosses were easy for four | Play |

### Open / deferred
- The brig and galleon and the creatures keep their own grill (docs/v1_29_plan.md said "1.30's grill").
- The order inside 1.30 is the lead's: the bugs (A, B) first, so the next playtest runs on a fixed game.
- Rivals at sea and boarding: after 1.30.
- The fruit pool's other sources: after the fruit tree pass.
