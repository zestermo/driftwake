extends SceneTree
## The double jump (once unlocked): a somersault of its own, tipped well over mid-flip, down in the kneeling landing.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var seen := {}
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


func _process(_d: float) -> bool:
	if p != null and p.body_model._land > 0.0:
		seen["land:" + p.body_model._land_kind] = true
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.set_ability("double_jump", true)
			until = TK.wait_secs(0.3)
		1:
			seen.clear()
			TK.act("jump")
			until = TK.wait_secs(0.25)
		2:
			check("jumped (%s)" % p.current_state_name(), p.current_state_name() in ["Jump", "Fall"])
			TK.act("jump")
			until = TK.wait_ticks(3)
		3:
			check("the double jump is its own move (%s)" % p.body_model.current_action(), p.body_model.current_action() == "double_jump")
			until = TK.wait_secs(0.2)
		4:
			check("mid-somersault the body is tipped well over (%.2f)" % p.body_model.pivot.rotation.x, absf(wrapf(p.body_model.pivot.rotation.x, -PI, PI)) > 1.0)
			until = TK.wait_secs(1.2)
		5:
			check("a double jump comes down in the kneeling landing (%s)" % [seen.keys()], seen.has("land:double"))
			check("the somersault is undone after (%.2f)" % p.body_model.pivot.rotation.x, absf(p.body_model.pivot.rotation.x) < 0.1)
			return TK.done(fails)
	step += 1
	return false
