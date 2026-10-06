extends SceneTree
## Gore frames: a grunt cut down by a severing killing blow (head or arm off,
## blood, splats) and a second grunt losing an arm. Args: <out_prefix>
var t := 0.0
var cam: Camera3D
var out := ""
var p
var g
var g2
var shots := [0.15, 0.5, 1.2, 2.5]
var si := 0
var t_hit := -1.0
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
		p = get_first_node_in_group("player")
		var camp = root.get_node("World/Islands/Brinehollow/SmugglersCamp")
		g = camp.grunts[0]
		g2 = camp.grunts[1]
		for x in camp.grunts:
			x._cooldown = 99.0
		g2.global_position = g.global_position + Vector3(1.6, 0.2, 0)
		g2.reset_physics_interpolation()
		p.global_position = g.global_position + Vector3(0, 0.3, 6.0)
		p.reset_physics_interpolation()
		cam = Camera3D.new(); cam.fov = 55; root.add_child(cam); cam.current = true
		cam.global_position = g.global_position + Vector3(-2.2, 2.0, 4.2)
		cam.look_at(g.global_position + Vector3(0.8, 0.7, 0), Vector3.UP)
		return false
	if t_hit < 0.0 and t > 2.6:
		t_hit = t
		var kill := HitData.new()
		kill.damage = 9999.0
		kill.knockdown = true
		kill.crumple = true
		kill.sever = true
		g.hurtbox.take_hit(kill, p)
		var plain := HitData.new()
		plain.damage = 9999.0
		g2.hurtbox.take_hit(plain, p)
		g2.humanoid.sever("arm_r", Vector3(2.5, 3.0, 1.0))
	if t_hit > 0.0 and si < shots.size() and t - t_hit >= float(shots[si]):
		root.get_texture().get_image().save_png("%s_%d.png" % [out, si])
		si += 1
		if si >= shots.size():
			quit()
	return false
