extends SceneTree
## The Echo Fruit (1.27): its item, fruit and tree; Echo Step puts you behind the nearest foe; Shatter Note's long,
## narrow line staggers whoever is on it and misses whoever is beside it; at Reflex (150 uses, mastery 12) a dodge
## rings out by itself, at most once every 6 s. Sonar marks the foes near you.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -8), "role": "sword", "seed": 95}, {"post": Vector3(4, 0, -8), "role": "sword", "seed": 96}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var pr = p.progression
	var gs: Array = stage.camp.grunts
	match step:
		0:
			until = TK.wait_secs(2.0)
		1:
			check("the Echo Fruit's item, fruit and tree", load("res://scripts/loot/item_db.gd").get_item("echo_fruit") != null
				and load("res://scripts/powers/devil_fruits.gd").FRUITS.has("echo") and load("res://scripts/progression/skill_trees.gd").nodes().has("ec_note"))
			p.power.fruit = "echo"
			p.state_machine.force_state("Idle", {})
			p.global_position = Vector3(0, 3.05, 0)
			p.reset_physics_interpolation()
			gs[0].global_position = Vector3(0, 3.05, -5)
			gs[1].global_position = Vector3(5, 3.05, 5)
			p.power.loadout[0] = "echo_step"
			p.power.energy = p.power.max_energy()
			p.power.cooldowns.clear()
			check("Echo Step casts", p.power.try_cast(0))
			var behind: float = p.global_position.z - gs[0].global_position.z
			check("...out behind the nearest foe (%.1f m past it)" % -behind, behind < -1.0 and absf(p.global_position.x) < 1.0)
			until = TK.wait_ticks(2)
		2:
			# the line: one foe on it 6 m ahead, one 3 m beside it
			p.global_position = Vector3(0, 3.05, 0)
			p.reset_physics_interpolation()
			p.player_model.global_basis = Basis.IDENTITY
			gs[0].global_position = Vector3(0, 3.05, -6)
			gs[1].global_position = Vector3(3, 3.05, -4)
			p.power.loadout[1] = "shatter_note"
			p.power.cooldowns.clear()
			p.power.energy = p.power.max_energy()
			p.state_machine.force_state("Idle", {})
			check("Shatter Note casts", p.power.try_cast(1))
			until = TK.wait_ticks(3)
		3:
			check("...the foe on the line reels (state %d)" % int(gs[0].state), int(gs[0].state) in [int(gs[0].S.STAGGER), int(gs[0].S.HITSTUN)])
			check("...the one beside it doesn't (state %d)" % int(gs[1].state), not int(gs[1].state) in [int(gs[1].S.STAGGER), int(gs[1].S.HITSTUN)])
			check("at Active, a dodge doesn't ring", not p.echo_dodge_reflex())
			pr.uses["shatter_note"] = 150
			pr.mastery["echo"] = {"lv": 12, "xp": 0}
			check("Reflex: a dodge rings out by itself", p.echo_dodge_reflex())
			check("...not twice in 6 s", not p.echo_dodge_reflex())
			p.power.loadout[2] = "sonar"
			p.power.cooldowns.clear()
			p.power.energy = p.power.max_energy()
			p.state_machine.force_state("Idle", {})
			check("Sonar casts", p.power.try_cast(2))
			check("...every foe near marked (%d)" % gs.filter(func(e): return e.get_node_or_null("SonarMark") != null).size(), gs.all(func(e): return e.get_node_or_null("SonarMark") != null))
			return TK.done(fails)
	step += 1
	return false
