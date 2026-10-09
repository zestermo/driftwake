extends SceneTree
## Sea and wind effects: Brinehollow's beach in calm and in a storm (surf
## rolling in, the swash, spray where waves break), and out at sea in a storm
## under full sail, from astern and from the deck (whitecaps, wind streaks,
## spray off the crests and over the bow). Three frames a shot, 0.35 s apart
## (spray comes and goes). Args: <out_prefix> [psx]
var t := 0.0
var out := ""
var cam: Camera3D
var p
var ship
var wx
var isl
var shots: Array = []
var i := -1
var frame := 0
var t0 := 0.0
var beach := Vector3.ZERO
var beach_out := Vector3.ZERO


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func weather(state: int) -> void:
	wx.forced = state
	wx.forced_at = wx.world_time() - 100.0


## Brinehollow's shoreline along bearing `a` (island-local): the first point
## from the middle out where the ground dips under the sea, and the way out to sea.
func find_beach(a: float) -> void:
	var d := Vector3(cos(a), 0.0, sin(a))
	for k in range(40, 400):
		var lp := d * float(k)
		if isl.height_at(lp.x, lp.z) < 0.0:
			beach = isl.to_global(lp)
			beach_out = (isl.global_basis * d).normalized()
			return


func _process(dt: float) -> bool:
	t += dt
	if t < 2.0: return false
	if i >= 0 and i < shots.size() and str(shots[i]).begins_with("sea"):
		_follow(shots[i])
	if cam == null:
		if OS.get_cmdline_user_args().has("psx"): root.get_node("Settings").set_value("video", "psx_preset", 4, false)
		else: root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		ship = get_first_node_in_group("ship")
		wx = root.get_node("Weather")
		isl = root.get_node("World/Islands/Brinehollow")
		find_beach(0.9)
		cam = Camera3D.new(); cam.fov = 62; cam.far = 1500
		root.add_child(cam); cam.current = true
		shots = ["beach_calm", "beach_storm", "sea_astern", "sea_deck"]
		return false
	if i < 0 or (t - t0 > 0.35 and frame < 3 and t0 > 0.0):
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s_%d.png" % [out, shots[i], frame])
			frame += 1
			t0 = t
			if frame < 3:
				return false
		i += 1
		frame = 0
		if i >= shots.size():
			print("SAVED")
			quit()
			return false
		_setup(shots[i])
		t0 = t + 4.0  # let the weather, the ship and the effects settle first
	return false


func _setup(s: String) -> void:
	match s:
		"beach_calm", "beach_storm":
			weather(0 if s == "beach_calm" else 3)
			var side := beach_out.cross(Vector3.UP)
			p.global_position = beach - beach_out * 6.0 + Vector3.UP * 3.0
			cam.global_position = beach - beach_out * 4.0 + side * 6.0 + Vector3.UP * 3.2
			cam.look_at(beach + beach_out * 10.0 - side * 4.0, Vector3.UP)
		"sea_astern", "sea_deck":
			weather(3)
			var wg = root.get_node("World/Islands")
			for k in range(32):
				var a := k * TAU / 32.0
				var c: Vector2 = wg.starter_center + Vector2(cos(a), sin(a)) * 380.0
				if wg._deep_enough(c, 140.0):
					if s == "sea_astern":
						ship.place(Vector3(c.x, 0, c.y), 0.4)
						ship.set_anchored(false)
						ship.sail = 1.0
					break
			p.state_machine.force_state("Idle", {})
			p.global_position = ship.global_transform * Vector3(0, HullBuilder.DECK_Y + 0.3, 1.0)
			p.reset_physics_interpolation()
			_follow(s)


## The sea shots ride along with the ship.
func _follow(s: String) -> void:
	var xf: Transform3D = ship.get_global_transform_interpolated()
	if s == "sea_astern":
		cam.global_position = xf * Vector3(-9.0, 9.0, 26.0)
		cam.look_at(xf * Vector3(0, 2.0, -6.0), Vector3.UP)
	else:
		cam.global_position = xf * Vector3(1.2, HullBuilder.DECK_Y + 2.0, -3.0)
		cam.look_at(xf * Vector3(-1.0, 1.0, -20.0), Vector3.UP)
