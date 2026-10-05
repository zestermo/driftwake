extends SceneTree
## Firearm / heavy glow shots. Args: <out_prefix>
var t := 0.0
var p
var camp
var cam: Camera3D
var out := ""
var phase := 0
var t0 := 0.0
var rifle
var sword
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func shot(n: String) -> void:
	root.get_texture().get_image().save_png("%s_%s.png" % [out, n])
	print("shot ", n)
func side_cam(a: Node3D, b: Vector3, dist: float = 5.0, h: float = 1.6, bias: float = 0.35) -> void:
	var ab: Vector3 = b - a.global_position; ab.y = 0
	var s := Vector3.UP.cross(ab.normalized())
	var foc: Vector3 = a.global_position.lerp(b, bias) + Vector3(0, 1.1, 0)
	cam.global_position = foc + s * dist + Vector3(0, h, 0)
	cam.look_at(foc, Vector3.UP)
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
		rifle = camp.grunts[2]
		sword = camp.grunts[3]
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
			for x in camp.grunts:
				if x != rifle: x.process_mode = Node.PROCESS_MODE_DISABLED
			cam.global_position = rifle.global_position + rifle._fwd() * 2.4 + Vector3(0.9, 1.4, 0)
			cam.look_at(rifle.global_position + Vector3(0, 1.1, 0), Vector3.UP)
			phase = 1; t0 = t
		1:
			if e < 0.4: return false
			shot("carry")
			p.global_position = rifle.global_position + rifle._fwd() * 11.0 + Vector3.UP * 0.5
			p.reset_physics_interpolation()
			phase = 2; t0 = t
		2:
			if has_meta("tf"):
				side_cam(rifle, p.global_position, 9.0, 2.5, 0.45)
				if t - float(get_meta("tf")) > 0.35 and not has_meta("a4"): set_meta("a4", 1); shot("smoke")
				if t - float(get_meta("tf")) > 0.9: shot("smoke2"); phase = 3; t0 = t
				return false
			if rifle.state != 15:
				if e > 10.0: quit()
				return false
			side_cam(rifle, p.global_position, 9.0, 2.5, 0.45)
			if rifle.st_t > 0.6 and not has_meta("a1"): set_meta("a1", 1); shot("aim_track")
			if rifle.st_t > 1.15 and not has_meta("a2"): set_meta("a2", 1); shot("aim_locked")
			if rifle._fired and not has_meta("a3"): set_meta("a3", 1); shot("fired"); set_meta("tf", t)
			if has_meta("tf") and t - float(get_meta("tf")) > 0.35 and not has_meta("a4"): set_meta("a4", 1); shot("smoke")
			if has_meta("tf") and t - float(get_meta("tf")) > 0.9: shot("smoke2"); phase = 3; t0 = t
		3:
			if e < 0.8: return false
			# shove
			rifle._shove_cd = 0.0; rifle._shot_cd = 99.0
			p.global_position = rifle.global_position + rifle._fwd() * 1.8
			p.reset_physics_interpolation()
			phase = 4; t0 = t
		4:
			side_cam(rifle, p.global_position, 3.6, 0.8, 0.5)
			if rifle.state == 18 and rifle.st_t > 0.4 and not has_meta("s1"): set_meta("s1", 1); shot("shove")
			if e > 2.5:
				rifle.process_mode = Node.PROCESS_MODE_DISABLED
				sword.process_mode = Node.PROCESS_MODE_INHERIT
				sword.alert()
				phase = 5; t0 = t
		5:
			if e < 0.9: return false
			p.global_position = sword.global_position + Vector3(11, 0.5, 2)
			p.reset_physics_interpolation()
			sword._start_aim("pistol")
			phase = 6; t0 = t
		6:
			side_cam(sword, p.global_position, 5.0, 1.2, 0.25)
			if e > 0.5 and not has_meta("p1"): set_meta("p1", 1); shot("pistol")
			if e > 1.6:
				p.global_position = sword.global_position + sword._fwd() * 3.2
				p.reset_physics_interpolation()
				sword._attack = "lunge"
				sword._start_wind()
				phase = 7; t0 = t
		7:
			var sd: Vector3 = Vector3.UP.cross(sword._fwd())
			cam.global_position = sword.global_position + sword._fwd() * 1.2 + sd * 2.6 + Vector3(0, 1.6, 0)
			cam.look_at(sword.global_position + Vector3(0, 1.3, 0), Vector3.UP)
			if e > 0.5:
				shot("heavy_glow")
				quit()
	return false
