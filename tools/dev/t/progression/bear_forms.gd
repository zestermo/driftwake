extends SceneTree
## The Bear Fruit (1.27): its item, fruit and tree; Bear Charge rushes you forward; Roar stuns the grunts round you; at
## Reflex (150 uses, mastery 12) you roar by yourself when surrounded (3+ foes close), not when they're few, at most
## once every 10 s.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var pos0 := Vector3.ZERO


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"hud": false, "grunts": [{"post": Vector3(3, 0, -6), "role": "sword", "seed": 81}, {"post": Vector3(-3, 0, -6), "role": "sword", "seed": 82},
		{"post": Vector3(0, 0, -9), "role": "sword", "seed": 83}, {"post": Vector3(5, 0, -9), "role": "sword", "seed": 84}]})


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
			check("the Bear Fruit's item, fruit and tree", load("res://scripts/loot/item_db.gd").get_item("bear_fruit") != null
				and load("res://scripts/powers/devil_fruits.gd").FRUITS.has("bear") and load("res://scripts/progression/skill_trees.gd").nodes().has("be_roar"))
			p.power.fruit = "bear"
			p.power.loadout[0] = "bear_charge"
			p.power.energy = p.power.max_energy()
			p.power.cooldowns.clear()
			pos0 = p.global_position
			p.state_machine.force_state("Idle", {})
			check("Bear Charge casts", p.power.try_cast(0))
			check("...a rush forward (%.1f m)" % Vector2(p.global_position.x - pos0.x, p.global_position.z - pos0.z).length(), Vector2(p.global_position.x - pos0.x, p.global_position.z - pos0.z).length() > 4.0)
			# the grunts round the captain
			var gs: Array = stage.camp.grunts.filter(func(g): return is_instance_valid(g))
			for i in range(gs.size()):
				gs[i].global_position = p.global_position + Vector3(cos(TAU * i / gs.size()), 0, sin(TAU * i / gs.size())) * 2.0
			until = TK.wait_ticks(3)
		2:
			check("at Active, no roar by itself", not p.bear_roar_reflex())
			pr.uses["bear_roar"] = 150
			pr.mastery["bear"] = {"lv": 12, "xp": 0}
			check("Reflex: surrounded, you roar by yourself", p.bear_roar_reflex())
			check("...not twice in 10 s", not p.bear_roar_reflex())
			return TK.done(fails)
	step += 1
	return false
