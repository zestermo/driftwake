extends SceneTree
## Skyward Kick end to end on one machine: you (black leg) open the zone, a captain-style crewmate (an AI, its own side
## run here as a guest's would be on theirs) joins; it steps onto your raised foot and your kick sends it high along
## your aim, and it comes down without fall damage. The cooldown starts for you only.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0
var y0 := 0.0
var top := 0.0
var hp0 := 0.0
var fwd := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if mate and step == 4:
		top = maxf(top, mate.global_position.y)
	if not stage.up or TK.ticking(until):
		return false
	match step:
		0:
			p = stage.player
			p.unequip_weapon()
			p.learn_black_leg()
			TK.act("ready_weapon")
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(2, 0.1, 0), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.8)
		1:
			var net = root.get_node("/root/Net")
			y0 = mate.global_position.y
			hp0 = mate.health_component.current_health
			net.everyone("_all_crew_offer", [net.key_of(p), "skyward_kick", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_ticks(8)
		2:
			check("you lead it (%s)" % p.current_state_name(), p.current_state_name() == "CrewTechnique" and p.state_machine.current_state.role == "lead")
			check("your crewmate plays its side (%s)" % mate.current_state_name(), mate.current_state_name() == "CrewTechnique" and mate.state_machine.current_state.role == "partner")
			check("your cooldown started", p.crew_tech.cooldown > 85.0)
			check("theirs didn't", mate.crew_tech.cooldown <= 0.0)
			var d: Vector3 = mate.global_position - p.global_position
			check("it stands on your raised foot (%.2f up)" % d.y, d.y > 0.4 and Vector2(d.x, d.z).length() < 1.2)
			check("the foot is up", p.body_model.current_action() == "ct_kick_launch")
			fwd = -p.player_model.global_basis.z
			until = TK.wait_secs(0.45)
		3:
			check("the kick sent it up (vy %.1f)" % mate.velocity.y, mate.velocity.y > 8.0)
			var hv := Vector3(mate.velocity.x, 0, mate.velocity.z)
			check("along your aim", hv.length() > 3.0 and hv.normalized().dot(Vector3(fwd.x, 0, fwd.z).normalized()) > 0.8)
			until = TK.wait_secs(4.0)
		4:
			check("high (%.1f m)" % (top - y0), top - y0 > 7.0)
			check("and down on its feet (%s)" % mate.current_state_name(), mate.is_on_floor() and mate.current_state_name() in ["Idle", "Move"])
			check("with no fall damage", mate.health_component.current_health >= hp0)
			check("you're back in stance (%s)" % p.current_state_name(), p.current_state_name() in ["Idle", "Move"])
			return TK.done(fails)
	step += 1
	return false
