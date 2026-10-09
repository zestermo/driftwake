# Animation lab: training rounds

Each round takes one action, builds two or three variants that each test an idea
(`scripts/npc/anim_lab.gd`), and Zach ranks them against the live one. The takeaways turn
into rules and recipes in the driftwake-animation skill; winners move into `humanoid.gd`.

How a round runs:
- Variants: `AnimLab.VARIANTS[action]` ("note" + spec overrides) and their poses in `AnimLab.pose()`.
- In game (debug build): **F5** cycles live -> A -> B -> C for `AnimLab.FOCUS` (a toast names
  it); attack and turn the camera round. The variant only changes your own captain.
- Renders: `animsheet.gd -- res://tools/dev/out/lab lab:<action>` writes one sheet per view
  (front3, side, back3, top), rows tagged live (white), A (red), B (green), C (blue), and prints
  each row's range of motion per axis.
- Ranking: best to worst, with what felt right or wrong. Logged below.

## Round 1 (2026-10-08): cutlass slash_r (combo hit 1, diagonal forehand)

The live cut moves the chest and the arm only: no whole-body tilt (pivot 0 on all axes), the
hips don't turn (0.00 rad), no squash, the blade never stretches. Ranges (rad, x/y/z):

| | pivot | hips | torso | head | lift | squash | smear |
|---|---|---|---|---|---|---|---|
| live | 0/0/0 | 0/0/0.02 | 0.49/1.96/0.19 | 0.15/1.53/0.03 | 0.18 | 0 | 0 |
| A | 0.20/0/0.15 | 0/0.69/0.05 | 0.52/1.58/0.38 | 0.17/1.62/0.24 | 0.13 | 0 | 0 |
| B | 0.20/0/0.15 | 0/0.74/0.05 | 0.51/1.52/0.37 | 0.18/1.55/0.24 | 0.13 | 0.10 | 0.22 |
| C | 0.24/0/0.18 | 0/0.90/0.05 | 0.67/2.08/0.50 | 0.22/2.04/0.30 | 0.23 | 0.20 | 0.70 |

Variants (same poses underneath, so the ranking isolates each idea):
- **A, Whip:** weight shifts back on the wind-up and steps through on the cut; hips turn
  (they lead the chest by 0.045 s, the chest leads the arm), the hand trails 0.03 s so the
  blade whips through last; the body tilts and rolls into it (pivot, side bend); the off
  hand sights the target, then is thrown back; the chest carries past the cut, then settles.
- **B, Impact:** A plus squash in the wind-up (0.9 tall), stretch along the swing (1.1
  forward), blade smear (stretched 45%) mid-swing, a hard stop on the cut and a held beat (no
  carry-through), snappier joints (sharp 60).
- **C, On twos:** stepped at 20 fps (each drawing held 0.05 s, snapped, no smoothing),
  bigger extremes (x1.2), one smear drawing between the cock and the cut (70%), a long held
  lunge. Lands a little later (hitbox 0.18-0.30 s instead of 0.11-0.21 s).

