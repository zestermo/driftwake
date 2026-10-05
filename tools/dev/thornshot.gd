extends SceneTree
## Thornbrush around the jungle stash: before / burning / after. Args: <out_prefix>
var t := 0.0
var out := ""
var cam: Camera3D
var isl
var p
var phase := 0
var t0 := 0.0
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if cam == null:
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		var hud = root.get_tree().get_first_node_in_group("hud")
		if hud: hud.visible = false
		p = root.get_tree().get_first_node_in_group("player")
		isl = root.get_node("World/Islands/Brinehollow")
		var stash: Vector3 = isl.to_global(Vector3(-92, isl.height_at(-92, 14), 14))
		p.global_position = stash + Vector3(7, 1.0, 7)
		p.reset_physics_interpolation()
		p.power.eat("ember")
		cam = Camera3D.new(); cam.fov = 55
		var a := Node3D.new(); var b := Node3D.new(); root.add_child(a); a.add_child(b); b.add_child(cam)
		cam.global_position = stash + Vector3(-6.0, 3.5, 5.0)
		cam.look_at(stash + Vector3(0, 0.8, 0), Vector3.UP)
		cam.current = true
		set_meta("stash", stash)
		return false
	var e := t - t0
	match phase:
		0:
			if t < 4.0: return false
			root.get_texture().get_image().save_png(out + "_1_before.png")
			for k in range(4):
				var th = isl.get_node("Thornbrush%d" % k)
				print("thorn ", k, " ", th.global_position)
			p.power.ignite_burnables(isl.get_node("Thornbrush1").global_position + Vector3(0, 1, 0), 1.0)
			p.power.ignite_burnables(isl.get_node("Thornbrush0").global_position + Vector3(0, 1, 0), 1.0)
			phase = 1; t0 = t
		1:
			if e < 1.2: return false
			root.get_texture().get_image().save_png(out + "_2_burning.png")
			phase = 2; t0 = t
		2:
			if e < 4.5: return false
			root.get_texture().get_image().save_png(out + "_3_after.png")
			quit()
	return false
