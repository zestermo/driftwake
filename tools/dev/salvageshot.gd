extends SceneTree
## Salvage afloat: a brig's haul scattered off the moored sloop, close up, from a few metres, from her deck,
## and each kind on its own. Args: <out_prefix>
var t := 0.0
var out := ""
var cam: Camera3D
var ship
var shots: Array = []
var i := -1
var t0 := 0.0
var at := Vector3.ZERO
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		ship = get_first_node_in_group("ship")
		cam = Camera3D.new(); cam.fov = 55; cam.far = 1500; root.add_child(cam); cam.current = true
		var sal = load("res://scripts/ship/salvage.gd")
		at = ship.global_transform * Vector3(-22, 0, -4)
		sal.scatter(current_scene, at, "brig", 1234)
		var k := 0
		for kind in sal.KINDS:
			var s = sal.new()
			s.item_id = kind
			current_scene.add_child(s)
			s.global_position = at + Vector3(-14 + k * 2.2, 0, 10)
			k += 1
		shots = [
			["close", Vector3(5, 2.2, 5), Vector3(0, 0, 0)],
			["mid", Vector3(14, 5, 10), Vector3(0, 0, 0)],
			["kinds", Vector3(-10.7, 1.6, 14), Vector3(-10.7, 0, 10)],
		]
		t0 = t
		return false
	if i < 0 or t - t0 > 2.0:
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [out, shots[i][0]])
			print("shot ", shots[i][0])
		i += 1
		if i >= shots.size():
			quit()
			return false
		t0 = t
	if i >= 0:
		var s: Array = shots[i]
		var focus: Vector3 = at + (s[2] as Vector3)
		focus.y = 0.0
		cam.global_position = at + (s[1] as Vector3)
		cam.look_at(focus, Vector3.UP)
	return false
