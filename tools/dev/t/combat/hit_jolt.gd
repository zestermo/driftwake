extends SceneTree
## (1.31) A blow that doesn't stagger still reads: Humanoid.jolt bends the upper body away from it on top of the
## pose (the legs untouched) and settles back within JOLT_SECS; a blow from the front bends the chest back.
## Measured against the same idle without a jolt (the idle breathes on its own).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var h
var step := 0
var until := 0
var fails := 0
var t0 := Vector3.ZERO
var leg0 := Vector3.ZERO
var peak := [0.0, 0.0]
var legs := [0.0, 0.0]


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up:
		return false
	if (step == 2 or step == 3) and h != null:
		var i := step - 2
		peak[i] = maxf(peak[i], h.torso.rotation.x - t0.x)
		legs[i] = maxf(legs[i], (h.leg_l.rotation - leg0).length())
	if TK.ticking(until):
		return false
	match step:
		0:
			h = stage.player.body_model
			until = TK.wait_secs(0.8)
		1:
			t0 = h.torso.rotation
			leg0 = h.leg_l.rotation
			until = TK.wait_secs(0.15)
		2:
			# the baseline window is over: now the same with a blow from in front (pushing back along +Z)
			t0 = h.torso.rotation
			leg0 = h.leg_l.rotation
			h.jolt(h.global_basis.z.normalized())
			until = TK.wait_secs(0.15)
		3:
			print("  chest back: idle ", snappedf(peak[0], 0.01), ", jolted ", snappedf(peak[1], 0.01), "; legs ", snappedf(legs[0], 0.001), " / ", snappedf(legs[1], 0.001))
			check("a blow from the front bends the chest back", peak[1] > peak[0] + 0.12)
			check("the legs carry on (only the upper body jolts)", legs[1] < legs[0] + 0.02)
			until = TK.wait_secs(0.4)
		4:
			check("it settles back", h._jolt <= 0.0)
			return TK.done(fails)
	step += 1
	return false
