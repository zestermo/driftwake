extends SceneTree
## The map on Brinehollow: the captain looks round a few places (the harbour, the ruins' path, the
## lighthouse hill), then shots of the island page and the sea chart.
## Args: <out_prefix> [psx]
var t := 0.0
var out := ""
var step := 0
var t0 := 0.0


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func _process(d: float) -> bool:
	t += d
	if t < 2.5:
		return false
	match step:
		0:
			if OS.get_cmdline_user_args().has("psx"):
				root.get_node("Settings").set_value("video", "pixelate", true, false)
			else:
				root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			for c in root.find_children("*", "CharacterCreator", true, false):
				c._finish(true)
			var gm = root.get_node("GameManager")
			var mf = load("res://scripts/map/map_fog.gd")
			var w = get_first_node_in_group("world_gen")
			var dd: Dictionary = load("res://scripts/map/map_isles.gd").of(w.starter_island)
			var o: Vector2 = dd["o"]
			for q in [Vector2(0, -62), Vector2(0, -110), Vector2(-30, -20), Vector2(-62, 58), Vector2(-40, 20), Vector2(40, -45), Vector2(78, -30)]:
				mf.look(gm, dd, Vector3(o.x + q.x, 30.0 if q == Vector2(78, -30) else 4.0, o.y + q.y))
			t0 = t
		1:
			if t - t0 < 0.5:
				return false
			root.get_node("GameMenu").open("chart")
			t0 = t
		2:
			if t - t0 < 1.0:
				return false
			root.get_texture().get_image().save_png("%s_isle.png" % out)
			print("shot isle")
			root.get_node("GameMenu")._chart.show_isle(false)
			t0 = t
		3:
			if t - t0 < 1.0:
				return false
			root.get_texture().get_image().save_png("%s_chart.png" % out)
			print("shot chart")
			quit()
	step += 1
	return false
