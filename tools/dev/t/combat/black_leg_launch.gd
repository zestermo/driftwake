extends SceneTree
## 1.23 black-leg's juggle set: Rising Heel launches the grunt in front; Sky Chase carries the captain up to it and
## kicks it higher (it stays juggled); Sky Chase with the stick held forward spikes it down and lands in a ring.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var g
var G
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var top := -INF
var y0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0.0, 0, -2.2), "role": "sword", "seed": 71}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func cast(id: String) -> void:
	p.power.energy = 999.0
	p.power.cooldowns.clear()
	p.state_machine.force_state("Technique", {"id": id, "slot": 0})


func _process(_d: float) -> bool:
	if p and step >= 4:
		top = maxf(top, p.global_position.y)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			if stage.camp.grunts.size() < 1:
				return false
			G = load("res://scripts/enemies/pirate_grunt.gd")
			p = stage.player
			g = stage.camp.grunts[0]
			stage.camera_rig.rotation.y = 0.0
			p.unequip_weapon()
			p.learn_black_leg()
			p.progression.master_all()
			p.hurtbox.monitorable = false
			TK.act("ready_weapon")
			until = TK.wait_secs(0.6)
		1:
			if not p.is_free():
				return false
			g.alert()
			# (facing away from the captain: no guard to turn it)
			g.facing.rotation.y = PI
			cast("rising_heel")
			until = TK.wait_secs(0.45)
		2:
			check("Rising Heel launches the grunt (state %d, %.2f m up)" % [g.state, g.global_position.y], g.state == G.S.AIR)
			until = TK.wait_secs(0.1)
		3:
			hp0 = g.health.current_health
			y0 = p.global_position.y
			cast("sky_chase")
			until = TK.wait_secs(0.45)
		4:
			check("Sky Chase carries you up to it (%.2f m)" % (top - y0), top - y0 > 1.0)
			check("...and kicks it (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			check("...higher: it's still up (state %d)" % g.state, g.state == G.S.AIR)
			until = TK.wait_secs(0.35)
		5:
			hp0 = g.health.current_health
			TK.press("move_forward")
			cast("sky_chase")
			until = TK.wait_ticks(4)
		6:
			TK.release("move_forward")
			until = TK.wait_secs(1.5)
		7:
			check("the spike lands (%.0f -> %.0f)" % [hp0, g.health.current_health], g.health.current_health < hp0)
			check("...and drives it down (state %d)" % g.state, g.state in [G.S.DOWN, G.S.GETUP, G.S.DEAD])
			check("you come down after it", p.is_on_floor())
			return TK.done(fails)
	step += 1
	return false
