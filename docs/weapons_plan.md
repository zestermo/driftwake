# The remaining weapons (1.21)

## What it is
The roadmap's 1.21 "remaining weapons": eight new weapon kinds, each with its own stance, moveset and mastery tree, built
and landed one kind at a time. The game already has fist, cutlass, katana, axe, dagger, dual swords, twin daggers,
Corsair (cutlass + pistol), pistol and dual pistols (plus the hybrid's claw). Grilled with Zach 2026-10-20.

## Decided (2026-10-20)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Kinds in this push | Polearm, hammer/kanabo, dual axes, greatsword, black-leg kicks, long guns, cannon, slingshot | Zach picked all of the candidates offered, plus a cannon/large firearm | After all eight land |
| Order | Polearm, hammer/kanabo, dual axes, greatsword, black-leg. **Black-leg is the last for now** (Zach, 2026-10-21): long guns, cannon and slingshot moved to docs/todo.md ("The ranged weapon kinds"); their rows below stay as the decided spec for when they come back | Melee kinds reuse the swing/hand-path tooling back to back | When the ranged kinds are picked up |
| Stances | **One stance per kind** (its guard pose, gait and moveset), as today; no switching within a weapon | Zach's pick | — |
| Landing | One kind at a time, end to end, landed before the next starts; keep moving through all eight without stopping for a check-in | Zach: "one at a time ... just continue moving through all the remaining weapons" | — |
| Testing | **Minimal until all eight are in:** per kind, one small atomic test group (`t/weapons/<kind>`: equip it, the light combo and heavy land on a dummy, the tree's entries are valid), `land.ps1 -NoTests`. No world suites and no nettest until the end; then one `prepush.ps1` run and a fix pass | Zach: keep testing straightforward and very minimal until we finish all of them | When all eight are landed |
| Variants within a kind | One moveset per kind; variants differ in model, reach, speed, damage and roll traits like today's weapons (trident pierces, bisento sweeps wider) | Cheap to add variants later | — |
| Polearm identity | Reach + sweeps: fast thrusts at range, wide spinning sweeps that clear a crowd, a pole vault; heavy variants (bisento) hit harder and slower. Keep foes at the tip | Zach's pick | Play |
| Cannon | Its own kind (hand cannon / shoulder bazooka): slow, explosive splash, big knockback, recoil pushes you back, long reload. Guns family | Zach's pick | — |
| Long guns | Musket/rifle (aimed long shot) and blunderbuss (close spread) as one two-handed kind | Cannon split out | — |
| Slingshot | Its own light ranged kind with trick ammo (fire, smoke, explosive, sticky) as its identity. Throwing knives/chakrams are dagger-tree techniques later, not a kind | Zach's pick | — |
| Depth per kind | Moveset (light combo, heavy, running and air attacks, block/parry), a three-branch mastery tree with its techniques and an ultimate, a colour identity in `FX.TREE_FX`. No drawn flipbook awakening: that joins the katana/axe series later | Zach's pick | — |
| Sources | Into the existing loot pools and weapon shops. Polearm, hammer, long guns, slingshot drop like cutlasses; cannon and greatsword are rarer (bosses, chests, specialist shops). Black-leg is learned (a trainer or manual), not found | Zach's pick | Economy pass |
| Enemies | Player only for now; the enemy pass ships with **1.19** (Zach, 2026-10-21; docs/v1_19_plan.md), alongside its captain-style AI | Zach's pick | 1.19 |
| Co-op | Standing rule: everything works for a guest (puppets show the stance and moves, hits go through Net) | CLAUDE.md | — |

## Decided (2026-10-21): stance poses from Zach's reference images
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Greatsword guard | A **low guard**: both hands on the hilt at the right hip, the blade angled down and forward across the body, its tip near the ground on the left (Zach's photo of a swordsman holding a long blade down). Replaces the shoulder rest | Zach's reference | Play |
| Greatsword moving | Low guard standing and walking; **at a sprint the tip drags behind and scrapes sparks off the ground** | Zach's pick | Play |
| Hammer guard | Raised so the head **rests on top of the shoulder**: today it sits too low and clips into the shoulder/chest with some designs. **Built** 2026-10-21 | Zach's report | — |
| Polearm run | **Running and sprinting**: one hand, the polearm trailed low at the side, head forward and down (Zach's anime reference of a runner with a naginata). Walking keeps the two-handed guard. Not gated. **Built** 2026-10-21 (above 3.2 m/s, not backing off) | Zach's pick | Play |
| Polearm planted stance | **Whitebeard's pose**: the butt planted on the ground beside you, the pole upright, one hand high on the shaft, chest out. A big node in the Polearm tree at mastery ~10; before it, standing still shows the guard. **Built** 2026-10-21: Emperor's Bearing (Guard, 10, mech) | A visible sign of mastery, free in balance | — |
| Plant vs guard | Planted when standing still with no attack, block or parry in the last ~3 s; anything comes straight out of it with no delay, and the readied guard holds for ~3 s after. **Built** 2026-10-21 | Calm confidence without costing responsiveness | Play |

## Decided (2026-10-21): the stance pass over every weapon
A guard render of every weapon (posebench, three-quarter + side) showed the one-handed guards nearly identical above the
hips: upright chest, square to the target, weapon arm pushed out to the side. Zach picked three of four proposals:

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Distinct guards | Each weapon its own silhouette (foot width, weight, chest turn and lean). Cutlass: side-on swashbuckler, lead shoulder to the target, blade forward and low, off hand up behind. Katana: sunk, knees bent, hips back. Axe: wide brawler's stance, hunched, the head on the shoulder or hung low. Dagger: **reverse grip**, blade along the forearm, low crouch on the balls of the feet. Twin daggers: one reverse, one forward, crossed low. Twin axes: hung low and out to the sides, shoulders forward. Pistol: **low ready** (angled down-forward, up only to aim or fire). Corsair: side-on, cutlass forward, pistol back across the chest. Fist: a light bounce. **Built** 2026-10-21 (axe hung low; the dagger reversed in the guard and run only, twirled to the normal grip as a move starts; twin axes kept their berserker's guard; the feet planted in every guard) | They read alike today; shonen stances read from the silhouette first | Play |
| Run poses | A run/sprint carry for every weapon without one: cutlass trailed low by the hip, axe and hammer on the shoulder, daggers reverse-grip with the arms pumping (katana, polearm, greatsword already have theirs). **Built** 2026-10-21 (also the Corsair's and dual swords' blades trailed, the pistol low at the side; the hammer already rode the shoulder) | Zach's pick | Play |
| Breathing + settle | A per-weapon breathing sway in the guard (heavy slow and deep, daggers quick), and a small overshoot settle back into the guard after every attack. **Built** 2026-10-21 (StanceLife; the settle is inside each move's own length) | Life in the stance; the punch lands on the settle | Play |
| Calm poses per weapon | **Not now** (Zach skipped it); the polearm's Emperor's Bearing stays the only one | — | After the stance pass |

### Built
- **Polearm** (2026-10-21): spear + trident, naginata, bisento (rare), halberd, pitchfork; stance with a solved two-handed grip
  (PoleMoves), combo, Skewer heavy, Leg Sweep, Pole Vault, Falling Spear, parry/block; the Polearm tree (Guard / Storm / Reach,
  lightning: TREE_FX "polearm"), Hundred Thrusts, Dragon Sweep, Vaulting Strike, Raijin's Wheel; loot and shops. dev_notes 2026-10-21.
- **Hammer** (2026-10-21): warhammer + kanabo, shipwright's mallet, iron maul, anchor hammer (rare); stance with the head on the
  shoulder and a heavy sway (HammerMoves, its grip solved by PoleMoves.hands), combo (smash, upswing, guard-breaking flat swing,
  Wrecking Spin), Earthquake heavy (a shockwave), Rising Crush, Hammerfall, parry/block on the haft; the Hammer tree (Iron / Quake /
  Weight, earth: TREE_FX "hammer", FX.rock_spikes), Skullcracker, Rolling Quake, Cyclone Crusher, Titan's Fall; loot and shops.
  dev_notes 2026-10-21 (the hammer).
- **Dual axes** (2026-10-21): style "dual_axe" (any axe + any axe; an axe beside another blade is still dual wield), two axes
  equipped main + off hand (no pair item); every axe design pairs, plus the tomahawk and reaver's axe (found two at a time);
  a berserker's guard (DualAxeMoves), combo (right chop, left chop, the hook that hauls them in, Reaping Whirl), Berserker
  Frenzy heavy, Raider's Leap, Buzzsaw, parry/block with crossed axes (a landed parry hooks them in); the Twin Axes tree (Hook /
  Frenzy / Reaver, frost: TREE_FX "dual_axe", FX.frost, ice spikes), Gallows Hook, Hewing Frenzy, Axestorm, Fimbulwinter; loot
  and Haldor's forge. dev_notes 2026-10-21 (the twin axes).
- **Greatsword** (2026-10-21): greatsword + black greatblade, claymore, sawtooth greatblade (bleeds), greatcleaver, Sea King's
  Fang (rare); the low guard from Zach's reference, the point dragged and sparking at a sprint (GreatswordMoves, its grip solved
  by PoleMoves.hands); combo (rising, falling, flat backhand, Gale Turn) with the momentum carry; the charged cleave (hold to
  charge, a full charge flings a gale crescent); Running Cleave, Falling Cleave, parry/block on the flat; the Greatsword tree
  (Bulwark / Gale / Momentum, wind: TREE_FX "greatsword", FX.gust, gale crescents), Guardbreaker, Crescent Gale, Tempest Turns,
  Skysplitter; rarer than the others (no island pool: a kept chest blade sometimes becomes one, a boss's hoard ~30%), Haldor's
  forge and the treasure merchants. dev_notes 2026-10-21 (the greatsword).

### Open / deferred
- **Hammer/kanabo feel** (**assumed**, built that way 2026-10-21): slow, two-handed, staggering; guard breaks and ground slams
  with a shockwave; heavy family.
- **Dual axes feel** (**assumed**, built that way 2026-10-21): fast chained chops from both hands, a whirl, hooking pulls; own style and tree (an axe + an
  axe in the off hand stops counting as dual swords); heavy family.
- **Greatsword feel** (**assumed**, built that way 2026-10-21; the guard became a low guard 2026-10-21): wide arcs whose momentum carries into the next swing,
  armour/guard breaking, a charged overhead; heavy family. Kept distinct from the hammer by sweeping cuts vs blunt slams.
- **Black-leg feel** (Zach, 2026-10-21; was assumed "hands in the pockets"): kick-focused with ACTIVE arms that swing and counter-rotate to balance every kick; moves with the hands planted on the ground (a handstand spinning kick, a hand-planted cartwheel/mule kick, a one-hand braced sweep); the default guard is springy with the hands loose and up for balance. **Hands in the pockets is a mastery pose** (a big node ~10, like Emperor's Bearing): the combat guard once owned, the hands out instantly for any move and back in as it settles. Kick combos,
  a heated kick as the ultimate's element; fists family.
- **Long-gun melee** (**assumed**): a butt stroke when foes close in; reload as part of the rhythm.
- **Families** (**assumed**): polearm in blades; hammer, dual axes, greatsword in heavy; long guns, cannon, slingshot in guns;
  black-leg in fists.
- **Two-handed kinds** (**assumed**): polearm, hammer, greatsword, long guns and cannon take both hands (no off hand).
- **Sheathe/draw animations and sounds per kind**: the existing todo item, later.
- **Each kind's colour/element identity**: chosen by the builder per kind, shown in its report.
- Later: the enemy pass, the flipbook awakenings, the remaining todo kinds (three-sword style, cane sword, staff, whip,
  claws, jitte/tonfa, shields).
