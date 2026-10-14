extends SceneTree
## Rain (RainFX): Brinehollow's village street and the ship's deck in the rain
## at 13:00 and at 21:00 (lamplit), and the sea's surface pocked by it; the
## ground soaked so its puddles show. Two frames a shot. Args: <out_prefix>
var t := 0.0
var out := ""
var cam: Camera3D
var p
var ship
var wx
var isl
const SHOTS := [["street_day", 13.0, "street"], ["street_night", 21.0, "street"], ["deck_day", 13.0, "deck"], ["deck_night", 21.0, "deck"], ["sea_day", 13.0, "sea"]]
var i := -1
var frame := 0
var t0 := 0.0


func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func set_hour(h: float) -> void:
	wx.skip_to(h)


func _process(dt: float) -> bool:
	t += dt
	if t < 2.0: return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		ship = get_first_node_in_group("ship")
		wx = root.get_node("Weather")
		wx.forced = 2
		wx.forced_at = wx.world_time() - 100.0
		isl = root.get_node("World/Islands/Brinehollow")
		cam = Camera3D.new(); cam.fov = 62; cam.far = 1500
		root.add_child(cam); cam.current = true
		return false
	if i < 0 or (t - t0 > 0.4 and t0 > 0.0):
		if i >= 0:
			root.get_texture().get_image().save_png("%s_%s_%d.png" % [out, SHOTS[i][0], frame])
			var fx = root.find_child("RainFX", true, false)
			print("%s: rain %.2f wet %.2f puddles %d (cells %d, with one %d) pocks %d" % [SHOTS[i][0], wx.rain, fx.wet, fx._puddle_mm.visible_instance_count,
				fx._cells.size(), fx._cells.values().filter(func(e): return not e.is_empty()).size(), fx._pocks.size()])
			frame += 1
			t0 = t
			if frame < 2:
				return false
		i += 1
		frame = 0
		if i >= SHOTS.size():
			print("SAVED")
			quit()
			return false
		_setup(SHOTS[i])
		t0 = t + 5.0
	return false


func _setup(s: Array) -> void:
	set_hour(float(s[1]))
	var fx = root.find_child("RainFX", true, false)
	fx.wet = 1.0
	ship.wet = 1.0
	match str(s[2]):
		"street":
			var at: Vector3 = isl.to_global(Vector3(isl.VILLAGE.x, 0.0, isl.VILLAGE.y))
			at.y = isl.height_at(isl.VILLAGE.x, isl.VILLAGE.y)
			p.global_position = at + Vector3(0, 0.5, 6.0)
			cam.global_position = at + Vector3(-6.0, 3.0, 10.0)
			cam.look_at(at + Vector3(2.0, 0.5, -4.0), Vector3.UP)
		"deck":
			var xf: Transform3D = ship.global_transform
			p.state_machine.force_state("Idle", {})
			p.global_position = xf * Vector3(0, HullBuilder.DECK_Y + 0.3, 3.0)
			cam.global_position = xf * Vector3(1.5, HullBuilder.DECK_Y + 2.4, 4.0)
			cam.look_at(xf * Vector3(-0.5, HullBuilder.DECK_Y, -4.0), Vector3.UP)
		"sea":
			var xf: Transform3D = ship.global_transform
			cam.global_position = xf * Vector3(7.0, 2.0, 0.0)
			cam.look_at(xf * Vector3(14.0, -1.5, -6.0), Vector3.UP)
