extends SceneTree
## The held map. On Brinehollow (after a look round the harbour, the ruins' path and the lighthouse
## hill, from the quay): half unrolled (_unroll), the game camera on the island page (_isle), zoomed in
## round the captain (_zoom), out on the chart (_chart), the captain holding it from the front (_front).
## Then out at sea on the sloop's deck (_sea: it opens on the chart), and on the chain's first island at
## its pier after a walk up from the dock (_chain, _chain_zoom). Args: <out_prefix> [psx]
var t := 0.0
var out := ""
var step := 0
var t0 := 0.0
var p
var hold
var cam: Camera3D


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")


func _shot(nm: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, nm])
	print("shot ", nm)


func _wait(s: float) -> bool:
	if t - t0 < s:
		return true
	t0 = t
	return false


func _look_round(d: Dictionary, pts: Array, high: Vector2 = Vector2.INF) -> void:
	var mf = load("res://scripts/map/map_fog.gd")
	var o: Vector2 = d["o"]
	for q in pts:
		mf.look(root.get_node("GameManager"), d, Vector3(o.x + q.x, 30.0 if q == high else 4.0, o.y + q.y))


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
			p = get_first_node_in_group("player")
			hold = p.get_node("MapHold")
			var w = get_first_node_in_group("world_gen")
			var dd: Dictionary = load("res://scripts/map/map_isles.gd").of(w.starter_island)
			_look_round(dd, [Vector2(0, -62), Vector2(0, -110), Vector2(-30, -20), Vector2(-62, 58), Vector2(-40, 20), Vector2(40, -45), Vector2(78, -30)], Vector2(78, -30))
			var at: Vector2 = dd["o"] + Vector2(6, -100)
			p.state_machine.force_state("Idle", {})
			p.global_position = Vector3(at.x, 6.0, at.y)
			p.reset_physics_interpolation()
			p.player_model.rotation.y = 0.0
			get_first_node_in_group("hud").visible = false
			t0 = t
		1:
			if _wait(1.5):
				return false
			hold.toggle()
		2:
			if _wait(0.17):
				return false
			_shot("unroll")
		3:
			if _wait(1.2):
				return false
			_shot("isle")
			hold.page.press(MOUSE_BUTTON_WHEEL_UP, Vector2.ZERO)
			hold.page.press(MOUSE_BUTTON_WHEEL_UP, Vector2.ZERO)
		4:
			if _wait(1.0):
				return false
			_shot("zoom")
			for i in range(3):
				hold.page.press(MOUSE_BUTTON_WHEEL_DOWN, Vector2.ZERO)
		5:
			if _wait(0.6):
				return false
			_shot("chart")
			hold.page.press(MOUSE_BUTTON_WHEEL_UP, Vector2.ZERO)
			cam = Camera3D.new()
			cam.fov = 50.0
			root.add_child(cam)
			var f: Vector3 = -p.player_model.global_basis.z
			var r: Vector3 = p.player_model.global_basis.x
			cam.global_position = p.global_position + f * 2.2 + r * 0.9 + Vector3.UP * 1.7
			cam.look_at(p.global_position + Vector3.UP * 1.1, Vector3.UP)
			cam.current = true
		6:
			if _wait(0.4):
				return false
			_shot("front")
			cam.queue_free()
			(get_first_node_in_group("player_camera") as Camera3D).current = true
			hold.toggle()
		7:
			if _wait(0.6):
				return false
			# out at sea at the sloop's helm; M lets go of the wheel and opens the chart on the deck
			var ship = get_first_node_in_group("ship")
			var sc: Vector2 = get_first_node_in_group("world_gen").starter_center
			ship.set_anchored(false)
			ship.place(Vector3(sc.x + 700.0, 0.0, sc.y - 500.0), 0.6)
			p.current_ship = ship
			p.state_machine.force_state("Helm", {})
		8:
			if _wait(2.5):
				return false
			hold.toggle()
			print("from the helm: ", p.current_state_name())
		9:
			if _wait(1.2):
				return false
			_shot("sea")
			hold.toggle()
		10:
			if _wait(1.0):
				return false
			p._debug_to_next_island()
		11:
			if _wait(3.0):
				return false
			var dd: Dictionary = load("res://scripts/map/map_isles.gd").at(self, Vector2(p.global_position.x, p.global_position.z))
			if not str(dd.get("key", "")).begins_with("isle"):
				p._debug_to_next_island()
				if t > 150.0:
					quit()
				return false
			var isl = dd["isl"]
			var pts: Array = []
			var a: Vector2 = isl.sites["dock_end"]
			var b: Vector2 = isl.sites["village"]
			for i in range(8):
				pts.append(a.lerp(b, i / 7.0))
			_look_round(dd, pts)
			print("chain island ", dd["name"], " spots ", dd["spots"].size())
		12:
			if _wait(1.5):
				return false
			hold.toggle()
		13:
			if _wait(1.2):
				return false
			_shot("chain")
			hold.page.press(MOUSE_BUTTON_WHEEL_UP, Vector2.ZERO)
		14:
			if _wait(1.0):
				return false
			_shot("chain_zoom")
			quit()
	step += 1
	return false
