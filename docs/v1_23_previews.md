# v1.23 previews (for Zach's OK before building)

These are the feel systems 1.23 holds back until you've seen the numbers: progression (points per tree, Will, passive
slots), combat (poise and enemy AI), the island arcs (with replies and hidden finishes), the beast pass (the first three
bosses, phases that escalate, part breaks, roamers) and bounty as heat. Each section ends with **the one call I need**.
Everything here is a proposal; nothing in it is built yet.

---

## 1. Weapon points per tree

Today: one Combat pool from Captain levels (about **26 points at Captain 15**) shared by every weapon tree. A weapon
tree costs **85-99 points** in full (its techniques, moves, mechanics, passive, elements, ultimate, variant and 30
step points). That's why mastery 18 black leg showed two abilities.

**Proposal A (recommended): 2 points per mastery level, +1 bonus every 5 levels.** 2 when the tree is found.
| Mastery | 1 | 5 | 10 | 15 | 18 | 20 | 25 | 30 |
|---|---|---|---|---|---|---|---|---|
| Points earned | 2 | 11 | 22 | 33 | 39 | 44 | 55 | 66 |

Black leg at mastery 18 under A: every node unlocked by 18 costs **39 points**, so you'd own all of them:
| Lv | Node | Kind | Cost |
|---|---|---|---|
| 2 | Handstand Spin | move | 2 |
| 3 | Shin Guard | mech | 2 |
| 4 | Arrow Kick | move | 2 |
| 5 | Hailstorm Heels | tech | 3 |
| 6 | Cyclone Heel | move | 2 |
| 8 | Mule Kick | tech | 3 |
| 10 | Nonchalance / Cartwheel Crescent | mech / tech | 3 / 4 |
| 12 | Cleaver Kick | tech | 4 |
| 13 | Galley Tempo | passive | 4 |
| 14 | Flambe Dash | tech | 4 |
| 16 | Searing Heel | element | 6 |

At 30 you'd own about 70% of a tree: every active, plus a choice among the steps, the variant and the second element.
Choices still matter, but nothing you've unlocked sits unaffordable.

**Proposal B: 3 points a level** (90 at 30): you own the whole tree by the top, and choices only matter on the way up.

Captain levels then give **stats + the Captain tree** only. Existing saves: every point spent is refunded once, and
your trees are re-bought at the new prices (you keep what you had).

**Call: A or B?**

---

## 2. Will (paths, points, slots)

**Will points** (no Will is tied to a specific boss or theme):
| Source | Points |
|---|---|
| An island's beast boss or an arc's villain | 2 |
| A named Admiralty hunter | 2 |
| A rival crew's captain, an outpost's sergeant, a miniboss | 1 |
| Meditation on deck (a sailing-downtime activity) | 1 per 3 game days of meditating |

