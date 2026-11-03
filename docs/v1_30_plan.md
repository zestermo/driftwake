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
| Enemy toughness | **Pirate crews and marines +30% base health** for everyone; **in co-op every enemy does +10% damage per extra captain** (+30% at four), on top of the health scaling | Zach: not only more health, slightly more damage too | Play |
| Enemy health bars | **A small PS1-style bar and a red marker over a hostile once it's engaged** (aggro'd, hit, or within ~15 m and after you), fading ~5 s out of combat; bosses keep the big top bar; townsfolk never get one, so hostiles stand out in a crowd | Zach: playing round enemies' health, and spotting them in towns | Play |
| Stronghold polish | The side areas reachable; **an objective indicator** for what to do in each district (with the guidance work); a polish pass on the models, layout and structure (renders) | Playtest | Renders |
| The Scouring | **A real escape set piece**: a dark sky, a ring of warships firing visible broadsides (big splashes, fire), shells tearing up the fortress, sirens and drums, a clear "Escape the ring" objective and the gap; **it ends once you're out of the ring** (the ring followed the ship long after in the playtest: a bug) | Visually underwhelming and not threatening | Play |
| The Scouring's look (2026-11-03) | **Huge explosions and fireballs everywhere round the captain** (buildings, walls, roofs), heavy shake and bright orange flashes; **fires many times a captain's height** burn at some shell landings; **the sky goes dark grey with smoke, like the desert sandstorm**, even at noon, so fire and glow pop | Zach | Renders, play |
| Movement | **Slope slide free for everyone** (jump off a mast, slide down a hill); **wall jump an Acrobatics skill** (chained jumps and more bounce as upgrades); more bounce on wall/surface jumps and the air walk; **a livelier mid-air / falling idle** | Zach | Play |
| Skill map | **Passives and stat nodes look clearly different from abilities**; every tree has icons and is **zoomable and pannable**, so trees don't fight for screen space; **fix nodes being skippable** (a bug: a node bought without its parent) | Zach, from the playtest | Mock |
| Progression pacing | **Preview first (numbers for Zach's OK):** Edy comes too often and gives too many points; the adventure trees earn too little xp (only Acrobatics levelled); **the Acrobatics tree remapped** (wall jump and slide upgrades in it); **strike-speed upgrades** in the weapon trees (the katana most). Weapon mastery felt good: keep it | Zach's preview rule for progression | After the preview |

### Open / deferred
- The brig and galleon and the creatures keep their own grill (docs/v1_29_plan.md said "1.30's grill").
- The order inside 1.30 is the lead's: the bugs (A, B) first, so the next playtest runs on a fixed game.
- Rivals at sea and boarding: after 1.30.
- The fruit pool's other sources: after the fruit tree pass.

## Build order (lead, 2026-11-03; two agents at a time)
Previews and mocks approved by Zach 2026-11-03 (docs/v1_30_previews.md, the "Driftwake 1.30 UI mocks" canvas).
1. Running: **sea fixes** (enemy_ship, admiralty, rival_watch) and **land fixes** (vault + fruit, rack and drills,
   Morrow's rush, scaling and toughness, log errors).
2. **Guidance and the Captain's Log**, when the first slot frees: the standing chain goal, the capital lines and the
   stronghold as journal quests, the Captain's Log screen (next / quests / news / done, numbered map marks, owner chips),
   pinned news, and enemy health bars with markers. Needs scripts/quests/ free (the land agent's).
3. **Skill maps and pacing**, after the land fixes land: every tree one branching map with zoom and pan, node shapes,
   the parent-check fix; Edy sources, the adventure curve and xp, Quick Hands strike speed; the Acrobatics map with the
   slope slide (free), wall jump family, air dash family and the livelier fall pose.
4. Then: collision holes + Unstuck, boss phase resets + clearing moves, the stronghold polish and the Scouring set
   piece, the rival ship arrival, the Redtide mountain; the brig, galleon and creatures after their own grill.
