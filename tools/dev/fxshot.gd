extends SceneTree
var t := 0.0
var step := 0
var wait := 0.0
var p
var n := 0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func tap(a: String) -> void:
	var e := InputEventAction.new(); e.action = a; e.pressed = true; Input.parse_input_event(e)
	var r := InputEventAction.new(); r.action = a; r.pressed = false; Input.parse_input_event(r)
func snap() -> void:
	root.get_texture().get_image().save_png("res://tools/dev/out/fx_%d.png" % n); n += 1
func _process(d: float) -> bool:
	t += d
	if wait > 0.0:
		wait -= d
		return false
	match step:
		0:
			if t < 1.5: return false
			p = root.get_tree().get_first_node_in_group("player")
			var isl = root.get_node("World/Islands/Brinehollow")
			var v = isl.VILLAGE + Vector2(0, 6)
			p.global_position = Vector3(150 + v.x, isl.hv(v) + 0.3, 150 + v.y)
			p.reset_physics_interpolation()
			tap("ready_weapon"); wait = 1.0
		1:
			tap("light_attack"); wait = 0.12
		2:
			snap(); wait = 0.25
		3:
			tap("light_attack"); wait = 0.12
		4:
			snap(); wait = 0.25
		5:
			tap("light_attack"); wait = 0.3
		6:
			snap(); wait = 1.0
		7:
			tap("dodge"); wait = 0.12
		8:
			snap(); wait = 1.0
		9:
			tap("heavy_attack"); wait = 0.62
		10:
			snap(); quit()
	step += 1
	return false
