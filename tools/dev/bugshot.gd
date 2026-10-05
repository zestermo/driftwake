extends SceneTree
## Scuttlebug shots. Args: <out_prefix> <mode: pose|fight|down|die>
var t := 0.0
var cam: Camera3D
var p
var bug
var big
var out := ""
var mode := ""
var t0 := -1.0
var times: Array = []
var idx := 0
func _initialize():
	var a := OS.get_cmdline_user_args()
	out = a[0]
	mode = a[1]
	change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if cam == null:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		for n in root.find_children("*", "CharacterCreator", true, false): n._finish(true)
		var hud = root.get_tree().get_first_node_in_group("hud")
		if hud: hud.visible = false
		p = root.get_tree().get_first_node_in_group("player")
		var nest = root.get_node("World/Islands/Brinehollow/ScuttlebugNest")
		for s in nest.spots:
			if s["big"]: big = s["bug"]
			elif bug == null: bug = s["bug"]
		cam = Camera3D.new(); cam.fov = 45; cam.far = 500
		root.add_child(cam); cam.current = true
		# park the player away so the bugs stay calm (for pose/down/die)
		if mode != "fight":
			p.global_position = bug.global_position + Vector3(40, 3, 0)
		else:
			p.global_position = bug.global_position + Vector3(7, 0.6, 0)
		p.reset_physics_interpolation()
		return false
	if t < 2.2: return false
	var b = big if mode == "posebig" else bug
	if t0 < 0.0:
		t0 = t
		match mode:
			"pose", "posebig":
				times = [0.3, 0.6]
			"fight":
				times = [0.3, 0.7, 1.0, 1.3, 1.6, 1.9, 2.1, 2.3, 2.6, 3.0, 3.5, 4.0]
			"down":
				var hit := HitData.new(); hit.damage = 1.0; hit.knockback_force = 9.0; hit.knockdown = true
				b.hurtbox.take_hit(hit, p)
				times = [0.1, 0.3, 0.6, 1.0, 1.5, 2.0, 2.6, 3.2, 4.0, 5.0, 6.0, 7.5]
			"die":
				var hit := HitData.new(); hit.damage = 99.0; hit.knockback_force = 9.0
				b.hurtbox.take_hit(hit, p)
				times = [0.1, 0.4, 0.8, 1.4, 2.2, 3.0, 3.4, 3.7]
	var e := t - t0
	var foc: Vector3 = b.global_position + Vector3(0, 0.3 * b.size_k, 0)
	if b._rag: foc = b._rag.root_body().global_position
	if mode.begins_with("pose"):
		b.set_physics_process(false)
		var fwd: Vector3 = -b.model.global_basis.z
		var side: Vector3 = b.model.global_basis.x
		var dist: float = 1.9 * b.size_k
		cam.global_position = foc + (fwd * 0.8 + side * 0.6).normalized() * dist + Vector3(0, 0.55 * b.size_k, 0)
		if idx == 1: cam.global_position = foc + (-fwd * 0.5 + side * 0.9).normalized() * dist + Vector3(0, 0.9 * b.size_k, 0)
	elif mode == "fight":
		var mid: Vector3 = (b.global_position + p.global_position) * 0.5
		foc = mid + Vector3(0, 0.4, 0)
		cam.global_position = foc + Vector3(0, 2.2, 6.5)
	else:
		cam.global_position = foc + Vector3(2.2, 1.0, 1.6)
	cam.look_at(foc, Vector3.UP)
	if idx < times.size() and e >= times[idx]:
		root.get_texture().get_image().save_png("%s_%02d.png" % [out, idx])
		print("frame ", idx, " t=", snappedf(e, 0.01), " state=", b.state, " up=", snappedf(b.body_node.global_basis.orthonormalized().y.y, 0.01))
		idx += 1
	if idx >= times.size():
		quit()
	return false
