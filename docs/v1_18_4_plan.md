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
| Old saves | **Buy-back, then refund** (Zach, preview OK): the pools rebuilt from levels, what the save owned bought back in order (bar skills and slotted passives, then each tree's big nodes lowest gate first, most-used tree first, then steps) while the pool affords it; the rest refunded | No progress lost that the new pools can carry | — |
| Combat pool size | **~25% under the preview's draft: 106 at Captain 40** (2 at level 1; 2/1 alternating to 10, 2 to 20, 3 to 30, 4 to 40). Prices unchanged | Zach: commit to one weapon | Play |
| Respec | **Costs gold at the ship's bunk**: a tree's purchases back whole for 100 + 40 x Captain level gold, shown in the confirm | Stings, doesn't block | Play |
| Adventure share | **~60% of all Adventure nodes buyable** at everything maxed (152 of 252), as previewed | Choices in Adventure too | Play |
| Unanswered | **assumed:** fruit trees spend Combat points, their level-1 powers free with the fruit; a step needs the node it hangs on, the second element needs the first | Kept from the preview | Play |
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

### Stragglers folded in (Zach, 2026-10-21)
- **The trees' missing moves** (docs/todo.md "Later": the progression trees' new moves): katana Falling Moon, Twin Waves,
  Side Step; Acrobatics Moonstep, Afterimage, Roll/Sidestep, Crash Landing (Sprint Jump and Rigging Monkey were built as
  numbers); Defense Disarm/Shove, Rolling Guard (Hold the Line, Iron Wall as numbers); Swimming Dolphin Kick / Long Glide;
  the other weapons' variants their tables mark "new move". The Acrobatics ones go with the movement agent; the rest
  after the first wave, by area.
- **1.18.3's weapon follow-ups** (docs/weapons_plan.md "Follow-ups after 1.18.3"), in the new weapons' finish: wide-stance
  feet, the greatsword guard's angle, the twin axes' heads and striped ice, the polearm run threshold, grunts' square
  attack starts, nettest on Earthquake and the hook.
