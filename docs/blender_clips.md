# Clips from Blender (the pilot, v1.18)

Long, natural, full-body loops (downtime, idles, gestures, NPC work) can be authored in Blender and played by
the Humanoid next to its keyed poses. Combat stays procedural. The pilot plays sailing downtime's **Read**
from a clip (`clip_read`).

## How it fits together

| Piece | Where | What |
|---|---|---|
| The rig | `art/clips/rig.glb` (made by `tools/dev/clip_rig.gd`) | The default captain's 14 joints as an armature, one bone per `Humanoid.JOINTS` name (`pivot`, `hips`, `torso`, `head`, `arm_l`, `fore_l`, `hand_l`, `arm_r`, ..., `shin_r`), at rest with every rotation zeroed, plus a stick body skinned to it. |
| The Blender file | `art/blender/clips.blend` (made by `tools/blender/rig_setup.py`) | The rig imported, 30 fps, quaternion bones, a glTF collection exporter aimed at `art/clips/`. Animate here. |
| A clip | `art/clips/<name>.glb` | The rig with an action on it, exported from Blender. |
| The importer | `tools/dev/clip_import.gd` -> `ClipPlayer.from_scene` | Samples the glb's animation at 30 fps and retargets it onto the captain: each joint's global rotation is `bone_now * bone_rest^-1 * source_rest` (the reverse of the old BlenderBody's), then its rotation against its parent joint, as the animator's Euler (YXZ), kept continuous. The hips' movement becomes lift. |
| The clip resource | `assets/clips/<name>.tres` (`BodyClip`) | Per-joint rotation tracks (one Euler a frame), fps, length, loop, mask, lift. |
| The player | `scripts/npc/clip_player.gd` (`ClipPlayer`) | An action named `clip_<name>` plays `assets/clips/<name>.tres` through `Humanoid._action_pose` (one line there). It blends, masks (`upper` keeps the legs walking or sitting), holds, loops on the action's own clock and mirrors to co-op screens like any keyed action. Play it with `body.hold("clip_<name>", 0.4)` or `body.play("clip_<name>", seconds)`. |

## Dropping in your own clip

1. **Blender** (once): make the file to animate in.
   `blender --background --python tools/blender/rig_setup.py -- art/clips/rig.glb art/blender/clips.blend`
   (It never overwrites: a second run writes `clips_new.blend`.) If the rig changes (a new joint), rerun
   `& $env:GODOT --path . --script res://tools/dev/clip_rig.gd -- res://art/clips/rig.glb` first.
2. **Animate** on the armature: rotate bones only (moving `pivot` up and down is kept as hip lift; other
   translations are ignored). Keep the bone names. One action per clip; name the action what the clip is
   (`read`, `coil_rope`). For a loop, make the last frame the first.
   - **Hand-keyed:** key rotations in pose mode at 30 fps.
   - **Mixamo or other mocap:** import the FBX, then retarget it onto this armature (Blender's own retargeting,
     or an add-on such as Rokoko's, mapping Mixamo's Hips/Spine/Neck/Head/LeftArm/LeftForeArm/LeftHand/
     LeftUpLeg/LeftLeg... to `hips`/`torso`/`head`/`arm_l`/`fore_l`/`hand_l`/`leg_l`/`shin_l`...). Bake the
     result to keyframes on our armature, then delete the Mixamo rig. Mixamo's rest is a T-pose, ours is arms
     down: the retarget has to line the rests up (in Rokoko: "use pose: current" with both in the same pose).
3. **Export** the glb: the collection's exporter (Collection properties > Exporters > Export), or File > Export >
   glTF 2.0 (.glb) with Animation ticked, "Actions" mode, "Always sample animations", +Y up, into
   `art/clips/<name>.glb`.
4. **Import** it into the game:
   `& $env:GODOT --path . --script res://tools/dev/clip_import.gd -- res://art/clips/<name>.glb res://assets/clips/<name>.tres upper`
   (`full` instead of `upper` for a clip that moves the legs; add the action's name if the glb holds several;
   `hold` at the end for a one-shot that stops on its last frame.) It prints the length, frames and joints.
5. **Play it**: `body.hold("clip_<name>", 0.4)`; give it an `ActionSpecs.SPECS` line (`"clip_<name>": {"len": 0.4, ...}`)
   like the keyed actions. To swap a downtime loop, point `Downtime.pose_of` at it (Read is `clip_read`).
6. **Check it**: `& $env:GODOT --path . --script res://tools/dev/posebench.gd -- res://tools/dev/out/pb sword none clip_<name>:0.15 three,side`
   (`PB_SEAT=0.45` for a seated clip; a held clip's time is u x 30 s), and in game.

## The pilot clip

`tools/blender/pilot_read.json` holds the reading loop's keys (joint Eulers in the animator's convention at
7 times over 4 s: reading down the page, a page turned at 2.9 s). In Blender:
`blender --background --python tools/blender/pilot_clip.py -- art/clips/rig.glb tools/blender/pilot_read.json art/clips/read.glb`
keys them on the armature (each key becomes the bone's rotation `Mr^-1 (C R C^-1) Mr`, Mr its world rest and C
Godot's axes to Blender's) and exports the glb. Blender wasn't installed on the machine the pilot was built on,
so the committed `art/clips/read.glb` came from the stand-in, `tools/dev/clip_rig.gd` given the same keys
file (it keys the rig in Godot and writes the same kind of glb); `pilot_clip.py` is untested until it runs in
Blender once. The importer and everything after it are the real path either way.
`t/downtime/clip_play` checks the glb imports to the saved clip, the keyed rotations at their times, the upper
mask and the body following it.
