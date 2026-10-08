---
name: driftwake-animation
description: >
  Make or tune character animations in Driftwake: the procedural keyframe animator in
  scripts/npc/humanoid.gd (actions played with Humanoid.play, poses as joint-rotation
  dictionaries, the `_keys` easing modes, upper/full masks, hip lift, spins), wiring an
  action to a player state or enemy (hitbox start/end timing, durations vs lengths, slash
  trails), co-op mirroring, and checking the result with the animsheet / posebench render
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

`JOINTS = pivot, hips, torso, head, arm_l, fore_l, arm_r, fore_r, leg_l, shin_l, leg_r, shin_r, hand_r, hand_l`

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
| `hand_r` / `hand_l` | wrists / weapon sockets. x- = blade tips forward along the arm (thrusts ~-1.5), x+ = cocked back; same sign both sides. `hand_l` holds the off-hand weapon and props (bottle, food) |

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
- **Mask**: `"upper"` only applies `torso, head, arms, hands`; legs keep walking and `lift`
  is *added*. `"full"` takes legs too and `lift` *replaces* the gait's.
- **Lift** is the hip offset (`Vector3`, y- = crouch). Prefer keying it: put `"_lift":
  Vector3(0, y, 0)` in the key dicts and it eases with the pose (see `peril_chop`,
  `thorn_whip`; keys without it fall back to the gait's lift). Older moves still compute
  `lift.y` by hand or with `_strike_lift(u, wind_end, hit, hold, coil, deep)`; a pose that
  has `_lift` overrides the returned lift.
- **Gaze is guarded for you**: during actions `_keep_gaze` caps pivot + torso + head pitch at
  `GAZE_UP_MAX` by tilting the head down. A move that means to look up (howl, flips, being
  hit) goes in `GAZE_FREE`.
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
- **An unknown name does nothing but log an error** ("Humanoid.play: no pose for action",
  once per play). When renaming or removing an action, grep every caller (`play("name"`) in
  `scripts/`, and watch the log after rendering.

## Wiring it up

- **Every action has an entry in `scripts/npc/action_specs.gd` (`ActionSpecs.SPECS`)**: its
  length, its strike window `"hit": [u_open, u_close]` for attacks, and its preview setup
  (stance, weapon, extras, variants). Add the entry with the pose; animsheet renders from it.
- Three ways to play (`body_model` on the player, `humanoid` on NPCs):
  - `play("name", length)`: a one-shot; `u` runs over `length` seconds.
  - `hold("name")`: ease in over the spec's length and stay until `stop_action()` or another
    action (block, iai charge, rope/vine hang). No more `play(..., 600.0)`.
  - `react("hit" | "stagger", length, push)`: a hit reaction away from the blow; `push` is
    the world direction it shoves the body (the knockback dir). The pose blends front/back/
    side versions from `_react_pose(front, back, side)` and picks a mirrored/scaled variant.
  - `stop_action()`, `current_action()`, `is_busy()`, signal `action_finished(name)`.
- Light and heavy attacks read **length and hitbox window from ActionSpecs**
  (`ActionSpecs.length(n)`, `ActionSpecs.hit_seconds(n)`); their `STYLES` only hold feel
  (durations before the next hit, impulses, damage, hitstop, shake, trails). Heavy's
  windup/active/recovery = open / open→close / close→end of that window. Skill, dodge,
  plunge and enemy timings are still in their own states.
- **Match the hit window to the keys**: open it near the end of the wind-up hold, close it a
  little after the strike key lands (slash_r: wind held to u 0.26, hit at 0.38 → `[0.23,
  0.44]`). animsheet draws a red bar under the frames inside the window: check the bar
  sits under the strike.
- Juice (hit-stop, shake, squash, wind puffs, sounds via `Net.fx`) belongs in the state, not
  the pose. See the game-feel skill.
- **Co-op**: `play()`/`hold()`/`react()`/`stop_action()` mirror to other screens
  automatically when the body has `net_sync` (`react` sends its direction and variant) (rate-limited: re-playing the same name/duration within 250 ms isn't resent).
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

Rules from training (docs/anim_lab.md; Zach's rankings, strongest first):

- **Swings are authored as paths, not arm angles.** Give a blade swing a `"swing"` spec
  (hand points around a centre, the blade direction at each, elbow pole): the hand arcs and
  keeps its speed, IK keeps shoulder/elbow/wrist anatomical from every side. Keyed arm angles
  interpolate joint by joint, so the blade loops wherever and the arm only reads from one
  view. Key the body (hips, chest, legs, lift, squash) as poses; the arm rides the path.
- **The body turns with the cut and loads away from it first.** A right-handed cut going
  right to left: wind-up turns hips and chest right (y-), the cut turns them left (y+), the
  head counters to stay on the target. Hips lead the chest, the chest leads the arm (`lead`).
- **Keep momentum through the strike.** Don't put a stopping key mid-swing; ease into the
  cock (anticipation) and out of the follow-through only.
- **Give it time to read.** A light hit needs a visible wind-up and follow-through (0.75 s
  beat 0.6 s; Zach still found 0.75 s "a little too fast": round 8 tests slower); give slower
  anims their own `"chain"` so the next click doesn't cut off the hit. Slow the wind-up and
  follow-through with `"retime"` rather than the strike itself.
- **Judge at full speed and in slow motion**: they can disagree (detail reads slowed, the
  silhouette reads at speed).
- **Weapon orientation (the essential one):** the sword is an extension of the forearm,
  broken back at the wrist toward the trailing side of the cut. Key the wrist `"break"` per
  path point (~1.4 cocked on the wind-up, ~0.3-0.5 at the strike); the solver tilts it to
  the trailing side in the cut's plane, so the edge always leads and a reverse grip can't
  happen. Never aim the blade independently of the forearm, and never derive "which way
  the cut goes" from the hand's motion (it reverses at the cock); it comes from the cut's
  plane, whose turning sense comes from the whole path.
- **Author the path for the guard stance; it follows the shoulders** (`anchor`). Keep the
  chest about square to the target at contact, the arm out in front: turned further, the
  shoulder passes the hand and the blade points back. Big turns belong to the wind-up and
  the follow-through.
- **Keep the cock point out from the body** (hand ~0.45 m+ from the shoulder): closer, the
  elbow folds in and the cocked blade crosses the head. The solver pushes a blade out of the
  head as a safety net, but a path that needs it reads as cramped.
- **Check the BLADE line** animsheet prints for every lab variant: edge leading the cut
  (avg > 0.3, min > 0), no REVERSE GRIP, forearm over-turn < 0.3, head clearance >= 0 (no
  THROUGH THE HEAD). If it's off, run with `AS_DEBUG=<variant>` for the per-frame solve
  (hand, shoulder, forearm, blade, edge).
- **The off arm answers the swing:** reaches toward the target on the wind-up, flings back
  through the cut, ideally dragging a little behind the chest.
- **No limb held straight.** Elbows and knees only straighten at the instant of full
  extension (a punch, a thrust); reaching or held, they keep 0.6+ rad of bend. Give each
  limb its own pose per phase instead of copying the previous phase's.
- **Free arms go on a "reach" path too**, not keyed shoulder angles (those roll the upper arm
  over between keys). Author the points as offsets from the arm's own shoulder in the
  chest's frame (`from_shoulder`, `follow` 1): the distance sets the elbow (0.55 m ~0.7 rad,
  0.49 m ~1.2). Pole "out to the side" (a pole along the reach leaves the elbow undefined).
- **Paths start at the guard hand and arc round the shoulder**, never straight through it.
- **Test from a walk:** `AS_MOVE=0,1` (and `0,-1`) starts the lab render mid-stride; the
  elbows went wrong only from there.
- **Impact helps:** squash on the wind-up, stretch and blade smear through the swing.
  Stepped/on-twos timing was not liked.
- **Check in slow motion from above and behind**, the game camera's side, not just the
  front three-quarter.

Rules from the full review (each one was a visible problem in the renders):

- **Eyes stay on the target.** Head x adds to torso x; `_keep_gaze` now stops the sky stare,
  but still key a head that counters the chest (head x ≈ -0.6 × torso x, head y against
  torso y the way the punches do) so the cap doesn't have to do the work.
- **Blades need the wrist.** Key `hand_r` on every key of a blade move: cocked back (x+) in
  the wind-up, flung out along the arm (x-) through the strike. Without it the blade stays
  upright off the forearm and the cut doesn't read (the grunt `E_*` swings still lack it).
  The off-hand blade works the same with `hand_l` (the dual-sword moves are the example).
- **Player pistols: leave `hand_r` alone.** The player's guns sit in a fixed grip
  (`auto_point_guns`, `GUN_GRIP`), so the arm does the aiming. A wrist key bends the barrel
  off the arm (`bullet_storm`'s -1.55 points the gun at the ground). Only grunts, who aim
  their own guns, use the wrist for aiming.
- **A full-body move keys every joint on its main keys, `hips` included.** A joint left out
  falls back to the stance pose, so the same skill looks different per stance: from the
  boxing guard the hips stay turned (-0.5) and the hands stay up by the face, and
  `foresight`, `coat` and `tekkai` barely change.
- **Give every distinct move its own pose.** Two names on one branch play identically (e.g.
  `vine_throw` / `thorn_whip`).
- **Played at several lengths?** Check the shortest. Keys are in u, so `spin_slash` at the
  boss's 0.32 s puts its crouch key 0.05 s in, below what the smoothing can show. For moves
  played at varied lengths, key the important beats in seconds (the `quick_draw` /
  `shoot_r` pattern: `k = t_seconds / _action["dur"]`).

## The reference moves (start here for any swing)

`scripts/npc/sword_moves.gd` holds the cutlass combo built the trained way; **slash_r (hit
1) is the reference**: Zach signed it off after 8 lab rounds. Copy its structure for new swings:
- three parts: a `SLASH_*_SWING` path for the sword hand (start at the guard hand, arc round
  the shoulder, cock wide and high, ease into the cock ("smooth"), snap out of it ("in"),
  cut at speed, wrap), a `SLASH_*_REACH` path for the free hand (offsets from its shoulder),
  and a body function keying hips/chest/legs/lift/squash/smear only (the arms ride paths);
- the ActionSpecs entry carries len, hit, chain, swoosh, sharp 55, lead (hips 0.04, chest
  0.02), swing, reach. Hit 1: 0.85 s, wrist break 1.0 -> 1.35 cocked -> 0.7 strike -> 0.1;
- **combo hits chain:** hit N's path starts on hit N-1's last point and its body starts on
  hit N-1's follow-through pose (the chain point); swings blend in from the hand's real
  position, so it's seamless. Set extras "after" to preview the chain in animsheet.
- **Trails:** a move with a swing path gets the blade's own trail (FX.blade_swoosh over its
  "swoosh" window) instead of the fixed arcs; never put an arc effect on a swing move.

## Training rounds (the anim lab)

Zach is training this skill: rounds of 2-3 variants of one action, ranked by him. Read
`docs/anim_lab.md` first: past rankings and takeaways outrank anything else in this file
when they disagree.
- Build variants in `scripts/npc/anim_lab.gd` (`VARIANTS` + `pose()`), point `FOCUS` at the
  action. Make each variant test **one** idea on shared poses (a helper like `_slash_r`), so
  the ranking says which idea won, not which pose happened to be nicer.
- Render with animsheet's lab mode (it draws the blade's real trail), read all four views,
  and fix anything that would confuse the comparison (e.g. a variant over-rotating) before
  showing it. Make the differences big: a variant that isn't obvious at game speed from the
  game camera isn't a test (round 1's first try failed this). Check the blade path in the
  trail: it should travel through the space in front where the target is.
