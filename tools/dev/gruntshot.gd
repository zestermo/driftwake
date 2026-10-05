extends SceneTree
## Smugglers' camp shots. Args: <out_prefix>
var t := 0.0
var p
var camp
var cam: Camera3D
var out := ""
var phase := 0
var t0 := 0.0
var g
var shots := 0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if p == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		var hud = root.get_tree().get_first_node_in_group("hud")
		if hud: hud.visible = false
		p = root.get_tree().get_first_node_in_group("player")
		p.health_component.max_health = 99999.0
		p.health_component.current_health = 99999.0
		camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
		var r2 := Node3D.new(); var a2 := Node3D.new()
		root.add_child(r2); r2.add_child(a2)
		cam = Camera3D.new(); cam.fov = 50; cam.far = 800
		a2.add_child(cam)
		return false
	var e := t - t0
	match phase:
		0:
			if t < 3.0: return false
			cam.current = true
			var fire: Vector3 = (camp.grunts[0].global_position + camp.grunts[1].global_position) * 0.5
			cam.global_position = fire + Vector3(-14, 9, 12)
			cam.look_at(fire, Vector3.UP)
			phase = 1; t0 = t
		1:
			if e < 0.5: return false
			shot("camp")
			var a = camp.grunts[0]
			var fire: Vector3 = (camp.grunts[0].global_position + camp.grunts[1].global_position) * 0.5
			cam.global_position = fire + Vector3(2.5, 1.6, 3.5)
			cam.look_at(fire + Vector3(0, 0.7, 0), Vector3.UP)
			phase = 2; t0 = t
		2:
			if e < 0.5: return false
			shot("fire")
			var guard = camp.grunts[2]
			cam.global_position = guard.global_position + guard._fwd() * 2.6 + Vector3(0.8, 1.5, 0)
			cam.look_at(guard.global_position + Vector3(0, 1.2, 0), Vector3.UP)
			phase = 3; t0 = t
		3:
			if e < 0.5: return false
			shot("sentry")
			var guard = camp.grunts[2]
			p.global_position = guard.global_position + guard._fwd() * 6.0 + Vector3.UP * 0.5
			p.reset_physics_interpolation()
			phase = 4; t0 = t
		4:
			# wait for someone to wind up
			if g == null:
				for x in camp.grunts:
					if is_instance_valid(x) and x.state == 5: g = x; break
				if g == null:
					if e > 15.0: quit()
					return false
				t0 = t; e = 0.0
			var mid: Vector3 = (g.global_position + p.global_position) * 0.5
			var side: Vector3 = Vector3.UP.cross((p.global_position - g.global_position).normalized())
			cam.global_position = mid + side * 4.5 + Vector3(0, 1.6, 0)
			cam.look_at(mid + Vector3(0, 1.0, 0), Vector3.UP)
			var times := [0.1, 0.35, 0.6, 0.75, 0.9, 1.1, 1.4]
			if shots < times.size() and e >= times[shots]:
				shot("fight%d" % shots)
				print("   state ", g.state)
				shots += 1
			if shots >= times.size():
				phase = 5; t0 = t
		5:
			# heavy hit -> knockdown
			var h := HitData.new(); h.damage = 20.0; h.knockdown = true; h.knockback_force = 10.0
			g.hurtbox.take_hit(h, p)
			phase = 6; t0 = t
		6:
			var hp: Vector3 = g.humanoid.hips.global_position
			cam.global_position = hp + Vector3(3.5, 1.5, 3.0)
			cam.look_at(hp, Vector3.UP)
			if e > 0.5 and not has_meta("k1"): set_meta("k1", 1); shot("knock")
			if e > 2.4 and not has_meta("k2"): set_meta("k2", 1); shot("getup")
			if e > 3.0: quit()
	return false
