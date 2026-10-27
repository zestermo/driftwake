extends SceneTree
## Guardian Stance (katana): a crewmate joins and is under your guard; a blow on them is turned aside (no harm) and you
## come out at the attacker's side with an iai cut that lands.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0
var dhp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "katana", "dummy": Vector3(5, 0, -5)})


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
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(3, 0.1, -3), 0.0, Node.new(), "Mate")
			stage.dummy.health_component.max_health = 10000.0
			stage.dummy.health_component.current_health = 10000.0
			until = TK.wait_secs(0.6)
		1:
			net.everyone("_all_crew_offer", [net.key_of(p), "guardian_stance", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_secs(0.9)
		2:
			check("you're guarding them", p.crew_tech.marked("guarding"))
			check("they're under your guard", mate.crew_tech.marked("guarded"))
			check("only you lead a state; the ward stays free (%s)" % mate.current_state_name(), mate.current_state_name() != "CrewTechnique")
			hp0 = mate.health_component.current_health
			dhp0 = stage.dummy.health_component.current_health
			var hd = load("res://scripts/combat/hit_data.gd").new()
			hd.damage = 20.0
			hd.stagger_duration = 0.3
			mate._on_hit_received(hd, stage.dummy)
			until = TK.wait_ticks(3)
		3:
			check("the blow on your ward was turned aside", mate.health_component.current_health >= hp0)
			check("you answer it (%s %s)" % [p.current_state_name(), p.state_machine.current_state.get("role")], p.current_state_name() == "CrewTechnique" and p.state_machine.current_state.role == "counter")
			check("at the attacker's side (%.1f m)" % p.global_position.distance_to(stage.dummy.global_position), p.global_position.distance_to(stage.dummy.global_position) < 2.5)
			until = TK.wait_secs(0.4)
		4:
			check("your iai cut lands (%.0f)" % (dhp0 - stage.dummy.health_component.current_health), stage.dummy.health_component.current_health < dhp0 - 20.0)
			check("a guard turns at most 3 blows (%d left)" % int(mate.crew_tech.marks["guarded"]["n"]), int(mate.crew_tech.marks["guarded"]["n"]) == 2)
			return TK.done(fails)
	step += 1
	return false
