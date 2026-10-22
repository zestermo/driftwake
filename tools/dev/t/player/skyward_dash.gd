extends SceneTree
## Skyward Dash (Acrobatics): after a Breakfall the dodge is an air dash that carries you a set distance level
## through the air, and you get extra air steps to climb back with.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var a := Vector3.INF
var b := Vector3.INF
var steps0 := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _physics_process(_d: float) -> bool:
	if p != null:
		if p.current_state_name() == "Dodge" and a == Vector3.INF:
			a = p.global_position
		elif a != Vector3.INF and b == Vector3.INF and p.current_state_name() != "Dodge":
			b = p.global_position
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.progression.owned["m_geppo"] = true
			p.progression.owned["ac_breakfall"] = true
			p.progression.owned["ac_skydash"] = true
			p.set_ability("double_jump", true)
			p.global_position.y += 12.0
			p.reset_physics_interpolation()
			p.knock_down(Vector3(4.0, 3.0, 0.0))
			until = TK.wait_secs(0.3)
		1:
			steps0 = p.max_jumps
			TK.act("jump")
			until = TK.wait_ticks(3)
		2:
			check("righted by Breakfall (%s)" % p.current_state_name(), p.current_state_name() == "Fall")
			check("Skyward Dash: extra air steps (%d, max %d)" % [p.jumps_remaining, steps0], p.jumps_remaining >= 2)
			TK.act("dodge")
			until = TK.wait_secs(0.6)
		3:
			var d := Vector2(b.x - a.x, b.z - a.z).length()
			check("an air dash (seen: %s)" % (a != Vector3.INF), a != Vector3.INF and b != Vector3.INF)
			check("the dash carries you %.1f m (set: %.1f)" % [d, p.state_machine.states["dodge"].AIR_DASH_DIST], absf(d - p.state_machine.states["dodge"].AIR_DASH_DIST) < 0.8)
			check("level through the air (%.2f m drop)" % (a.y - b.y), a.y - b.y < 0.5)
			check("only one dash a recovery", not p.skyward_dash)
			return TK.done(fails)
	step += 1
	return false
