extends SceneTree
## Crossed Blades (cutlass): a crewmate steps onto your braced blade and is flung off it up and forward; alone, Blade
## Vault leaps you forward into a leaping slash that cuts what's round where you land.
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
	stage = TK.stage(self, {"weapon": "cutlass", "dummy": Vector3(0, 0, -7)})


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
			y0 = p.global_position.y
			stage.dummy.health_component.max_health = 10000.0
			stage.dummy.health_component.current_health = 10000.0
			dhp0 = 10000.0
			check("alone: Blade Vault (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(2.5)
		1:
			check("you vaulted forward (%.1f m)" % -p.global_position.z, -p.global_position.z > 4.0)
			check("down on your feet (%s)" % p.current_state_name(), p.is_on_floor() and p.current_state_name() in ["Idle", "Move"])
			check("the leaping slash cut what was there (%.0f)" % (dhp0 - stage.dummy.health_component.current_health), stage.dummy.health_component.current_health < dhp0)
			p.global_position = Vector3(0, y0, 6)
			p.reset_physics_interpolation()
			p.crew_tech.cooldown = 0.0
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(2, 0.1, 0), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.6)
		2:
			net.everyone("_all_crew_offer", [net.key_of(p), "crossed_blades", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_ticks(8)
		3:
			var d: Vector3 = mate.global_position - p.global_position
			check("your crewmate stands on the braced blade (%.2f up)" % d.y, mate.current_state_name() == "CrewTechnique" and d.y > 1.0)
			until = TK.wait_secs(0.55)
		4:
			check("flung up and forward (v %.1f, %.1f)" % [mate.velocity.y, -mate.velocity.z], mate.velocity.y > 5.0 and -mate.velocity.z > 5.0)
			return TK.done(fails)
	step += 1
	return false