First look (Zach): couldn't tell them apart in game. Two causes: the arc effect (a fixed
shape on its own timer, not the blade's path) covers the swing, and the variants were too
close (a 0.1 squash or a 0.03 s lag doesn't show at 0.48 s). Fixes: Ctrl+F5 clean view
(BladeTrail: a ribbon from the real blade's base and tip, arcs hidden), Shift+F5 slow motion
(0.25x), renders draw the blade trail, and the variants pushed much further (A: body x1.35,
hips lead 0.07 s, hand trails 0.05 s; B: squash 0.82, stretch 1.24 forward, smear 90%; C: 15
fps drawings, x1.3, a full-length smear frame). Lesson: **a variant has to be visible at game
speed from the game camera, or it isn't a test.** The trails also showed the live blade loops
over the head and finishes off to the side instead of cutting down through the space in front.

Ranking (Zach): **A and B liked** (whip/rotation, impact squash and smear); C (stepped)
not picked. Slow motion showed the real problems in almost every animation: "the wind-ups
and follow-throughs don't make sense, the character should rotate more, the sword swing
needs momentum and to arc through, the animations are too fast, and the shoulder, elbow and
wrist don't make sense from above or behind."

Takeaways:
- **Keyed arm angles can't make a swing.** Each joint interpolates on its own, so the blade's
  path is whatever falls out (the live cut loops over the head) and the arm only looks right
  from the angle it was posed from. Swings need the hand/blade path authored and the arm
  solved from it: `swing` in ActionSpecs (Humanoid._swing: a curve through keyed hand
  points, arm IK, the wrist laying the blade along the keyed direction, edge leading).
- **The body turns with the cut, loaded away from it first.** The live forehand turns the
  chest left on the wind-up and right on the cut while the arm goes right to left: backwards.
  Torso/hips y- faces right, y+ left. Audit every move for this.
- **Momentum: keys must not stop the blade.** Per-key smoothstep stops at every key; swing
  paths run through their keys at speed (Catmull-Rom, "linear"); ease only into the cock and
  out of the follow-through.
- Rotation, whip and impact (squash, stretch, smear) are wanted; stepped timing isn't.
- Light hits are too fast to read: the wind-up and follow-through need time.

## Round 2 (2026-10-08): slash_r on a swing path

Same diagonal forehand, now with the hand on a swing path (high behind the right shoulder ->
through the space in front -> wrapped low round the left side), the body turning the right
way (right on the wind-up, left through the cut), round 1's squash and smear on every
variant. What differs is the timing and what drives the arc:
- **A, Arc 0.6 s:** body turn x1, hips lead 0.05 s, hit 0.26-0.36 s, chains at 0.42 s.
- **B, Big arc 0.75 s:** longer wind-up, x1.35 turn, a 15% wider path, a longer wrap; hit
  0.34-0.45 s, chains at 0.55 s.
- **C, Body-driven 0.6 s:** the hand path rides the chest (it stays in front of the chest)
  and the hips and chest turn x1.6, swinging it round.

Ranges (rad, x/y/z): live hips y 0.00, A 0.98, B 1.33, C 1.57; torso y live 1.96 (but the
wrong way), A 1.36, B 1.84, C 2.17.

Ranking (Zach): **B liked a lot, C pretty good** ("these are getting better"). B: the
angle and wind-up are really good. C: its chest turn. The off arm moving in response to the
swing helps sell it. Problem: the sword twists and rotates in the hand too much and breaks
the swing.

Takeaways:
- **The wrist never rolls.** The solver aimed the blade freely and rolled it so the edge led
  the travel; the travel flips at the cock and on every change of direction, so the sword
  spun in the fist. Now the wrist only bends (back/forward, a little sideways, limited and
  smoothed) and the arm and elbow turn the blade the rest of the way.
- 0.75 s with a long wind-up and a wide path beats 0.6 s for this cut.
- Big chest/hip turn (x1.6) wanted. The off arm reacting (reach forward, fling back) sells it.

## Round 3 (2026-10-08): slash_r, B's path with C's turn and a steady wrist

All three: round 2 B's path, timing (0.75 s) and wind-up, C's x1.6 chest and hip turn, the
wrist limited to bending (no roll). What differs:
- **A:** the path in the body's frame.
- **B:** the path turning half way with the chest (`follow` 0.5): a flatter, rounder cut
  that wraps round the body.
- **C:** A with a big off-arm counter-swing (x1.6 reach and fling) that drags behind the
  chest (lags 0.04-0.06 s).

Ranking (Zach): **C's off-arm counter-swing and follow-through, A/B's beginning.** Big
problem: the sword's tip and blade direction are wrong through the swing, at times it looks
like a reverse-grip stab. "An essential detail to get right moving forward."

Takeaways (each found with the solver's debug print, `AS_DEBUG=a`, and the new BLADE line):
- **The sword is an extension of the forearm, broken back at the wrist toward the trailing
  side of the cut.** With the hammer grip the rig uses (blade square out of the fist, edge
  toward the fingers), the edge faces away from the side the blade tilts to, so tilting it
  to the trailing side leaves the edge leading, always. Aiming the blade independently of
  the forearm (radial from a centre) can't work: whenever the arm points elsewhere the edge
  flips (that was the reverse-grip look). Key the wrist "break" instead: cocked ~80 deg on
  the wind-up, near in line at the strike.
- **"Which way the cut goes" comes from the cut's plane, never the hand's motion.** The
  motion reverses at the cock and flipped everything. The plane's turning sense must come
  from the whole path (first-to-last alone took the short way, behind the body).
- **The path moves with the shoulders.** It's authored for the guard; crouching (hip drop,
  squash) and leaning dropped the shoulder 0.3 m under a strike point drawn at chest
  height, the arm reached up and the blade pointed back.
- **At contact the chest is about square to the target**, the arm out in front; the big
  turn happens in the wind-up and the follow-through. At x1.6 through the strike the
  shoulder passed the hand and the blade pointed back across the body.
- Euler angles lock up exactly where a blade lines up with the forearm: do grip maths
  with vectors.
- Checks now printed per variant (animsheet BLADE line): edge leading the cut (avg/min, 1
  ideal), worst grip angle (> 2.1 rad = reverse grip), worst forearm over-turn.

## Round 4 (2026-10-08): slash_r, the forearm-break solver

A/B's start and wind-up, C's off-arm counter-swing and follow-through, the chest square at
contact, the path anchored to the shoulders. Variants differ in the wrist break per key
(wind start, cock, launch, strike, follow, wrap; rad off the forearm's line):
- **A:** 1.2, 1.45, 1.3, 0.45, 0.25, 0.35: cocked on the wind-up, opening to near straight.
- **B:** 1.3, 1.5, 1.45, 0.7, 0.1, 0.3: whippy, the wrist stays cocked late and snaps.
- **C:** 0.8, 0.9, 0.85, 0.7, 0.6, 0.6: firm, half-cocked throughout.

Checks: edge leads avg A 0.36 / B 0.23 / C 0.43 (was -0.7 in round 3), no reverse grip,
forearm over-turn 0.24 (was ~3).

Ranking (Zach): **B best** (whippy wrist). Problem: the wind-up/cock folds the arm in on
itself and the sword passes slightly through the head.

Takeaways:
- The cock point sat ~0.3 m from the shoulder (elbow folded tight) and the cocked blade,
  square to the forearm on the trailing side, ran straight through where the head is.
- **The solver keeps blades out of the head** (`_blade_clear`: the blade segment vs a head
  sphere of HEAD_CLEAR 0.2 m; any overlap pushes the hand and sword out from the head that
  frame, the push easing off once clear). animsheet's BLADE line reports head clearance and
  flags THROUGH THE HEAD.

## Round 5 (2026-10-08): slash_r, round 4 B with head clearance

All: round 4 B's whippy wrist (1.3, 1.5, 1.45, 0.7, 0.1, 0.3), the head clearance.
- **A:** round 4 B's path; the solver alone keeps the blade off the head.
- **B:** a wider, higher wind-up and cock (hand ~0.44 m from the shoulder instead of 0.32):
  the arm opens out.
- **C:** B's wide cock, the wrist eased there (1.15, 1.3, 1.35): the blade sits up over the
  shoulder instead of square behind the head.

Checks: no blade through the head in any (min clearance A 0.00, B 0.04, C 0.07 m). The wide
cock costs some edge lead (A 0.25, B 0.10, C 0.17) and the forearm over-turns at the cock
(1.17 vs A 0.17).

Ranking (Zach): **C > B > A.** The wide, high cock with the eased wrist wins. Problem: the
off arm is almost straight the whole wind-up and follow-through; a real arm keeps some bend.

Takeaways:
- **No limb held straight.** The off arm reached at 0.3 rad elbow on the wind-up and
  copied the cut's arm into the follow-through. Rule: an elbow or knee only straightens at
  the instant of full extension (a punch, a thrust); held or reaching it keeps 0.6+ rad.
- The 1.17 over-turn wasn't at the cock: it was a blip in the first frames, blending from the
  guard into the path (the forearm swings fast and the swivel lagged). Fixed most of it: the
  swivel follows fast while blending in, and the wrist's turn is taken nearest last frame's
  (no flip across +-pi). A 0.39 blip remains in those first frames (known).

## Round 6 (2026-10-08): slash_r, round 5 C with the off arm's elbow bent

All: round 5 C (wide high cock, eased wrist, whippy through the strike), the off arm with its
own follow-through pose. Off-arm elbow (rad) on the wind-up reach / the cut / the
follow-through:
- **A:** 0.6 / 1.2 / 0.9 (a little)
- **B:** 0.9 / 1.4 / 1.2 (more)
- **C:** 1.2 / 1.6 / 1.5 (a lot: the fist up by the face on the wind-up)

Ranking (Zach): **A** (a little bend). Bugs: "the elbow will flips and the arm bends
backwards", mainly after walking forward/back. Wants the off arm to raise and lower
smoothly, as well as turning toward and away from the chest.

Takeaways (reproduced with animsheet `AS_MOVE=0,1`: start the action from a walk):
- **Sword arm:** from a walk the elbow search settled with the elbow turned in across the
  chest for the whole wind-up. The elbow solver now has anatomy: an elbow pointing in across
  the body or far forward costs heavily.
- **Off arm:** keyed shoulder angles blending one by one rolled the upper arm over mid-cut.
  It's now on a hand path too ("reach": IK, points as offsets from its own shoulder in the
  chest's frame, so distance sets the elbow bend: 0.55 m ~0.7, 0.49 m ~1.2).
- **A pole along the reach leaves the elbow undefined**: the follow-through swept the hand
  down and back, exactly where the pole (out, down, back) pointed, and the elbow flipped up.
  A free arm's pole is "out to the side", and the solver leans any pole that lines up with
  the reach out to the side.
- **Paths start at the guard hand and arc round the shoulder.** A straight blend from the
  guard to behind the shoulder ran the hand through it, folding the arm and swinging the
  elbow across for a moment.

## Round 7 (2026-10-08): slash_r, the off hand on a path

All: round 6 A, the anatomical elbow, the wind-up arcing out from the guard (two new keys),
the off hand's path riding the chest. Off-hand offsets from the left shoulder:
- **A:** rises to chin height reaching toward the target, pulled down to the side through
  the cut, swept back low behind.
- **B:** A, raised higher (above the eyes) on the wind-up.
- **C:** A, but pulled in to the chest through the cut and kept tucked.

Ranking (Zach): **C best in slow motion, B a little better at full speed.** The whole move is
"a little too fast right now". The off hand in the cutlass guard sits too high.

Takeaways:
- Judge at full speed and in slow motion both: they can disagree (detail reads slowed, the
  silhouette reads at speed). Merge the two: B's raise, C's tuck.
- **Live change:** SWORD_GUARD's off hand lowered (arm_l (0.55, 0.35, -0.4) / elbow 1.35 ->
  (0.3, 0.25, -0.32) / 0.95): it rests low by the belly instead of up at the chest.
- New tool: spec "retime" (a time map) slows chosen phases (wind-up, follow-through) while
  the strike keeps its speed, without re-keying.

Follow-up (Zach): the guard's off hand should sit out to the side, not in front. SWORD_GUARD's
off arm opened sideways ((0.15, 0.1, -0.58), elbow 0.8): the hand hangs at the left side by
the hip, a little forward. The lab's off-hand path starts there (OFF_GUARD).

## Round 8 result and lock-in (2026-10-08)

Ranking (Zach): **A (0.85 s, slowed evenly)**, "pretty satisfied with the looks of it": locked
in as the live combo hit 1 and **the reference move** for every swing that follows
(`scripts/npc/sword_moves.gd`: SLASH_R_SWING, SLASH_R_REACH, `slash_r()` body keys;
ActionSpecs `slash_r`: 0.85 s, hit 0.45-0.6, chain 0.62 s, swoosh 0.4-0.66, sharp 55).

Also: the slash effects never matched the weapon (a fixed arc on its own timer). Moves on a
swing path now draw their trail off the real blade (`FX.blade_swoosh`: a BladeTrail ribbon in
the attack's colour for the spec's "swoosh" window), mirrored in co-op on the other screens'
copy of the body. Other moves keep the old arcs until they get a swing path.

## Round 8 (2026-10-08): slash_r timing

All: round 7's B raise with C's tuck, the lowered guard. Timing (now 0.75 s, hit ~0.34 s):
- **A:** 0.85 s, slowed evenly (hit ~0.38-0.51 s).
- **B:** 0.95 s retimed: the strike at the old speed (launch to follow-through ~0.17 s), the
  wind-up (~0.42 s) and follow-through longer (hit ~0.46-0.57 s).
- **C:** 0.95 s, slowed evenly (hit ~0.43-0.57 s).

Ranking: **A** (see "Round 8 result and lock-in" above).

## Round 9 (2026-10-08): combo hit 2, slash_l (the rising backhand)

Zach's brief: chain smoothly from hit 1; a left-to-right slash from the bottom left, the blade
turning up and slicing up, the follow-through carrying the sword past the right side.

Built from the reference (SwordMoves.SLASH_L_SWING / SLASH_L_REACH / `slash_l()`, 0.8 s, hit
0.37-0.52, chain 0.58 s):
- **Chaining:** its path starts on hit 1's last point (low left, the hand where hit 1's wrap
  leaves it) and its body starts on hit 1's follow-through pose (the chain point: hit 1 chains
  at 0.62 s, just before its wrap key), so hit 1's coil to the left is hit 2's wind-up. Swings
  and reaches now blend in from where the hand really was last frame (a new action starts
  them afresh even mid-swing), not from the keyed arm.
