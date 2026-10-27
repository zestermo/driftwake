extends SceneTree
## Guardian Stance's self version (katana, nobody near): Counter Stance holds a guard for 3 s; a blow in it is turned
## and answered by the katana's riposte; nobody coming, the stance ends on its own.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var dhp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "katana", "dummy": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			stage.dummy.health_component.max_health = 10000.0
			stage.dummy.health_component.current_health = 10000.0
			check("alone: the self version (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(1.0)
		1:
			check("still on guard a second in", p.current_state_name() == "CrewTechnique" and p.power.buff("riposte"))
			hp0 = p.health_component.current_health
			dhp0 = stage.dummy.health_component.current_health
			var hd = load("res://scripts/combat/hit_data.gd").new()
			hd.damage = 20.0
			p._on_hit_received(hd, stage.dummy)
			until = TK.wait_secs(0.4)
		2:
			check("the blow turned", p.health_component.current_health >= hp0)
			check("and answered (%.0f)" % (dhp0 - stage.dummy.health_component.current_health), stage.dummy.health_component.current_health < dhp0)
			p.crew_tech.cooldown = 0.0
			until = TK.wait_secs(0.8)
		3:
			p.crew_tech.trigger()
			until = TK.wait_secs(3.3)
		4:
			check("nobody came: the stance ends by itself (%s)" % p.current_state_name(), p.current_state_name() in ["Idle", "Move"] and not p.power.buff("riposte"))
			return TK.done(fails)
	step += 1
	return false
