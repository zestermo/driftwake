# Makes the .blend Zach animates in (docs/blender_clips.md): the captain's armature from art/clips/rig.glb
# (tools/dev/clip_rig.gd: one bone per Humanoid joint, named after it, and a stick body skinned to it), with
# the scene at 30 fps and a glTF collection exporter aimed at art/clips/<name>.glb. Run headless:
#   blender --background --python tools/blender/rig_setup.py -- art/clips/rig.glb art/blender/clips.blend
# Never overwrites an existing .blend (it writes <name>_new.blend beside it instead).
import os
import sys

import bpy

rig, out_blend = sys.argv[sys.argv.index("--") + 1:]
if os.path.exists(out_blend):
    out_blend = out_blend[:-6] + "_new.blend"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=rig, bone_heuristic="BLENDER", guess_original_bind_pose=False)
scene = bpy.context.scene
scene.render.fps = 30
col = bpy.data.collections.new("Captain")
scene.collection.children.link(col)
for ob in list(scene.collection.objects):
    col.objects.link(ob)
    scene.collection.objects.unlink(ob)
for ob in col.objects:
    if ob.type == "ARMATURE":
        ob.animation_data_create()
        for pb in ob.pose.bones:
            pb.rotation_mode = "QUATERNION"

clips_dir = os.path.normpath(os.path.join(os.path.dirname(out_blend), "..", "clips"))
layer = bpy.context.view_layer.layer_collection.children[col.name]
bpy.context.view_layer.active_layer_collection = layer
with bpy.context.temp_override(collection=col):
    bpy.ops.collection.exporter_add(name="IO_FH_gltf2")
props = col.exporters[0].export_properties
props.filepath = os.path.join(clips_dir, "clip.glb")
for k, v in dict(export_format="GLB", export_animations=True, export_animation_mode="ACTIVE_ACTIONS",
                 export_force_sampling=True, export_yup=True, export_apply=False).items():
    setattr(props, k, v)

os.makedirs(os.path.dirname(out_blend), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=out_blend, relative_remap=False)
print("saved", out_blend)
