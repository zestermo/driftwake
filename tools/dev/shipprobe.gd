extends SceneTree
var t := 0.0
var p
var ship
var step := 0
var log_t := 0.0
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if p == null:
		p = root.get_tree().get_first_node_in_group("player")
		ship = root.get_tree().get_first_node_in_group("ship")
		p.global_position = ship.global_position + ship.global_basis * Vector3(0, 2.0, 1.0)
		p.reset_physics_interpolation()
		print("ship ", ship.global_position, " class ", ship.get_class())
	log_t += d
	if log_t > 0.5:
		log_t = 0.0
		var local: Vector3 = ship.to_local(p.global_position)
		print("t=%.1f ship y=%.2f spd=%s  player local=%s floor=%s state=%s" % [t, ship.global_position.y, ship.speed, local, p.is_on_floor(), p.current_state_name()])
	if t > 6.0: return true
	return false
