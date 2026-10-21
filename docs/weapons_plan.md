# The remaining weapons (1.21)

## What it is
The roadmap's 1.21 "remaining weapons": eight new weapon kinds, each with its own stance, moveset and mastery tree, built
and landed one kind at a time. The game already has fist, cutlass, katana, axe, dagger, dual swords, twin daggers,
Corsair (cutlass + pistol), pistol and dual pistols (plus the hybrid's claw). Grilled with Zach 2026-10-20.

## Decided (2026-10-20)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Kinds in this push | Polearm, hammer/kanabo, dual axes, greatsword, black-leg kicks, long guns, cannon, slingshot | Zach picked all of the candidates offered, plus a cannon/large firearm | After all eight land |
| Order | Polearm, hammer/kanabo, dual axes, greatsword, black-leg, long guns, cannon, slingshot (melee then ranged) | Melee kinds reuse the swing/hand-path tooling back to back; the guns share aiming and ammo work | — |
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
| Enemies | Player only for now; one enemy pass after all kinds land (spearmen, hammer brutes, cannoneers...) | Zach's pick | After the eighth kind |
| Co-op | Standing rule: everything works for a guest (puppets show the stance and moves, hits go through Net) | CLAUDE.md | — |

## Decided (2026-10-21): stance poses from Zach's reference images
| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Greatsword guard | A **low guard**: both hands on the hilt at the right hip, the blade angled down and forward across the body, its tip near the ground on the left (Zach's photo of a swordsman holding a long blade down). Replaces the shoulder rest | Zach's reference | Play |
| Greatsword moving | Low guard standing and walking; **at a sprint the tip drags behind and scrapes sparks off the ground** | Zach's pick | Play |
| Hammer guard | Raised so the head **rests on top of the shoulder**: today it sits too low and clips into the shoulder/chest with some designs | Zach's report | — |
| Polearm run | **Running and sprinting**: one hand, the polearm trailed low at the side, head forward and down (Zach's anime reference of a runner with a naginata). Walking keeps the two-handed guard. Not gated | Zach's pick | Play |
| Polearm planted stance | **Whitebeard's pose**: the butt planted on the ground beside you, the pole upright, one hand high on the shaft, chest out. A big node in the Polearm tree at mastery ~10; before it, standing still shows the guard | A visible sign of mastery, free in balance | — |
| Plant vs guard | Planted when standing still with no attack, block or parry in the last ~3 s; anything comes straight out of it with no delay, and the readied guard holds for ~3 s after | Calm confidence without costing responsiveness | Play |

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
- **Black-leg feel** (**assumed**): hands stay free (in the pockets on the guard), kick combos, a handstand spinning kick,
  a heated kick as the ultimate's element; fists family.
- **Long-gun melee** (**assumed**): a butt stroke when foes close in; reload as part of the rhythm.
- **Families** (**assumed**): polearm in blades; hammer, dual axes, greatsword in heavy; long guns, cannon, slingshot in guns;
  black-leg in fists.
- **Two-handed kinds** (**assumed**): polearm, hammer, greatsword, long guns and cannon take both hands (no off hand).
- **Sheathe/draw animations and sounds per kind**: the existing todo item, later.
- **Each kind's colour/element identity**: chosen by the builder per kind, shown in its report.
- Later: the enemy pass, the flipbook awakenings, the remaining todo kinds (three-sword style, cane sword, staff, whip,
  claws, jitte/tonfa, shields).
