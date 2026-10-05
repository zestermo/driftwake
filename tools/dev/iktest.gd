extends SceneTree
var f := 0
var h
func _process(d: float) -> bool:
	f += 1
	if f == 1:
		var root3 := Node3D.new(); get_root().add_child(root3)
		h = Humanoid.new(); h.setup(CharacterLook.default_look()); root3.add_child(h)
		return false
	if f < 4: return false
	var worst := 0.0
	for tgt in [Vector3(0.2, 1.2, -0.45), Vector3(-0.3, 1.0, -0.3), Vector3(0.1, 1.5, -0.5), Vector3(-0.5, 1.2, 0.0)]:
		for pole in [Vector3(-1, -1, 0.3).normalized(), Vector3(-0.5, -1, 0.5).normalized()]:
			h.reach_left_hand(tgt, pole)
			var hp: Vector3 = h.hand_l.global_position
			var tip: Vector3 = h.hand_l.global_transform * Vector3(0, -0.05, 0)
			var err := tip.distance_to(tgt)
			# elbow side
			var elbow: Vector3 = h.fore_l.global_position
			var mid: Vector3 = (h.arm_l.global_position + tgt) * 0.5
			print("tgt ", tgt, " err ", snappedf(err, 0.001), " elbow-toward-pole ", snappedf((elbow - mid).normalized().dot(pole), 0.01))
			worst = maxf(worst, err)
	print("WORST ", worst)
	return true
