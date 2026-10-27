extends SceneTree
## C sneaks out of combat stance; with the weapon out (black leg's kicks) it's the crew technique instead, and with
## nobody near it plays the self version at once (Wall Kick: up off the ground, down without fall damage).
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var y0 := 0.0
var hp0 := 0.0
var top := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if step == 5:
		top = maxf(top, p.global_position.y)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.unequip_weapon()
			p.learn_black_leg()
			y0 = p.global_position.y
			TK.act("crouch")
			until = TK.wait_ticks(6)
		1:
			check("out of stance C sneaks (%s)" % p.current_state_name(), p.current_state_name() == "Crouch")
			TK.act("crouch")
			until = TK.wait_ticks(6)
		2:
			check("C again stands", p.current_state_name() == "Idle")
			TK.act("ready_weapon")
			until = TK.wait_secs(0.7)
		3:
			check("kicks ready (%s, armed %s)" % [p.style(), p.armed], p.armed and p.style() == "black_leg")
			hp0 = p.health_component.current_health
			TK.act("crouch")
			until = TK.wait_ticks(3)
		4:
			check("in stance C is the crew technique, not a sneak (%s)" % p.current_state_name(), p.current_state_name() == "CrewTechnique")
			check("no crewmate near: no join zone", p.crew_tech.offer <= 0.0)
			check("the cooldown is running (%.1f)" % p.crew_tech.cooldown, p.crew_tech.cooldown > 85.0)
			until = TK.wait_secs(3.5)
		5:
			check("Wall Kick launched you (top %.1f m)" % (top - y0), top - y0 > 4.0)
			check("down on your feet (%s)" % p.current_state_name(), p.is_on_floor() and p.current_state_name() in ["Idle", "Move"])
			check("no fall damage", p.health_component.current_health >= hp0)
			return TK.done(fails)
	step += 1
	return false
