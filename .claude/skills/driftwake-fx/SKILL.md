---
name: driftwake-fx
description: >
  Make visual effects in Driftwake: particles, rings, trails, streaks, glints, spray, water and
  fire bursts, screen flashes, slow motion, camera punch-ins and shake, built in code on the FX
  autoload (scripts/game/fx.gd) and CombatManager. Covers each weapon tree's colour identity
  (FX.TREE_FX), the effect primitives and when to use which, layering an effect (anticipation,
  impact, aftermath), co-op (Net.fx on every screen vs local-only juice), budgets (particles,
  materials, real lights), the PS1 look for effects, and checking them with abilityshot. Use when
  Zach asks for effects, particles, "more impact", "make it look cool", a new spell or ultimate's
  visuals, or an effect that looks wrong (too faint, too busy, wrong colour, lingers, not seen in
  co-op). For how an ability is timed and wired see driftwake-abilities.
---

# Driftwake effects

Every effect is code: `FX` (autoload, `scripts/game/fx.gd`) spawns short-lived nodes that free
themselves, CombatManager owns time and the camera's juice. No imported particle scenes, no
shaders per effect beyond the shared ones (`slash_trail.gdshader`).

**Read first:** grep `docs/dev_notes.md` for the ability or effect, then the effects already
on that tree (`TechniqueState`, `SkillState`, `HeavyAttackState`, `Projectile`).

## How Zach judges an effect

- He plays it, at speed and in slow motion (Shift+F5), from the game camera (behind and above)
  and in F12 captures. It has to read at speed: a big shape for a big moment, small for small.
- What he asked for: polish, particles where appropriate, and **more cool effects on the more
  advanced abilities**: a basic skill gets a clean accent, an ultimate gets a signature moment.
- Picks (2026-10-08): **a colour identity per tree, big ultimates** (a signature moment: slow
  motion, a punch-in, a flash, and one effect only that ultimate has).

## Tree identities (FX.TREE_FX: [CORE, EDGE, ACCENT])

| Tree | Look | Signature materials |
|---|---|---|
| sword (cutlass) | sea spray, blue and white | spray, water tentacles, rings of foam |
| katana | pale steel and white, petals | thin long arcs, petals, afterimages |
| axe | ember orange, rock and dust | dust, sparks, cracks, debris |
| dual | twin colours: cyan and violet crossing | paired trails, X shapes |
| pistol | gold flashes, grey powder smoke | muzzle sparks, tracers, smoke |
| unarmed | white wind, warm dust | punch_wind, rings of air, dust rings |
| haki | crimson and black | dark rings, red sparks, a weight on the screen |

`FX.tree_col(tree, FX.EDGE)`; in TechniqueState `_col(which)` picks the technique's tree (a
riposte answer takes the style's). Core = the hot centre (white-ish): glints, flashes, the
inside of a streak. Edge = the tree's colour: rings, trails, crescents. Accent = the material
(spray, petals, embers). Keep the Haki override: a coated blow trails `Player.HAKI_TRAIL`.

**The element is earned (mastery).** Until the tree's tier-1 mastery passive
(`Progression.elemental(tree)`, flag `elem_<tree>`) its skills are clean and physical: the
"plain" palette (white, steel, dust), rings, dust, streaks, glints; no spray, petals, embers,
tentacles or other signature material. `_col()` already falls back to "plain"; gate the
material with `_elem()` (or `_spray()` for the cutlass) and give the plain version its own
weight (Kraken's Wake: a dust gather and rings instead of tentacles). Tier 2
(`elemental(tree, 2)`) puts the element on the basics: the trail of lights and heavies in the
tree's edge colour, `FX.elem_hit` on each light/heavy/plunge hit (PowerComponent.on_sword_hit).
Projectiles carry it as model `"elem"`. Film both: `AB_TIER=0` and the default 2.

## Primitives (FX.*; all callable through Net.fx)

| Call | What | Use for |
|---|---|---|
| `ring(pos, normal, radius, color, life, width)` | a band racing out and fading, flat to `normal` | UP: a blow landing, a release of force; a direction: air round a thrust's point, a punch, a projectile's launch |
| `spray(pos, dir, amount, color, speed)` | droplets in an arc that fall back, plus mist | water (the cutlass), blood-free hit splash, a wake behind projectiles |
| `gather(pos, radius, color, secs, amount)` | motes rushing in to a point | wind-ups and charges: power drawn to the blade or the fist |
| `streak(from, to, color, width, life)` | a hot-cored line that thins | blinks, dashes, lunges (the path you took) |
| `glint(pos, color, size)` | a star flash | the blade catching the light: the beat before a strike, a guard waiting |
| `water_tentacles(pos, height, color, count, seed)` | curling water tubes rise, hang, fall as spray | the Kraken's Wake (the sword ult's signature) |
| `screen_flash(at, color_with_alpha, secs)` | a full-screen flash for a camera within 35 m | an ultimate's moment (alpha 0.2-0.45) |
| `impact(pos, color)`, `parry_sparks(pos, dir)` | flash + sparks | every hit; clashes |
| `sparkle`, `dust`, `dust_ring`, `smoke`, `splash`, `muzzle_sparks`, `tracer`, `flame`, `fire_ring`, `fire_pillar`, `punch_wind`, `afterimage`, `blood` | the older set | see their doc comments in fx.gd |
| `blade_swoosh(body, secs, color)` | the real blade's trail (BladeTrail) | any strike where the blade moves: swing paths and keyed technique cuts alike |
| `slash(follow, kind, dur, color)` | a fixed arc mesh | spins and wide arcs the blade alone can't show (keep few; prefer blade_swoosh) |

