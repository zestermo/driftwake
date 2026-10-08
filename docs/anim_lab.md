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

Ranking: _waiting for Zach_
