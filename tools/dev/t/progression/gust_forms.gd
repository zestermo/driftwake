extends SceneTree
## The Gust Fruit (1.27): its item, fruit and tree are there; Gale Dash rushes you forward; Gust Cone blows the foe
## ahead back; at Reflex (150 uses, mastery 12) the wind blows back whoever hits you, at most once every 6 s.
const TK := preload("res://tools/dev/test_kit.gd")
var stage
var step := 0
var until := 0
var fails := 0
var pos0 := Vector3.ZERO
var hp0 := 0.0


func _initialize() -> void:
	TK.seed_of(self)
	stage = TK.stage(self, {"dummy": true})


func check(what: String, cond: bool) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1


func _process(_d: float) -> bool:
	if not stage.up or TK.ticking(until):
		return false
	var p = stage.player
	var pr = p.progression
	var d = stage.dummy
	match step:
		0:
			check("the Gust Fruit's item, fruit and tree", load("res://scripts/loot/item_db.gd").get_item("gust_fruit") != null
				and load("res://scripts/powers/devil_fruits.gd").FRUITS.has("gust") and load("res://scripts/progression/skill_trees.gd").nodes().has("gu_dash"))
			p.power.fruit = "gust"
			p.power.loadout[0] = "gale_dash"
			p.power.loadout[1] = "gust_cone"
			p.power.energy = p.power.max_energy()
			p.power.cooldowns.clear()
			# (facing away from the dummy for the blink: open ground)
			p.player_model.look_at(p.global_position + (p.global_position - d.global_position), Vector3.UP)
			pos0 = p.global_position
			p.state_machine.force_state("Idle", {})
			check("Gale Dash casts", p.power.try_cast(0))
			until = TK.wait_ticks(2)
		1:
			var moved: float = Vector2(p.global_position.x - pos0.x, p.global_position.z - pos0.z).length()
			check("...a blink forward (%.1f m)" % moved, moved > 6.0)
			hp0 = d.health.current_health if d.get("health") else 0.0
			var struck: Array = p.power.gust_cone(d.global_position + Vector3(0, 0, 2.0), Vector3(0, 0, -1), 6.0, 10.0)
			check("Gust Cone blows the foe back (%d struck)" % struck.size(), struck.size() >= 1)
			check("at Active, being hit leaps nowhere", not p.gust_reflex(d))
			pr.uses["gust_cone"] = 150
			pr.mastery["gust"] = {"lv": 12, "xp": 0}
			check("Reflex: the wind blows back whoever hits you", p.gust_reflex(d))
			check("...not twice in 6 s", not p.gust_reflex(d))
			return TK.done(fails)
	step += 1
	return false
