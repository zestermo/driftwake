# 1.28 and on: the weekend build (gadgets, life systems, weapons, islands, the sea)

## What it is
A large batch built over the weekend of 2026-10-31 while Zach can't playtest: Usopp/Franky-style gadgets built at a
workbench, deeper reading, cooking and fishing, three new weapon kinds, two new island themes (volcanic, coral atoll),
sea stops between islands (a floating restaurant, a merchant ship, a warlord's flagship, an Admiralty lieutenant's
warship), three new leviathans, dev tools and a polish pass. The fruits are **not** polished here: they get tuned as
they're played (Zach, 2026-10-31). Sky islands and the cloud sea stay after 2.0 (roadmap, 2026-10-15, re-confirmed).
Everything uses Driftwake's own names (docs/originality_plan.md): the inspirations are One Piece's, the content is ours.

## Decided (2026-10-31)

### How the weekend runs
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Run mode | Mix: this session leads and builds tools and polish itself; **at most 2 driftwake-feature agents at a time** besides it (Zach) | Use the weekend's usage without a pile-up | Zach's back |
| Order | Wave 0 (quiet window, this session): test kit helpers, the debug warp/spawn lists, fix t/island/beast_moves. Then pairs, each with this session's own piece: (1) gadgets core + volcanic isle / ocean visuals; (2) rapier + sea stops & big ships / enemy tells; (3) coral atoll + books & cooking / QoL; (4) fighting staff + leviathans / hit feel & audio mix; (5) chain sickle + fishing / review gallery pages | Tools first; each pair in separate areas; leviathans after the harpoon cannon (gadgets) and the ocean pass | A pair runs long |
| Releasing | After waves pass prepush: push main, tag an **unstable** pre-release (tools/release/UNSTABLE) with its releases-page section and news entry | Zach plays them later; unstable stays off Download/home | Zach plays one |
| Usage | Check weekly usage between pieces; stop cleanly near 85% (memory: usage stop point) | Unattended | - |
| Preview rule | Cost and curve tables (gadgets, parts, blueprints, recipes, books, fish) go in a preview page Zach can comment on; agents build to them; all numbers in one data file per system | The feel-systems rule, but Zach is away | Zach's comments |

### Gadgets and tinkering
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Carrying | A **gadget belt**: 3 slots of their own, G fires the selected one, a key cycles; whatever weapon is held; drawn on the belt (crewmates see it) | Always at hand; doesn't fight skills for the bar | Play |
| Kinds | All four: **combat tricks** (smoke and flash pellets, tar/pepper bombs, exploding stars, decoy, caltrops), **traversal** (grappling hook, spring boots, pocket glider, climbing spike), **utility** (spyglass marking, diving helmet, auto-reel, lockpick, lantern-bomb), **ship gadgets** (burst launcher, paddle boost, harpoon cannon, smoke screen) | Zach | - |
| Making | **Blueprints + parts** at a workbench (aboard, at camps, the forge town). Blueprints from books, the forge town's master tinkerer, loot and the merchant ship; parts from salvage, ore, beast and leviathan parts. Tiers Mk I-III, each visibly different and stronger; tiers gated by Tinkering level | The inventor fantasy and an item economy | Play |
| Limits | **Charges + a short cooldown**; charges refill at a workbench or camp from cheap parts; traversal gadgets cooldown only | Usopp's ammo pouch, no grind | Play |
| Downtime tinker | Kept (the tuned-kit buff), alongside the workbench (**assumed**: it still feeds Tinkering XP) | Nothing to remove | - |
| Co-op (**assumed**) | Gadgets are each captain's own (synced like weapons); ship gadgets are fitted to the ship, fired from the helm; their effects on the world run on the host (Net.fx / host-arbitrated) | CLAUDE.md co-op rules | - |