- Tell Zach: F5 cycles live/A/B/C in a debug build, Shift+F5 slow motion, Ctrl+F5 clean
  view (blade trail instead of the arc effects, which aren't synced to the blade); what each tries; ask for a best-to-worst
  ranking with notes. Log the variants, ranges, ranking and takeaways in `docs/anim_lab.md`.
- After a ranking: move the winner into humanoid.gd (or the technique file), fold the
  takeaway into the rules below, and set up the next round.
- Rig features for variants (any action can use them via its ActionSpecs entry or pose
  keys): `"_scale"` squash/stretch, `"_smear"` blade stretch, spec `"lead"` overlap,
  `"sharp"`, `"step"` (stepped/on-twos). See the ActionSpecs header.

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

Render, then read the PNGs. From bash, wrap in PowerShell so `$env:GODOT` resolves. Output
goes straight into `tools/dev/out/` (subfolders must already exist or the save fails).

```bash
# whole moves at the length the game plays them, 8 frames each, 3 moves per sheet
# (args: out prefix, then names or stances to render, then yaw: 125 front 3/4, 90 side)
powershell -NoProfile -Command '& $env:GODOT --path . --script res://tools/dev/animsheet.gd -- res://tools/dev/out/anim slash_r,slash_l'
powershell -NoProfile -Command '& $env:GODOT --path . --script res://tools/dev/animsheet.gd -- res://tools/dev/out/side katana 90'
# frozen key poses from several angles (u values = the keys you care about)
powershell -NoProfile -Command '& $env:GODOT --path . --script res://tools/dev/posebench.gd -- res://tools/dev/out/axe sword cutlass guard,slash_r:0.26,slash_r:0.38,slash_r:0.6 side,front,three'
```

- animsheet renders every `ActionSpecs` entry (holds through `hold`, reactions through
  `react` with each push variant as its own row). A red bar under a frame = hitbox open.
- Moves render in place on flat ground: no root motion, jumps don't leave the floor.
- Don't use `heavyshots` for timing or legs: it shows each pose a sample late and leaves the
  skinned legs stale (boots come loose from the shins in lunges). The legs are a skinned
  `LowerBody` that only follows on frames the rig posed itself, so a tool that steps
  `_process` by hand must call `hips.get_node("LowerBody")._pose()` before capturing.
- posebench and animsheet load the whole project: a parse error anywhere (even in unrelated
  work in progress) can stop posebench from saving.

posebench views: `side, right, front, back, three, top, chest, chestf, chests, hipsb, hipss,
hips3, hipsf, hipsu`. Env: `PB_SPEED=6` (mid-stride, `PB_SPRINT=1`), `PB_AIR=-6`
(airborne), `PB_FEM=1`, `PB_BEAST=1`, `PB_DUAL=1`, `PB_REST=1`, `PB_KV="build=broad"`.
Weapon names come from `Props.weapon_mesh`; stance `katana` for the katana. Both tools open
a window (GPU).

Then run the suites that cover the move (`axetest`, `katanatest`, `stamtest`, `progtest`,
`vinetest`, `fixtest`, `r7test` reference actions by name), plus `nettest.ps1` if you
touched sync. Finish by telling Zach what to try in game (which weapon/style, which button,
where), add a short dated entry to `docs/dev_notes.md` for anything substantial, and commit.
