extends SceneTree
## Moonstep (Acrobatics 20): dodge in mid-air bursts you ~4.5 m straight up with both feet stamped on the air, for
## 18 stamina and no air step; once a jump (a second press does nothing), back once you've landed.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var y0 := 0.0
var top := -INF
var jumps0 := 0
var stam0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _physics_process(_d: float) -> bool:
	if p != null:
		top = maxf(top, p.global_position.y)
	return false


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.progression.owned["ac_moonstep"] = true
			until = TK.wait_secs(0.3)
		1:
			TK.act("jump")
			until = TK.wait_secs(0.3)
		2:
			y0 = p.global_position.y
			top = y0
			jumps0 = p.jumps_remaining
			stam0 = p.stamina
			TK.act("dodge")
			until = TK.wait_ticks(4)
		3:
			check("Moonstep plays (%s)" % p.body_model.current_action(), p.body_model.current_action() == "moonstep")
			check("18 stamina (%.1f)" % (stam0 - p.stamina), absf(stam0 - p.stamina - 18.0) < 0.6)
			check("no air step spent", p.jumps_remaining == jumps0)
			until = TK.wait_secs(0.75)
		4:
			print("   rose %.2f m" % (top - y0))
			check("bursts ~4.5 m up", top - y0 > 3.6 and top - y0 < 5.5)
			TK.act("dodge")
			until = TK.wait_ticks(6)
		5:
			check("once a jump", p.body_model.current_action() != "moonstep")
			until = TK.wait_secs(1.5)
		6:
			check("landed", p.is_on_floor())
			TK.act("jump")
			until = TK.wait_secs(0.25)
		7:
			TK.act("dodge")
			until = TK.wait_ticks(4)
		8:
			check("back after landing", p.body_model.current_action() == "moonstep")
			return TK.done(fails)
	step += 1
	return false
