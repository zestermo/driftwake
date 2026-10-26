extends SceneTree
## The air step (Geppo, Sky Walk): its own move, leaning into the step (1.23: not upright) but never a flip, the knee driven high; it gains height, and the
## next step takes the other foot.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var tip := 0.0
var knee := 0.0
var top := -INF
var y0 := 0.0
var foot := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if p != null and p.body_model.current_action() == "double_jump":
		var c: Dictionary = p.body_model._cur
		tip = maxf(tip, absf(wrapf(p.body_model.pivot.rotation.x, -PI, PI)))
		knee = maxf(knee, maxf((c["leg_l"] as Vector3).x, (c["leg_r"] as Vector3).x))
		top = maxf(top, p.global_position.y)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.progression.owned["m_geppo"] = true
			p.progression.owned["m_skywalk"] = true
			p.set_ability("double_jump", true)
			check("Sky Walk: three jumps (%d)" % p.max_jumps, p.max_jumps == 3)
			until = TK.wait_secs(0.3)
		1:
			TK.act("jump")
			until = TK.wait_secs(0.3)
		2:
			check("jumped (%s)" % p.current_state_name(), p.current_state_name() in ["Jump", "Fall"])
			y0 = p.global_position.y
			TK.press("jump")
			until = TK.wait_ticks(3)
		3:
			check("the air step is its own move (%s)" % p.body_model.current_action(), p.body_model.current_action() == "double_jump")
			foot = p.body_model.air_foot
			until = TK.wait_secs(0.35)
		4:
			check("no flip: it leans into the step, never over (%.2f rad at most)" % tip, tip > 0.2 and tip < 0.7)
			check("the stepping knee is driven high (%.2f)" % knee, knee > 1.6)
			check("the step gains height (%.2f m over where it kicked off)" % (top - y0), top - y0 > 0.8)
			TK.release("jump")
			until = TK.wait_ticks(2)
		5:
			TK.press("jump")
			until = TK.wait_ticks(4)
		6:
			TK.release("jump")
			check("Sky Walk's next step takes the other foot (%s, %.0f then %.0f)" % [p.current_state_name(), foot, p.body_model.air_foot], p.body_model.air_foot == -foot)
			until = TK.wait_secs(1.8)
			until = TK.wait_secs(1.5)
		7:
			check("down again (%s)" % p.current_state_name(), p.is_on_floor())
			check("upright after (%.2f)" % p.body_model.pivot.rotation.x, absf(p.body_model.pivot.rotation.x) < 0.1)
			return TK.done(fails)
	step += 1
	return false