- **1.18.2's unfinished checks**, at this batch's prepush: occluder popping in the capital and Brinehollow, an
  islanddump, `nettest.ps1 chain`, the perf gate re-baselined on this PC (`perf_gate.ps1 -Update`, Zach's OK), and the
  suites 1.18.3 skipped.
- **The tooling window now** (docs/todo.md "Tooling window (after v1.18)", moved out of 1.19's first step): the crew_lib
  deps-file race, the autoload-in-static-func lint, nettest modes' own log/deps names, fauna tests naming their
  creatures, Humanoid._rng seeded. A quiet window: only the progression agent's number table (no code) runs beside it;
  the movement and fist agents start once it lands.

## Preview: the numbers (points rework, piece 1, 2026-10-21; for Zach's OK, no code yet)

### The level curve, from the code
- Captain: `xp_to_next(lv) = 200 x lv^1.5` (level 2 at 200 xp, level 10 at 22k, 20 at 134k, 40 at 784k in all).
- Foes scale with their level (`Levels.xp_k = (lv/4)^1.5`), so **every Captain level costs the same ~36 kills of a
  same-level grunt** (45 base xp), from level 1 to 40. Elites, bosses, ships and Sea Kings shorten it. Each level is
  about the same stretch of play; 40 levels is ~1,400 grunt-equivalents.
- Mastery: `mastery_to_next(lv) = 60 x lv^1.3` (62.6k for mastery 30). A grunt kill teaches ~32 (8 counted hits x 4)
  plus a quarter of its xp. Estimate: fighting with **one** weapon only, mastery runs ahead of the Captain:
  Captain 5 -> mastery ~10, 10 -> ~16, 15 -> ~22, 20 -> ~28, 22 -> 30. Split between **two** weapons: 10 -> ~12,
  20 -> ~21, 30 -> 30. So mastery gates are rarely what stops you; **the pool is the choice**, which is the point.
- Adventure trees: the same mastery curve to level 20 (24k xp).

### Combat points (one pool, from Captain levels)
| Captain levels | Points each | Pool at the end of the band |
|---|---|---|
| 1 (a new captain) | 2 | 2 |
| 2-10 | 2 on even levels, 1 on odd | 16 |
| 11-20 | 2 | 36 |
| 21-30 | 3 | 66 |
| 31-40 | 4 | **106** |
Rising per level, because a level is the same length of play all the way and late nodes cost more. (Zach's OK,
2026-10-21: about 25% under the first draft's 141, prices unchanged, so a captain commits to one weapon.)

**Prices (derived, so other blocks need no numbers):** `price = BASE[kind] + gate level / 10` (integer division).
BASE in a weapon (or fruit) tree: move 2, mech 2, tech 3, passive 3, variant 4 (both versions), element 5, ultimate 8;
a step 1 a step. A node may carry `"cost"` to override (`_big(...)["cost"] = 4`), so the movement and fists agents'
blocks add nodes without touching prices. **Gate:** the tree's mastery >= the node's level. **assumed:** a step also
needs the node it hangs on (steps off the root need nothing), the second element needs the first; no other path rule.
The root (the basics) stays free.

**Each weapon tree** (name gate/price; then steps, all 1 a step). Totals: big nodes + steps = all of it.
- **Cutlass** 54+30 = 84: Running Cut 2/2, Arrow Cutting 3/2, Flying Slash 4/3, Boarding Dive 6/2, Riposte 8/3,
  Swordfish Flurry 10/4, Flourish 13/4, Call of the Tide 16/6, Return to Sender 20/4, Pirate's Way 22/6, Tidewalker 25/7,
  Kraken's Wake 30/11. Steps: Keen Edge 5, Whetstone 5, Boarding Edge 5, Steady Hand 3, Light Feet 3, Lunge 3, Flow 3, Swift Recovery 3.
- **Katana** 64+30 = 94: Quick Draw 2/2, Cut the Shot 3/2, Wind Severer 5/3, Full Draw 6/2, Crescent Arc 7/2,
  Iai Counter 8/3, Tiger Rush 10/4, Iai Upgrade 12/5, Clean Line 13/4, Phantom Step 14/4, Falling Petals 16/6,
  Bullet Return 20/4, Empty Mind 22/5, Blossom Path 25/7, Thousand Petals 30/11. Steps: Keen Edge 5, Deep Draw 5,
  Whetstone 5, Steel Nerves 3, Counterweight 3, Light Feet 3, Flow 3, Swift Recovery 3.
- **Dual Wield** 54+30 = 84: Twin Spin 2/2, Twin Deflect 3/2, Blade Dance 5/3, Twin Cyclone 7/2, Crossed Counter 8/3,
  Cross Fang 10/4, Whirling Steel 13/4, Twin Currents 16/6, Ricochet Steel 20/4, Dancer's Way 22/6, Crossing Storm 25/7,
  Tempest of Steel 30/11.
- **Axe** 51+30 = 81: Skybreaker 2/2, Hatchet Throw 3/3, Unstoppable 6/2, Earthsplitter 9/3, Berserk 11/4,
  Bloodlust 12/4, Sunder 14/3, Ember Heart 16/6, Rage 20/6, Living Fire 25/7, Maelstrom 30/11.
- **Dagger** 54+30 = 84: Gutting Strike 2/2, Flick the Shot 3/2, Knife Fan 5/3, Fang Dive 7/2, Slip 8/3, Cutthroat 10/4,
  Deep Cuts 13/4, Nightfall 16/6, Knife in the Dark 20/4, Killer's Way 22/6, Blood Moon 25/7, Red Eclipse 30/11.
- **Twin Daggers** 54+30 = 84: Fang Whirl 2/2, Crossed Knives 3/2, Viper Flurry 5/3, Knife Rain 7/2, Bleeding Edge 8/3,
  Scissor Leap 10/4, Open Wounds 13/4, Viper's Kiss 16/6, Knives Back 20/4, Viper's Way 22/6, Serpent's Coil 25/7,
  Hundred Fangs 30/11.
- **Polearm** 61+30 = 91: Wheel Sweep 2/2, Turn the Shot 3/2, Pole Vault 4/2, Hundred Thrusts 5/3, Leg Sweep 6/2,
  Vaulting Strike 8/3, Falling Spear 9/2, Emperor's Bearing 10/3, Dragon Sweep 10/4, Long Reach 13/4,
  Rolling Thunder 16/6, Spear Wall 20/4, Lancer's Way 22/6, Storm Bearer 25/7, Raijin's Wheel 30/11.
- **Hammer** 56+30 = 86: Wrecking Spin 2/2, Iron Wall 3/2, Rising Crush 4/2, Rolling Quake 5/3, Hammerfall 6/2,
  Skullcracker 8/3, Cyclone Crusher 10/4, Aftershock 13/4, Rumbling Earth 16/6, Immovable 20/4, Smith's Way 22/6,
  Mountain's Weight 25/7, Titan's Fall 30/11.
- **Twin Axes** 56+30 = 86: Reaping Whirl 2/2, Hooked Guard 3/2, Raider's Leap 4/2, Hewing Frenzy 5/3, Buzzsaw 6/2,
  Gallows Hook 8/3, Axestorm 10/4, Red Rhythm 13/4, Hoarfrost 16/6, Bloodrage 20/4, Reaver's Way 22/6,
  Winter's Bite 25/7, Fimbulwinter 30/11.
- **Greatsword** 56+30 = 86: Gale Turn 2/2, Flat of the Blade 3/2, Running Cleave 4/2, Crescent Gale 5/3,
  Falling Cleave 6/2, Guardbreaker 8/3, Tempest Turns 10/4, Unbroken Momentum 13/4, Gale Edge 16/6, Unyielding 20/4,
  Swordmaster's Way 22/6, Tempest Blade 25/7, Skysplitter 30/11.
- **Corsair** 56+30 = 86: Powder Finale 2/2, Steel and Shot 3/2, Grapeshot 5/3, Dead Man's Drop 7/2, Parley 8/3,
  Bandolier 9/2, Crossfire 12/4, Smoke and Steel 13/4, Black Powder 16/6, Return Fire 20/4, Corsair's Way 22/6,
  Powder Keg 25/7, Broadside 30/11.
- **Pistol** 62+30 = 92: Hang Shot 2/2, Gun Kata 3/2, Bullet Storm 5/3, Smoke Bomb 6/3, Extra Powder 7/2, Gun Rain 9/2,
  Deadeye 10/4, Point Blank 11/4, Hang Time 14/3, Close Quarters 15/4, Golden Powder 16/6, Ricochet 20/4,
  Coup de Grace 22/5, Gilded Gun 25/7, Death's Waltz 30/11.
- **Unarmed** 64+30 = 94 (today's tree; the fists agent reshapes it, prices follow by kind): Roundhouse 2/2,
  Shoulder Throw 3/3, Shockwave Palm 4/3, Meteor Kick 6/2, Rising Dragon 8/3, Heavy Landing 9/2, Iron Body 11/4,
  Suplex 12/4, Hundred Fists 13/4, Chi 15/4, Rushing Wind 16/6, Giant Swing 18/4, Finishing Blow 22/5, Gale Fists 25/7,
  Sea King Fist 30/11.
- **Black Leg** 59+30 = 89: Handstand Spin 2/2, Shin Guard 3/2, Arrow Kick 4/2, Hailstorm Heels 5/3, Cyclone Heel 6/2,
  Mule Kick 8/3, Nonchalance 10/3, Cartwheel Crescent 10/4, Galley Tempo 13/4, Searing Heel 16/6, Kick Back 20/4,
  Cook's Way 22/6, Red-Hot Leg 25/7, Last Course 30/11.
- Every weapon's steps are the same shape: three x5 and five x3 (30 points).

**What a captain can afford** (katana as the main weapon; any tree reads the same, they're 81-94 each):
| Captain | Pool | Main weapon's mastery (est.) | One way to spend it | Another |
|---|---|---|---|---|
| 10 | 16 | ~16 | The katana's early kit to mastery 8 (Quick Draw, Cut the Shot, Wind Severer, Full Draw, Crescent Arc, Iai Counter = 14) + 2 steps | The cutlass's first four (9) + the pistol's first two (4) + 3 steps |
| 20 | 36 | ~28 | Every katana big node to 14 (31) + 5 steps | Katana to 10 (18) + the cutlass's first four (9) + 9 steps |
| 30 | 66 | 30 | Every katana big node (64) + 2 steps | The katana's big nodes to 22 (46) + 20 steps |
| 40 | 106 | 30 | **One tree full (94)** + a second tree's first four nodes (10) + 2 steps | Every katana big node (64) + the pistol's to 11 (22) + 20 steps |
One weapon, mastered over the whole game; a second is a dabble.

### Adventure points (one pool, from Adventure levels)
- **A point for each level any Adventure tree gains** (Acrobatics 1 -> 2 is a point). Eight trees x 19 = 152 at
  everything maxed.
- **Prices:** Adventure big nodes are numbers, not moves: `BASE = 1 (mech/move), 2 (tech/passive/variant)` +
  level / 10; steps 1 each. Gate: that tree's own level. Same step rule as the weapons.

| Tree | Big nodes (gate/price) | Steps | Total |
|---|---|---|---|
| Acrobatics | Geppo 2/1, Long Stride 3/1, Swift Step 4/1, Sprint Jump 6/1, Sky Walk 9/1, Sure Footing 10/2, Fleetfoot 12/2, Featherfall 15/2, Rigging Monkey 16/2 (+ Breakfall ~12, Skyward Dash ~18 from the movement agent) | Light Step 5, Quick Feet 5, Hang Time 3, Spring 3, Wind 3 | 13+19 = 32 |
| Defense | Clean Parry 2/1, Brace 3/1, Steadfast 4/1, Iron Body 8/1, Unshaken 9/1, Hold the Line 11/2, Battle Instinct 12/2, Second Skin 14/2, Unbreakable 18/2, Iron Wall 20/3 | Timing 5, Sturdy Guard 5, Thick Skin 5, Recovery 3, Composure 3 | 16+21 = 37 |
| Sailing | Sea Hand 2/1, Gun Captain 4/1, Helmsman 5/1, Hard Over 7/1, Storm Sailing 10/2, Broadside Master 15/2, Bosun 20/3 | Steady Helm 5, Gunnery 5, Carpenter 3, Bilge Rat 3, Lookout 3 | 11+19 = 30 |
| Swimming | Strong Strokes 2/1, Deep Lungs 4/1, Sea Born 7/1, Current Reader 8/1, Catch Your Breath 10/2, Deep Diver 14/2, Child of the Sea 15/2, Old Salt Lungs 20/3 | Long Strokes 5, Big Lungs 5, Tireless 5, Cold Blood 5 | 13+20 = 33 |
| Cooking | Galley Hand 2/1, Ship's Cook 5/1, Long Feast 8/1, Iron Gut 10/2, Master Chef 15/2, Captain's Table 20/3 | Seasoning 5, Slow Simmer 5, Taster 5, Good Stock 5 | 10+20 = 30 |
| Fishing | Patient Line 2/1, Steady Hands 5/1, Bait Saver 8/1, Sea Lore 10/2, Old Salt 15/2, Master Angler 20/3 | Quick Bite 5, Strong Reel 5, Lucky Cast 5, Thrifty 5 | 10+20 = 30 |
| Stealth | Soft Step 2/1, Ambush 4/1, Slip Away 8/1, Ghost 12/2, Assassin 15/2, Shadow 20/3 | Quiet Feet 5, Knife Work 5, Patience 5, Nimble 5 | 10+20 = 30 |
| Tinkering | Tight Fit 2/1, Dry Powder 5/1, Clever Hands 8/1, Fine Springs 10/2, Powder Horn 15/2, Field Whetstone 20/3 | Oil 5, Ramrod 5, File 5, Patchwork 5 | 10+20 = 30 |

- The flow: the trees that grow from fighting (Acrobatics, Defense) fund the quiet ones too, so a fisher's points
  can buy Geppo. Example mid-game: Acrobatics 10, Defense 8, Swimming 6, Sailing 6 = 26 points: every Acrobatics node
  to 10 (7), Defense to 8 (4), Swimming to 6 (2), Sailing to 6 (4) = 17, and 9 steps.
- All of Adventure costs 252 against 152 at everything maxed: about 60%. **Option** if that's too tight: Adventure
  steps x5 become x3 (all of it ~190).

### Fruit trees (**assumed**, not answered)
The fruit's level-1 powers (Fire Fist + Blazing Ring, Rending Fang + Pounce, Vine Snare + Vine Swing) come with eating
it, like a weapon's root basics; the rest is bought with **Combat** points at the weapon prices, gated by the fruit's
level (Ember 41 for the rest, Wolf 28, Vine 28).

### Captain tree: unchanged
Talents (picked every 5 levels), milestones (Soru 8, third loadout 10, Tekkai 14, fourth slot 25) and Will stay as
they are; the per-level growth stays. The Captain tree's only change is that its levels feed the Combat pool.

### Respec (Zach, 2026-10-21: it costs gold)
At the ship's bunk, a tree's purchases come back whole into their pool for **100 + 40 x Captain level gold** (500 at
10, 900 at 20, 1,700 at 40: about half to two-thirds of the gold a level of fighting brings in; tune in play). The
confirm shows the price; versions and talents still switch free there.

### Old saves (format 5 -> 6)
Kept: Captain level and xp, every mastery and Adventure level, uses and tiers, talents, Will, versions picked.
The pools are rebuilt from levels (Combat from the Captain level, Adventure from every Adventure level). What the save
owns (all of which came free by level, and the per-tree steps) is then **bought back for the player, in order, while
the pool affords it**: (1) the skills on the bar and the slotted passives, (2) each tree's big nodes, lowest gate
first, the trees in order of their level (the most-used weapon first), (3) steps. What doesn't fit is refunded (left
unbought, buyable later). One banner on load: "The skill trees are new: N Combat and M Adventure points to spend
(K)", only if something is left to spend. (Zach picked this over starting in debt.)
- Example: Captain 18 (32 Combat points), katana 24, cutlass 12, both trees' steps bought. Kept: the katana's big
  nodes to 14 (31; Tiger Rush and Iai Counter first if they're on the bar), then the 1 left buys back a step. The
  rest of the katana, the cutlass and the steps are refunded (buyable again as the pool grows).

### The menu, slimmed (mock)
```
 [Captain] [Combat] [Adventure] [Loadout] [Driftfruit*]        LV 18  COMBAT 6  ADVENTURE 3      <- beam: both pools, always
 ------------------------------------------------------------------------------------------------
 |                                                          |  KATANA          MASTERY 24 ====-  |
 |        (Thousand Petals)                                 |  ------------------------------    |
 |   (Bullet Return)   (Blossom Path)   (Empty Mind)        |  Iai Upgrade        VARIANT        |
 |          |            (Iai Upgrade)        |             |  Needs mastery 12  -  yours: 24    |
 |   (Phantom Step)      (Tiger Rush)   (Clean Line)        |  Price 5   [ENTER  BUY]            |
 |   (Iai Counter)       (Full Draw)    (Crescent Arc)      |  Through the Guard: your iai...    |
 |   (Cut the Shot)  o o              o (Wind Severer)  o   |  Mind's Eye: charges 30% faster    |
 |                     \   (KATANA)  /                      |                                    |
 |   icons + names only; steps are pips that fill           |  (one panel, only for the picked)  |
 ------------------------------------------------------------------------------------------------
   CUTLASS   [KATANA]   PISTOL                <- rail: only found weapons (none greyed or locked)
```
- **On the tree:** each node's icon and name; owned lit, buyable now a soft glow, out of reach dim. Steps are small
  pips that fill (no "2/5" chips); no level numbers on nodes, no "coming next" list, no points chip on the card.
- **Hover tooltip** (small, by the cursor): name, price and the gate in one line ("Iai Upgrade - 5 pts - mastery 12").
- **The select panel** (the right card, slimmer): name and kind, the gate against your level, the price, what it does,
  and the one action (Buy / Switch / Pick). A variant's two versions side by side; at the bunk Enter opens a small
  modal to switch. An Adventure tree's "how it grows" goes in the root's panel, not always on screen.
- **Hidden entirely:** unfound weapons (not on the rail or the Tab chart), unfound Adventure trees (not in the list),
  the Driftfruit tab without a fruit. The chart (Tab) draws found weapons only, bigger.
- **Pools:** on the beam beside the level ("COMBAT 6 ADVENTURE 3"), coral only when something is buyable now.

### The stale prompts: diagnosis
No stored counter goes stale: `points_free(tree)` is computed fresh each time (progression.gd:454). The prompts are
wrong about **what** they announce:
1. **progression.gd:330**, `_gain`: every level-up of **any** tree toasts "+N point(s) (K)", where N is the levels just
   gained (`ups`), not what's unspent and not whether anything is buyable. Adventure trees level from jumps, dodges,
   blocks, swims and helm time (jump_state.gd:28, dodge_state.gd:39, block_state.gd:52, seamanship.gd:27), so after
   spending the katana's points Zach still gets "+1 point (K)" every few minutes for a tree he wasn't thinking about.
   That reads as "points I already spent". With 22 per-tree wallets there is always one with a point in it.
2. **skill_bar.gd:427-431**: the "+N KATANA [K]" pulse by the level badge shows whenever the hand weapon's own wallet
   has a point, every frame, forever, if he chooses not to buy a step.
3. **progression.gd:431-435** (the new-tree card's "N points to spend") and **skill_map_screen.gd:570-575** (the card's
   points chip) repeat the per-tree count.
4. The Captain level-up's "a talent to pick (K)" (progression.gd:182-185) is correct (only while one is unpicked).
**Fix (piece 2):** the per-tree wallets go (two pools); the mastery/Adventure level toast is just "Katana mastery 12"
(and what it opens to buy, by name); one short line "N Combat points (K)" / "N Adventure points (K)" only on the level
that **earned** points and only when that pool has points **and** a node it can afford is open; the HUD pulse follows
the same test. Not verified against Zach's capture (none named); if he saw a line with a pool truly empty, that capture
would point at a fifth source.

### Tests and readers (pieces 2-3)
The readers (has_move, owns_node, stat, style_stat, skill_tier, knows, elemental, known_skills) keep their signatures;
`points_free(tree)` becomes `pool(section)`; `buy_step` becomes `buy(node)` (steps and big nodes). t/progression's
grant_by_level, steps_points, refund_migration and format5_migration change with it; new atomic tests: pools,
prices, gates, buy and respec, the format 6 migration, the prompt only with something to buy. t/ui: skills_buy_step,
skills_tabs (hidden trees). Suites likely affected at prepush: storytest (Vey's drill), techtest, any suite that calls
`master_all()` (it will buy everything).

### Open / deferred
- The Captain-level point rate, node prices and mastery gates: **in the preview**, then tuned in play.
- **assumed:** the fists' power-punch branch and new big-fist techniques are pitched to Zach as one-liners before they're built (like the new weapons' techniques).
- **assumed:** Breakfall and Skyward Dash count for the air-step agent; their tree entries go through the progression agent's data.
- **assumed:** the mastered guard is the same node pattern on every weapon; the first one (on the axe, with its awakening) is checked by Zach before the rest.
- 1.19 (docs/v1_19_plan.md) starts after this batch.
