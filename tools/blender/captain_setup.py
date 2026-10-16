# Blender side of BlenderBody (scripts/npc/blender_body.gd), run by it as:
#   blender --background --python captain_setup.py -- <export.glb> <out.blend> <model.glb or "">
# Imports the baked captain, sets the PS1 look up for editing, adds a glTF collection
# exporter aimed at the game's model and saves the .blend (exporting the model too when given).
import os
import sys

import bpy

src, out_blend, model = sys.argv[sys.argv.index("--") + 1:]

bpy.ops.wm.read_factory_settings(use_empty=True)
# BLENDER keeps every bone's rest exactly as glTF has it, so the export comes back unchanged
bpy.ops.import_scene.gltf(filepath=src, bone_heuristic="BLENDER", guess_original_bind_pose=False,
                          import_scene_as_collection=False, disable_bone_shape=True)

scene = bpy.context.scene
col = bpy.data.collections.new("Captain")
scene.collection.children.link(col)
for ob in list(scene.collection.objects):
    col.objects.link(ob)
    scene.collection.objects.unlink(ob)
print("objects", sorted(ob.name for ob in col.objects))

for mat in bpy.data.materials:
    if mat.node_tree:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE":
                n.interpolation = "Closest"
bpy.ops.file.pack_all()

for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == "VIEW_3D":
            area.spaces.active.shading.type = "MATERIAL"

blend_dir = os.path.dirname(out_blend)
model_path = os.path.normpath(os.path.join(blend_dir, "..", "..", "assets", "models", "captain", "captain.glb"))
settings = dict(export_format="GLB", export_vertex_color="ACTIVE", export_all_influences=True,
                export_animations=False, export_yup=True, export_apply=False)

layer = bpy.context.view_layer.layer_collection.children[col.name]
bpy.context.view_layer.active_layer_collection = layer
with bpy.context.temp_override(collection=col):
    bpy.ops.collection.exporter_add(name="IO_FH_gltf2")
props = col.exporters[0].export_properties
props.filepath = model_path
for k, v in settings.items():
    setattr(props, k, v)

os.makedirs(blend_dir, exist_ok=True)
# (absolute: the glTF exporter refuses "//" paths)
bpy.ops.wm.save_as_mainfile(filepath=out_blend, relative_remap=False)
print("saved", out_blend)

if model:
    os.makedirs(os.path.dirname(model), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=model, use_active_collection=True, **settings)
    print("exported", model)
