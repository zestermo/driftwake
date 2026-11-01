extends SceneTree
## The cooking game in first person on the light stage: one shot per beat (stir, flip mid-heat, plate sweeping)
## and the plated result. Args: <out_prefix>  (saves <out>_stir.png, _flip.png, _plate.png, _done.png)
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var t := 0.0
var step := 0
var gm
var scr


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func shot(name: String) -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out.get_base_dir()))
	root.get_texture().get_image().save_png("%s_%s.png" % [out, name])


func _process(d: float) -> bool:
	var cc := load("res://scripts/ui/character_creator.gd")
	for n in root.find_children("*", "", true, false):
		if n.get_script() == cc and n.is_inside_tree():
			n._finish(true)
	if not stage.up:
		return false
	t += d
	match step:
		0:
			var inv = stage.player.inventory_component
			inv.add_item(ItemDB.get_item("fish"), 2)
			inv.add_item(ItemDB.get_item("rice"), 2)
			gm = root.get_node("GameMenu")
			gm.open_galley(1)
			gm._galley._pick("fish_stew")
			gm._galley.play_selected()
			scr = gm._cook
			step = 1
			t = 0.0
		1:
			if t > 0.9:
				shot("stir")
				for i in range(3):
					scr.timing.t = scr.timing.mark_angle() / (TAU * CookTiming.STIR_TURNS)
					scr.press()
				step = 2
				t = 0.0
		2:
			if t > 1.1:
				shot("flip")
				scr.timing.t = scr.timing.rise_secs() * 0.79
				scr.press()
				step = 3
				t = 0.0
		3:
			if t > 1.0:
				shot("plate")
				scr.timing.t = CookTiming.PLATE_SWEEP * 0.5
				scr.press()
				step = 4
				t = 0.0
		4:
			if t > 0.5:
				shot("done")
				print("SAVED")
				quit()
	return false
