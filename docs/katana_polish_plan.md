# Katana animation and effects pass (plan, 2026-10-17)

## What it is
The katana keeps its combo pattern (the overhead diagonal slash, the side slash, the stab dash) but its
animations and slash effects are redone so every effect follows the blade's real path, and its effects move to
the drawn flipbook style the cutlass got on 2026-10-16 (docs/dev_notes.md "the cutlass's drawn water";
driftwake-fx "Drawn elements"): big, cloudy, pixelated animated slashes with sakura petals. Its mastery
awakening (the tree's element passive) gets the cutlass's level of treatment, and all five katana abilities get
an animation, timing and effects polish.

## Decided (2026-10-17)

| Decision | Choice | Why | Revisit when |
|---|---|---|---|
| Combo pattern | Keep: overhead diagonal (`katana_r`), side slash (`katana_l`), stab dash (`katana_stab`); fix the animations | Zach likes the pattern; the poses and arcs don't match | - |
| Slash direction | Every slash effect follows the blade's actual hand path for that move (from the animation, not a hand-set angle), so a diagonal looks diagonal and a side cut is level | Zach's main complaint | - |
| Awakening scope | **Katana now**, to the cutlass's drawn-water level; the axe, daggers, dual and corsair follow later, one pass each with its own element | One weapon done properly; they'd share fx.gd anyway | After this lands |
| Awakened look | **Steel-blue cloud, pink petals**: billowing pixel-cloud crescents in the tree's pale steel and blue-white, edges curling like the cutlass's water, shedding sakura petals that drift and fall; an awakened-blade aura of the same (the BladeWater pattern) | Keeps the katana's colour identity | Play-test |
| Plain swings | A **smaller drawn-style crescent** in plain steel and dust, no petals, that follows the blade; awakening adds the cloud and petals | Mastery reads as an upgrade | - |
| Abilities | **All five**: Tiger Rush, Wind Severer, Phantom Step, Iai Counter, Thousand Petals (ult): animation, timing, hit reliability and the new drawn effects on each; the ult is the showpiece | Zach's pick | - |
| Art | Generated sheets in their own generator (`tools/texture_gen/gen_katana_fx.py`, like gen_water_fx.py), so the shared sheet library and t/fx/sheets stay as they are | The cutlass's precedent | - |
| Co-op | Hits as today (host-arbitrated through melee_hit); effects on every screen via Net.fx; the awakened aura on puppets by a snapshot flag (the cutlass's NF_TIDE pattern) | Standing rule | - |
| Feel | Shonen, readable, punchy, not cartoony; walk/sprint/stance numbers unchanged | Standing rule | - |

### Order
1. The combo: animations fixed (the three moves and the air slash), slash effects laid along the blade's real
   path, the plain drawn steel slash. Lands on its own.
2. The awakening: petal-cloud sheets, awakened slashes, drawn hits (`FX.elem_hit` "katana"), the blade aura.
3. The abilities, one at a time, the ult last.

### Open / deferred
- **assumed:** each ability keeps what it does (its description in Skills.ALL); the agent may propose behaviour
  tweaks in its report but changes only animation, timing, reliability and effects.
- **assumed:** iai (heavy: hold to charge, attack to draw) and the plunge get the new slash look too where they
  share the combo's effects.
- Other weapons' awakenings: later passes, one weapon at a time.
