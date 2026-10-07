extends SceneTree
## The shipwright's work: the plain sloop, then fully refitted in two colour
## schemes (side, bow, masthead), Tackett at his timber, and the yard screen.
## Args: <out_prefix>
var t := 0.0
var out := ""
var cam: Camera3D
var ship
var p
var gm
var shots: Array = []
var i := -1
var t0 := 0.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func kit(k: Dictionary) -> void:
	var full: Dictionary = load("res://scripts/ship/ship_kit.gd").merged(k)
	root.get_node("Net").set_ship_kit(full)
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		ship = get_first_node_in_group("ship")
		p = get_first_node_in_group("player")
		gm = root.get_node("GameManager")
		cam = Camera3D.new(); cam.fov = 55; cam.far = 1500; root.add_child(cam); cam.current = true
		var tackett = null
		for n in current_scene.find_children("*", "NPC", true, false):
			if n.dialogue_id == "tackett": tackett = n
		var refit := {"armour": true, "guns": true, "sails": true, "rudder": true}
		shots = [
			["plain", {}, Vector3(14, 4, 3), Vector3(0, 2, 0)],
			["refit_side", refit.merged({"hull": 2, "sail": 1, "field": 1, "emblem": 1, "mark": 0, "figure": 1}), Vector3(14, 4, 3), Vector3(0, 2, 0)],
			["refit_bow", refit.merged({"hull": 2, "sail": 1, "field": 1, "emblem": 1, "mark": 0, "figure": 1}), Vector3(4, 2.5, -14), Vector3(0, 1, -7)],
			["masthead", refit.merged({"hull": 2, "sail": 1, "field": 1, "emblem": 1, "mark": 0, "figure": 1}), Vector3(4, 12, 3), Vector3(0, 10.8, -0.5)],
			["navy", refit.merged({"hull": 3, "sail": 4, "field": 2, "emblem": 3, "mark": 2, "figure": 2}), Vector3(-13, 5, -6), Vector3(0, 2, -1)],
			["lion", refit.merged({"hull": 3, "sail": 4, "field": 2, "emblem": 3, "mark": 2, "figure": 2}), Vector3(3, 2.0, -13), Vector3(0, 1, -7.5)],
			["serpent", refit.merged({"hull": 5, "sail": 2, "field": 3, "emblem": 2, "mark": 2, "figure": 3}), Vector3(5, 3.5, -14), Vector3(0, 2, -5)],
			["eagle", refit.merged({"hull": 1, "sail": 0, "field": 4, "emblem": 4, "mark": 3, "figure": 4}), Vector3(-5, 3.5, -14), Vector3(0, 2, -5)],
		]
		if tackett:
			shots.append(["tackett", null, tackett.global_position + tackett.global_basis.z * 4.0 + Vector3(1.5, 1.6, 0), tackett.global_position + Vector3(0, 1.0, 0)])
		shots.append(["screen", null, Vector3.ZERO, Vector3.ZERO])
		t0 = t
		return false
	if i < 0 or t - t0 > 1.2:
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s.png" % [out, shots[i][0]])
			print("shot ", shots[i][0])
		i += 1
		if i >= shots.size():
			quit()
			return false
		var s: Array = shots[i]
		if s[0] == "screen":
			root.get_node("GameMenu").open("yard")
		elif s[0] == "tackett":
			cam.global_position = s[2]
			cam.look_at(s[3], Vector3.UP)
		else:
			kit(s[1])
			cam.global_position = ship.global_transform * s[2]
			cam.look_at(ship.global_transform * s[3], Vector3.UP)
		t0 = t
	elif shots[i][0] != "screen" and shots[i][0] != "tackett":
		cam.global_position = ship.global_transform * (shots[i][2] as Vector3)
		cam.look_at(ship.global_transform * (shots[i][3] as Vector3), Vector3.UP)
	return false
