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

Ranking: _waiting for Zach_

Takeaways: _after the ranking_