- Body: dip and coil (lift -0.3, squash), step through on the right foot into the cut (chest
  about square), turn right after it. Off hand: from hit 1's tuck forward as the body coils,
  then flung out and back to the left against the cut.
- animsheet shows it chained: ActionSpecs extras "after": "slash_r" plays hit 1 to its chain
  time first.

Checks (live): edge leads the cut avg 0.56 (hit 1: 0.3), no reverse grip, roll 0.37, head
clear. Variants (rise angle; body live):
- **A:** diagonal (live): low left up through the front to high right.
- **B:** steep: nearly straight up the front, ending high.
- **C:** flatter: a rising sweep ending at shoulder height.

Zach's first note: the off elbow looked wonky in places and the sword tip came close to the
body; he wanted the off arm straighter, popping out to the side and behind the chest in the
follow-through to sell the momentum. Changes:
- SLASH_L_REACH: an arc key at u 0.34 out past the hip (the straight chord from the front to
  behind the shoulder folded the elbow to 1.5 rad), points further out (0.64-0.67 m), poles
  down and back. Bends now 0.8 through the cut and 0.4-0.5 in the follow-through (was 1.5 / 0.9).
- The reach's pole fallback: when "out to the side" also lies along the reach (a hand flung
  out sideways), the elbow goes down.
