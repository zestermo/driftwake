---
name: driftwake-animation
description: >
  Make or tune character animations in Driftwake: the procedural keyframe animator in
  scripts/npc/humanoid.gd (actions played with Humanoid.play, poses as joint-rotation
  dictionaries, the `_keys` easing modes, upper/full masks, hip lift, spins), wiring an
  action to a player state or enemy (hitbox start/end timing, durations vs lengths, slash
  trails), co-op mirroring, and checking the result with the posebench / heavyshots render
  tools. Use when Zach asks for a new attack, move, emote, idle/locomotion tweak, pose fix,
  "the swing looks wrong", wind-up/follow-through timing, or anything about how a body moves.
---

# Driftwake animation

There are no AnimationPlayer clips. Every body (player, crew, grunts, bosses) is a
`Humanoid` (`scripts/npc/humanoid.gd`) of plain `Node3D` joints, posed in code each frame.
An "animation" is a list of key poses in `_action_pose()`, played by name.

Before changing a move, grep `docs/dev_notes.md` for its name (and the system around it):
most moves have tuning notes and past bugs recorded there.

## How a frame is built (`Humanoid._process`)

1. `_locomotion(delta)`: the gait/idle/air/swim/stance pose for every joint, plus `_lift`.
2. If an action is playing: `u = t / dur` (0..1), `_base = locomotion pose`, then
   `_action_pose(name, u)` returns `[pose, mask, lift]`, blended in over 0.06 s.
3. Every joint is low-passed toward its target: `k = 1 - exp(-sharp * delta)`, sharp 22
   normally, **38 during actions** (time constant ~26 ms). Keys closer together than about
   0.03 s never fully land; a pose meant to read needs a held key.
4. Rotations are written to the joints. Head turn is split 40/60 over neck/head, then the
   look-at layer (`_update_look`) goes on top.
5. Foot IK (`_foot_ik`) re-solves the legs on uneven ground (off for getup/seated/swim/etc).
6. Hand IK: `_katana_hands()` / `_axe_hands()` put the left hand on a two-handed grip. For
   those, the `arm_l`/`fore_l` values in your pose only seed the IK.
7. `_update_physics`: hair/cloth spring chains.

`freeze(t)` holds the pose (per-body hit-stop). LOD bodies far away pose every Nth frame.

## Joints and sign conventions (radians, Euler `Vector3(x, y, z)`)

`JOINTS = pivot, hips, torso, head, arm_l, fore_l, arm_r, fore_r, leg_l, shin_l, leg_r, shin_r, hand_r`

| Joint | Meaning |
|---|---|
| `pivot` | whole body at hip height. x- = pitch forward (lean, roll), y = spin about up |
| `hips` | pelvis. y = turn the hips (boxing guard -0.5 = left side leads) |
| `torso` | x- = lean/bend forward, y+ = chest turns left, z = side bend |
| `head` | x- = look down, y = turn (split over neck + head) |
| `arm_l` / `arm_r` | shoulder. x+ = swing forward/up (1.57 ≈ straight ahead, 2.7 ≈ overhead). `arm_r` z+ = raise sideways (out right), `arm_l` z- = raise sideways (out left). y = twist |
| `fore_l` / `fore_r` | elbow. x+ = bend (0 = straight, 2.3 = fully folded) |
| `leg_l` / `leg_r` | thigh. x+ = forward/knee up, x- = trail behind. z: `leg_l` z- / `leg_r` z+ = out to the side. Never let a leg cross the midline (gait clamps leg_l z ≤ 0.08, leg_r z ≥ -0.08) |
| `shin_l` / `shin_r` | knee. **x- = bend** (-0.3 slight, -1.4 deep lunge, -2.2 full tuck) |
| `hand_r` | right wrist / weapon socket. x- = blade tips forward along the arm (thrusts ~-1.5), x+ = cocked back |

Left/right mirror rule: to mirror a pose, swap `_l`/`_r` and negate y and z on every joint
(keep x). Facing is -Z; feet at y 0; `PIVOT_Y` 0.9 m.