### Reading, cooking, fishing
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Reading | **Collectible books** (items: loot, shops, libraries, the forge town). Each reading teaches one thing: a gadget blueprint, a recipe, a technique manual (a small permanent perk), a sea chart (marks a sea stop or leviathan), or a lore set with a set reward. A **bookshelf aboard** shows the collection | Reading becomes a reason to explore | Play |
| Cooking | **Island dishes** (each theme's ingredients make its own dishes with stronger themed buffs), **crew feasts** (a big meal buffs the whole crew in co-op), a **cooking timing game** (stir, flip, plate) whose quality sets the buff | Zach's picks; experiment-discovery not picked | Play |
| Fishing | **Fish per theme and the open sea + one legendary per theme** with its own fight (the atoll the best spot); a **fish journal** (records, where caught, a page reward); **spearfishing** while diving; **fishing contests** in towns (crewmates compete) | All four picked | Play |

### Weapons (three, all to the full 1.26 sheet: docs/weapons_126.md)
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Depth | Moveset, a tree with two ultimates, crew technique(s), three alternates (aerial 8, sprint 14, right-click 20), an aerial heavy, a launcher, bridges, its FX.TREE_FX colours, rack (Shift+F10) and loot. Drawn awakening later, in its own series | Same as the other 17 | - |
| Rapier | A fencing duelist (thrusts, lunges, parry-ripostes); **quicksilver mirror**: silver afterimages, mirror flashes, phantom double thrusts | Zach | - |
| Fighting staff | Spinning sweeps, pole-vault, juggles (blunt and acrobatic, not the polearm's thrusts); **leaves and wind**: green and gold leaves whirled along each spin (kept apart from the greatsword's air crescents and pressure) | Zach | - |
| Chain sickle | A sickle in hand + a weighted chain: close cuts and long chain sweeps, wraps that pull or bind; **ghostfire**: sickly green spectral fire along the links, souls tugged on the pull | Two ranges in one weapon | - |

### Islands (two themes, both to the full standard of snow / desert / forest)
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Depth | Terrain, style table, a town with harbour and shops, places, encounters, dense life, 2-3 beasts and a boss with its own arena, music and ambience, chain weights; the island subtype standard (big pools, nothing guaranteed, fights in the terrain) | The standard | - |
| Volcanic isle | A **forge town** (lava-fed forges, smiths, the master tinkerer who teaches blueprints, the best parts); **rumbles and bursts**: every few minutes the ground shakes and telegraphed lava bombs fall on part of the island, lava flows are fixed hazards; boss: a **magma salamander** in the caldera that swims through lava, its fight erupting in phases | Ties into tinkering | Play |
| Coral atoll | **A ring of islets and sandbars round a calm lagoon**: wade and swim between them, dive the reef for pearls, wrecks and treasure, the chain's best fishing, a **stilt town** over the water; boss: a **giant hermit crab** with a breakable shell | Pairs with fishing, spearfishing, the ocean pass | Play |

### The sea
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Stops | All four: **floating restaurant**, **wandering merchant ship**, **warlord pirate's flagship**, **Admiralty lieutenant's warship** | Zach | - |
| Appearance | Rolled per sea leg: rare early, more often later in the chain, never guaranteed; some rumoured in taverns or marked by a sea chart from a book | The subtype standard | Play |
| Big named ships | **Cannons, board, duel**: a broadside with a much bigger ship, board it, fight across its decks, the named captain a boss duel with a cutscene intro; sinking it from afar costs the loot; fleeing is allowed. The lieutenant comes more often with a higher bounty | Builds on fleets, boarding, rival duels, cutscenes | Play |
| Restaurant | **A sea hub**: the head chef teaches recipes and sells island dishes, a cook-off (the timing game) for prizes, rest and save, rumours of other stops; sometimes under pirate attack on arrival, and defending it earns the chef's favour | Zach | - |
| Merchant (**assumed**) | Rare gear, blueprints, parts, exotic ingredients and books; stock rerolled per visit | - | - |
| Leviathans | **Colossal squid** (tentacles grab the rails and drag the ship; cut them on deck while shelling the body), **storm eel** (comes with storms, lightning to the mast, strikes from below, tracked by its glow), **abyssal angler** (night, deep water, a lure light, jaws up under the ship). Not the island turtle | Zach | - |
| Leviathan fights | **Ship + deck, harpoon finish**: cannons and the harpoon cannon wear it down, its parts reach the deck to be fought by hand, a harpooned leviathan can be reeled close for a finisher; rare parts for gadgets and trophies | Ties gadgets, ship and combat together | Play |

### Dev tools and polish
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Dev tools | **F4 warp and spawn lists** (any island, the stronghold, the capital, a sea stop; any beast, leviathan, ship or stop; any gadget or book), **test kit helpers** (TK.calm(foe), TK.cast_wait, a lint for unsafe knockdown checks), **review gallery pages** (each pair's renders published as one artifact page for Zach's comments). Not playtest auto-capture | Zach | - |
| Polish | **Ocean visuals** (shoreline foam, the ship's wake, sun and moon glint path, whitecaps in storms, turquoise shallows: WAVES and ocean.gdshader together), **enemy tells everywhere** (the grunts' red wind-up glint on bosses, beasts, leviathans; ground telegraphs for area attacks), **quality of life** (loadout presets, gear compare tooltip, quick-stack to storage, placeable map marker), **hit feel + audio mix** (one impact recipe across weapon techniques, hit-stop on heavies, music ducking under combat, beast-form footsteps) | Zach | - |

### Open / deferred
- Sky islands and the cloud sea: after 2.0 (unchanged).
- The island turtle, playtest auto-capture, cooking by experiment: not picked; later if wanted.
- The new weapons' drawn awakenings: their own series later.
- Exact names (weapons' skills, stops, captains, leviathans, dishes): the agents name them in Driftwake's voice (**assumed**).
- All numbers: first guesses in data files, tuned in play (**assumed**).
