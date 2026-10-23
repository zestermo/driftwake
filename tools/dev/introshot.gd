extends SceneTree
## A new game's opening (Intro), rendered (GPU, opens a window): a frame of each narration shot, then one of the fight
## on Holt's deck. `& $env:GODOT --path . --script res://tools/dev/introshot.gd -- <out_prefix>`
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var out := "res://tools/dev/out/intro"
var intro
var shot := -1
var saved := 0
var t := 0.0
var step := 0
var until := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "weather": true, "water": true})


func _save(tag: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := "%s_%02d_%s.png" % [out, saved, tag]
	img.save_png(ProjectSettings.globalize_path(path))
	print("IS saved ", path)
	saved += 1


func _process(d: float) -> bool:
	# (a windowed first launch opens the character creator: accept the default captain)
	var cc := load("res://scripts/ui/character_creator.gd")
	for n in root.find_children("*", "", true, false):
		if n.get_script() == cc and n.is_inside_tree():
			n._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			intro = load("res://scripts/game/intro.gd").play(stage.player, func(): pass)
			step = 1
		1:
			var c = load("res://scripts/dialogue/cutscene.gd").active
			if c == null:
				until = TK.wait_secs(4.0)
				step = 2
				return false
			if c._i != shot:
				shot = c._i
				t = 0.0
			t += d
			if t >= c._len * 0.8 and t - d < c._len * 0.8:
				_save("shot%d" % shot)
		2:
			_save("fight")
			print("IS done")
			quit()
	return false
