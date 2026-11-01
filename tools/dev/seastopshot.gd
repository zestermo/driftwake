extends SceneTree
## 1.28 sea stops renders on the light stage (opens a window): the merchant ship from afar and on her deck
## (_merchant_far, _merchant_near, _merchant_deck), the floating restaurant from afar, close, at her landing stage,
## inside the hall and with raiders on her deck (_rest_far, _rest_near, _rest_landing, _rest_hall, _rest_raid), and the
## big named ships (_<kind>_far, _<kind>_near, _<kind>_deck, _<kind>_fight) once they exist. Args: <out_prefix> [psx]
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var out := ""
var cam: Camera3D
var ship
var stop
var step := 0
var until := 0
var pending := ""
var SeaStops


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "ship": true})


func _look(node: Node3D, from_local: Vector3, at_local: Vector3, n: String) -> void:
	cam.global_position = node.to_global(from_local)
	cam.look_at(node.to_global(at_local), Vector3.UP)
	pending = n
	until = TK.wait_ticks(4)


func _make(kind: String, at: Vector3, seed_value: int) -> Node3D:
	if stop and is_instance_valid(stop):
		stop.queue_free()
	var s = SeaStops.build(stage, kind, Vector2(at.x, at.z), 12, seed_value)
	s.set_meta("no_sleep", true)
	return s


func _restaurant_seed(attacked: bool) -> int:
	var R = load("res://scripts/sea/floating_restaurant.gd")
	for s in range(1, 200):
		if R.new().setup(Vector3.ZERO, 12, s).attacked == attacked:
			return s
	return 1


func _process(_d: float) -> bool:
	if not stage.up:
		for c in root.find_children("*", "CharacterCreator", true, false):
			c._finish(true)
	if not stage.up or TK.ticking(until):
		return false
	if pending != "":
		root.get_texture().get_image().save_png(out + "_" + pending + ".png")
		print("saved " + out + "_" + pending + ".png")
		pending = ""
	match step:
		0:
			SeaStops = load("res://scripts/sea/sea_stops.gd")
			if OS.get_cmdline_user_args().has("psx"):
				root.get_node("Settings").set_value("video", "pixelate", true, false)
			else:
				root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
			ship = stage.ship
			stage.player.global_position = ship.to_global(Vector3(-1.0, 0.6, 1.0))
			stage.player.reset_physics_interpolation()
			cam = Camera3D.new()
			cam.fov = 55
			cam.far = 3000
			cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			root.add_child(cam)
			cam.current = true
			stop = _make("merchant", ship.global_position + Vector3(60, 0, -30), 4242)
			until = TK.wait_secs(4.0)
		1:
			_look(ship, Vector3(-3.0, 6.0, 8.0), ship.to_local(stop.global_position) + Vector3(0, 6.0, 0), "merchant_near")
		2:
			cam.global_position = stop.global_position + Vector3(-260.0, 14.0, 160.0)
			cam.look_at(stop.global_position + Vector3(0, 8.0, 0), Vector3.UP)
			pending = "merchant_far"
			until = TK.wait_ticks(4)
		3:
			_look(stop, Vector3(2.5, 2.4, 3.5), Vector3(0.0, 1.4, -4.2), "merchant_deck")
		4:
			stop = _make("restaurant", ship.global_position + Vector3(90, 0, -40), _restaurant_seed(false))
			until = TK.wait_secs(3.0)
		5:
			cam.global_position = stop.global_position + Vector3(-420.0, 20.0, 260.0)
			cam.look_at(stop.global_position + Vector3(0, 8.0, 0), Vector3.UP)
			pending = "rest_far"
			until = TK.wait_ticks(4)
		6:
			_look(stop, Vector3(45.0, 12.0, 40.0), Vector3(0.0, 4.0, -4.0), "rest_near")
		7:
			_look(stop, Vector3(-30.0, 9.0, -45.0), Vector3(0.0, 2.0, -18.0), "rest_bow")
		8:
			_look(stop, Vector3(19.0, 2.0, 14.0), Vector3(11.0, -0.5, -4.0), "rest_landing")
		9:
			_look(stop, Vector3(3.5, 2.6, 7.0), Vector3(-0.5, 1.2, -10.0), "rest_hall")
		10:
			stop = _make("restaurant", ship.global_position + Vector3(90, 0, -40), _restaurant_seed(true))
			until = TK.wait_secs(5.0)
		11:
			_look(stop, Vector3(-6.0, 5.0, 24.0), Vector3(0.0, 1.0, 10.0), "rest_raid")
		12:
			quit()
			return true
	step += 1
	return false
