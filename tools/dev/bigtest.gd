extends SceneTree
var t := 0.0
var p
var big
var down_seen := false
var parried := false
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _process(d: float) -> bool:
	t += d
	if t < 1.5: return false
	if p == null:
		p = root.get_tree().get_first_node_in_group("player")
		var nest = root.get_node("World/Islands/Brinehollow/ScuttlebugNest")
		for s in nest.spots:
			if s["big"]: big = s["bug"]
		p.global_position = big.global_position + Vector3(7, 0.6, 0)
		p.reset_physics_interpolation()
		return false
	if p.current_state_name() == "Downed": down_seen = true
	if t > 7.0:
		print(("PASS" if down_seen else "FAIL") + " big ram knocks the player down")
		# parry test: put the bug in a ram and have the player parry
		big.parried(p)
		print(("PASS" if big.state == 8 else "FAIL") + " parried ram flips the bug")
		print("RESULT")
		return true
	return false
