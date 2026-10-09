---
name: driftwake-abilities
description: >
  Make or polish the player's abilities in Driftwake: weapon techniques and ultimates
  (TechniqueState), skills and fruit powers (SkillState), heavy attacks (HeavyAttackState),
  projectiles (Projectile), from the skill's entry (Skills.ALL, SkillTree nodes, icons) through
  its timeline in seconds (wind-up, the moments it hits, recovery), targeting (cones, rings,
  lines, aimed, grabs, blinks), damage through Player.melee_hit, its keyed poses
  (TechniquePoses), its effects and juice (with driftwake-fx), co-op, and filming and testing it
  (abilityshot, techtest). Use when Zach asks for a new skill, technique, ultimate, grapple or
  power, wants abilities polished ("refine", "add fx", "make the ult feel big"), or reports an
  ability bug ("doesn't hit", "whiffs", "fires late", "nothing in co-op").
---

# Driftwake abilities

An ability is four things kept in step: **the data** (what it is, what it costs, where it sits
in a tree), **the timeline** (a state that runs it in seconds), **the body** (keyed poses played
by name), **the show** (effects, sound, juice). Polish means the four line up: the pose's strike
key, the damage moment and the effect all land on the same beat.

**Read first:** grep `docs/dev_notes.md` for the skill and its tree; the driftwake-animation
skill for poses, driftwake-fx for effects, driftwake-coop for anything new a guest must see.

## How Zach judges an ability

