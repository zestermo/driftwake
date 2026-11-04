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

## Decided (2026-11-03, round 3): the stronghold run reworked
Zach, after the playtest: "it was a large fortress where we fought maybe 40 people over ~30 minutes"; enemies should
swarm, the crew should need gadgets, strategy and stealth to reach the objectives, then fight through large crowds in
fast boss fights; the enemies felt like sponges, only a few groups of 5 at a time, the bosses not memorable.

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Run shape | **A raid in acts**: land and breach the gate; the two seals in either order (each its own set piece and boss); the keep and Vane; the vault; the Scouring escape. Cleared areas stay cleared | Zach | Play |
| Enemies | **Garrison + alarm**: placed garrisons (sentries, posts, barracks) that react; a raised alarm brings visible reinforcements through doors, from barracks and by boat; a cleared district stays clear (no 90 s respawns) | Zach | Play |
| Crowd size | **20-30 fighting at once**, ~150-200 over the run; most are a cheap **fodder tier** (rig LOD, simple AI, shared materials), a few elites and officers mixed in; inside the perf gate | Zach | Bench at prepush |
| Toughness | **Fodder dies in 2-4 hits** (no +30%); the +30% and the co-op scaling stay on elites, officers and bosses | "Enemies felt like sponges" | Play |
| Stealth | **An infiltration before the alarm**: sneak past sentries (the crouch stealth system), silent takedowns from behind, cut or guard alarm bells to slow reinforcements | Zach | Play |
| Gadgets | **Carried gadgets** the crew brings: smoke bombs, a grapple hook, explosive charges, flash powder (bought or crafted; a small belt) | Zach | Play |
| Co-op roles | **Objectives that split the crew**: hold a gate while another opens it, a sniper perch covering the others, two levers at once | Zach | Play |
| Bosses | **Set-piece arenas**: each officer owns a district with a gimmick (Kesh in a pouring foundry, Marrow in a prison riot, Vane on the keep's roof as the Scouring starts), an intro name card, mid-fight events, faster aggressive movesets with big readable attacks | "Not memorable or interesting" | Play |
| Downed in a boss fight | **Revive, else rejoin**: the crew revives as usual; bled out, a captain respawns at a checkpoint just outside the arena and walks back in; only a full crew wipe resets the boss. (The playtest's stuck death is a bug, being fixed) | Zach | Play |

## Decided (2026-11-03, round 4): overkill launches and wall splats
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Overkill launch | **A big hit that overkills a foe by a margin** (assumed: the overkill is >= 50% of its max health, or the hit is a heavy/technique/ultimate finisher) **throws it flat**: back for a forward blow, up for a launcher | Zach | Play |
| Wall splat | **Within ~6-9 m (20-30 ft)** of a wall or ceiling the body flies flat into it, **leaves an impact mark** (cracks, dust, blood where fitting), sticks ~1 s, then ragdolls to the floor. **Nothing near:** it drops and skids a few feet, or falls back from a launch and lands with a small impact mark | Zach | Play |
| On captains | **Enemy moves can do it to a captain**: only a real strong move that breaks poise and does over a set damage (assumed: >= 30% of max health in one hit). Captains can do it to each other in duels and to AI captains. **Dazed ~1 s**, and it takes slightly longer to get up than a normal knockdown | Zach | Play |
| Blood | **A blood splatter** from the hit and on the surface it hits, where fitting (none for spirits, bloodless kinds, or with the gore setting off) | Zach | Play |

## Decided (2026-11-03, round 5): the level gap
Gap = the foe's level minus the captain's (per captain). Multipliers on top of Levels' curves; 0 = today's balance.

| Gap | -6 | -4 | -2 | 0 | +2 | +3 | +5 |
|---|---|---|---|---|---|---|---|
| Captain's damage to it (1 - 0.06g, 0.7-1.5) | 1.36 | 1.24 | 1.12 | 1 | 0.88 | 0.82 | 0.70 |
| Its damage to the captain (1 + 0.12g, 0.4-2.0) | 0.40 | 0.52 | 0.76 | 1 | 1.24 | 1.36 | 1.60 |
| Its poise (1 + 0.12g, 0.3-1.8) | 0.30 | 0.52 | 0.76 | 1 | 1.24 | 1.36 | 1.60 |
| Overkill needed to splat (1 + 0.15g, 0.1-2.0) | 0.1 | 0.4 | 0.7 | 1 | 1.3 | 1.45 | 1.75 |
| Level badge | grey (<= -5) | white | white | white | white | red (>= +3) | red |

- Fodder marines: normal marine stats at **the fortress's level - 4** (not a fixed 30 HP).
- Health bars: 22x2 px (was 28x4) on the 800x450 canvas, a small level number in a box to the bar's left.
- Approved by Zach 2026-11-03.
- **Splat power by overkill** (Zach, same day): the flight's speed and reach grow with how far past the splat line the
  blow went. Just over: a mellow throw of a few feet (~1-2 m, no wall unless one is right there). Far over: shot fast
  (up to ~25 m/s) to the full 8 m reach. The same for captains. **Bodies in the flight's path are knocked down or
  aside** (a knockdown and small damage to foes; captains in a duel too), host-decided.

## Decided (2026-11-03, round 6): enemy personalities, verticality, riflemen
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Personalities | **Four, rolled per foe** (grunts, marines, fodder, AI captains/officers): **Berserker** (crazy aggression: closes at once, long combos, chases), **Opportunist** (waits for a couple of others to engage first, then strikes an occupied or staggered captain), **Duelist** (favours parrying: reads swings, parries and ripostes), **Bulwark** (blocks a lot, pushes forward behind the guard, punishes whiffs). Readable tells (stance, a short bark) so a captain can spot which is which. Weights per kind (assumed: fodder mostly berserker/opportunist; officers and captains any) | Zach: more variance | Play |
| Verticality | **Strong foes (elites, officers, AI captains, the stronghold's Admiralty) use jumping attacks now and then**: a leaping overhead, a jump-in slash from range, a dive off a ledge or stair onto a captain below. Cooldowns so it's occasional | Zach | Play |
| Riflemen | **More moves, less predictable**: reposition between shots (side-steps, falling back to cover or high ground), a quick hip shot at close range, a bayonet/stock strike when rushed, a kneeling aimed shot with a visible tell, a dodge roll, staggered timings so a group doesn't fire in rhythm | "Too predictable" | Play |

### Open / deferred
- The brig and galleon and the creatures keep their own grill (docs/v1_29_plan.md said "1.30's grill").
- The order inside 1.30 is the lead's: the bugs (A, B) first, so the next playtest runs on a fixed game.
- Rivals at sea and boarding: after 1.30.
- The fruit pool's other sources: after the fruit tree pass.

## Decided (2026-11-03, round 7): the fortress's look
Zach, after the stronghold renders (blockout-like up close: a plain foundry, an empty cell block, sparse props):
"I like it as a marineford/enies lobby type of thing".

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Reference | **Marineford + Enies Lobby**: a white-and-blue naval citadel. Huge pale stone walls with dark-blue trim and gold accents, the Admiralty's gull crest, a towering keep that reads from the sea like the Tower of Justice, a giant main gate, wide plazas and long stairs, colonnades and arches, bridges between districts, rows of cannon batteries on the walls, flags and banners everywhere, the bay ringed by docked warships | Zach | Renders |
| Scale | Monumental: walls and gates many captains tall, plazas big enough for the 20-30 crowd; side areas and wall walks for stealth routes | Round 3 crowds + stealth | Play |
| Districts keep their role | Foundry (Kesh), prison (Marrow), keep (Vane), batteries, barracks, docks each dressed for what it is, in the same white-blue palette | Each act reads at a glance | Renders |
| Budget | A set piece may spend, but inside the perf gate: MultiMesh repeats, shared PSXMat, visibility ranges | CLAUDE.md | Bench at prepush |
| Scope (Zach, later the same day) | **Keep the current design** (layout, massing, silhouettes): "the design looked cool, it just needs much much more detail and more models and more lived in, alive, rather than all just box shapes". The work is architectural detail on the existing shapes, many more props, and lived-in dressing, in the Marineford / Enies Lobby palette | Zach | Renders |

## Decided (2026-11-04, round 8): the brig, the galleon and the creatures
Picks the open rows of docs/v1_29_plan.md ("The brig and galleon (1.30)", "Creatures (1.30)").

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Creature themes | **Fog + forest**: the two thinnest (both lean on the shared wolf, boar and fox; fog adds only wisps, forest only deer). 2-3 new hostile creatures each | Zach | Play |
| Fog creatures | **Eerie and ghostly**: e.g. a pale long-limbed stalker that fades in and out of the mist, drowned bog hounds, giant moths drawn to your lantern. **Plus graveyards and zombies**: fog already has one graveyard per island (FogTheme.plan_places), the drowned and ghosts; grow it into bigger graveyards with crypts and mausoleums, and **zombies that claw up out of the graves**, distinct from the drowned | Zach | Renders, play |
| Forest creatures | **Fairy-tale forest**: e.g. mushroom crawlers, thorn-backed boars, owl-beasts that hunt at night | Zach | Renders, play |
| Brig and galleon | **Yours to buy** at the canal city's shipyard (the galleon later in the chain), each with its own layout on HullLayout, gun deck(s) and cabins. Enemy fleets keep today's hulls | Zach | After 1.30: enemy versions and boarding them |
| Solo crewing | **The guns fire on their own**: no NPC deckhands; the broadside fires from the helm like the sloop's, with more guns. In co-op, captains can still man guns | Zach | Play |
| Size | **Brig 1.5x the sloop** (two masts, one gun deck, a bigger cabin); **galleon 2.2x** (three masts, two gun decks, a high stern castle). Slower to turn, much tougher, fits the harbours | Zach | Play |
| The old ship | **Keep every ship you own, swap at a shipyard.** Paint and figurehead carry over; upgrades are per ship | Zach | Play |
| Numbers | **The agent picks** price, parts, hull, guns, speed, turn and the galleon's chain unlock on the economy's curve; Zach tunes in play (no preview table) | Zach | Play |

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
