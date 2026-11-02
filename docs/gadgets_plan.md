# Gadgets and the workbench (1.28): the numbers

The readable copy of `scripts/gadgets/gadget_data.gd` (retune there: every number is in that one file). First guesses,
written 2026-10-31 while Zach is away (the feel-systems rule: numbers before the build). Design decisions:
docs/v1_28_plan.md "Gadgets and tinkering".

## How it works
- **The belt:** 3 slots. **U** fires the selected gadget, **O** cycles (was Shift+U until 2026-11-01: Shift is sprint) (pad: LB+LT fires, the share button
  cycles). Any weapon in hand, on foot, free (idle, moving, jumping, falling). The HUD shows the slots right of the
  skill bar; the pouch on the captain's back shows the belt's best tier to the crew.
- **Charges + cooldown:** a use spends a charge and starts the cooldown (game time). Traversal gadgets, the spyglass
  and the paddle boost have no charges, cooldown only. Charges refill at any workbench or camp for the "refill" parts.
- **Making:** a blueprint is learned (Gadgets.teach, or carried to a workbench: it's studied and used up). At a
  workbench: **build** Mk I, **upgrade** to Mk II and Mk III, each for gold and parts, each tier gated by the
  Tinkering level. Each tier looks different (Mk I plain clay/wood, Mk II brass-banded, Mk III iron and red lacquer)
  and is stronger.
- **Tinkering XP:** downtime tinker stays (10 an interval, the tuned-kit buff); building Mk I gives 60, upgrading to
  Mk II 150, to Mk III 300; a refill 10.
- **Tier gates (Tinkering level):** Mk I 1, Mk II 6, Mk III 12 (the tree goes to 20; level 6 is ~1,300 xp, 12 ~7,200).
- **Workbenches:** aboard the sloop (on deck), at every captain's camp (a field bench by the fire), the forge town's
  (style "forge", placed by the volcanic isle). Ship gadgets are built and fitted only at the bench aboard.

## The gadgets (per tier: Mk I / Mk II / Mk III)

### Combat tricks (thrown, auto-aimed at the foe nearest your line of sight within range)
| Gadget | Charges | Cooldown s | Range m | Effect | Blueprint from |
|---|---|---|---|---|---|
| Smoke Pellet | 3/4/5 | 6/5/4 | 14/16/18 | cloud r 3.5/4.5/5.5 m for 6/8/10 s; foes caught stagger 1.6/2.0/2.6 s; you can't be noticed or attacked inside | known from the start |
| Tar Bomb | 3/4/5 | 7/6/5 | 13/15/17 | pool r 2.4/3.0/3.6 m for 7/9/11 s; foes in it at 0.5/0.38/0.26 speed | chests (any); forge tinkerer |
| Flash Pellet | 2/3/4 | 10/9/8 | 14/16/18 | burst r 4/5/6 m; foes facing it stunned 1.2/1.6/2.0 s | forge tinkerer |
| Pepper Bomb | 3/4/5 | 8/7/6 | 13/15/17 | cloud r 3.0/3.8/4.6 m for 5/6/7 s; 4/6/8 dmg/s; foes break off to cough every 1.6/1.4/1.2 s | hidden chests; books |
| Burst Star | 3/4/5 | 5/4.5/4 | 15/17/19 | blast r 2.5/3.0/3.5 m, 30/48/72 dmg; Mk III knocks down | hidden chests; forge tinkerer |
| Decoy | 2/2/3 | 14/12/10 | 8/9/10 | a straw captain for 5/7/9 s, draws foes within 10/12/14 m; Mk III bursts for 25 | hoard chests; merchant ship |
| Caltrops | 3/4/5 | 8/7/6 | 10/11/12 | spikes r 2.2/2.8/3.4 m for 8/10/12 s; 3/5/7 dmg/s, speed 0.7/0.6/0.5; Mk III bleeds 3 s | chests (any) |

### Traversal (cooldown only)
| Gadget | Cooldown s | Effect | Blueprint from |
|---|---|---|---|
| Grappling Hook | 4/3/2 | aim at a ledge, branch or mast within 14/18/22 m, pulled at 16/20/24 m/s | forge tinkerer |
| Spring Boots | 6/5/4 | a jump at 11/13/15 m/s up (the normal jump is ~7) | hoard chests |
| Pocket Glider | 8/7/6 | glide falling at 2.5/2.0/1.6 m/s, 9/10/11 m/s ahead, for up to 6/9/12 s | hoard chests; merchant ship |
| Climbing Spike | 6/5/4 | hang on any rock or timber face 4/6/8 s and climb on | hidden chests; books |
| Skimmer (1.28.1, atoll only) | 3/2.5/2 | a windsurfing board ridden on the water: top 9/11/13 m/s times the wind's angle (beam 1.0, running 0.8, into it 0.45); Mk III hops on Space | an atoll's pearl trader; a lagoon wreck |

Skimmer costs: Mk I 80g, 4 coral spar, 2 sea-silk, 1 lagoon pearl; Mk II 200g, 6 spar, 3 silk, 3 pearls, 1 brass; Mk III
450g, 8 spar, 5 silk, 5 pearls, 2 brass (an atoll gives 20 spar and 8 lagoon pearls, so Mk III wants a second atoll).
Its parts and blueprint are kept out of `blueprint_ids()` / `part_ids()` (shops and loot); `all_blueprint_ids()` has it.

### Utility
| Gadget | Charges | Cooldown s | Effect | Blueprint from |
|---|---|---|---|---|
| Marking Spyglass | - | 30/25/20 | marks foes and caches within 40/60/80 m on the compass for 20/30/40 s | forge tinkerer |
| Diving Helmet | 2/3/4 | 20 | breath lasts x1.5/x2/x3 for 60/90/120 s | hoard chests; books |
| Auto-Reel | 3/4/5 | 5 | the next 3/5/8 catches reel 25/40/60% faster | hidden chests; books |
| Lockpick Set | 2/3/4 | 3 | opens a locked chest or door in 3/2/1 s | chests (any) |
| Lantern Bomb | 3/4/5 | 6 | thrown 14/16/18 m; a light r 8/10/12 m burning 30/45/60 s; beasts keep clear by night | hidden chests; forge tinkerer |

### Ship gadgets (fitted at the bench aboard, fired by the helmsman)
| Gadget | Charges | Cooldown s | Effect | Blueprint from |
|---|---|---|---|---|
| Burst Launcher | 2/3/4 | 30/25/20 | flings the ship forward at +12/16/20 m/s | merchant ship; forge tinkerer |
| Paddle Boost | - | 40/35/30 | +25/35/45% speed for 8/10/12 s, whatever the wind | forge tinkerer |
| Harpoon Cannon | 4/6/8 | 12/10/8 | range 30/40/50 m, 40/60/90 dmg; the target reeled in at 3/5/7 m/s for 8/10/12 s | merchant ship; forge tinkerer |
| Smoke Screen | 2/2/3 | 45/40/35 | smoke r 10/13/16 m round the ship for 10/14/18 s; enemy gunners lose her | forge tinkerer |

## Costs (gold + parts; Mk I builds, Mk II and III upgrade) and refills
| Gadget | Mk I | Mk II | Mk III | Refill (all charges) |
|---|---|---|---|---|
| Smoke Pellet | 30g, 2 blackpowder, 1 canvas | 90g, 3 blackpowder, 1 springs, 1 copper | 240g, 4 blackpowder, 2 brass, 1 ember ore | 1 blackpowder |
| Tar Bomb | 30g, 2 pitch, 1 timber | 90g, 3 pitch, 1 iron, 1 springs | 240g, 4 pitch, 1 brass, 2 ember ore | 1 pitch |
| Flash Pellet | 45g, 1 blackpowder, 1 lens, 1 copper | 120g, 2 blackpowder, 1 lens, 1 brass | 300g, 2 lens, 2 brass, 1 ember ore | 1 blackpowder, 1 copper |
| Pepper Bomb | 35g, 1 blackpowder, 2 pepper | 100g, 2 blackpowder, 3 pepper, 1 springs | 260g, 4 pepper, 1 brass, 1 ember ore | 1 pepper |
| Burst Star | 40g, 2 blackpowder, 1 iron | 110g, 3 blackpowder, 2 iron, 1 springs | 280g, 4 blackpowder, 1 brass, 2 ember ore | 2 blackpowder |
| Decoy | 50g, 2 timber, 2 canvas | 130g, 2 timber, 2 canvas, 2 springs | 320g, 2 brass, 2 springs, 3 blackpowder, 1 plume | 1 canvas |
| Caltrops | 30g, 2 iron | 90g, 3 iron, 1 springs | 240g, 4 iron, 2 chitin shard, 1 ember ore | 1 iron |
| Grappling Hook | 60g, 2 iron, 1 timber, 1 springs | 160g, 3 iron, 2 springs, 1 brass | 380g, 2 brass, 3 springs, 2 snakeskin, 1 ember ore | - |
| Spring Boots | 60g, 2 springs, 1 iron | 160g, 3 springs, 1 brass, 1 bear claw | 380g, 4 springs, 2 brass, 1 ember ore | - |
| Pocket Glider | 70g, 3 canvas, 2 timber | 180g, 4 canvas, 1 brass, 2 plume | 400g, 4 canvas, 2 brass, 3 plume, 1 ember ore | - |
| Climbing Spike | 40g, 2 iron | 110g, 2 iron, 1 springs, 1 tusk | 280g, 1 brass, 2 tusk, 1 ember ore | - |
| Marking Spyglass | 50g, 1 lens, 2 copper | 140g, 2 lens, 1 brass | 340g, 3 lens, 2 brass, 1 pearl | - |
| Diving Helmet | 60g, 3 copper, 1 lens | 160g, 4 copper, 1 brass, 1 lens | 380g, 3 brass, 1 lens, 2 pearl | 1 pitch |
| Auto-Reel | 40g, 2 springs, 1 copper | 110g, 3 springs, 1 brass | 280g, 3 springs, 2 brass, 1 pearl | 1 springs |
| Lockpick Set | 30g, 1 iron, 1 springs | 90g, 2 springs, 1 brass | 240g, 2 brass, 2 springs, 1 ivory | 1 iron |
| Lantern Bomb | 35g, 1 blackpowder, 1 canvas, 1 copper | 100g, 2 blackpowder, 1 copper, 1 lens | 260g, 1 brass, 1 lens, 1 ember ore | 1 blackpowder |
| Burst Launcher | 120g, 4 blackpowder, 4 iron | 300g, 6 blackpowder, 4 iron, 2 brass | 700g, 8 blackpowder, 4 brass, 3 ember ore | 3 blackpowder |
| Paddle Boost | 100g, 4 timber, 2 springs | 260g, 4 timber, 4 springs, 2 brass | 600g, 4 brass, 4 springs, 2 ember ore | - |
| Harpoon Cannon | 140g, 4 iron, 2 timber, 2 springs | 340g, 6 iron, 2 brass, 2 springs | 800g, 4 brass, 3 ember ore, 1 leviathan scale | 2 iron |
| Smoke Screen | 100g, 4 blackpowder, 2 pitch | 260g, 6 blackpowder, 3 pitch, 1 brass | 600g, 8 blackpowder, 2 brass, 2 ember ore | 2 blackpowder, 1 pitch |

For scale: a ship refit level costs 60-300g plus 2-8 salvage (ShipLines). A Mk I is about a refit's first step, a Mk
III about its last.

## Parts and where they come from
| Part | Value | New? | Where |
|---|---|---|---|
| Blackpowder | 3 | new | chandlers (harbour vendors) 6 a day; ordinary and hidden chests |
| Pitch | 2 | new | chandlers 4 a day; ordinary chests |
| Springs & Cogs | 6 | new | chandlers 3 a day; all chests |
| Brass Fittings | 10 | new | hidden and hoard chests; the merchant ship (later); the forge town |
| Ground Lens | 16 | new | hoard chests; the merchant ship (later); the forge town |
| Ember Ore | 18 | new | the volcanic isle (the volcanic agent drops it: `Gadgets.part_ids()`) |
| Leviathan Scale | 60 | new | leviathans (wave 4: the leviathan agent drops it) |
| Iron, copper, timber, canvas | - | salvage | floating salvage, chandlers (already) |
| Pepper | - | grocery | grocers (already) |
| Chitin shard, snakeskin, bear claw, tusk, plume, pearl, ivory | - | trophies | beasts, dives, chests (already) |

**Chests** (Loot.chest, their own random stream so nothing else in a chest changes): parts 25% ordinary (1-2 of
blackpowder/pitch/springs), 40% hidden (1-2 of blackpowder/springs/brass), 60% hoards (1-3 of springs/brass/lens); a
blueprint 3% ordinary, 8% hidden, 20% hoards, from that kind's pool, one the captain doesn't know yet:
- ordinary: Tar Bomb, Caltrops, Lockpick Set
- hidden: Pepper Bomb, Burst Star, Climbing Spike, Lantern Bomb, Auto-Reel
- hoard: Spring Boots, Pocket Glider, Decoy, Diving Helmet
The rest come from the forge town's master tinkerer (`Gadgets.teach`), books and the merchant ship (their agents).

## Contracts for other features
- `Gadgets.teach(player, blueprint_id) -> bool`, `Gadgets.blueprint_ids()` ("bp_<gadget>"), `Gadgets.part_ids()`.
  A blueprint id is also an item id (a scroll in the bag; a workbench studies it).
- `Workbench.place(parent, at, yaw, opts)`; opts "style": "forge" | "ship" | "camp" (default: a plain bench).
- **Harpoon Cannon (for the leviathans):** see "Harpoon contract" below.

## Harpoon contract (2026-11-01, `scripts/ship/harpoon_cannon.gd`)
- `HarpoonCannon.harpoon(ship: Node3D, target: Node3D, tier := 0, by: Node = null) -> bool`: tethers `target` to `ship`
  (false when there's no target or it's dead). Call it on every machine (ShipGadgets does, from the helmsman's
  "gadget_use" event): each shows its own line; only the host's bites and reels.
- `HarpoonCannon.target_ahead(ship, range) -> Node3D`: what the bow gun would hit (groups `enemy_ships`, `sea_kings`,
  `harpoonable`; within 35 degrees of the bow).
- A target: in one of those groups, with a `hurtbox` (Hurtbox) property (the bite is a `siege` HitData of the tier's
  damage, as the helmsman's). Optional methods, called on the host: `harpooned(ship)` once when it bites,
  `reel_toward(at: Vector3, speed: float, delta: float)` every physics tick while reeled (else its global_position is
  moved), `released()` when the line goes (hold over, ship or target gone), `is_dead()` (a dead one is let go).
- Every HarpoonCannon node (group `harpoons`) emits `released` on every machine when its line goes. Reeling stops 14 m
  off (REEL_CLOSE). EnemyShip implements all of it (`harpooned_by`).
- **For a leviathan:** join `harpoonable`, have a `hurtbox`, and implement `reel_toward` (a big beast might pull back:
  move toward the ship at less than `speed`, or drag the ship: that's the leviathan agent's call).

## Assumed (revisit in play)
- Every number above. O for cycling (a free key next to I; Shift+U clashed with sprint).
- Auto-aim for throws (no aiming mode). Blueprints studied at a bench rather than read from the bag.
- Tar and caltrops slow grunts, beasts (JungleBeast) and wildlife (Creature) alike: each has `slowed(secs, k)`.
