# Axe pass: drawn fire, two new abilities (plan, 2026-10-17)

## What it is
The second weapon in the weapon-by-weapon drawn-awakening series, after the katana (docs/katana_polish_plan.md;
the cutlass's drawn water before it). **Starts once the katana pass has landed** (they share fx.gd, humanoid.gd,
the technique and attack states and skills.gd). The axe's combo gets the katana's fix (effects on the blade's real
path, a plain drawn crescent), its awakening becomes drawn fire and embers, its four abilities (Berserk,
Earthsplitter, Hatchet Throw, Maelstrom) are polished, and it gains two: **Skyfall Smash** and **War Cry**.

## Decided (2026-10-17)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Series | Drawn awakenings weapon by weapon (katana, then axe, then the rest one at a time) | Zach's pick over polearms / fruits / breadth first | After the axe |
| Next weapon | **Axe** | Fewest abilities (4), a clear element | - |
| Look | **Fire and embers**: molten orange-to-crimson cloud crescents with a charred edge, ember sparks and drifting ash; flame licking along the bite once awakened (the blade aura, BladeWater pattern) | Its tree colours are already ember | Play-test |
| Combo | The katana's fix: every swing's effect on the blade's real path, animation fixed where they disagree, a plain drawn crescent (steel and dust) when not awakened | Same complaint would apply | - |
| Existing abilities | Berserk, Earthsplitter, Hatchet Throw, Maelstrom: animation, timing, reliability, drawn effects | The katana pass's standard | - |
| New: Skyfall Smash | Leap high and drive the axe down; the further you fall (off a ledge, the rigging), the bigger the crater and knockdown ring | Zach's pick | Tune in play |
| New: War Cry | A roar that staggers everyone close, breaks guards, and gives a short burst of armour | Zach's pick | Tune in play |
| Co-op / feel | As the katana's: Net.fx, the aura on puppets by a snapshot flag; shonen, readable, punchy | Standing rules | - |

### Order
1. The combo fix and the plain crescent.  2. The drawn fire awakening (sheets in their own generator, like
gen_water_fx.py / gen_katana_fx.py), elem_hit "axe", the blade aura.  3. The four abilities.  4. Skyfall Smash,
War Cry (skill entries, tree nodes, icons, poses, tests).

### Open / deferred
- **assumed:** the new abilities' costs, cooldowns and tree positions follow the katana tree's pattern; the agent
  places them and says where.
- **assumed:** reuse what the katana pass builds (the path-following ribbon, the sheet pipeline) rather than a second
  copy; if the katana's helper is katana-specific, generalise it first.
