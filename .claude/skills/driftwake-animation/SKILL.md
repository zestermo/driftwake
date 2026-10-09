---
name: driftwake-animation
description: >
  Make or tune character animations in Driftwake: the procedural keyframe animator in
  scripts/npc/humanoid.gd (actions played with Humanoid.play, poses as joint-rotation
  dictionaries, the `_keys` easing modes, upper/full masks, hip lift, spins), weapon swings
  on hand paths (ActionSpecs "swing"/"reach", SwordMoves), wiring an action to a player
  state or enemy (hitbox timing, chains, blade trails), co-op mirroring, the anim lab
  (ranked variant rounds) and the animsheet / posebench render and trace tools. Use when
  Zach asks for a new attack, move, emote, idle/locomotion tweak, pose fix, "the swing looks
  wrong", wind-up/follow-through timing, or anything about how a body moves.
---

# Driftwake animation

There are no AnimationPlayer clips. Every body (player, crew, grunts, bosses) is a
`Humanoid` (`scripts/npc/humanoid.gd`) of plain `Node3D` joints, posed in code each frame.
An "animation" is an action played by name: key poses in `_action_pose()`, plus (for weapon
swings) hand paths solved by IK.

**Read first:** `docs/anim_lab.md` (every training round, Zach's rankings and what each
taught; it outranks this file where they disagree) and grep `docs/dev_notes.md` for the
move and its system.

## How Zach judges an animation

