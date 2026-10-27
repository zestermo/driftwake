extends SceneTree
## Human Cannonball (fists): your crewmate launches from your cupped hands low and fast along your aim; alone,
## Cannonball sends you low and fast through the foes ahead, bowling over what's in the way.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0
var y0 := 0.0
var dhp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"dummy": Vector3(0, 0, -4)})


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
			p.unequip_weapon()
			TK.act("ready_weapon")
			y0 = p.global_position.y
			stage.dummy.health_component.max_health = 10000.0
			stage.dummy.health_component.current_health = 10000.0
			dhp0 = 10000.0
			until = TK.wait_secs(0.7)
		1:
			check("fists up (%s)" % p.style(), p.armed and p.style() == "fist")
			check("alone: Cannonball (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(0.3)
		2:
			check("low and fast (%.1f m/s)" % Vector2(p.velocity.x, p.velocity.z).length(), Vector2(p.velocity.x, p.velocity.z).length() > 12.0)
			until = TK.wait_secs(1.5)
		3:
			check("you bowled over what was in the way (%.0f)" % (dhp0 - stage.dummy.health_component.current_health), stage.dummy.health_component.current_health < dhp0)
			p.global_position = Vector3(0, y0, 12)
			p.reset_physics_interpolation()
			p.crew_tech.cooldown = 0.0
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(2, 0.1, 0), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.6)
		4:
			net.everyone("_all_crew_offer", [net.key_of(p), "human_cannonball", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_ticks(8)
		5:
			check("your crewmate's foot is in your hands", mate.current_state_name() == "CrewTechnique" and mate.global_position.distance_to(p.global_position) < 1.2)
			until = TK.wait_secs(0.35)
		6:
			check("launched low and fast (v %.1f, %.1f)" % [-mate.velocity.z, mate.velocity.y], -mate.velocity.z > 18.0 and mate.velocity.y < 8.0)
			return TK.done(fails)
	step += 1
	return false