## Writing an action

Add a branch to the `match n:` in `_action_pose()` (group it with its weapon/style):

```gdscript
"axe_upper":
	# rising cut from the right hip up across the chest, stepping in on the left foot
	var g := _guard()
	var step := {"leg_l": Vector3(0.9, 0, -0.1), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.6, 0, 0.1), "shin_r": Vector3(-0.35, 0, 0)}
	var low := {"arm_r": Vector3(-0.4, 0.3, 0.5), "fore_r": Vector3(0.6, 0, 0), "hand_r": Vector3(0.6, 0, 0), "torso": Vector3(0.1, -0.8, 0)}
	var up := {"arm_r": Vector3(2.4, -0.4, -0.3), "fore_r": Vector3(0.1, 0, 0), "hand_r": Vector3(-0.9, 0, 0), "torso": Vector3(-0.2, 0.7, 0)}
	lift.y = _strike_lift(u, 0.3, 0.42, 0.65, -0.08, -0.22)
	return [_keys(u, [[0.0, g], [0.25, low.merged(step), "out"], [0.3, low.merged(step)], [0.42, up.merged(step), "out"], [0.65, up.merged(step)], [1.0, g]]), "full", lift]
```

- **Keys**: `[[u, pose_dict, mode?], ...]`, `u` ascending 0..1. The mode on key *b* shapes
  the segment a→b: `"out"` fast start/soft stop (strikes, snapping into a wind-up), `"in"`
  slow start/fast end, `"back"` overshoot and settle, default smoothstep.
- **Missing joints fall back to the locomotion pose** (`_base`), per key. `{}` as a key means
  "whatever the body was doing", which is how upper-body actions ease in and out.
- **Mask**: `"upper"` only applies `torso, head, arms, hand_r`; legs keep walking and `lift`
  is *added*. `"full"` takes legs too and `lift` *replaces* the gait's.
- **Lift** is the hip offset (`Vector3`, y- = crouch). `_strike_lift(u, wind_end, hit, hold,
  coil, deep)` gives the standard sink-through-a-strike curve.
- **Spins**: write `pose["pivot"] = Vector3(0, -TAU * k, 0)` (or x for flips) and add the
  name to `SPIN_ACTIONS`. Pivot is then applied exactly (no smoothing across 2π) and reset
  in `_finish_action`.
- **One-shot events** inside the pose (attach weapon, show a prop): guard with
  `_action["events"]`; if it must also happen when interrupted, add it to `_finish_action`.
- **Stance-aware**: start/end on `_guard()` so it returns to the right guard for the
  stance. `_guns_out()` + `_gun_tuck(pose, k)` keep pistols tucked in body moves.
- **Reuse** the pose consts above `_action_pose` (`GUARD`, `SWORD_GUARD`, `KATANA_*`,
  `FIST_GUARD`, `REST_ARMS`, the enemy `E_*` set) and `dict.merged()` to combine upper and
  lower halves.
- Time-based wiggle (`sin(_t * f)`) is fine inside a pose; it keeps working during holds.
- Two-handed weapons: if the left hand should leave the grip during the move, add the name
  to the skip list in `_katana_hands()` / `AXE_TWO_HANDED` handling in `_axe_hands()`.
- **An unknown name silently does nothing** (falls through to `[{}, "upper", lift]`). When
  renaming or removing an action, grep every caller (`play("name"`) in `scripts/`.

## Wiring it up

- Play it: `body_model.play("name", length)` (player) or `humanoid.play(...)` (NPCs).
  `u` maps over `length` seconds. `stop_action()`, `current_action()`, `is_busy()`,
  signal `action_finished(name)`.
- Player combos live in state configs, e.g. `scripts/player_states/light_attack_state.gd`
  `STYLES`: `anims`, `lengths` (anim length), `durations` (how long the state lasts before
  you can act), `starts`/`ends` (hitbox window, **seconds**), `trails` (FX.slash arc kind,
  `scripts/game/fx.gd` `_slash_mesh`), impulses, hitstops, shakes. Heavy, skill, dodge and
  air states follow the same idea.
