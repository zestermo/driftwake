# The Blender clip pilot (docs/blender_clips.md): keys a clip on the captain's armature and exports it as a
# glb the game imports (tools/dev/clip_import.gd). Run headless:
#   blender --background --python tools/blender/pilot_clip.py -- art/clips/rig.glb tools/blender/pilot_read.json art/clips/read.glb
# The rig (art/clips/rig.glb, from tools/dev/clip_rig.gd) has one bone per Humanoid joint, named after it.
# The keys are joint rotations in the Humanoid's own convention (Euler YXZ in Godot's axes, relative to the
# parent joint); each becomes the pose bone's rotation q = Mr^-1 (C R C^-1) Mr, Mr the bone's rest in world
# space and C Godot's axes to Blender's (glTF's Y-up to Z-up), the reverse of what the importer undoes.
import json
import sys

import bpy
from mathutils import Matrix

rig, keys_path, out = sys.argv[sys.argv.index("--") + 1:]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=rig, bone_heuristic="BLENDER", guess_original_bind_pose=False)
arm = next(ob for ob in bpy.context.scene.objects if ob.type == "ARMATURE")
with open(keys_path) as f:
    clip = json.load(f)

C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
fps = int(clip["fps"])
scene = bpy.context.scene
scene.render.fps = fps
scene.frame_start = 0
scene.frame_end = int(round(clip["length"] * fps))

bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="POSE")
action = bpy.data.actions.new(clip["name"])
arm.animation_data_create()
arm.animation_data.action = action


def godot_basis(e):
    # Godot's Basis.from_euler(e) in YXZ order: Ry * Rx * Rz
    return (Matrix.Rotation(e[1], 3, "Y") @ Matrix.Rotation(e[0], 3, "X") @ Matrix.Rotation(e[2], 3, "Z"))


for key in clip["keys"]:
    frame = int(round(key["t"] * fps))
    for joint, e in key["pose"].items():
        pb = arm.pose.bones[joint]
        mr = (arm.matrix_world @ pb.bone.matrix_local).to_3x3().normalized()
        q = (mr.inverted() @ C @ godot_basis(e) @ C.inverted() @ mr).to_quaternion()
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=frame)

bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True, export_animation_mode="ACTIONS",
                          export_frame_range=True, export_force_sampling=True, export_yup=True, export_apply=False)
print("exported", out, "frames", scene.frame_end, "joints", len(clip["keys"][0]["pose"]))
