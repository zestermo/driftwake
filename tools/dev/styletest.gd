extends SceneTree
## Shonen body: permanent style, neck joint, head look layer.
var t := 0.0
var step := 0
var p
var fails := 0
var hmin := Vector3(9, 9, 9)
var hmax := Vector3(-9, -9, -9)
var tor_dev := 0.0
var head_dev := 0.0
func check(n: String, c: bool) -> void:
	print(("PASS " if c else "FAIL ") + n); if not c: fails += 1
func _initialize(): change_scene_to_file("res://scenes/world/world.tscn")
func _yaw_dev(n: Node3D, ref: Node3D) -> float:
	var f: Vector3 = -n.global_basis.z; var r: Vector3 = -ref.global_basis.z
	return absf(wrapf(atan2(f.x, f.z) - atan2(r.x, r.z), -PI, PI))
func _process(d: float) -> bool:
	t += d
	var b = p.body_model if p else null
	match step:
		0:
			if t < 1.0: return false
			p = root.get_tree().get_first_node_in_group("player")
			b = p.body_model
			check("shonen hip height %.2f" % b.hip_y, b.hip_y > 0.95)
			check("player has physics chains (%d sims)" % b._sims.size(), b._sims.size() >= 1)
			check("neck joint drives the head", b.neck != null and b.head.get_parent() == b.neck)
			check("art style option removed", not root.get_node("Settings").has_method("x") and root.get_node("Settings").get_value("gameplay", "art_style") == null)
			var lk: Dictionary = b.look.duplicate(); lk["style"] = "chibi"
			b.apply_look(lk)
			check("explicit style still builds (chibi hips %.2f)" % b.hip_y, b.hip_y < 0.5)
			lk.erase("style"); b.apply_look(lk)
			check("back to shonen", b.hip_y > 0.95 and b.weapon != null and b.weapon.get_parent() != null)
			step = 1; t = 0
		1:
			# idle life on an NPC (the player's head follows the camera aim instead)
			var nb = null
			for n in root.find_children("*", "Humanoid", true, false):
				if n != b and n.ground_speed < 0.1 and not n.talking: nb = n; break
			if nb == null: nb = b
			hmin = Vector3(minf(hmin.x, nb.head.rotation.x), minf(hmin.y, nb.neck.rotation.y), minf(hmin.z, nb.head.rotation.z))
			hmax = Vector3(maxf(hmax.x, nb.head.rotation.x), maxf(hmax.y, nb.neck.rotation.y), maxf(hmax.z, nb.head.rotation.z))
			if t < 6.0: return false
			var rng := hmax - hmin
			check("idle head moves on the neck (range %s)" % str(rng), rng.x > 0.02 and (rng.y > 0.02 or rng.z > 0.02))
			var e := InputEventAction.new(); e.action = "move_forward"; e.pressed = true; Input.parse_input_event(e)
			step = 2; t = 0
		2:
			if t > 0.6:
				tor_dev = maxf(tor_dev, _yaw_dev(b.torso, b))
				head_dev = maxf(head_dev, _yaw_dev(b.head, b))
			if t < 2.0: return false
			check("moves", p.velocity.length() > 3.0)
			check("running head steadier than torso (head %.3f < torso %.3f)" % [head_dev, tor_dev], head_dev < tor_dev * 0.75)
			print("RESULT fails=", fails); quit()
	return false