- **Match the hitbox to the keys**: open it near the end of the wind-up hold
  (`wind_key_u × length`), close it a little after the strike key lands. slash_r: wind held
  to u 0.26, hit at 0.38, length 0.48 → hitbox 0.11–0.21 s.
- Juice (hit-stop, shake, squash, wind puffs, sounds via `Net.fx`) belongs in the state, not
  the pose. See the game-feel skill.
- **Co-op**: `play()`/`stop_action()` mirror to other screens automatically when the body has
  `net_sync` (rate-limited: re-playing the same name/duration within 250 ms isn't resent).
  Per-frame inputs a pose reads (`dash_dir`, `aim_pitch`, `local_move`, flags like
  `swimming`) travel through `scripts/net/humanoid_sync.gd`; a new input the pose depends on
  must be added there or guests see a different pose.

## Feel (what Zach wants)

Shonen, punchy and readable; not cartoony. The pattern every good move here follows:

1. **Anticipation**: a wind-up that sinks the hips and turns the chest away (torso y ±1.0),
   held a beat (enemies hold it longer as a readable tell).
2. **Strike**: one short `"out"` segment, ~0.1–0.15 of u, driving through a lunge (front
   shin ≈ -1.4, back leg extended), the weapon flung out along the arm (`hand_r` x-).
3. **Follow-through hold** to u ≈ 0.6–0.75 so the shape reads.
4. **Recover** smoothly to `_guard()`.

Big arcs, both sides of the body working (the free arm counters), head leading the turn.
Check that limbs don't pass through the torso and that the blade doesn't bend back at the
wrist (an upper-arm twist plus wrist bend does that, see the slash_l note).

## Rig gotchas

- Anything that writes joint *global* transforms (ragdoll, IK, hand placement) must keep
  local origin/scale: write `basis = rotation × own local scale` or restore afterwards
  (`Ragdoll.restore_rig`). A katana once grew every parry from this.
- Physics interpolation is on: things following a joint should read
  `get_global_transform_interpolated()`.
- Locomotion tweaks live in `_locomotion()` (gait, start/stop/skid, jump `_jside`/`_jv`,
  fall pose), `_feral()` (claw stance), `_swim_pose()`, `_getup_pose()`; read the
  dev_notes entry before touching them, the numbers were tuned against Zach's feedback.

## Checking it

Render, then read the PNGs. From bash, wrap in PowerShell so `$env:GODOT` resolves:

```bash
# frozen key poses from several angles (u values = the keys you care about)
powershell -NoProfile -Command '& $env:GODOT --path . --script res://tools/dev/posebench.gd -- res://tools/dev/out/pb/axe sword cutlass guard,slash_r:0.26,slash_r:0.38,slash_r:0.6 side,front,three'
# 8-frame strip of the whole move with the real timing: <out.png> <anim> <weapon> <length> <yaw_deg> [stance]
powershell -NoProfile -Command '& $env:GODOT --path . --script res://tools/dev/heavyshots.gd -- res://tools/dev/out/pb/strip.png slash_r cutlass 0.48 60 sword'
```

posebench views: `side, right, front, back, three, top, chest, chestf, chests, hipsb, hipss,
hips3, hipsf, hipsu`. Env: `PB_SPEED=6` (mid-stride, `PB_SPRINT=1`), `PB_AIR=-6`
(airborne), `PB_FEM=1`, `PB_BEAST=1`, `PB_DUAL=1`, `PB_REST=1`, `PB_KV="build=broad"`.
Weapon names come from `Props.weapon_mesh`; stance `katana` for the katana. Both tools open
a window (GPU).

Then run the suites that cover the move (`axetest`, `katanatest`, `stamtest`, `progtest`,
`vinetest`, `fixtest`, `r7test` reference actions by name), plus `nettest.ps1` if you
touched sync. Finish by telling Zach what to try in game (which weapon/style, which button,
where), add a short dated entry to `docs/dev_notes.md` for anything substantial, and commit.
