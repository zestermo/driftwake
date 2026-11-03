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

## 4. Acrobatics remapped (with the wall jump)

The slope slide is free for everyone (decided). Three columns; the kind each node is shows on the map (section 5).

| Air | Walls and slides (new) | Footwork (Dodge and Stride merged) |
|---|---|---|
| 2 **Geppo** (ability: a second air jump) | 4 **Wall Jump** (ability: kick off a wall once) | 3 Long Stride (stat) |
| 9 **Sky Walk** (ability: a third jump) | 6 Slick Slide (stat: slide 25% faster and further) | 4 Swift Step (stat) |
| 12 Breakfall (passive) | 10 **Wall Kick** (ability: chain a second wall jump) | 6 Sprint Jump (stat) |
| 15 Landing style (variant) | 12 Slide Jump (passive: a jump out of a slide keeps its speed) | 8 Dodge Style (variant) |
| 18 **Skyward Dash** (ability) | 14 Spring Heels (passive: more bounce on wall jumps and the air walk) | 8 **Squall Step** (ability) |
| 20 **Moonstep** (ability) | 18 **Wall Run** (ability: three steps along a wall) | 10 Sure Footing (stat) |
| 22 **Sky Leap** (ability) | 24 Rebound (passive: a wall jump refills an air jump) | 12 Fleetfoot (stat) |
| 28 **Heavenward** (ultimate) | | 16 Rigging Monkey (stat) / 18 **Afterimage** (ability) |

## 5. The skill map: what's a passive and what's an ability

- **Abilities** (things you press or that fire as a move): big round nodes with their icon, gold-rimmed.
- **Passives** (always-on effects): diamond nodes with their icon, blue-rimmed.
- **Stat upgrades** (+% numbers, step chains): small square pips in a line, labelled with the stat ("+4% strike speed").
- Every tree zooms (mouse wheel / triggers) and pans (drag / right stick), and opens centred on what you can buy next.
- **Fix:** a node can only be bought once its parent is owned (the playtest bought past one: a bug).
The mock comes with the journal's.
