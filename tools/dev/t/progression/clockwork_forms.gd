extends SceneTree
## The Clockwork Fruit (1.27): its item, fruit and tree; Rewind puts you back where you stood 3 s ago; Time Stop holds
## the foe in front of you; at Reflex (150 uses, mastery 12) whoever strikes you is stopped by itself, at most once
## every 10 s.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var pos0 := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(0, 0, -6), "role": "sword", "seed": 91}]})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var pr = p.progression
	match step:
		0:
			until = TK.wait_secs(2.0)
		1:
			check("the Clockwork Fruit's item, fruit and tree", load("res://scripts/loot/item_db.gd").get_item("clockwork_fruit") != null
				and load("res://scripts/powers/devil_fruits.gd").FRUITS.has("clockwork") and load("res://scripts/progression/skill_trees.gd").nodes().has("cw_stop"))
			p.power.fruit = "clockwork"
			p.state_machine.force_state("Idle", {})
			pos0 = p.global_position
			until = TK.wait_secs(3.5)
		2:
			# walked off since: 8 m east
			p.global_position = pos0 + Vector3(8, 0, 0)
			p.reset_physics_interpolation()
			p.power.loadout[0] = "rewind"
			p.power.energy = p.power.max_energy()
			p.power.cooldowns.clear()
			check("Rewind casts", p.power.try_cast(0))
			var back := Vector2(p.global_position.x - pos0.x, p.global_position.z - pos0.z).length()
			check("...back where you stood (%.1f m off)" % back, back < 1.5)
			var g = stage.camp.grunts[0]
			p.player_model.global_basis = Basis.IDENTITY
			g.global_position = p.global_position + Vector3(0, 0, -3)
			p.power.loadout[1] = "time_stop"
			p.power.cooldowns.clear()
			p.state_machine.force_state("Idle", {})
			check("Time Stop casts", p.power.try_cast(1))
			until = TK.wait_ticks(3)
		3:
			var g = stage.camp.grunts[0]
			check("...the foe ahead held (state %d)" % int(g.state), int(g.state) in [int(g.S.STAGGER), int(g.S.HITSTUN)])
			check("at Active, no stop by itself", not p.clock_reflex(g))
			pr.uses["time_stop"] = 150
			pr.mastery["clockwork"] = {"lv": 12, "xp": 0}
			check("Reflex: whoever strikes you is stopped", p.clock_reflex(g))
			check("...not twice in 10 s", not p.clock_reflex(g))
			return TK.done(fails)
	step += 1
	return false
