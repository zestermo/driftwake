extends SceneTree
## Sprinting round a curve (the camera sweeping left), the body leans into the turn.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var turn_t := 0.0
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _physics_process(d: float) -> bool:
	# (the sweep is per physics tick: frame times vary with load)
	if step == 2:
		stage.camera_rig.rotation.y += 2.2 * d
		turn_t += d
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			TK.press("move_forward")
			TK.press("sprint")
			until = TK.wait_secs(0.4)
		1:
			pass
		2:
			if turn_t < 0.7:
				return false
			var roll: float = Basis(p.lean.basis.orthonormalized()).get_euler().z
			check("leans INTO the turn, i.e. left (roll %.2f rad)" % roll, roll > 0.05)
			TK.release("move_forward")
			TK.release("sprint")
			return TK.done(fails)
	step += 1
	return false
