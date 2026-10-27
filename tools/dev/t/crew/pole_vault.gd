extends SceneTree
## Pole Vault (polearm): your crewmate goes up the planted pole and vaults far along your aim; alone you vault far
## yourself; both come down without fall damage.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0
var y0 := 0.0
var hp0 := 0.0
var m0 := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "spear"})


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
			hp0 = p.health_component.current_health
			check("alone: Pole Vault (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(2.8)
		1:
			check("you vaulted far (%.1f m)" % -p.global_position.z, -p.global_position.z > 8.0)
			check("and down unhurt (%s)" % p.current_state_name(), p.is_on_floor() and p.health_component.current_health >= hp0)
			p.global_position = Vector3(0, y0, 20)
			p.reset_physics_interpolation()
			p.crew_tech.cooldown = 0.0
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(2, 0.1, 0), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.6)
		2:
			net.everyone("_all_crew_offer", [net.key_of(p), "pole_vault", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_ticks(8)
		3:
			var d: Vector3 = mate.global_position - p.global_position
			check("your crewmate is up the pole (%.2f up)" % d.y, mate.current_state_name() == "CrewTechnique" and d.y > 1.4)
			m0 = mate.global_position
			until = TK.wait_secs(3.0)
		4:
			check("it vaulted far (%.1f m)" % (m0.z - mate.global_position.z), m0.z - mate.global_position.z > 12.0)
			check("and landed (%s)" % mate.current_state_name(), mate.is_on_floor() and mate.current_state_name() in ["Idle", "Move"])
			return TK.done(fails)
	step += 1
	return false
