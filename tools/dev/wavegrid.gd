extends SceneTree
## Debug: balls placed on the computed wave surface should sit on the
## rendered sea. Args: <out_prefix>
var t := 0.0
var balls: Array = []
var cam: Camera3D
var out := ""
var n := 0
var origin := Vector3(170, 0, -60)
func _initialize():
	out = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	var oc = root.get_node("Ocean")
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for c in root.find_children("*", "CharacterCreator", true, false): c._finish(true)
		get_first_node_in_group("hud").visible = false
		get_first_node_in_group("player").global_position = origin + Vector3(0, 30, 30)
		var sm := SphereMesh.new(); sm.radius = 0.12; sm.height = 0.24
		var mat := StandardMaterial3D.new(); mat.albedo_color = Color(1, 0.2, 0.2); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.material = mat
		for i in range(-12, 13):
			var mi := MeshInstance3D.new(); mi.mesh = sm
			current_scene.add_child(mi); balls.append([mi, origin + Vector3(i * 0.5, 0, 0)])
		cam = Camera3D.new(); cam.fov = 45; root.add_child(cam); cam.current = true
		cam.global_position = origin + Vector3(0, 1.6, 9)
		cam.look_at(origin, Vector3.UP)
		return false
	for b in balls:
		var p: Vector3 = b[1]
		(b[0] as Node3D).global_position = Vector3(p.x, oc.get_wave_height(p), p.z)
	if t > 3.0 + n * 0.6:
		root.get_texture().get_image().save_png("%s_%d.png" % [out, n])
		n += 1
		if n >= 2: quit()
	return false
