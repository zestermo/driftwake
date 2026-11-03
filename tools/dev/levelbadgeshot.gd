extends SceneTree
## (1.30) The enemy health bars' level badges on the light stage: a level-10 captain facing three grunts at gaps -6,
## 0 and +3 (grey, white, red), hit so their bars show. Saves <out>.png (the screen) and <out>_zoom.png (the bars x4).
## Args: <out base path> [WxH]
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0


func _initialize() -> void:
	TK.seed_of(self)
	var a := OS.get_cmdline_user_args()
	if a.size() > 1:
		var wh := a[1].split("x")
		root.size = Vector2i(int(wh[0]), int(wh[1]))
	stage = TK.stage(self, {"grunts": [
		{"post": Vector3(-2.6, 0, -7.0), "yaw": PI, "mode": "stand", "seed": 11},
		{"post": Vector3(0.0, 0, -7.5), "yaw": PI, "mode": "stand", "seed": 12},
		{"post": Vector3(2.6, 0, -7.0), "yaw": PI, "mode": "stand", "seed": 13}]})


func _process(_d: float) -> bool:
	# (a windowed run opens the creator first)
	for c in root.find_children("*", "CharacterCreator", true, false):
		c._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 3:
				return false
			stage.player.progression.level = 10
			var lv := [4, 10, 13]
			var hp := [0.8, 0.45, 0.95]
			for i in 3:
				var g = stage.camp.grunts[i]
				g.level = lv[i]
				g.process_mode = Node.PROCESS_MODE_DISABLED
				g.health.current_health = g.health.max_health * hp[i]
				stage.hud._enemy_bars.shown[g.get_instance_id()] = {"n": g, "t": 0.0}
			until = TK.wait_secs(0.8)
		1:
			for e in stage.hud._enemy_bars.shown.values():
				e["t"] = 0.0
			until = TK.wait_ticks(4)
		2:
			var out: String = OS.get_cmdline_user_args()[0]
			var img := root.get_texture().get_image()
			img.save_png(out + ".png")
			var sz := img.get_size()
			var crop := img.get_region(Rect2i(sz.x / 4, sz.y / 8, sz.x / 2, sz.y * 3 / 8))
			crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
			crop.save_png(out + "_zoom.png")
			print("SAVED ", out)
			quit()
	step += 1
	return false