- He equips it and uses it in a fight (on grunts at the smugglers' camp), from the game camera,
  at speed and in slow motion (Shift+F5). It must read: the wind-up says what's coming, the hit
  lands on the frame the pose strikes, the payoff is bigger than the cost.
- Asks (2026-10-08): a pass over every weapon skill and animation, refine and polish, effects
  where they fit, **cooler effects on the more advanced abilities**. Picks: one tree at a time
  (cutlass first) with a check-in between, keyed poses polished (not rebuilt on swing paths),
  a colour identity per tree, big ultimates.

## Where things are

| Piece | File | Notes |
|---|---|---|
| Skill data | `scripts/progression/skills.gd` (`Skills.ALL`) | name, tree, cost (energy), cooldown, `styles` / `needs_text` (what's in hand), `"state": "Technique"` or a SkillState id, desc; `is_ult`; `icon` |
| Tree nodes | `scripts/progression/skill_tree.gd` | `_add(id, name, kind, region, _g(col,row), links, effects, desc, req, skill)`; weapon trees paid with mastery |
| Casting | `scripts/powers/power_component.gd` | `equip(id, slot)` (slot 4 = R ult), `can_cast`, `try_cast` -> the state; energy, ult meter, cooldowns, buffs, `enemies_in`, `blast` |
| Techniques | `scripts/player_states/technique_state.gd` | weapon/unarmed techniques, ults, grapples, guards; helpers below |
| Skills/powers | `scripts/player_states/skill_state.gd` | Soru, Tekkai, Flying Slash, Tiger Rush, Bullet Storm, Haki, Wolf/Vine/Ember fruits |
| Heavies | `scripts/player_states/heavy_attack_state.gd` | `STYLES` per weapon: anim, impulse, damage, trail, `"tree"` for effects |
| Projectiles | `scripts/powers/projectile.gd` | slash, wave, axe, seed; run on every screen |
| Poses | `scripts/npc/technique_poses.gd` (`TechniquePoses.pose`) | reached from `Humanoid._action_pose` for names it doesn't know |
| Specs | `scripts/npc/action_specs.gd` | every action: len, hit window, stance/weapon for previews |
| Icons | `tools/texture_gen/gen_psx_textures.py` `gen_technique_icons` | `py ... techniques` |

## TechniqueState in brief

`enter` picks the length (`dur`), plays the pose, sets up targets; `physics_update` runs the
timeline with one-shots `_once("key", t_seconds)`; `t >= dur` finishes. Helpers:
- movement: `_rooted(delta, keep)`, `_drift(delta, speed)`, `_place(p)`, `_blink_behind(e)`.
- targets: `_closest(reach, n)`, `_nearest(reach, front)`, `_aimed(reach)` (by camera aim),
  `_grab_target()` (light, not bosses), `_reticle_target(reach)` (snaps to a chest), `_body_center(e)`.
- hits: `_cone(reach, cos, base, knock, down, unblock)`, `_ring(...)`, `_spin_hits(...)`,
  `_hd(base, knock, down)` (through `player.melee_hit(base, "skill")`), `_strike(e, hd)`,
  `_strike_toward(e, hd, push)` (knockback along `push`), `_split(...)` (a line).
- show: `_tree()`, `_col(FX.EDGE)`, `_blade_tip()`, `_chest()`, `_moment(slow, secs, kick, flash)`.
- `_refund(why)` when there's nothing to use it on (gives energy/ult and the cooldown back).

## The beat sheet (write this first)

For each ability, a table in seconds before touching code:

| t (s) | pose key | gameplay | show |
|---|---|---|---|
| 0 | guard -> wind-up | | gather, sfx |
| 0.12 | wind-up held | | glint on the blade |
| 0.2 | strike key ("out") | damage (`_once`) | trail, ring, material, impact |
| 0.2-0.5 | follow-through held | | aftermath |
| dur | guard | finish | |

- **Damage lands on the pose's strike key**, never before the wind-up has read. A pose keyed
  in u: strike at u_k means `_once("hit", u_k * dur)`; moves played at varied lengths key their
  beats in seconds (`s / T`, see `TechniquePoses`).
- The ActionSpecs `"hit"` window covers the strike (animsheet's red bar sits under it).
- Wind-up length is the readability budget: a basic skill 0.1-0.2 s, a heavy 0.2-0.3 s, an
  ultimate's gather 0.35-0.5 s (with its moment).
- Multi-hit: hits on a fixed rhythm (0.1-0.15 s), the last bigger (knockdown, ring, kick).
- Ultimates: invulnerable through the dangerous part (`hurtbox monitorable false`, restored in
  `exit()` and at the payoff); the payoff after a held beat (Kraken's Wake: blinks, then your
  back to them, a glint, then everything tears).

## Polishing a pose (keyed)

The animation skill's keyed rules, applied: key **every joint** on main keys (hips and head
too), head counters the chest, wrist cocked in the wind-up and flung through the strike,
`_lift` keyed, `"_scale"` squash on the gather / stretch along the motion on the strike,
`"_smear"` (x: blade stretch) only on the one fast key (not held), a held follow-through, back
to `_guard()`. Big turns load *away* from the cut. Check with animsheet (shortest length the
game plays) and from behind.

## Effects (driftwake-fx)

Every ability gets: its tree colours (`_col`), a glint before blade strikes, the release
(blade_swoosh / projectile / ring), impacts in the accent colour. Ultimates add the moment and
one effect only they have. Effects go through `Net.fx`; slow motion, hit-stop, camera kick and
shake stay local.

## Co-op

- The caster's machine runs the state, hits and effects (`Net.fx`); hits on host-run enemies
  route through `Net.route_hit`; projectiles replicate via `net_power("projectile")` and run on
  every screen; poses mirror through `net_sync`. New per-frame pose inputs need
  `humanoid_sync.gd`. Calls on enemies that change their state from a guest (grabbed, rooted,
  vine_yank) go in `Net.HOST_CALLS`. Run `nettest.ps1`.

## Checking

```powershell
# film it (driftwake-fx for the views and env)
& $env:GODOT --path . --script res://tools/dev/abilityshot.gd -- res://tools/dev/out/abil/x swordfish sword game,side 8 1.0
# the poses at the game's length, frame by frame
& $env:GODOT --path . --script res://tools/dev/animsheet.gd -- res://tools/dev/out/anim swordfish,kraken_cut
```

Suites: `techtest` (every technique lands, knockdowns, grapples, guards), `fixtest`, `feat`,
`stamtest` (combo, heavies), `progtest` (trees, costs), `powertest` (skills), `axetest`,
`katanatest`, and `nettest.ps1`. Tell Zach what to equip (weapon, slot, R for ults), where to try
it, and to watch from behind in slow motion; log it in `docs/dev_notes.md`; commit.

## Symptom -> cause

| Zach sees | Cause | Fix |
|---|---|---|
| "hits before the swing" | `_once` time earlier than the pose's strike key | line the damage up with the key (u x dur) |
| "nothing happened" | no target -> silent | `_refund("Nobody close enough")` |
| flurry hits nobody past the first | `_cone` reach from where you started | `_drift` keeps you moving; reach from the chest each hit |
| effect at the old spot after a blink | read position before `_place` | read after moving |
| ult takes damage mid-move | hurtbox left on | off in enter, back in exit and at the payoff |
| stuck slow-mo after an ult | time_scale touched outside CombatManager | `apply_slowmo` only |
| pose differs per stance | joints not keyed fall back to the stance | key every joint |