- He plays it in the editor, at full speed **and** in slow motion (Shift+F5), and turns the
  camera to look **from behind and above** (the game camera's side). Something that only
  reads from the front three-quarter isn't done. Full speed and slow motion can disagree:
  the silhouette reads at speed, the detail slowed.
- What he has asked for, consistently: rotation and momentum (the body drives the weapon,
  the blade arcs through, nothing stops mid-swing), a wind-up and a follow-through that make
  physical sense, squash/stretch and smear for impact, the free arm answering the swing,
  bent (never locked) limbs, a sword that sits right in the hand (edge leading, no twisting,
  no reverse grip), nothing clipping the body, and a smooth path (no wobble).
- His notes name the symptom, not the cause ("the upper arm clips the head", "it wobbles").
  Trace before tuning: the cause has usually been somewhere else (see **Diagnosing**).
- Small asks get a direct fix, not a variant round. Rounds are for "which of these is
  better" questions. Keep the change he didn't ask about as it was.

## Two ways to animate, and when

| | Keyed poses | Paths (swing / reach) |
|---|---|---|
| What you write | joint Euler angles per key (`_action_pose`) | hand points around a centre, wrist break, elbow pole (ActionSpecs `"swing"` / `"reach"`) |
| Use for | body (pivot, hips, torso, head, legs, lift, squash), emotes, non-weapon moves, punches/kicks | **every weapon swing** (the sword hand) and the free hand during one |
| Why | cheap, fine for joints that rotate about one axis | keyed arm angles interpolate joint by joint: the blade loops wherever and the arm only reads from one view |

A swing move is always three parts: the body keyed as poses, the sword hand on a `"swing"`
path, the free hand on a `"reach"` path. `scripts/npc/sword_moves.gd` (SwordMoves) holds the
cutlass combo built this way; copy it.

## How a frame is built (`Humanoid._process`)

1. `_locomotion(delta)`: the gait/idle/air/swim/stance pose for every joint, plus `_lift`.
2. If an action is playing: `u = t / dur` (through the spec's `"retime"`), `_base` =
   locomotion, then `_action_pose(name, u)` returns `[pose, mask, lift]`, blended in 0.06 s.
3. Joints low-pass toward their targets: `k = 1 - exp(-sharp * delta)`, sharp 22 normally,
   38 during actions, or the spec's `"sharp"` (swings use 55). Keys closer than ~0.03 s
   never fully land; a pose meant to read needs a held key.
4. Rotations are written. Head turn splits 40/60 over neck/head; `_update_look` on top;
   `_keep_gaze` caps upward gaze during actions (moves that look up go in `GAZE_FREE`).
5. Foot IK on uneven ground.
6. **Swing and reach solvers** (`_swing`, `_reach`): the hand on its path by arm IK,
   overriding the posed arm; the wrist solved so the blade extends the forearm. Then the
   katana/axe two-handed grips (`_katana_hands`, `_axe_hands`).
7. Hair/cloth spring chains.

`freeze(t)` holds the pose (hit-stop). LOD bodies pose every Nth frame.

## Joints and sign conventions (radians, Euler `Vector3(x, y, z)`)

`JOINTS = pivot, hips, torso, head, arm_l, fore_l, arm_r, fore_r, leg_l, shin_l, leg_r, shin_r, hand_r, hand_l`

| Joint | Meaning |
|---|---|
| `pivot` | whole body at hip height. x- = pitch forward, y = spin about up |
| `hips` | pelvis. y = turn the hips (y- faces right, y+ left) |
| `torso` | x- = lean forward, y+ = chest turns left, z = side bend |
| `head` | x- = look down, y = turn |
| `arm_l` / `arm_r` | shoulder. x+ = forward/up (1.57 ahead, 2.7 overhead). `arm_r` z+ / `arm_l` z- = raise sideways. y = twist |
| `fore_l` / `fore_r` | elbow. x+ = bend (0 straight, 2.3 folded) |
| `leg_l` / `leg_r` | thigh. x+ = forward. `leg_l` z- / `leg_r` z+ = out. Never cross the midline |
| `shin_l` / `shin_r` | knee. **x- = bend** (-0.3 slight, -1.4 lunge, -2.2 tuck) |
| `hand_r` / `hand_l` | wrist / weapon socket. x- = blade tips forward along the arm, x+ = cocked back |

Mirror a pose: swap `_l`/`_r`, negate y and z (keep x). Facing -Z, feet at y 0, `PIVOT_Y` 0.9.
Body space for paths: x+ right, y up, z+ behind; the sword hand's full reach is ~0.64 m from
its shoulder joint.

## Writing a keyed action

Add a branch to `match n:` in `_action_pose()` (or a static function in a technique file like
SwordMoves, called from there):

```gdscript
"axe_upper":
	var g := _guard()
	var step := {"leg_l": Vector3(0.9, 0, -0.1), "shin_l": Vector3(-0.9, 0, 0), "leg_r": Vector3(-0.6, 0, 0.1), "shin_r": Vector3(-0.35, 0, 0)}
	var low := {"torso": Vector3(0.1, -0.8, 0), "_lift": Vector3(0, -0.12, 0)}.merged(step)
	var up := {"torso": Vector3(-0.2, 0.7, 0), "_lift": Vector3(0, -0.2, 0)}.merged(step)
	return [_keys(u, [[0.0, g], [0.25, low, "out"], [0.3, low], [0.42, up, "out"], [0.65, up], [1.0, g]]), "full", Vector3.ZERO]
```

- **Keys** `[[u, pose, mode?], ...]`, u rising 0..1. The mode on key *b* shapes a→b: default
  smoothstep (stops at both ends), `"out"` (starts at 3x its average speed, eases in),
  `"in"` (eases out, ends at 3x), `"back"` (overshoot), `"linear"`.
- Missing joints fall back to the locomotion pose; `{}` = "whatever the body was doing".
- **Mask** `"upper"` (torso, head, arms, hands; legs keep walking, lift *added*) or
  `"full"` (lift *replaces* the gait's).
- **Pose channels** in key dicts: `"_lift"` (hip offset, y- = crouch), `"_scale"` (squash/
  stretch about the feet: x side, y up, z forward), `"_smear"` (x = blade stretch).
- A full-body move keys every joint on its main keys, `hips` included (a joint left out
  takes the stance's pose: the boxing guard's turned hips leak into everything).
- Start and end on `_guard()`. Pistols: `_guns_out()` + `_gun_tuck()`; never key the player's
  `hand_r` with guns out (the grip is fixed, the arm aims).
- Spins: `pivot` y = `-TAU * k` and add the name to `SPIN_ACTIONS`.
- One-shot events: guard with `_action["events"]`; if they must happen when interrupted too,
  add them to `_finish_action`.
- An unknown name logs "Humanoid.play: no pose for action". Grep callers when renaming.
- Moves played at several lengths: keys are in u, so check the shortest; key key beats in
  seconds (`t_seconds / _action["dur"]`) if needed.

## Swing paths (weapon swings)

The spec's `"swing"` (`ActionSpecs` header documents every field). The hand runs a
Catmull-Rom curve through key points (`center + dir.normalized() * r`, body space at the
guard), the arm by IK with an anatomical elbow search, the sword as an **extension of the
forearm broken back at the wrist** by the key's `"break"` toward the trailing side of the
cut's plane, so the edge always leads. Nothing else may aim the blade.

**Authoring recipe** (the reference is hit 1, `SLASH_R_SWING`; hit 2 `SLASH_L_SWING` shows a
chained hit):
1. **First key at the guard hand** (or, for a chained hit, the last hit's final point). The
   wind-up arcs out round the shoulder, never across it.
2. **Wind-up/cock wide and high** (hand ≥ 0.45 m from the shoulder, break ~1.0-1.35): a
   close cock folds the elbow and puts the cocked blade through the head.
3. **Contact in the space in front of the chest**, the chest about square to the target,
   break ~0.4-0.7.
4. **Follow-through past the body**, arm extended but not locked (break ~0.1-0.3), then hold.
5. **Stop the path at the end of the follow-through.** After the last key the solver turns
   each arm joint back to its posed (guard) rotation over 0.1 s, swivel and wrist held, so
   the recovery needs no keys. Don't add return keys: squeezed into the move's tail they
   whip back faster than the strike. Make sure last key + lag + 0.1 s ends before the
   action does (or the arm snaps to the guard on the last frame).
6. `"plane_from"` skips wind-up keys that travel against the cut.

**Spacing: the hand's speed is set by key spacing, not by the keys' positions.** Each
segment's speed = its path length / its time. Make neighbouring segments meet at about the
same speed: one acceleration into contact (an `"in"` key ending at contact, or linear keys
spaced wider and wider), peak speed through contact, only slowing after it, then a short
`"out"` settle. Never a smoothstep (default) key mid-strike: it stops the hand dead, which
reads as a wobble. Compute the distances (`center + dir.normalized() * r`) when placing keys.

**Reach and bend.** The bend comes from distance to the shoulder, and the path's frame isn't
centred on the shoulder, so read the result, don't compute it: `AS_DEBUG` ELBOW lines give
bend and target. Bend ~0.09 = **locked, the target is out of reach** (the hand stalls, then
lurches when the path comes back in range); trim `r`. A point further from the shoulder
than its neighbours straightens then re-bends the elbow, dipping the tip. Aim for 0.4-1.2
through the swing, straight only for an instant at contact if at all.

**Height.** A sweep's height must change monotonically (rising cut: rises the whole way). The
path rides the shoulders (`anchor`), so the body's vertical bob adds to it: keep squash/
stretch off the vertical under a sweeping cut (stretch along the cut, z).

**Frame.** The path is authored for the guard and follows the shoulders' offset from where
they were when the swing started (`anchor`), optionally the chest's turn (`follow`). A hit
chained from a running swing keeps that swing's anchor (one frame for the whole combo), so
author its keys in the guard's frame too.

**Clearance.** The solver pushes the blade 0.2 m off the head sphere and chest capsule
(`_blade_clear`). That's a safety net; a path that needs it looks cramped.

**Swings that turn the body (spins; hit 3 `SLASH_SPIN_SWING` is the example).** Use
`"follow": 1.0` with `"from_shoulder": true` (points are offsets from the sword shoulder in
the chest's frame, so `r` is the reach: ~0.62-0.64 arm out, ~0.6 a little bent) and give
`"plane"` (and `"cut"`) explicitly: in the chest's frame the hand barely moves while the body
carries it round, so the keys can't say which way the cut goes. Put the spin in `pivot` y
on top of the keyed body (a full turn ends wrapped, `_finish_action`), not in
`SPIN_ACTIONS` (those skip the blend in). Let the body do the sweeping: the arm's own sweep
on top of the turn doubles the blade's speed. Hand slightly below the shoulder (dir y ~-0.3)
keeps the forearm and blade level (the elbow sits low, so a hand at shoulder height angles
the blade up). Unwind the coil into the turn at a steady rate (`"linear"` body keys): eased
keys peak the chest's turn for a frame and the blade flicks.

## Reach paths (the free hand)

The spec's `"reach"`: the same curve, arm IK, wrist as posed. Use `from_shoulder: true`,
`follow: 1.0`: points are offsets from that arm's shoulder in the chest's frame, so their
length sets the bend (~0.64 m locked, ~0.6 ≈ 0.6 rad, ~0.55 ≈ 0.9, ~0.49 ≈ 1.2; check the
REACH lines). Poles: "out to the side" by default; a hand flung out sideways or back takes a
down-and-back pole (the solver leans a pole that lines up with the reach toward the side,
then down). A hand going from in front to behind needs a key on the arc out past the hip (the
chord runs past the shoulder and folds the elbow). The free arm's job: reach toward the
target on the wind-up, fling out and back against the cut (behind the chest in the follow-
through), arm near straight but never locked.

## Body keys for a swing

- **Load away, then turn with the cut.** A right-to-left forehand: hips and chest turn right
  (y-) on the wind-up, left through the cut; the head counters to stay on the target. Big
  turns (x1.6 of a first guess) in the wind-up and follow-through; **the chest about square
  at contact** (turned further, the shoulder passes the hand and the blade points back).
- Overlap via the spec's `"lead"` (hips 0.04 s ahead, chest 0.02): hips lead chest, chest
  leads arm, the blade whips last.
- Squash on the gather/wind-up, stretch along the cut and blade smear on the whoosh key, a
  firm landing key with a slight squash. Not stepped/on-twos timing (Zach didn't like it).
- Step through on the front foot into the cut (front shin ~-1.0, back leg extended).
- Too much follow-through turn lifts the sword arm by the head: keep the chest turn after
  contact moderate (hit 2: hips -0.3, chest -0.33, x1.6).
- The body function keys only the body; arm keys there merely seed the blend.

## Timing

- Lengths that worked: hit 1 0.85 s (the opener: a long readable wind-up), hit 2 0.7 s (a
  chained hit gets its wind-up from the hit before, so it's quicker), hit 3 0.8 s (a full
  turn and a landing; not yet judged by Zach). The
  *motion* of every hit should feel equally quick; Zach compares hits within a combo.
- **Carry the follow-through fast, then hold.** A long eased-out sweep after contact reads as
  slow motion (~0.1 s from contact to the end of the sweep was right for hit 2).
- `"retime"` slows a phase (wind-up, follow-through) without touching the strike's speed.
- `"chain"` (s): when the next light attack can follow; put it after the follow-through key
  so the shape is seen, before the recovery.
- `"hit"` [u, u]: open just before contact, close after the blade passes the target; the
  red bar in animsheet should sit under the strike frames.
- `"swoosh"` [u, u]: the blade trail window (FX.blade_swoosh): from the launch to the end
  of the follow-through sweep.

## Diagnosing (symptom → what it was)

| Zach says | Cause found | Fix |
|---|---|---|
| "can't tell the variants apart" | arc FX hid the blade; differences too small | Ctrl+F5 clean view; make variants obvious at game speed |
| "sword twists in the hand" | wrist rolled to make the edge lead the motion | wrist only bends (2 DOF); arm turns the blade |
| "reverse grip / stab look" | blade aimed independently of the forearm | blade = forearm + break toward the trailing side |
| "blade through the head" | cock point too close to the shoulder | cock wide and high; clearance push as backup |
| "elbow flips / arm bends backwards" | elbow search unanatomical after a walk; keyed shoulder angles rolling; pole along the reach | anatomy penalty; reach paths; side/down pole fallback. Test with `AS_MOVE=0,1` |
| "upper arm clips the head" | chained hit re-anchored on a coiled body: path slid out of reach, arm locked straight and rode up | keep the anchor across a chain; trim radii; less follow-through turn |
| "wonky off elbow" | off hand's path ran a chord past the shoulder | a key on the arc out past the hip |
| "too slow at the end" | long eased-out follow-through sweep | compress the sweep, then hold |
| "wobbles up and down" | smooth key stopping the hand mid-rise; body bob under the path; height peaking then sinking; locked arm stalling and lurching | space keys by distance; stretch along the cut; monotonic height; trim radii |
| (hit 3) elbow bent 1.2-1.9 though the keys reach 0.6 | two keys far apart round the shoulder: the curve cuts a chord inside them | a key on the arc between them |
| (hit 3) elbow flipped up after the spin, upper arm in the head | the elbow search judged "out to the side" in the feet's frame | it reads the swing's frame now (`_swing_b`) |
| (hit 3) tip 100 m/s at contact | eased body keys (in/out) peaked the chest's turn; the arm swept on top of the turn | linear unwind; smaller arm sweep, the body carries it |
| (found by trace) blade pops on recovery, hits 1 and 2 | the release re-ran IK toward the posed hand; the elbow search found another solution | release in joint space (slerp each joint to its posed rotation) |

## Tools

All from bash wrapped in PowerShell (`$env:GODOT`). Renders open a window (GPU). Output dirs
must exist (`tools/dev/out/`).

```bash
# lab mode: live + each AnimLab variant as rows, 4 views (front3, side, back3, top), the real
# blade trail drawn, RANGE and BLADE lines printed per row
powershell -NoProfile -Command '& $env:GODOT --path . --script res://tools/dev/animsheet.gd -- res://tools/dev/out/lab lab:slash_l'
# per-frame trace of one row (live or a variant letter): hand/tip height and speed, elbow bend
powershell -NoProfile -Command "\$env:AS_TRACE='live'; & \$env:GODOT --path . --script res://tools/dev/animsheet.gd -- res://tools/dev/out/lab lab:slash_l 2>&1 | Select-String '^TRACE'"
# whole moves at game length, 8 frames, 3 per sheet: names or stances, then yaw (125 front 3/4, 90 side)
powershell -NoProfile -Command '& $env:GODOT --path . --script res://tools/dev/animsheet.gd -- res://tools/dev/out/anim slash_r,slash_l'
# frozen key poses from several angles
powershell -NoProfile -Command '& $env:GODOT --path . --script res://tools/dev/posebench.gd -- res://tools/dev/out/pb sword cutlass guard,slash_r:0.4 side,front,three'
```

- **BLADE line targets:** edge leads the cut avg > 0.3 and min ≥ 0; no REVERSE GRIP (grip
  > 2.1 rad); roll in fist < 0.5; body clearance ≥ 0 (no THROUGH THE BODY); upper arm clear
  of head ≥ 0 (no ARM IN THE HEAD). Hits 1/2: edge 0.31/0.42, roll 0.20/0.23, clearances
  0.27/0.28 and 0.07 m.
- **AS_TRACE** (lab mode): a height that dips and recovers, or a speed that stalls and
  surges or spikes (a one-frame tip speed of 50+ m/s is a flip), is what Zach sees as a
  wobble or pop. Read it for every swing change, including the recovery after the last key.
  The tip is the blade as modelled (smear excluded). Speeds are in the root's space, so a
  spin's turn counts. References: hits 1/2 hand peaks ~12-19 m/s, tip ~45; hit 3 tip ~40-60.
- **AS_DEBUG=<live|a|b|c>**: the solver per frame. SWING (path point vs where the hand got,
  shoulder, forearm, cut direction, blade, edge, wrist, swivel), ELBOW (sword elbow
  direction, bend, arm-to-head clearance, clearance push, IK target), REACH (free hand
  target, pole, elbow, bend). With extras "after" the earlier hit prints first; take the
  second run of u.
- **AS_MOVE="x,y"**: start the render mid-walk (y+ forward). Elbow bugs showed only there.
- Combo hits: extras `"after": "<previous hit>"` plays it (and its own "after", back to the
  opener) up to each chain time first.
- animsheet steps `_process` by hand: skinned legs need `LowerBody._pose()` and two
  `frame_post_draw`s per capture (done). Don't use heavyshots (stale legs, late frames).
- A parse error anywhere in the project can stop posebench from saving; animsheet tolerates
  autoload errors.

In game (debug build): **F5** cycles live → A → B → C for `AnimLab.FOCUS`, **Shift+F5** slow
motion (0.25x), **Ctrl+F5** clean view (blade trail, arc effects hidden), F12 capture.

## Training rounds (the anim lab)

For "which is better" questions: 2-3 variants of one action, ranked by Zach.
- Variants in `scripts/npc/anim_lab.gd`: `VARIANTS[action][letter] = {"note", "spec"}`
  (spec overrides: a different swing path, length, retime...) and, for body changes,
  `pose()`; point `FOCUS` at the action. Each variant tests **one** idea on shared poses.
- Differences must be obvious at game speed from the game camera, or it isn't a test.
- Before showing: render all four views, read the BLADE lines and the trace, fix anything
  that would confuse the comparison.
- Tell Zach the keys, what each variant tries, and ask for a best-to-worst ranking with notes.
- After the ranking: move the winner into the live move (SwordMoves for swings), empty the
  variants, log variants, ranking and takeaways in `docs/anim_lab.md`, fold the takeaway in
  here.

## Wiring

- **Every action has an `ActionSpecs.SPECS` entry** (`scripts/npc/action_specs.gd`): len,
  hit, chain, swoosh, sharp, lead, retime, swing, reach, stance/weapon/extras for previews.
  Light and heavy attack states read length, hit window, chain and swoosh from it.
- Play: `play(name, len)`; `hold(name)` (until stopped: block, charge, hang); `react("hit" |
  "stagger", len, push)` (blends front/back/side `_react_pose`); `stop_action()`,
  `is_busy()`, signal `action_finished`.
- **Trails:** swing-path moves draw the real blade's trail (`FX.blade_swoosh` via `Net.fx`
  over the swoosh window); never give them the fixed arc effect.
- Juice (hit-stop, shake, sounds) lives in the state, not the pose.
- **Co-op:** play/hold/react/stop mirror automatically with `net_sync`. Per-frame inputs a pose
  reads (`dash_dir`, `aim_pitch`, `local_move`, flags) go through `humanoid_sync.gd`. The swing
  solver runs on every screen from the same spec, so paths need no sync.

## Older keyed-move rules (from the full review)

- Key the wrist on every blade key of a keyed (non-path) move: cocked back in the wind-up,
  flung out along the arm through the strike (the grunt `E_*` swings still lack it).
- Head counters the chest (head x ≈ -0.6 × torso x, head y against torso y).
- Every distinct move gets its own pose (two names on one branch play identically).
- No limb held straight: elbows and knees only straighten at the instant of full extension.

## Rig gotchas

- Anything writing joint *global* transforms (ragdoll, IK) must keep local origin/scale
  (`basis.orthonormalized()` after IK, `Ragdoll.restore_rig`).
- Physics interpolation is on: follow joints with `get_global_transform_interpolated()`.
- Euler angles lock where a blade lines up with the forearm: do grip maths with vectors.
- Locomotion lives in `_locomotion()`, `_feral()`, `_swim_pose()`, `_getup_pose()`: tuned
  against Zach's feedback, read the dev_notes entry first.

## Finishing

Run the suites that cover the move (`fixtest`, `feat`, `stamtest` for the cutlass combo;
`axetest`, `katanatest`, `progtest`, `vinetest`, `r7test` reference actions by name), plus
`nettest.ps1` if sync changed. Tell Zach what to try in game (weapon, clicks, slow motion,
which camera side), log rounds in `docs/anim_lab.md` and substantial changes in
`docs/dev_notes.md`, commit.
