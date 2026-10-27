extends SceneTree
## Hurl (axe): your crewmate is swung round you by the arm once and thrown along your aim; alone, Hurled Slam leaps you
## forward into a ground slam that knocks down what's round where you land.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0
var dhp0 := 0.0
var y0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "boarding_axe", "dummy": Vector3(0, 0, -8)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var net = root.get_node("/root/Net")
	match step:
		0:
			p = stage.player
			# (the dummy's a target here, not a training yard's: no sparring partner)
			stage.dummy.remove_from_group("training_dummies")
			y0 = p.global_position.y
			stage.dummy.health_component.max_health = 10000.0
			stage.dummy.health_component.current_health = 10000.0
			dhp0 = 10000.0
			check("alone: Hurled Slam (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(2.5)
		1:
			check("you leapt forward (%.1f m)" % -p.global_position.z, -p.global_position.z > 4.0)
			check("the slam hit what was there (%.0f)" % (dhp0 - stage.dummy.health_component.current_health), stage.dummy.health_component.current_health < dhp0)
			p.global_position = Vector3(0, y0, 8)
			p.reset_physics_interpolation()
			p.crew_tech.cooldown = 0.0
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(2, 0.1, 0), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.6)
		2:
			net.everyone("_all_crew_offer", [net.key_of(p), "hurl", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_secs(0.35)
		3:
			var d: Vector3 = mate.global_position - p.global_position
			check("your crewmate is swung round you (%.2f m out, %.2f up)" % [Vector2(d.x, d.z).length(), d.y],
				mate.current_state_name() == "CrewTechnique" and absf(Vector2(d.x, d.z).length() - 1.4) < 0.2 and d.y > 0.4)
			check("behind you mid-swing", Vector2(d.x, d.z).normalized().dot(Vector2(0, -1)) < 0.5)
			until = TK.wait_secs(0.5)
		4:
			check("thrown along your aim (v %.1f, %.1f)" % [-mate.velocity.z, mate.velocity.y], -mate.velocity.z > 10.0 and mate.velocity.y > 2.0)
			return TK.done(fails)
	step += 1
	return false