CombatManager: `apply_hitstop(secs, bodies)`, `apply_camera_shake(intensity)`,
`apply_slowmo(scale, secs, ease_out)` (single player; hit-stop returns to it, not to full speed;
the anim lab's Shift+F5 goes through it too), `apply_camera_kick(amount 0..1, secs)` (the view
narrows and the arm draws in, then eases out; real time).

## Layering an effect (the recipe)

1. **Anticipation**: `gather` to where the power will leave from, a `glint` on the blade a
   beat before the strike (0.05-0.1 s before contact), a faint ground `ring` for a big one.
2. **Release**: the trail (`blade_swoosh` or the projectile), a `ring` at the point or round
   the body, the tree's material (`spray` for the cutlass) thrown along the motion, the sound.
3. **Impact** on each victim: `impact` in the accent colour, a small ring along the blow,
   material thrown away from you. Hit-stop and shake come from the HitData, not by hand.
4. **Aftermath**: dust settling, a lingering glint, smoke. Short: 0.3-0.6 s.
5. **Ultimates only: the moment.** `_moment(slow, secs, kick, flash)` in TechniqueState
   (slow motion ~0.3-0.4 for 0.25-0.35 s, punch-in 0.45-0.7, flash 0.2-0.45) at the start
   (gather) and/or at the payoff, plus **one effect unique to it** (Kraken's Wake: water
   tentacles under every victim). Basic skills may kick the camera lightly (0.1-0.25), never
   slow time.

Scale with the ability's tier: a light skill 1-2 layers, a heavy or a finisher 3, an ultimate
all five. Repeated hits (flurries) get small per-hit accents and one bigger one on the last.

## Co-op

- **Net.fx(method, args)** runs `FX.method(args)` here and on every other screen (args: Vector3,
  Color, float, int, String, nodes by key). Use it for everything another player should see.
- **Local only**: hit-stop, shake, slow motion, camera kick (they're your screen's juice).
  `screen_flash` is sent but shows only for cameras within 35 m.
- Projectiles run on every screen already (`net_power("projectile")`): their own effects call
  `FX.*` directly, never Net.fx (or every screen would send them again).
- Randomness in a sent effect is fine (each screen gets the same args); seeded shapes take a
  `seed` arg (`water_tentacles`).

## Budgets and the PS1 look

- Bursts beyond `FX.BURST_RANGE` (160 m) are skipped; keep it so for new primitives.
- Particles: a burst 4-20 typical, 30 for an ultimate. Every burst is a node + a CPUParticles3D:
  a flurry firing every 0.1 s at 20 is too much; 3-6 per hit.
- Additive unshaded materials (`_glow_mat`) for light; each effect owns its material only when
  it tweens it (fading); otherwise share (`_quad`, `_curve`, `_fade_to_clear` caches).
- No real lights in effects (the lighting budget is the village's NightLights). Glow is emissive.
- Shapes, not noise: a few bold rings and streaks read on a 640x360 grid; a cloud of tiny
  sparks turns to mush. Billboards stay `TEXTURE_FILTER_NEAREST`.
- Effects in slow motion slow with the world (tweens and particles run on scaled time) except
  `screen_flash` (real time).

## Checking

```powershell
# a skill filmed on a clean stage against three staggered grunts: one row per view, frames along
# game time (held frames = hit-stop / slow motion). Args: out, skill (or "heavy" /
# "riposte_counter"), style, views (game,side,front3,top), frames, span s, start s
& $env:GODOT --path . --script res://tools/dev/abilityshot.gd -- res://tools/dev/out/abil/x kraken_wake sword game,side 10 2.2
$env:AB_HOUR='21'   # at night: does it glow?
$env:AB_TIER='0'    # mastery tier 0/1/2 (default 2): the plain version before the element
```

Read every sheet: does each layer appear when it should, is the tree colour right, is the
ultimate's moment unmistakable, does anything linger or clutter the frame, is the body still
readable through it. Then run the ability's suites (techtest for techniques) and `nettest.ps1`.

## Symptom -> cause

| Zach sees | Cause | Fix |
|---|---|---|
| effect not there in co-op | called FX.* directly from a state | Net.fx |
| doubled effect in co-op | a projectile / puppet sent Net.fx | projectiles and puppets call FX.* |
| everything slow-motion forever | slow motion set Engine.time_scale directly, a hit-stop "restored" it | only CombatManager touches time_scale |
| flash/slow on the wrong screen | juice sent through Net.fx | local calls for juice |
| mush of sparks | too many small particles | fewer, bigger shapes; rings and streaks |
| a ring buried in the ground | flat ring at foot height | rings on UP sit 8 cm up (ring() does it) |
| effect in the wrong place mid-spin | position read before the body moved | read the blade (`_blade_tip()`), the hand, or the chest at the moment it fires |
