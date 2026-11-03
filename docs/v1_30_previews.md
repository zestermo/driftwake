# 1.30 previews: progression pacing (for Zach's OK)

Built from the 2026-11-02 playtest save (3h22m, level 14). Every number is tuned in play after it lands.

## 1. Edy: fewer, bigger moments

**Today:** 23 Edy by level 14. Every boss, villain, hunter and leviathan pays 2; every rival, officer, sergeant
and miniboss pays 1 (`WillPaths.SOURCES`). Brinehollow's three minibosses alone paid 3 before the first chain island.
The 7 paths cost 70 to own, so 23 at level 14 is a third of everything after one evening.

| Deed | Today | Proposed |
|---|---|---|
| Island boss, beast boss | 2 | **1** |
| Story villain (Morrow, the arc villains), leviathan | 2 | **2** |
| Stronghold boss (each of 3) | 2 | **1** |
| Hunter, rival captain | 2 / 1 | **1** |
| Officer, sergeant, miniboss | 1 | **0** (bounty and gold only) |
| Meditation | 1 per 3 game days | **1 per 6 game days** |

This playtest under the new rule: **about 12 Edy at level 14** (Morrow 2, the leviathan 2, three island/beast
bosses 3, the stronghold's three 3, Vael and the rival 2), and about 35 by level 40, so half the paths. The toast also
stops coming every few minutes.

## 2. The adventure trees: earn by doing, more

**Today:** the same curve as the weapons (60 x lv^1.3: 822 xp for level 5, 4,617 for 10). Acrobatics earns xp on every
plain jump, so it reached **12**; everything else stayed at **1-4** (defence 2, cooking 2, seamanship 4, swimming 3,
tinkering 2, stealth 1).

**Proposed:**
- A gentler curve for the adventure trees only: **40 x lv^1.15** (467 xp for level 5, 2,349 for 10, 26,893 for 30).
- **Twice the xp** from defence, cooking, seamanship, swimming, tinkering, fishing and stealth.
- **Acrobatics earns only from what counts:** double jumps, wall jumps, dodges through a blow, falls you live through,
  sky leaps. No xp for plain jumps, so acrobatics doesn't level from moving about.

| Tree | Playtest xp | Level today | Level proposed |
|---|---|---|---|
| Acrobatics | 7,587 | 12 | 12 (half its xp, the cheaper curve) |
| Seamanship | 794 | 4 | **8** |
| Swimming | 311 | 3 | **5** |
| Defence | 205 | 2 | **4** |
| Cooking | 120 | 2 | **3** (cook 5 meals and it's 5) |
| Tinkering | 70 | 2 | **3** |

Adventure points (one per level gained) go from 19 to ~29 at the same point, spread over the trees the crew used.

## 3. Strike speed

**Today:** the light attack reads an `attack_speed_pct` stat, but **no node grants it**. Only Edy's flow and the
Storm type's 3% after a dodge speed up strikes.

**Proposed: a "Quick Hands" step chain in every weapon tree** (1 point a step, the steps' usual price):

| Weapon | Steps | Opens at mastery | Total |
|---|---|---|---|
| Katana | 5 x +4% | 3, 7, 11, 15, 19 | **+20%** (its identity: fastest hands) |
| Cutlass, rapier, dagger, sickle, unarmed / Black Leg | 4 x +4% | 4, 9, 14, 19 | +16% |
| Staff, spear, axe | 3 x +4% | 5, 11, 17 | +12% |
| Greatsword, warhammer, kanabo | 3 x +3% | 6, 12, 18 | +9% |

Plus one passive at mastery 20 in the katana's Blade column: **Flowing Edge**, +10% strike speed for 3 s after a
perfect dodge or an Iai counter. Strike speed from all sources is capped at +35%.

## 4. Acrobatics as one branching map (revised 2026-11-03, Zach: maps, not columns; smaller, more nodes)

**Every tree is one connected map**: a root in the middle, branches growing out of it, sub-branches off them, and a
few bridges between branches. You buy any node whose parent you own (and whose level you've reached), so a build
can go deep down one branch or take a little of several. **Small nodes, many of them**: most cost 1 point, big moves 2,
the ultimate 4. Acrobatics goes from 19 nodes to 34; owning all of it takes ~52 points (~level 30 of Acrobatics),
so at level 15 you've picked about a third.

The slope slide is free for everyone (decided); this map upgrades it.

| Branch | Node (kind, cost, Acrobatics level) | Needs |
|---|---|---|
| **Root** | Acrobatics (owned) | - |
| **Air** | Geppo (ability 2, lv 2): a second jump in mid-air | root |
| | **Air Dash** (ability 2, lv 4): a quick dash in any direction in mid-air, once before you land | Geppo |
| | Dash Distance (stat steps 1 x3, lv 5/8/11): +15% air dash distance a step | Air Dash |
| | **Dash Strike** (ability 1, lv 7): attack out of an air dash, a diving cut | Air Dash |
| | **Twin Dash** (ability 2, lv 10): a second air dash | Air Dash |
| | Hang Time (passive 1, lv 8): you fall slower while you attack in the air | Geppo |
| | Aerial Combo (passive 1, lv 12): your air light chain is one hit longer | Hang Time |
| | Air Control (stat steps 1 x3, lv 3/6/9): +10% steering in mid-air a step | Geppo |
| | Sky Walk (ability 2, lv 9): a third jump | Geppo |
| | Feather Fall (passive 1, lv 6): no fall damage under 12 m, a softer landing | Air Control |
| | Skyward Dash (ability 2, lv 18): a dash straight up | Twin Dash or Sky Walk |
| | Moonstep (ability 2, lv 20): kick off the air again and again for 2 s (stamina) | Sky Walk |
| | Sky Leap (ability 2, lv 22) | Moonstep |
| | **Heavenward** (ultimate 4, lv 28) | Sky Leap and Dash Strike |
| **Walls** | Wall Jump (ability 2, lv 4): kick off a wall once in mid-air | root |
| | Spring Heels (passive 1, lv 6): more bounce on wall jumps, the air walk and surface jumps | Wall Jump |
| | Wall Kick (ability 1, lv 10): a second wall jump before you land | Wall Jump |
| | Wall Run (ability 2, lv 14): three steps along a wall | Wall Kick |
| | Wall Cling (passive 1, lv 8): hold on a wall for a second before sliding down | Wall Jump |
| | **Rebound** (passive 1, lv 16): a wall jump gives back an air jump and an air dash (**the bridge to Air**) | Wall Kick and Air Dash |
| **Slides** | Slick Slide (stat steps 1 x3, lv 3/7/11): +8% slide speed a step | root |
| | Slide Jump (passive 1, lv 6): a jump out of a slide keeps its speed (jump off a mast, slide the hill, launch) | Slick Slide |
| | Slide Kick (ability 1, lv 9): slide into a foe and knock them down | Slick Slide |
| | Long Slide (passive 1, lv 12): slides keep going on gentle slopes and flat decks | Slide Jump |
| **Footwork** | Swift Step (stat steps 1 x3, lv 2/5/8): cheaper, longer dodges | root |
| | Dodge Style (variant 2, lv 8) | Swift Step |
| | Squall Step (ability 2, lv 8) | Swift Step |
| | Afterimage (ability 2, lv 18) | Squall Step |
| | Sprint Jump (stat 1, lv 6), Long Stride (stat steps 1 x2, lv 3/9), Fleetfoot (stat steps 1 x3, lv 12/15/18), Sure Footing (passive 1, lv 10), Rigging Monkey (stat 1, lv 16), Breakfall (passive 1, lv 12) | Swift Step or Long Stride |

**An aerial build** at Acrobatics 15 (about 15 points): Geppo, Air Dash, Dash Distance x2, Dash Strike, Twin Dash,
Hang Time, Aerial Combo, Air Control x2, Wall Jump: you fight mostly off the ground. **A runner** instead takes
Slides and Footwork; **a climber** Walls and the Rebound bridge.

The weapon trees get the same treatment in the build (one map each, their Quick Hands steps a small branch of their own).

## 5. The skill map: what's a passive and what's an ability

- **Abilities** (things you press or that fire as a move): round nodes with their icon, gold-rimmed.
- **Passives** (always-on effects): diamond nodes with their icon, blue-rimmed.
- **Stat upgrades** (+% numbers, step chains): small square pips, labelled with the stat ("+4% strike speed").
- Every tree is **one branching map** from a root, zooms (mouse wheel / triggers) and pans (drag / right stick), and
  opens centred on what you can buy next.
- **Fix:** a node can only be bought once its parent is owned (the playtest bought past one: a bug).
