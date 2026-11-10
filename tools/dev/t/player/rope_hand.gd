extends SceneTree
## (1.31) Ropes in either hand: the hand on the anchor's side takes it (Humanoid.pick_rope_hand), the other when a
## weapon fills that hand; on the left the rope actions play mirrored (the left arm up the vine).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var h
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			h = stage.player.body_model
			var left_pt: Vector3 = h.global_position + h.global_basis * Vector3(-3, 4, -2)
			var right_pt: Vector3 = h.global_position + h.global_basis * Vector3(3, 4, -2)
			h.pick_rope_hand(left_pt)
			check("an anchor on the left: the left hand", h.rope_left and h.rope_hand() == h.hand_l)
			h.pick_rope_hand(right_pt)
			check("an anchor on the right: the right hand", not h.rope_left and h.rope_hand() == h.hand_r)
			h.pick_rope_hand(left_pt)
			h.hold("vine_hang")
			until = TK.wait_secs(0.5)
		1:
			print("  arm_l %.2f  arm_r %.2f" % [h.arm_l.rotation.x, h.arm_r.rotation.x])
			check("hanging on the left: the left arm up the vine", h.arm_l.rotation.x > 2.5 and h.arm_r.rotation.x < 2.0)
			h.stop_action()
			return TK.done(fails)
	step += 1
	return false
