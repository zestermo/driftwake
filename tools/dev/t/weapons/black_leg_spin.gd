extends SceneTree
## Handstand Spin (black-leg's fourth kick, bl_4): the split legs' plane is tipped off flat and the tip wanders round
## as it turns, so the feet don't ride one flat circle (the line between the feet slopes, both ways, and the way the
## high foot points changes from the first turn to the second); held forward, the spin creeps that way slowly.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var slope_min := 0.0
var slope_max := 0.0
## [best |slope|, the high foot's bearing] for each of the two turns
var peaks := [[0.0, 0.0], [0.0, 0.0]]
var from := Vector3.ZERO
var moved := Vector3.ZERO
var spin_t := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _foot(shin: Node3D) -> Vector3:
	return shin.global_transform * Vector3(0, shin.position.y, 0)


func _sample() -> void:
	var b = p.body_model
	if b.current_action() != "bl_4":
		return
	var u: float = float(b._action["t"]) / float(b._action["dur"])
	if u < 0.3 or u > 0.72:
		return
	var d: Vector3 = _foot(b.shin_r) - _foot(b.shin_l)
	var flat := Vector2(d.x, d.z).length()
	var s := d.y / maxf(flat, 0.01)
	slope_min = minf(slope_min, s)
	slope_max = maxf(slope_max, s)
	var turn := 0 if u < 0.45 else 1
	if absf(s) > peaks[turn][0]:
		var hi := d if s > 0.0 else -d
		peaks[turn] = [absf(s), atan2(hi.x, hi.z)]


func _process(_d: float) -> bool:
	if stage.up and step >= 2:
		_sample()
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.learn_black_leg()
			p.progression.master_all()
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		1:
			p.velocity = Vector3.ZERO
			p.remember_combo(3)
			p.state_machine.force_state("LightAttack", {})
			until = TK.wait_ticks(2)
		2:
			check("Handstand Spin (%s, %.2f s)" % [p.body_model.current_action(), float(p.body_model._action["dur"])],
				p.body_model.current_action() == "bl_4" and float(p.body_model._action["dur"]) < 1.0)
			TK.press("move_forward")
			until = TK.wait_secs(0.3)
		3:
			from = p.global_position
			spin_t = 0.4
			until = TK.wait_secs(spin_t)
		4:
			moved = p.global_position - from
			moved.y = 0.0
			TK.release("move_forward")
			until = TK.wait_secs(0.6)
		5:
			check("the legs' plane is tipped, both ways round the turn (slope %.2f .. %.2f)" % [slope_min, slope_max], slope_min < -0.12 and slope_max > 0.12)
			var drift := absf(wrapf(float(peaks[1][1]) - float(peaks[0][1]), -PI, PI))
			check("...and the tip wanders: the high foot points another way on the second turn (%.2f rad)" % drift, drift > 0.3)
			var v := moved.length() / spin_t
			check("held forward, it creeps forward slowly (%.2f m/s, %.2f ahead)" % [v, -moved.z], v > 0.6 and v < 1.6 and -moved.z > 0.2)
			return TK.done(fails)
	step += 1
	return false
