extends SceneTree
## Anvil (hammer): your crewmate stands on the hammer's head and your upswing bats them skyward; alone, Rebound slams
## the ground round you (it hits what's close) and rides the rebound up.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0
var y0 := 0.0
var top := 0.0
var dhp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "warhammer", "dummy": Vector3(0, 0, -2.2)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if step == 1:
		top = maxf(top, p.global_position.y)
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
			check("alone: Rebound (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(2.6)
		1:
			check("the slam hit what was close (%.0f)" % (dhp0 - stage.dummy.health_component.current_health), stage.dummy.health_component.current_health < dhp0)
			check("and you rode it up (%.1f m)" % (top - y0), top - y0 > 4.0)
			p.global_position = Vector3(0, y0, 10)
			p.reset_physics_interpolation()
			p.crew_tech.cooldown = 0.0
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(2, 0.1, 0), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.6)
		2:
			net.everyone("_all_crew_offer", [net.key_of(p), "anvil", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_ticks(8)
		3:
			var d: Vector3 = mate.global_position - p.global_position
			check("your crewmate stands on the hammer's head (%.2f out)" % Vector2(d.x, d.z).length(), mate.current_state_name() == "CrewTechnique" and Vector2(d.x, d.z).length() < 1.3)
			until = TK.wait_secs(0.45)
		4:
			check("batted skyward (vy %.1f)" % mate.velocity.y, mate.velocity.y > 15.0 and Vector2(mate.velocity.x, mate.velocity.z).length() < 8.0)
			return TK.done(fails)
	step += 1
	return false