**Paths** (pick one first; a second is open from 8 points spent; Captain's Will needs 4 in each):
| Path | Tier 1 (1 pt each) | Tier 2 (2 pts, from 4 spent) | Tier 3 (3 pts, from 8 spent) | Its passive (slotted) |
|---|---|---|---|---|
| **Iron Will** | Coat (fists or weapon: hits ignore a share of armour) | Emission (a coated strike lands at range, 6 m) | Inner Strike (through guards and armour, staggers on hit) | Hardening (+8 defence, energy +20%) |
| **Sense** | Flash (attacks flash red as they start) | Foresight (a perfect dodge slows time for 0.6 s) | Crowd Read (see every foe's next move for 4 s) | Instinct (8% of blows sidestepped) |
| **Captain's Will** | - | Roar (weak foes round you drop; others stagger) | Clash (Will clashes: timed presses decide them) | King's Will (+6% damage, +20 health) |

**Versions** (switched at a rest spot): each tier-1 and tier-2 ability has 2-3 versions, e.g. **Coat:** heavier hits /
faster combo / hits through blocks; **Flash:** longer warning / also shows ranged shots / also on bosses' big moves.

**Your colour:** pick a Will colour and aura (black lightning, red crackle, blue haze, gold) at the first Will node; crewmates see it.

**Passive slots:** 2 at the start, +1 at Captain levels 10, 20 and 30 (5 at most). Will passives are bought and slotted
like any other.

**Call: are the Will point sources and the three paths right?** (Path abilities and their numbers get tuned in play.)

---

## 3. Poise and knockdowns

Every enemy has **poise** (hidden; a stagger shows it). Hits drain it, and it refills 2 s after the last hit. Empty, the
enemy is **knocked down or staggered hard**, and then **immune for 4 s** (its poise refills). Knockdown moves no longer
knock down on their own: they drain a lot of poise.

| Enemy | Poise | Refill / s | Notes |
|---|---|---|---|
| Grunt | 30 | 12 | any hit of 10+ still flinches it |
| Elite grunt, rival crewman | 55 | 15 | flinches only on heavies |
| Captain (camp boss), outpost sergeant | 90 | 18 | never flinches on lights |
| Rival captain, Admiralty hunter | 80 | 20 | the captain AI, so it dodges too |
| Miniboss / roamer | 160 | 25 | |
| Beast boss | 400 (+25% each phase) | 30 | a break = the stagger pose + 3 s of double damage |

| Your move | Poise damage |
|---|---|
| Light hit | 6 |
| Combo finisher | 14 |
| Heavy (right-click) | 25 |
| Kick moves (Arrow Kick, Cyclone Heel, Handstand Spin) | 30 |
| Technique | 35-60 by the technique |
| Ultimate | 120 |
| Shot (pistol) | 4 (12 point-blank) |

So a grunt goes down from one kick move or two heavies, but not again for 4 s. A boss takes a planned chain (a
technique, a heavy and a kick, or part breaks) to break.

**Call: do these feel right as a starting point (tuned in play), and should poise stay hidden?** (It's hidden today;
you didn't pick the visible bar earlier.)

---

## 4. Smarter enemies

| Behaviour | What it does |
|---|---|
| Defend | A sword grunt blocks about 25% of front hits (never twice in a row without a counter); 15% sidestep; a **shield grunt** (new, 1 in 6 on tier 2+) blocks everything from the front until a heavy, a kick or a flank breaks the guard |
| Group tactics | 2-3 attackers per captain at once (more at higher tier), with clear tells; riflemen keep 10-15 m and reposition; a **horn-blower** calls the nearest camp's help after 8 s if left alive; a camp captain gives nearby men +15% damage (kill him first) |
| Elites | 1 in 6 enemies on tier 2+, 1 in 4 on tier 3+, with one trait: **Armoured** (+50% poise), **Berserk** (faster, no flinch under 30% health), **Quick** (dodges more, shorter tells), **Burning** (hits set you alight), with a tinted aura |
| Punish | Whiff a heavy in front of a grunt and he counters within 1 s; block a brute three times and he grabs you (mash to break) |

**Call: OK as listed?**

---

## 5. Island arcs (10 templates)

Each island rolls one from the pool that fits its theme. Beat 1: arrive and hear of it (the elder, rumours, a poster).
Beat 2: investigate or help (2-3 of the island's places as story steps). Beat 3: the showdown with the villain (the
island's boss). **Reply choices** come at the villain's first meeting and at one moment in beat 2. **Hidden finishes**
pay extra.

| # | Arc | Villain | Beat 2 | A reply that changes things | Hidden finish |
|---|---|---|---|---|---|
| 1 | The Tyrant's Tax | a pirate warlord bleeding the village | break his collectors at the camp, take back the strongbox | pay his tax (he leaves you alone, the village hates you) / refuse (he sends men tonight) | beat him without killing his men (they surrender) |
| 2 | Iron Boot | a corrupt Admiralty captain | free the prisoner, steal his ledger from the outpost | bribe him (the outpost looks away) / expose him (a showdown now) | win with the ledger in hand: his own men turn on him |
| 3 | The Beast of the Hollow | the island's beast boss | track it, defend the village at night (a wave) | hunt it now / set a trap (it comes to you, wounded) | break both its parts before it falls |
| 4 | The Stolen Heirloom | a thieves' captain | three witnesses, a stealthy way into the hideout (a cave) | buy it back / take it back | finish him without being spotted first |
| 5 | The Cursed Festival | a ghost captain (fog isle) | light the festival lanterns, banish the drowned | promise the dead their offering / defy them | keep every lantern lit through the fight |
| 6 | The Rebellion | the outpost's commander | arm the villagers (deliveries), raid the outpost | lead the charge / let the villagers fight beside you | no villager falls |
| 7 | The Castaway Noble | a rival crew wanting the ransom | find the castaway, escort them through the wilds | hand them over for gold / defend them | the noble lands a blow on the rival captain |
| 8 | The Poisoned Well | the Brood Queen | herbs for the healer, clear the nest | cure the village first / chase the queen | win before the poison timer runs out |
| 9 | The Champion's Challenge | the island's swordmaster | beat three students | fight fair (no techniques) / fight dirty | win fair: a unique technique variant |
| 10 | The Treasure Race | a rival crew | three map pieces, a dive or a cave | share the find / race them | reach it first and hold it |

Rewards: the arc's chest (gold, a trait weapon a tier up), bounty, Will points; a hidden finish adds a unique reward
(a named weapon, a technique variant or a flag emblem). The log pose still works without an arc. The villagers'
traders, quests and rumours point at the arc.

**Call: is this pool right? Cut, add or change any.**

---

## 6. The beast pass: three bosses first, phases that escalate

Rule for every boss: **each phase adds moves it didn't have** (not faster copies), **shortens its openings**, and
**chains moves** (phase 1 single moves; phase 2 a move then another; phase 3 three in a row with one long opening at the
end). Every phase change gets a moment: it staggers, roars, the camera punches in, its look changes (cracked armour, a
glow, steam), and a ring of dust pushes you back. Motion: body sway, head tracking, tail and mane on springs,
anticipation and follow-through on every attack, hit reactions, and a stagger pose when poise breaks.

### The Silverback (jungle)
| Phase | Moves (new in bold) | Tempo |
|---|---|---|
| 1 (100-60%) | Swipe, Slam (KO), Leap, Throw | single moves, 1.4 s openings |
| 2 (60-30%) | + **Canopy Drop** (climbs, drops on you), **Rock Barrage** (three throws in a row) | pairs (Swipe -> Leap), 1.1 s openings |
| 3 (<30%) | + **Grab** (mash out), **Berserk Pound** (four slams walking at you, cracks the floor) | chains of three, 0.8 s openings, +15% speed |
Parts to break: **tusks** (no Grab once broken; drops ivory), **fists** (Slam's dust ring shrinks). Its effect:
chest-beat shockwave rings, leaves raining from the canopy on every slam.

### The Sand King (desert)
| Phase | Moves | Tempo |
|---|---|---|
| 1 | Erupt, Bite, Slam (KO), Dive (once) | singles |
| 2 | + **Sinkhole**, **Acid Spit** | pairs; never the same move twice in a row |
| 3 | + **Twin** (a second worm), **Sandstorm** (the arena fills with blowing sand; it hunts by sound, so stand still to lose it) | chains of three |
Parts: **armour plates** (two, on its back: run up it during Slam's opening and break them; each one +25% damage
taken), **mandibles** (no Bite once broken). Effect: sand geysers, a heat shimmer, a roar that bends the sand.

### The Bear King (snow, rebuilt body)
| Phase | Moves | Tempo |
|---|---|---|
| 1 | Maul, Charge, Swat | singles |
| 2 | + Body Slam (KO), Fish-scoop (snow chunk) | pairs |
| 3 | + Frenzy (four-swipe chain), **Avalanche Roar** (snow slides from the arena's walls in lanes) | chains, foaming, red eyes |
Parts: **claws** (Frenzy is two swipes, not four), **hide** (a broken patch takes double damage). Effect: breath in
the cold, snow kicked up on every step, an icicle fall on the roar.

The other 14 bosses get the same treatment after these three, each with its 1.20 move list as phase 1.

**Roamers (fewer, with behaviour):** one roamer an island at most, half the islands. Herds graze and bolt together,
predators stalk from cover and ambush, territorial beasts posture and roar before charging (a 2 s warning, back off
and they settle). The roamer is an event you hear first (a roar across the island, birds lifting off), then a short
hunt.

**Call: do these three show the escalation you want, and is the roamer plan right?** Then I build the three and
send you a render sheet plus a test build.

---

## 7. Bounty as heat

| Tier | Bounty | At sea | On islands | Rewards |
|---|---|---|---|---|
| 0 | <5,000 | the odd patrol, ignores you | - | - |
| Wanted | 5,000 | patrols come about if they see you | posters; Admiralty shops +15% | +10% chest gold |
| Notorious | 20,000 | 1-2 hunters chase you; blockades after island bosses | bounty hunters; elites +5% | +20% gold, purple a bit likelier |
| Infamous | 60,000 | a fleet rings you after island bosses; a named hunter on your wake | Admiralty shops refuse you; elites +10% | +30% gold |
| Dreaded | 150,000 | the hunters come in pairs; the Admiralty waits at harbours | the strongest rival crews seek you | +40% gold, gold-tier a bit likelier |

You raise it by sinking, raiding and beating; you can **lie low** too: a day without a deed takes 2% off the heat (not the
number), so patrols thin out.

**Call: OK as the curve?**
