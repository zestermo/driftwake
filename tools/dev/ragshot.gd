extends SceneTree
## Frames of the player's knockdown ragdoll + get-up (or a death with "dead").
## Args: <out_prefix> [dead|front]
var t := 0.0
var cam: Camera3D
var isl: Node3D
var p
var out := ""
var mode := ""
var t_hit := -1.0
var times := [0.05, 0.15, 0.35, 0.6, 1.0, 1.6, 2.0, 2.3, 2.6, 2.9, 3.3]
var idx := 0
func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	mode = a[1] if a.size() > 1 else ""
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		isl = root.get_node("World/Islands/Brinehollow")
		var hud = root.get_tree().get_first_node_in_group("hud")
		if hud: hud.visible = false
		p = root.get_tree().get_first_node_in_group("player")
		var spot := Vector2(6, -56)
		p.global_position = isl.to_global(Vector3(spot.x, isl.height_at(spot.x, spot.y) + 0.2, spot.y))
		p.reset_physics_interpolation()
		p.player_model.rotation.y = 0.0
		cam = Camera3D.new(); cam.fov = 50; cam.far = 500
		root.add_child(cam); cam.current = true
		return false
	if t_hit < 0.0:
		if t < 2.5: return false
		var pp: Vector3 = p.global_position
		cam.global_position = pp + Vector3(4.8, 1.5, 1.6)
		cam.look_at(pp + Vector3(0, 0.5, 1.6), Vector3.UP)
		if mode == "dead":
			p._last_hit_velocity = Vector3(0, 3, 7)
			p.health_component.take_damage(9999)
		else:
			var v := Vector3(0, 3.0, -4.5) if mode == "front" else Vector3(0, 3.0, 4.5)
			p.knock_down(v)
		t_hit = t
	var e := t - t_hit
	var hp: Vector3 = p.body_model.hips.global_position
	var foc := Vector3(hp.x, p.global_position.y + 0.5, hp.z)
	cam.global_position = foc + (Vector3(-2.4, 1.6, 3.6) if mode == "diag" else Vector3(4.2, 1.1, 0.0))
	cam.look_at(foc, Vector3.UP)
	if idx < times.size() and e >= times[idx]:
		root.get_texture().get_image().save_png("%s_%02d.png" % [out, idx])
		print("frame ", idx, " t=", snappedf(e, 0.01), " state=", p.current_state_name(), " act=", p.body_model.current_action())
		idx += 1
	if idx >= times.size():
		quit()
	return false
