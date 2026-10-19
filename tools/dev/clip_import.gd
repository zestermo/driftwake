extends SceneTree
## Imports a clip authored on the rig (docs/blender_clips.md): a glb whose armature's bones are named after the
## Humanoid's joints, its first animation (or the named one) sampled at 30 fps and retargeted onto the default
## captain (ClipPlayer.from_scene), saved as a BodyClip the game plays as "clip_<name>".
##   godot --path . --script res://tools/dev/clip_import.gd -- res://art/clips/read.glb res://assets/clips/read.tres upper [anim] [hold]
## mask: "upper" (the legs keep walking or sitting) or "full"; "hold" for a one-shot that stops on its last frame.

var _f := 0


func _process(_d: float) -> bool:
	_f += 1
	if _f < 3:
		return false
	var a := OS.get_cmdline_user_args()
	var clip := load_clip(self, a[0], a[2], a[3] if a.size() > 3 else "", not a.has("hold"))
	assert(ResourceSaver.save(clip, a[1]) == OK)
	print("CLIP %s: %.2f s, %d frames, joints %s%s" % [a[1], clip.length, clip.frames(), ",".join(clip.tracks.keys()), ", lift" if not clip.lift.is_empty() else ""])
	quit()
	return false


## The glb at `path` as a BodyClip (also the clip test's check that the saved clip is the glb's).
static func load_clip(tree: SceneTree, path: String, mask: String, anim: String, looped: bool) -> BodyClip:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(ProjectSettings.globalize_path(path), state) == OK, "can't read " + path)
	var scene := doc.generate_scene(state)
	tree.root.add_child(scene)
	var h = load("res://scripts/npc/humanoid.gd").new()
	tree.root.add_child(h)
	h.setup(CharacterLook.default_look())
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var name := anim if anim != "" else str(ap.get_animation_list()[0])
	var clip := ClipPlayer.from_scene(scene, name, ClipPlayer.rests(h), 30.0, mask, looped)
	scene.queue_free()
	h.queue_free()
	return clip
