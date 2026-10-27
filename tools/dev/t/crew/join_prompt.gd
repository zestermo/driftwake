extends SceneTree
## The joiner's side: inside a crewmate's open zone the HUD prompts F; F joins (the host takes the first ask) and you
## step onto their raised foot; their kick's launch signal sends you up, and you land without fall damage.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0
var y0 := 0.0
var hp0 := 0.0
var top := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"crew": [{"name": "Mate", "at": Vector3(0, 0, -2)}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if step == 4:
		top = maxf(top, p.global_position.y)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			mate = stage.crew[0]
			y0 = p.global_position.y
			hp0 = p.health_component.current_health
			check("out of the zone: no prompt", p.crew_tech.join_target == null)
			root.get_node("/root/Net").everyone("_all_crew_offer", [root.get_node("/root/Net").key_of(mate), "skyward_kick", 6.0])
			until = TK.wait_ticks(4)
		1:
			check("in a crewmate's zone: F to join", p.crew_tech.join_target == mate.crew_tech)
			check("the prompt says so (%s)" % stage.hud._prompt.text, stage.hud._prompt.visible and "Skyward Kick" in stage.hud._prompt.text)
			TK.act("interact")
			until = TK.wait_ticks(6)
		2:
			check("F joined (%s)" % p.current_state_name(), p.current_state_name() == "CrewTechnique")
			check("their zone is taken and closed", mate.crew_tech.taken and mate.crew_tech.offer <= 0.0)
			check("the prompt went", not stage.hud._prompt.visible)
			var d: Vector3 = p.global_position - mate.global_position
			check("perched on their raised foot (%.2f up, %.2f out)" % [d.y, Vector2(d.x, d.z).length()], d.y > 0.4 and Vector2(d.x, d.z).length() < 1.2)
			root.get_node("/root/Net").crew_signal(p, "launch", [Vector3(0, 18, -7), "", false])
			until = TK.wait_ticks(2)
		3:
			check("the kick launches you", p.velocity.y > 10.0)
			until = TK.wait_secs(4.0)
		4:
			check("high (%.1f m)" % (top - y0), top - y0 > 6.0)
			check("down on your feet (%s)" % p.current_state_name(), p.is_on_floor() and p.current_state_name() in ["Idle", "Move"])
			check("no fall damage", p.health_component.current_health >= hp0)
			return TK.done(fails)
	step += 1
	return false
