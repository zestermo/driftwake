extends SceneTree
## Shield Wall (greatsword): the flat planted as a wall stops blows from the front (not from behind) and C drops it;
## with a crewmate joined, shots at them stop at the wall while they're behind it and blows land at half.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var p
var mate
var step := 0
var until := 0
var fails := 0
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"weapon": "greatsword", "dummy": Vector3(0, 0, -4)})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func blow(on, ranged: bool) -> float:
	var hd = load("res://scripts/combat/hit_data.gd").new()
	hd.damage = 20.0
	hd.ranged = ranged
	var h0: float = on.health_component.current_health
	on._on_hit_received(hd, stage.dummy)
	return h0 - on.health_component.current_health


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var net = root.get_node("/root/Net")
	match step:
		0:
			p = stage.player
			check("alone: the wall goes up (%s)" % p.crew_tech.trigger(), p.current_state_name() == "CrewTechnique")
			until = TK.wait_secs(0.6)
		1:
			check("a blow from the front stops at it", blow(p, false) == 0.0)
			TK.act("crouch")
			until = TK.wait_ticks(4)
		2:
			check("C drops it (%s)" % p.current_state_name(), p.current_state_name() != "CrewTechnique" and not p.crew_tech.marked("wall"))
			p.crew_tech.cooldown = 0.0
			p.crew_tech.trigger()
			stage.dummy.global_position = p.global_position + Vector3(0, 0, 3)
			check("a blow from behind gets through", blow(p, false) > 0.0)
			stage.dummy.global_position = p.global_position + Vector3(0, 0, -4)
			p.crew_tech.cooldown = 0.0
			p.health_component.current_health = p.health_component.max_health
			var look: Dictionary = load("res://scripts/npc/character_look.gd").default_look()
			mate = load("res://scenes/player/player.gd").spawn_ai(stage, look, p.global_position + Vector3(0.6, 0.1, 1.6), 0.0, Node.new(), "Mate")
			until = TK.wait_secs(0.6)
		3:
			net.everyone("_all_crew_offer", [net.key_of(p), "shield_wall", 6.0])
			net.crew_join(p, mate)
			until = TK.wait_secs(0.4)
		4:
			check("your crewmate is behind the wall", mate.crew_tech.marked("walled") and p.current_state_name() == "CrewTechnique")
			check("a shot at them stops at the wall", blow(mate, true) == 0.0)
			var full: float = 20.0 * (1.0 - mate.damage_reduction())
			var got := blow(mate, false)
			check("a blow lands at half (%.1f of %.1f)" % [got, full], got > 0.0 and got <= full * 0.55)
			return TK.done(fails)
	step += 1
	return false
