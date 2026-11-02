extends SceneTree
## Every Edy type's attunement (Progression.attune: the burst and the banner) played in a window on the light stage, one
## shot each, to see the burst and catch a GPU-only fault the headless tests can't. Args: <out_prefix>
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var t := 0.0
var step := 0
var ids: Array = []


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func _process(d: float) -> bool:
	var cc := load("res://scripts/ui/character_creator.gd")
	for n in root.find_children("*", "", true, false):
		if n.get_script() == cc and n.is_inside_tree():
			n._finish(true)
	if not stage.up:
		return false
	t += d
	if step == 0:
		ids = load("res://scripts/progression/edy_types.gd").TYPES.keys()
		step = 1
		t = 0.0
		return false
	var i := step - 1
	if i >= ids.size():
		print("SAVED")
		quit()
		return false
	if t > 0.3 and not stage.has_meta("did%d" % i):
		stage.set_meta("did%d" % i, true)
		print("attune ", ids[i])
		stage.player.progression.attune(str(ids[i]))
	if t > 0.75:
		var out := OS.get_cmdline_user_args()[0]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
		root.get_texture().get_image().save_png("%s_%s.png" % [out, ids[i]])
		step += 1
		t = 0.0
	return false
