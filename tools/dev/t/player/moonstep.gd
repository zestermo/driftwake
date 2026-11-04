extends SceneTree
## Moonstep (Acrobatics 20, 1.30): out of air steps, jump kicks you ~3 m up off the air with both feet stamped on it,
## 10 stamina a kick and no air step; again and again for 2 s from the first kick, then no more till you've landed.
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
			TK.act("jump")
			until = TK.wait_ticks(4)
		3:
			check("out of air steps, jump is a Moonstep (%s)" % p.body_model.current_action(), p.body_model.current_action() == "moonstep")
			check("10 stamina (%.1f)" % (stam0 - p.stamina), absf(stam0 - p.stamina - 10.0) < 0.6)
			check("no air step spent", p.jumps_remaining == jumps0)
			until = TK.wait_secs(0.45)
		4:
			print("   rose %.2f m" % (top - y0))
			check("kicks ~3 m up", top - y0 > 2.2 and top - y0 < 4.0)
			stam0 = p.stamina
			TK.act("jump")
			until = TK.wait_ticks(4)
		5:
			check("...and again within 2 s", p.body_model.current_action() == "moonstep" and stam0 - p.stamina > 9.0)
			until = TK.wait_secs(1.9)
		6:
			stam0 = p.stamina
			TK.act("jump")
			until = TK.wait_ticks(6)
		7:
			check("past 2 s from the first: no more (%.1f)" % (stam0 - p.stamina), stam0 - p.stamina < 1.0 or p.is_on_floor())
			until = TK.wait_secs(2.5)
		8:
			check("landed", p.is_on_floor())
			TK.act("jump")
			until = TK.wait_secs(0.25)
		9:
			TK.act("jump")
			until = TK.wait_ticks(4)
		10:
			check("back after landing", p.body_model.current_action() == "moonstep")
			return TK.done(fails)
	step += 1
	return false
