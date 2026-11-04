extends SceneTree
## The 1.28 sea stops in the real world (opens a window): the real sea, sky and light, unlike seastopshot's bare
## stage. Each stop is built on open water off Brinehollow and filmed far, near and close: the merchant, the floating
## restaurant (and a raided one), the warlord's flagship and the Admiralty warship.
## Args: <out_prefix> [x z: the open-water spot, default 0 -700]
var out := ""
var at := Vector3(0, 0, -700)
var cam: Camera3D
var stop: Node3D
var holder: Node3D
var SeaStops
var shots: Array = []
var i := -1
var until := 0.0
var t := 0.0
var pending := ""


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() >= 3:
		at = Vector3(float(a[1]), 0, float(a[2]))
	change_scene_to_file("res://scenes/world/world.tscn")


func _restaurant_seed(attacked: bool) -> int:
	var R = load("res://scripts/sea/floating_restaurant.gd")
	for s in range(1, 200):
		if R.new().setup(Vector3.ZERO, 12, s).attacked == attacked:
			return s
	return 1


func _make(kind: String, seed_value: int) -> void:
	if stop and is_instance_valid(stop):
		stop.queue_free()
	if kind in ["flagship", "warship"]:
		stop = SeaStops.big(holder, kind, at, 12, seed_value)
	else:
		stop = SeaStops.build(holder, kind, Vector2(at.x, at.z), 12, seed_value)
	stop.set_meta("no_sleep", true)


func _process(d: float) -> bool:
	t += d
	if t < 2.0 or t < until:
		return false
	if cam == null:
		root.get_node("Settings").set_value("video", "pixelate", true, false)
		for c in root.find_children("*", "CharacterCreator", true, false):
			c._finish(true)
		var hud := get_first_node_in_group("hud")
		if hud:
			hud.visible = false
		SeaStops = load("res://scripts/sea/sea_stops.gd")
		holder = Node3D.new()
		holder.name = "StopShots"
		current_scene.add_child(holder)
		cam = Camera3D.new()
		cam.fov = 55
		cam.far = 3000
		cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		root.add_child(cam)
		cam.current = true
		# [name, kind to build first (or ""), seed, from (stop-local), at (stop-local)]
		shots = [
			["merchant_far", "merchant", 4242, Vector3(-200, 14, 120), Vector3(0, 8, 0)],
			["merchant_near", "", 0, Vector3(30, 9, 26), Vector3(0, 6, 0)],
			["merchant_deck", "", 0, Vector3(2.5, 2.4, 3.5), Vector3(0, 1.4, -4.2)],
			["rest_far", "restaurant", _restaurant_seed(false), Vector3(-300, 20, 190), Vector3(0, 8, 0)],
			["rest_near", "", 0, Vector3(90, 24, 80), Vector3(0, 6, -8)],
			["rest_bow", "", 0, Vector3(-60, 12, -100), Vector3(0, 3, -52)],
			["rest_eye", "", 0, Vector3(-26, 4, -66), Vector3(-12, 1.5, -54)],
			["rest_front", "", 0, Vector3(-9, 4, 38), Vector3(0, 6, 14)],
			["rest_side", "", 0, Vector3(36, 7, -16), Vector3(12, 5, -7)],
			["rest_landing", "", 0, Vector3(31, 2.5, 18), Vector3(22, -0.5, -6)],
			["rest_hall", "", 0, Vector3(3.5, 2.6, 12), Vector3(-0.5, 1.2, -18)],
			["rest_kitchen", "", 0, Vector3(-3.0, 2.3, -13.0), Vector3(3.0, 1.4, -22.5)],
			["rest_hall_back", "", 0, Vector3(-2.0, 2.4, -12.0), Vector3(0.0, 3.0, 14.0)],
			["rest_raid", "restaurant", _restaurant_seed(true), Vector3(-10, 6, 40), Vector3(0, 1, 20)],
			["flagship_far", "flagship", 4242, Vector3(-240, 16, 160), Vector3(0, 12, 0)],
			["flagship_near", "", 0, Vector3(34, 10, 30), Vector3(0, 9, 0)],
			["flagship_deck", "", 0, Vector3(-2.5, 4.0, -9), Vector3(0.5, 1.5, 0)],
			["warship_near", "warship", 777, Vector3(34, 10, 30), Vector3(0, 9, 0)],
		]
		# the captain stands off on the water's edge of the weather (the weather follows the player)
		var p = get_first_node_in_group("player")
		p.global_position = at + Vector3(0, 40, 60)
	if pending != "":
		root.get_texture().get_image().save_png("%s_%s.png" % [out, pending])
		print("saved %s_%s.png" % [out, pending])
		pending = ""
	i += 1
	if i >= shots.size():
		quit()
		return true
	var s: Array = shots[i]
	if s[1] != "":
		_make(s[1], s[2])
		until = t + 3.0
		i -= 1
		shots[i + 1] = [s[0], "", 0, s[3], s[4]]
		return false
	if stop.has_method("_start_deck_fight"):
		stop.set_physics_process(false)
	cam.global_position = stop.to_global(s[3])
	cam.look_at(stop.to_global(s[4]), Vector3.UP)
	pending = s[0]
	until = t + 0.15
	return false