- Blade clearance now covers the chest (a capsule hips to neck, 0.2 m) as well as the head;
  the BLADE line reports it as body clearance.

Ranking: **C > others** (the flatter rise, now live). Zach's note on C: in the follow-through
the arm is up with the chest turned and the upper arm clips the head; less chest turn, a
little more elbow bend. What it really was:
- **The chained hit re-anchored its path on a coiled body.** The swing frame follows the
  shoulders from where they were on the action's first frame, and paths are authored for the
  guard. Hit 2 starts with the shoulders still coiled left from hit 1, so as the body turned
  back the path slid ~0.4 m right and up, out of reach: the arm locked straight (bend 0.09)
  from contact through the follow-through and the upper arm rode up by the head. Fix: a hit
  chained from a running swing keeps that swing's anchor (one frame for the whole combo).
- Then retuned on the true frame: cut points nearer (r 0.58/0.53/0.5, the arm straight only
  for an instant at contact), the follow point further out (0.66, bend ~1.4), the cock eased
  (break 0.9/0.4, so the blade comes round into the cut sooner), and the follow-through
  turn cut from hips -0.45 / chest -0.6 to -0.3 / -0.33 (x1.6).
- New check: "upper arm clear of head" in the BLADE line (ARM IN THE HEAD when < 0), the
  sword arm's upper arm against the head sphere; `AS_DEBUG=live` now debugs the live row.

Checks (live): edge avg 0.32, body clearance 0.25 m, upper arm clear of head 0.04 m.
