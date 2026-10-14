extends SceneTree
## Idle, a villager's head drifts on the neck; running, the captain's head stays steadier than the torso.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var hmin := Vector3(9, 9, 9)
var hmax := Vector3(-9, -9, -9)
var tor_dev := 0.0
var head_dev := 0.0
var step := 0
var until := 0
var t0 := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "npc": {}})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _yaw_dev(n: Node3D, ref: Node3D) -> float:
	var f: Vector3 = -n.global_basis.z
	var r: Vector3 = -ref.global_basis.z
	return absf(wrapf(atan2(f.x, f.z) - atan2(r.x, r.z), -PI, PI))


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	match step:
		0:
			p = stage.player
			until = TK.wait_secs(6.0)
			step = 1
		1:
			var nb = stage.npc.humanoid
			hmin = Vector3(minf(hmin.x, nb.head.rotation.x), minf(hmin.y, nb.neck.rotation.y), minf(hmin.z, nb.head.rotation.z))
			hmax = Vector3(maxf(hmax.x, nb.head.rotation.x), maxf(hmax.y, nb.neck.rotation.y), maxf(hmax.z, nb.head.rotation.z))
			if TK.ticking(until):
				return false
			var rng := hmax - hmin
			check("idle head moves on the neck (range %s)" % str(rng), rng.x > 0.02 and (rng.y > 0.02 or rng.z > 0.02))
			TK.press("move_forward")
			t0 = Engine.get_physics_frames()
			until = TK.wait_secs(2.0)
			step = 2
		2:
			var b = p.body_model
			if Engine.get_physics_frames() - t0 > 36:
				tor_dev = maxf(tor_dev, _yaw_dev(b.torso, b))
				head_dev = maxf(head_dev, _yaw_dev(b.head, b))
			if TK.ticking(until):
				return false
			TK.release("move_forward")
			check("moves", p.velocity.length() > 3.0)
			check("running head steadier than torso (head %.3f < torso %.3f)" % [head_dev, tor_dev], head_dev < tor_dev * 0.75)
			return TK.done(fails)
	return false
