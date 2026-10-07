extends SceneTree
## README screenshots: Brinehollow's street, the tavern inside, and a katana
## fight at the smugglers' camp (a burst of frames to pick from), HUD off,
## late afternoon, clear. Args: <out_prefix>
var t := 0.0
var out := ""
var p
var w
var isl
var camp
var rig
var cam: Camera3D
var step := 0
var t0 := 0.0
var g
var n := 0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func shot(name: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, name])
	print("shot ", name)
func aim(from: Vector3, at: Vector3) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
func _process(d: float) -> bool:
	t += d
	if t < 2.0: return false
	if p == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for k in root.find_children("*", "CharacterCreator", true, false): k._finish(true)
		get_first_node_in_group("hud").visible = false
		p = get_first_node_in_group("player")
		p.health_component.max_health = 99999.0
		p.health_component.current_health = 99999.0
		w = root.get_node("Weather")
		w.forced = 0
		w.forced_at = w.world_time() - 100.0
		w.world_offset += fposmod(16.3 - float(w.hour()), 24.0) / 24.0 * float(w.DAY_LEN)
		isl = root.get_node("World/Islands/Brinehollow")
		camp = isl.get_node("SmugglersCamp")
		# (attacks aim along the current camera's grandparent: a stand-in rig)
		rig = Node3D.new()
		var arm := Node3D.new()
		root.add_child(rig); rig.add_child(arm)
		cam = Camera3D.new(); cam.fov = 60; cam.far = 3000
		arm.add_child(cam)
		cam.current = true
		t0 = t
		return false
	var e := t - t0
	if step < 2 and OS.get_cmdline_user_args().has("fight"):
		step = 2
	match step:
		0:
			# the main road, looking up into the village
			aim(Vector3(149.0, 5.0, 33.0), Vector3(150.0, 4.0, 80.0))
			if e < 1.5: return false
			shot("village")
			step = 1; t0 = t
		1:
			var tv: Node3D = isl._tavern
			var bk: Vector3 = (tv.get_node("Barkeep") as Node3D).global_position
			var mid := tv.global_position + Vector3.UP * 1.0
			aim(mid + (mid - bk).normalized() * 3.5 + Vector3.UP * 1.4, bk + Vector3.UP * 0.6)
			if e < 1.5: return false
			shot("tavern")
			step = 2; t0 = t
		2:
			g = camp.grunts[1]
			var katana = load("res://resources/items/katana.tres")
			p.inventory_component.add_item(katana, 1)
			p.equip_weapon(katana, false)
			p.set_offhand(null)
			p.global_position = g.global_position + Vector3(3.2, 0.4, 0)
			p.velocity = Vector3.ZERO
			p.reset_physics_interpolation()
			p.state_machine.force_state("Idle", {})
			p.draw_weapon()
			step = 3; t0 = t
		3:
			var to: Vector3 = g.global_position - p.global_position
			rig.global_rotation.y = atan2(-to.x, -to.z)
			var mid: Vector3 = (g.global_position + p.global_position) * 0.5
			var side: Vector3 = Vector3.UP.cross(to.normalized())
			aim(mid + side * 4.2 + Vector3(0, 1.3, 0), mid + Vector3(0, 1.0, 0))
			if e < 1.0: return false
			var k := int((e - 1.0) / 0.12)
			if k > n:
				n = k
				Input.action_press("light_attack") if n % 4 == 0 else Input.action_release("light_attack")
				shot("fight_%02d" % n)
			if n >= 40:
				quit()
	return false
